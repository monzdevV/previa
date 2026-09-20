import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tema.dart';
import '../../data/repositories/repositorio_auth.dart';

/// Pantalla principal tras iniciar sesion.
///
/// De momento es un marcador de posicion: confirma que la sesion y el perfil
/// funcionan de punta a punta. El mapa llega en la fase 2.
class PantallaInicio extends ConsumerWidget {
  const PantallaInicio({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(miPerfilProvider);
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Previa'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(repositorioAuthProvider).salir(),
          ),
        ],
      ),
      body: perfil.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(EspaciadoPrevia.l),
            child: Text('No se ha podido cargar tu perfil.\n\n$e',
                textAlign: TextAlign.center, style: textos.bodyMedium),
          ),
        ),
        data: (p) => ListView(
          padding: const EdgeInsets.all(EspaciadoPrevia.l),
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: ColoresPrevia.primario,
                  child: Text(
                    p?.iniciales ?? '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: EspaciadoPrevia.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hola, ${p?.nombre ?? ''}', style: textos.titleLarge),
                      Text('@${p?.username ?? ''}', style: textos.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: EspaciadoPrevia.xl),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(EspaciadoPrevia.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: ColoresPrevia.acento, size: 20),
                        const SizedBox(width: EspaciadoPrevia.s),
                        Text('Fase 1 en marcha', style: textos.titleLarge),
                      ],
                    ),
                    const SizedBox(height: EspaciadoPrevia.m),
                    Text(
                      'Registro, inicio de sesión y perfil funcionan contra '
                      'Supabase, con las políticas de seguridad activas.',
                      style: textos.bodyMedium,
                    ),
                    const SizedBox(height: EspaciadoPrevia.l),
                    const Divider(),
                    const SizedBox(height: EspaciadoPrevia.m),
                    Text('Lo siguiente', style: textos.titleLarge),
                    const SizedBox(height: EspaciadoPrevia.m),
                    const _Pendiente('Mapa con las previas cercanas'),
                    const _Pendiente('Publicar una previa'),
                    const _Pendiente('Solicitar plaza para tu grupo'),
                    const _Pendiente('Chat en tiempo real'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pendiente extends StatelessWidget {
  const _Pendiente(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: EspaciadoPrevia.s),
      child: Row(
        children: [
          const Icon(Icons.radio_button_unchecked,
              size: 18, color: ColoresPrevia.textoTenue),
          const SizedBox(width: EspaciadoPrevia.s),
          Expanded(
            child: Text(
              texto,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
