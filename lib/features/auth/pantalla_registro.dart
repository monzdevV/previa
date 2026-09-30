import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';
import '../../data/repositories/repositorio_auth.dart';
import '../party/estados_pantalla.dart';
import 'aparece.dart';
import 'cabecera_auth.dart';
import 'fuerza_contrasena.dart';
import 'validadores.dart';

class PantallaRegistro extends ConsumerStatefulWidget {
  const PantallaRegistro({super.key});

  @override
  ConsumerState<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends ConsumerState<PantallaRegistro> {
  final _formulario = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _username = TextEditingController();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();

  final _focoNombre = FocusNode();
  final _focoUsername = FocusNode();
  final _focoFecha = FocusNode();
  final _focoCorreo = FocusNode();
  final _focoContrasena = FocusNode();
  final _focoCondiciones = FocusNode();

  DateTime? _fechaNacimiento;
  bool _aceptaCondiciones = false;
  bool _cargando = false;
  bool _oculta = true;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _username.dispose();
    _correo.dispose();
    _contrasena.dispose();
    _focoNombre.dispose();
    _focoUsername.dispose();
    _focoFecha.dispose();
    _focoCorreo.dispose();
    _focoContrasena.dispose();
    _focoCondiciones.dispose();
    super.dispose();
  }

  String? _validarNombre(String? v) => (v == null || v.trim().length < 2)
      ? 'Escribe al menos 2 caracteres'
      : null;

  String? _validarUsername(String? v) => (v == null || v.trim().length < 3)
      ? 'Mínimo 3 caracteres, sin espacios'
      : null;

  String? _validarCorreo(String? v) =>
      esCorreoValido(v) ? null : 'Escribe un correo válido';

