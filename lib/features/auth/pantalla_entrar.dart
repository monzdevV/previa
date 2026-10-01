import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';
import '../../data/repositories/repositorio_auth.dart';
import 'aparece.dart';
import 'piezas_acceso.dart';
import 'validadores.dart';

/// Volver a entrar: dos campos y un boton, con la misma voz que el registro
/// para que las dos puertas se reconozcan como la misma casa.
class PantallaEntrar extends ConsumerStatefulWidget {
  const PantallaEntrar({super.key});

  @override
  ConsumerState<PantallaEntrar> createState() => _PantallaEntrarState();
}

class _PantallaEntrarState extends ConsumerState<PantallaEntrar> {
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  final _focoContrasena = FocusNode();

  bool _cargando = false;
  bool _oculta = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // El boton se enciende en cuanto los dos campos tienen algo; mejor eso
    // que dejar pulsar y responder con "escribe tu contraseña".
    _correo.addListener(_repintar);
    _contrasena.addListener(_repintar);
  }

  void _repintar() => setState(() {});

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    _focoContrasena.dispose();
    super.dispose();
  }

  bool get _completo =>
      _correo.text.trim().isNotEmpty && _contrasena.text.isNotEmpty;

  Future<void> _entrar() async {
    if (!_completo || _cargando) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      await ref
          .read(repositorioAuthProvider)
          .entrar(correo: _correo.text, contrasena: _contrasena.text);
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      context.go(Rutas.inicio);
    } on ErrorPrevia catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _olvidada() {
    mostrarHoja<void>(
      context,
      builder: (_) => _HojaRecuperar(correoInicial: _correo.text.trim()),
    );
  }

  void _volver() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Rutas.bienvenida);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final textos = Theme.of(context).textTheme;
    final conTeclado = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      body: SafeArea(
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  left: EspaciadoPrevia.xs,
                  top: EspaciadoPrevia.xs,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: VolverAcceso(onPressed: _volver),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    EspaciadoPrevia.l,
                    conTeclado ? EspaciadoPrevia.m : EspaciadoPrevia.l,
                    EspaciadoPrevia.l,
                    EspaciadoPrevia.m,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Aparece(
                        child: Semantics(
                          header: true,
                          child: Titular(
                            'Vuelve a la noche',
                            tamano: conTeclado ? 34 : 42,
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: EspaciadoPrevia.s + EspaciadoPrevia.xs,
                      ),
                      Aparece(
                        orden: 1,
                        child: Text(
                          'Tus planes y tus conversaciones siguen aquí.',
                          style: textos.bodyLarge,
                        ),
                      ),
                      SizedBox(
                        height: conTeclado
                            ? EspaciadoPrevia.l
                            : EspaciadoPrevia.xl,
                      ),
                      Aparece(
                        orden: 2,
                        child: TextField(
                          controller: _correo,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: const [
                            AutofillHints.email,
                            AutofillHints.username,
                          ],
                          textInputAction: TextInputAction.next,
                          onEditingComplete: _focoContrasena.requestFocus,
                          decoration: const InputDecoration(
                            // "o usuario": la cuenta de demostracion entra
                            // escribiendo solo "admin".
                            labelText: 'Correo o usuario',
                            prefixIcon: Icon(Icons.mail_outline_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(height: EspaciadoPrevia.m),
                      Aparece(
                        orden: 3,
                        child: TextField(
                          controller: _contrasena,
                          focusNode: _focoContrasena,
                          obscureText: _oculta,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          onEditingComplete: _entrar,
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              tooltip: _oculta
                                  ? 'Mostrar contraseña'
                                  : 'Ocultar contraseña',
                              icon: Icon(
                                _oculta
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () =>
                                  setState(() => _oculta = !_oculta),
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _olvidada,
                          style: TextButton.styleFrom(
                            foregroundColor: c.textoSuave,
                            minimumSize: const Size(48, 48),
                          ),
                          child: const Text('¿Olvidaste la contraseña?'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // El boton vive fuera del scroll: con el teclado abierto se
              // queda justo encima, al alcance del pulgar, en vez de
              // esconderse debajo.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  EspaciadoPrevia.l,
                  EspaciadoPrevia.s,
                  EspaciadoPrevia.l,
                  EspaciadoPrevia.s,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedSize(
                      duration: MovimientoPrevia.rapido,
                      curve: MovimientoPrevia.curva,
                      child: _error == null
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(
                                bottom: EspaciadoPrevia.s + EspaciadoPrevia.xs,
                              ),
                              child: AvisoError(_error!),
                            ),
                    ),
                    BotonAcceso(
                      texto: 'Entrar',
                      cargando: _cargando,
                      mientrasCarga: 'Entrando',
                      onPressed: _completo ? _entrar : null,
                    ),
                    if (!conTeclado)
                      TextButton(
                        onPressed: () =>
                            context.pushReplacement(Rutas.registro),
                        style: TextButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text('No tengo cuenta todavía'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Recuperar la contraseña sin salir de la pantalla: una hoja con el correo
/// ya escrito si la persona lo habia puesto arriba.
class _HojaRecuperar extends ConsumerStatefulWidget {
  const _HojaRecuperar({required this.correoInicial});

  final String correoInicial;

  @override
  ConsumerState<_HojaRecuperar> createState() => _HojaRecuperarState();
}

class _HojaRecuperarState extends ConsumerState<_HojaRecuperar> {
  late final _correo = TextEditingController(
    // "admin" no es un correo: mejor el campo vacio que uno que va a fallar.
    text: widget.correoInicial.contains('@') ? widget.correoInicial : '',
  );

  bool _cargando = false;
  bool _enviado = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _correo.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _correo.dispose();
    super.dispose();
  }

  bool get _valido => esCorreoValido(_correo.text);

  Future<void> _enviar() async {
    if (!_valido || _cargando) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await ref.read(repositorioAuthProvider).recuperarContrasena(_correo.text);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _enviado = true);
    } on ErrorPrevia catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Padding(
      // La hoja sube con el teclado en lugar de quedar tapada por el.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          EspaciadoPrevia.l,
          0,
          EspaciadoPrevia.l,
          EspaciadoPrevia.l,
        ),
        child: AnimatedSwitcher(
          duration: MovimientoPrevia.normal,
          switchInCurve: MovimientoPrevia.curva,
          child: _enviado
              ? Column(
                  key: const ValueKey('enviado'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Pegatina('📬', tamano: 56, giro: -0.15),
                    ),
                    const SizedBox(height: EspaciadoPrevia.m),
                    const Titular('Mira tu correo', tamano: 32),
                    const SizedBox(height: EspaciadoPrevia.s),
                    Text(
                      'Si ${_correo.text.trim()} tiene cuenta, te llegará un '
                      'enlace para poner una contraseña nueva.',
                      style: textos.bodyLarge,
                    ),
                    const SizedBox(height: EspaciadoPrevia.l),
                    BotonAcceso(
                      texto: 'Vale',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                )
              : Column(
                  key: const ValueKey('pedir'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Titular('Nueva contraseña', tamano: 32),
                    const SizedBox(height: EspaciadoPrevia.s),
                    Text(
                      'Te mandamos un enlace para cambiarla.',
                      style: textos.bodyLarge,
                    ),
                    const SizedBox(height: EspaciadoPrevia.l),
                    TextField(
                      controller: _correo,
                      autofocus: _correo.text.isEmpty,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.send,
                      onEditingComplete: _enviar,
                      decoration: const InputDecoration(
                        labelText: 'Correo',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: EspaciadoPrevia.m),
                      AvisoError(_error!),
                    ],
                    const SizedBox(height: EspaciadoPrevia.l),
                    BotonAcceso(
                      texto: 'Mandar enlace',
                      cargando: _cargando,
                      mientrasCarga: 'Mandando el enlace',
                      onPressed: _valido ? _enviar : null,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
