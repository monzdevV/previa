import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/tema.dart';
import '../../data/repositories/repositorio_auth.dart';

class PantallaEditarPerfil extends ConsumerStatefulWidget {
  const PantallaEditarPerfil({super.key});

  @override
  ConsumerState<PantallaEditarPerfil> createState() =>
      _PantallaEditarPerfilState();
}

class _PantallaEditarPerfilState extends ConsumerState<PantallaEditarPerfil> {
  final _formulario = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _bio = TextEditingController();

  DateTime? _fechaNacimiento;
  bool _cargandoDatos = true;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final repo = ref.read(repositorioAuthProvider);
    final perfil = await repo.miPerfil();
    // La fecha de nacimiento no viene en el perfil: no es legible por SELECT.
    // Hay que pedirla por su funcion, que solo responde al titular.
    final fecha = await repo.miFechaNacimiento();

    if (!mounted) return;
    setState(() {
      _nombre.text = perfil?.nombre ?? '';
      _bio.text = perfil?.bio ?? '';
      _fechaNacimiento = fecha;
      _cargandoDatos = false;
    });
  }

  @override
  void dispose() {
    _nombre.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate:
          _fechaNacimiento ?? DateTime(hoy.year - 18, hoy.month, hoy.day),
      firstDate: DateTime(hoy.year - 100),
      lastDate: hoy,
      locale: const Locale('es', 'ES'),
      helpText: 'Tu fecha de nacimiento',
    );
    if (elegida != null) setState(() => _fechaNacimiento = elegida);
  }

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      await ref.read(repositorioAuthProvider).actualizarPerfil(
            nombre: _nombre.text,
            bio: _bio.text,
            fechaNacimiento: _fechaNacimiento,
          );
      ref.invalidate(miPerfilProvider);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado.')),
      );
    } on ErrorPrevia catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoDatos) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final textos = Theme.of(context).textTheme;
    final formatoFecha = DateFormat('d MMMM y', 'es_ES');

    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: SafeArea(
        child: Form(
          key: _formulario,
          child: ListView(
            padding: const EdgeInsets.all(EspaciadoPrevia.l),
            children: [
              TextFormField(
                controller: _nombre,
                textCapitalization: TextCapitalization.words,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: 'Cómo te llamas',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Escribe al menos 2 caracteres'
                    : null,
              ),

              TextFormField(
                controller: _bio,
                maxLines: 3,
                maxLength: 280,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Sobre ti',
                  hintText: 'Dos líneas para que sepan quién eres.',
                  alignLabelWithHint: true,
                ),
              ),

              const SizedBox(height: EspaciadoPrevia.m),
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
              Text(
                'Nadie más puede verla. Solo se publica tu edad.',
                style: textos.bodyMedium?.copyWith(
                  fontSize: 12,
                  color: ColoresPrevia.textoTenue,
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: EspaciadoPrevia.m),
                Container(
                  padding: const EdgeInsets.all(EspaciadoPrevia.m),
                  decoration: BoxDecoration(
                    color: ColoresPrevia.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
                    border: Border.all(
                      color: ColoresPrevia.error.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(_error!,
                      style: const TextStyle(color: ColoresPrevia.error)),
                ),
              ],

              const SizedBox(height: EspaciadoPrevia.l),
              FilledButton(
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