  String? _validarContrasena(String? v) =>
      (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null;

  /// Lleva el foco (y la vista) a un campo. Con el teclado abierto el campo
  /// inválido puede quedar oculto; los que no son de texto (fecha, casilla)
  /// no se desplazan solos, por eso se pide la visibilidad explícitamente.
  void _enfocar(FocusNode nodo) {
    nodo.requestFocus();
    final contexto = nodo.context;
    if (contexto != null) {
      Scrollable.ensureVisible(
        contexto,
        alignment: 0.3,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 250),
      );
    }
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      // Se abre directamente en el año en que se cumplen los 18: el gesto
      // por defecto no debe facilitar mentir sobre la edad.
      initialDate:
          _fechaNacimiento ?? DateTime(hoy.year - 18, hoy.month, hoy.day),
      firstDate: DateTime(hoy.year - 100),
      lastDate: hoy,
      locale: const Locale('es', 'ES'),
      helpText: 'Tu fecha de nacimiento',
    );
    if (elegida != null) setState(() => _fechaNacimiento = elegida);
  }

  Future<void> _registrar() async {
    // Se valida en el orden en que aparecen los campos y el foco va al
    // primero que falle.
    if (!_formulario.currentState!.validate()) {
      if (_validarNombre(_nombre.text) != null) {
        _enfocar(_focoNombre);
      } else if (_validarUsername(_username.text) != null) {
        _enfocar(_focoUsername);
      } else if (_validarCorreo(_correo.text) != null) {
        _enfocar(_focoCorreo);
      } else {
        _enfocar(_focoContrasena);
      }
      return;
    }

    if (_fechaNacimiento == null) {
      setState(() => _error = 'Necesitamos tu fecha de nacimiento.');
      _enfocar(_focoFecha);
      return;
    }
    if (!RepositorioAuth.esMayorDeEdad(_fechaNacimiento!)) {
      setState(() => _error = 'Previa es solo para mayores de 18 años.');
      _enfocar(_focoFecha);
      return;
    }
    if (!_aceptaCondiciones) {
      setState(
          () => _error = 'Tienes que aceptar las condiciones para continuar.');
      _enfocar(_focoCondiciones);
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      await ref.read(repositorioAuthProvider).registrar(
            correo: _correo.text,
            contrasena: _contrasena.text,
            username: _username.text,
            nombre: _nombre.text,
            fechaNacimiento: _fechaNacimiento!,
          );
      if (mounted) context.go(Rutas.inicio);
    } on ErrorPrevia catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final formatoFecha = DateFormat('d MMMM y', 'es_ES');
    const margenTeclado = EdgeInsets.only(bottom: 160);

    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(EspaciadoPrevia.l),
          child: Form(
            key: _formulario,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Aparece(
                  child: CabeceraAuth(
                    icono: Icons.celebration_outlined,
                    titulo: 'Crea tu cuenta',
                    subtitulo:
                        'Solo lo imprescindible. Nada de teléfono ni apellidos.',
                  ),
                ),
                const SizedBox(height: EspaciadoPrevia.xl),

                const Aparece(orden: 1, child: EtiquetaSeccion('Sobre ti')),
                const SizedBox(height: EspaciadoPrevia.m),

                Aparece(
                  orden: 1,
                  child: TextFormField(
                    controller: _nombre,
                    focusNode: _focoNombre,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    scrollPadding: margenTeclado,
                    decoration: const InputDecoration(
                      labelText: 'Cómo te llamas',
                      hintText: 'Tu nombre o como quieras que te llamen',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: _validarNombre,
                    onFieldSubmitted: (_) => _focoUsername.requestFocus(),
                  ),
                ),
                const SizedBox(height: EspaciadoPrevia.m),

                Aparece(
                  orden: 2,
                  child: TextFormField(
                    controller: _username,
                    focusNode: _focoUsername,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    scrollPadding: margenTeclado,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
                      LengthLimitingTextInputFormatter(20),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Nombre de usuario',
                      hintText: 'sin espacios, en minúsculas',
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                    validator: _validarUsername,
                    onFieldSubmitted: (_) => _focoCorreo.requestFocus(),
                  ),
                ),
                const SizedBox(height: EspaciadoPrevia.m),

                // Fecha de nacimiento. Un InkWell suelto no se anuncia como
                // botón ni dice su valor: se envuelve con una etiqueta que
                // incluye la fecha elegida.
                Aparece(
                  orden: 3,
                  child: Semantics(
                    button: true,
                    excludeSemantics: true,
                    label: _fechaNacimiento == null
                        ? 'Fecha de nacimiento, sin elegir'
                        : 'Fecha de nacimiento, '
                            '${formatoFecha.format(_fechaNacimiento!)}',
                    onTap: _elegirFecha,
                    child: InkWell(
                      focusNode: _focoFecha,
                      onTap: _elegirFecha,
                      borderRadius:
                          BorderRadius.circular(EspaciadoPrevia.radio),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Fecha de nacimiento',
                          prefixIcon: Icon(Icons.cake_outlined),
                        ),
                        child: Text(
                          _fechaNacimiento == null
                              ? 'Toca para elegir'
                              : formatoFecha.format(_fechaNacimiento!),
                          style: TextStyle(
                            color: _fechaNacimiento == null
                                ? ColoresPrevia.textoTenue
                                : ColoresPrevia.texto,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: EspaciadoPrevia.xs),
                Padding(
                  padding: const EdgeInsets.only(left: EspaciadoPrevia.s),
                  child: Text(
                    'Solo guardamos tu edad. Nadie ve tu fecha de nacimiento.',
                    style: textos.bodyMedium?.copyWith(
                      fontSize: 13,
                      color: ColoresPrevia.textoTenue,
                    ),
                  ),
                ),
                const SizedBox(height: EspaciadoPrevia.l),

                const EtiquetaSeccion('Tu acceso'),
                const SizedBox(height: EspaciadoPrevia.m),

                TextFormField(
                  controller: _correo,
                  focusNode: _focoCorreo,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  scrollPadding: margenTeclado,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                  validator: _validarCorreo,
                  onFieldSubmitted: (_) => _focoContrasena.requestFocus(),
                ),
                const SizedBox(height: EspaciadoPrevia.m),

                TextFormField(
                  controller: _contrasena,
                  focusNode: _focoContrasena,
                  obscureText: _oculta,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  scrollPadding: margenTeclado,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    hintText: 'mínimo 6 caracteres',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip:
                          _oculta ? 'Mostrar contraseña' : 'Ocultar contraseña',
                      icon: Icon(
                        _oculta
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => _oculta = !_oculta),
                    ),
                  ),
                  validator: _validarContrasena,
                  onFieldSubmitted: (_) => _enfocar(_focoCondiciones),
                ),
                IndicadorFuerzaContrasena(controlador: _contrasena),
                const SizedBox(height: EspaciadoPrevia.m),

                // Consentimiento explicito, casilla sin premarcar (RGPD).
                // Texto a 14 (antes 13) y fila con altura mínima de 48.
                CheckboxListTile(
                  focusNode: _focoCondiciones,
                  value: _aceptaCondiciones,
                  onChanged: (v) =>
                      setState(() => _aceptaCondiciones = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: ColoresPrevia.primario,
                  title: Text(
                    'Soy mayor de 18 años y acepto las condiciones de uso y la '
                    'política de privacidad.',
                    style: textos.bodyMedium?.copyWith(fontSize: 14),
                  ),
                ),
                const MensajeResponsable(),

                if (_error != null) ...[
                  const SizedBox(height: EspaciadoPrevia.s),
                  AvisoError(_error!),
                ],

                const SizedBox(height: EspaciadoPrevia.l),
                FilledButton(
                  onPressed: _cargando ? null : _registrar,
                  child: _cargando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                            semanticsLabel: 'Creando la cuenta',
                          ),
                        )
                      : const Text('Crear cuenta'),
                ),

                TextButton(
                  onPressed: () => context.pushReplacement(Rutas.entrar),
                  child: const Text('Ya tengo cuenta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
