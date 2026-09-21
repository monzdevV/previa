import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';
import '../../data/repositories/repositorio_auth.dart';

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
    super.dispose();
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
    if (!_formulario.currentState!.validate()) return;

    if (_fechaNacimiento == null) {
      setState(() => _error = 'Necesitamos tu fecha de nacimiento.');
      return;
    }
    if (!RepositorioAuth.esMayorDeEdad(_fechaNacimiento!)) {
      setState(() => _error = 'Previa es solo para mayores de 18 años.');
      return;
    }
    if (!_aceptaCondiciones) {
      setState(
        () => _error = 'Tienes que aceptar las condiciones para continuar.',
      );
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      await ref
          .read(repositorioAuthProvider)
          .registrar(
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

    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(EspaciadoPrevia.l),
          child: Form(
            key: _formulario,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Crea tu cuenta', style: textos.headlineMedium),
                const SizedBox(height: EspaciadoPrevia.s),
                Text(
                  'Solo lo imprescindible. Nada de teléfono ni apellidos.',
                  style: textos.bodyMedium,
                ),
                const SizedBox(height: EspaciadoPrevia.xl),

                TextFormField(
                  controller: _nombre,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Cómo te llamas',
                    hintText: 'Tu nombre o como quieras que te llamen',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Escribe al menos 2 caracteres'
                      : null,
                ),
                const SizedBox(height: EspaciadoPrevia.m),

                TextFormField(
                  controller: _username,
                  autocorrect: false,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
                    LengthLimitingTextInputFormatter(20),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Nombre de usuario',
                    hintText: 'sin espacios, en minúsculas',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                  validator: (v) => (v == null || v.trim().length < 3)
                      ? 'Mínimo 3 caracteres, sin espacios'
                      : null,
                ),
                const SizedBox(height: EspaciadoPrevia.m),

                // Fecha de nacimiento
                InkWell(
                  onTap: _elegirFecha,
                  borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
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
                const SizedBox(height: EspaciadoPrevia.xs),
                Padding(
                  padding: const EdgeInsets.only(left: EspaciadoPrevia.s),
                  child: Text(
                    'Solo guardamos tu edad. Nadie ve tu fecha de nacimiento.',
                    style: textos.bodyMedium?.copyWith(
                      fontSize: 12,
                      color: ColoresPrevia.textoTenue,
                    ),
                  ),
                ),
                const SizedBox(height: EspaciadoPrevia.m),

                TextFormField(
                  controller: _correo,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Escribe un correo válido'
                      : null,
                ),
                const SizedBox(height: EspaciadoPrevia.m),

                TextFormField(
                  controller: _contrasena,
                  obscureText: _oculta,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    hintText: 'mínimo 6 caracteres',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _oculta
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => _oculta = !_oculta),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 6)
                      ? 'Mínimo 6 caracteres'
                      : null,
                ),
                const SizedBox(height: EspaciadoPrevia.m),

                // Consentimiento explicito, casilla sin premarcar (RGPD).
                CheckboxListTile(
                  value: _aceptaCondiciones,
                  onChanged: (v) =>
                      setState(() => _aceptaCondiciones = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: ColoresPrevia.primario,
                  title: Text(
                    'Soy mayor de 18 años y acepto las condiciones de uso y la '
                    'política de privacidad.',
                    style: textos.bodyMedium?.copyWith(fontSize: 13),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: EspaciadoPrevia.s),
                  Container(
                    padding: const EdgeInsets.all(EspaciadoPrevia.m),
                    decoration: BoxDecoration(
                      color: ColoresPrevia.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(
                        EspaciadoPrevia.radio,
                      ),
                      border: Border.all(
                        color: ColoresPrevia.error.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: ColoresPrevia.error,
                          size: 20,
                        ),
                        const SizedBox(width: EspaciadoPrevia.s),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: ColoresPrevia.error,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
