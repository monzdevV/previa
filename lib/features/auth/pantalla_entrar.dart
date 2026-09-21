import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';
import '../../data/repositories/repositorio_auth.dart';

class PantallaEntrar extends ConsumerStatefulWidget {
  const PantallaEntrar({super.key});

  @override
  ConsumerState<PantallaEntrar> createState() => _PantallaEntrarState();
}

class _PantallaEntrarState extends ConsumerState<PantallaEntrar> {
  final _formulario = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();

  bool _cargando = false;
  bool _oculta = true;
  String? _error;

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_formulario.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      await ref
          .read(repositorioAuthProvider)
          .entrar(correo: _correo.text, contrasena: _contrasena.text);
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

    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, restricciones) => SingleChildScrollView(
            padding: const EdgeInsets.all(EspaciadoPrevia.l),
            child: ConstrainedBox(
              // El panel de accion baja al alcance del pulgar en lugar de
              // dejar medio movil vacio bajo el formulario.
              constraints: BoxConstraints(
                minHeight: restricciones.maxHeight - EspaciadoPrevia.l * 2,
              ),
              child: IntrinsicHeight(
                child: Form(
                  key: _formulario,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Vuelve a la noche.', style: textos.displaySmall),
                      const SizedBox(height: EspaciadoPrevia.s),
                      Text(
                        'Tus planes, solicitudes y conversaciones siguen aquí.',
                        style: textos.bodyMedium,
                      ),

                      const Spacer(),
                      const SizedBox(height: EspaciadoPrevia.xl),

                      TextFormField(
                        controller: _correo,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Correo o usuario',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Escribe tu correo o usuario'
                            : null,
                      ),
                      const SizedBox(height: EspaciadoPrevia.m),

                      TextFormField(
                        controller: _contrasena,
                        obscureText: _oculta,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
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
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Escribe tu contraseña'
                            : null,
                        onFieldSubmitted: (_) => _entrar(),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: EspaciadoPrevia.m),
                        _AvisoError(_error!),
                      ],

                      const SizedBox(height: EspaciadoPrevia.l),
                      FilledButton(
                        onPressed: _cargando ? null : _entrar,
                        child: _cargando
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: context.colores.fondoProfundo,
                                ),
                              )
                            : const Text('ENTRAR'),
                      ),

                      TextButton(
                        onPressed: () =>
                            context.pushReplacement(Rutas.registro),
                        child: const Text('No tengo cuenta todavía'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvisoError extends StatelessWidget {
  const _AvisoError(this.mensaje);
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(EspaciadoPrevia.m),
      decoration: BoxDecoration(
        color: context.colores.error.withValues(alpha: 0.12),
        border: Border.all(color: context.colores.error.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: context.colores.error, size: 20),
          const SizedBox(width: EspaciadoPrevia.s),
          Expanded(
            child: Text(
              mensaje,
              style: TextStyle(color: context.colores.error, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
