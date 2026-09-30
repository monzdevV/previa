import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';
import '../../data/repositories/repositorio_auth.dart';
import '../party/estados_pantalla.dart';
import 'aparece.dart';
import 'cabecera_auth.dart';
import 'validadores.dart';

class PantallaEntrar extends ConsumerStatefulWidget {
  const PantallaEntrar({super.key});

  @override
  ConsumerState<PantallaEntrar> createState() => _PantallaEntrarState();
}

class _PantallaEntrarState extends ConsumerState<PantallaEntrar> {
  final _formulario = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  final _focoCorreo = FocusNode();
  final _focoContrasena = FocusNode();

  bool _cargando = false;
  bool _oculta = true;
  String? _error;

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    _focoCorreo.dispose();
    _focoContrasena.dispose();
    super.dispose();
  }

  String? _validarCorreo(String? v) =>
      esCorreoValido(v) ? null : 'Escribe un correo válido';

  String? _validarContrasena(String? v) =>
      (v == null || v.isEmpty) ? 'Escribe tu contraseña' : null;

  Future<void> _entrar() async {
    if (!_formulario.currentState!.validate()) {
      // Con el teclado abierto el primer error puede quedar fuera de la
      // vista: se enfoca el primer campo inválido (y el campo se desplaza
      // solo hasta quedar visible).
      if (_validarCorreo(_correo.text) != null) {
        _focoCorreo.requestFocus();
      } else {
        _focoContrasena.requestFocus();
      }
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      await ref.read(repositorioAuthProvider).entrar(
            correo: _correo.text,
            contrasena: _contrasena.text,
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
    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: SingleChildScrollView(
          // Cierra el teclado al arrastrar y deja aire bajo el campo activo
          // para que el botón y los errores no queden tapados.
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(EspaciadoPrevia.l),
          child: Form(
            key: _formulario,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Aparece(
                  child: CabeceraAuth(
                    icono: Icons.nightlife_outlined,
                    titulo: 'Bienvenida de vuelta',
                    subtitulo: 'Entra para ver qué se cuece cerca de ti.',
                  ),
                ),
                const SizedBox(height: EspaciadoPrevia.xl),

                Aparece(
                  orden: 1,
                  child: TextFormField(
                    controller: _correo,
                    focusNode: _focoCorreo,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    scrollPadding: const EdgeInsets.only(bottom: 160),
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                    validator: _validarCorreo,
                    onFieldSubmitted: (_) => _focoContrasena.requestFocus(),
                  ),
                ),
                const SizedBox(height: EspaciadoPrevia.m),

                Aparece(
                  orden: 2,
                  child: TextFormField(
                    controller: _contrasena,
                    focusNode: _focoContrasena,
                    obscureText: _oculta,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    scrollPadding: const EdgeInsets.only(bottom: 160),
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: _oculta
                            ? 'Mostrar contraseña'
                            : 'Ocultar contraseña',
                        icon: Icon(
                          _oculta
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(() => _oculta = !_oculta),
                      ),
                    ),
                    validator: _validarContrasena,
                    onFieldSubmitted: (_) => _entrar(),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: EspaciadoPrevia.m),
                  AvisoError(_error!),
                ],

                const SizedBox(height: EspaciadoPrevia.l),
                Aparece(
                  orden: 3,
                  child: FilledButton(
                    onPressed: _cargando ? null : _entrar,
                    child: _cargando
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                              semanticsLabel: 'Entrando',
                            ),
                          )
                        : const Text('Entrar'),
                  ),
                ),

                TextButton(
                  onPressed: () => context.pushReplacement(Rutas.registro),
                  child: const Text('No tengo cuenta todavía'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
