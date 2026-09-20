import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/tema.dart';
import '../../data/models/previa.dart';
import '../../data/repositories/repositorio_auth.dart';
import '../../data/repositories/repositorio_previas.dart';

/// Mensajes en vivo. Supabase Realtime empuja cada insercion por WebSocket,
/// asi que no hay que refrescar ni sondear.
final mensajesProvider = StreamProvider.family<List<Mensaje>, String>(
  (ref, previaId) =>
      ref.watch(repositorioPreviasProvider).mensajesDe(previaId),
);

/// Quien va, para poder poner nombre a cada mensaje.
final miembrosProvider =
    FutureProvider.family<Map<String, String>, String>((ref, previaId) async {
  final filas = await ref.watch(repositorioPreviasProvider).miembrosDe(previaId);
  return {
    for (final f in filas)
      f['profile_id'] as String:
          (f['profiles'] as Map?)?['display_name'] as String? ?? 'Alguien',
  };
});

class PantallaChat extends ConsumerStatefulWidget {
  const PantallaChat({super.key, required this.previaId, this.titulo});

  final String previaId;
  final String? titulo;

  @override
  ConsumerState<PantallaChat> createState() => _PantallaChatState();
}

class _PantallaChatState extends ConsumerState<PantallaChat> {
  final _texto = TextEditingController();
  final _scroll = ScrollController();
  bool _enviando = false;

  @override
  void dispose() {
    _texto.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final texto = _texto.text.trim();
    if (texto.isEmpty || _enviando) return;

    setState(() => _enviando = true);
    // Se vacia ya: si falla se repone, pero lo normal es que funcione y
    // esperar al servidor con el campo lleno se siente lento.
    _texto.clear();

    try {
      await ref
          .read(repositorioPreviasProvider)
          .enviarMensaje(widget.previaId, texto);
      _alFinal();
    } catch (_) {
      if (mounted) {
        _texto.text = texto;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se ha podido enviar. Inténtalo otra vez.')),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _alFinal() {
    if (!_scroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mensajes = ref.watch(mensajesProvider(widget.previaId));
    final nombres = ref.watch(miembrosProvider(widget.previaId)).valueOrNull ?? {};
    final yo = ref.watch(repositorioAuthProvider).usuarioActual?.id;

    ref.listen(mensajesProvider(widget.previaId), (_, _) => _alFinal());

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.titulo ?? 'Chat'),
            Text(
              nombres.isEmpty
                  ? 'Cargando…'
                  : '${nombres.length} ${nombres.length == 1 ? "persona" : "personas"}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: ColoresPrevia.textoSuave,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: mensajes.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(EspaciadoPrevia.l),
                  child: Text(
                    'No se ha podido abrir el chat.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
              data: (lista) => lista.isEmpty
                  ? const _ChatVacio()
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(EspaciadoPrevia.m),
                      itemCount: lista.length,
                      itemBuilder: (_, i) {
                        final m = lista[i];
                        final anterior = i > 0 ? lista[i - 1] : null;
                        return _Burbuja(
                          mensaje: m,
                          esMio: m.autorId == yo,
                          nombre: nombres[m.autorId] ?? 'Alguien',
                          // El nombre solo se repite cuando cambia de persona:
                          // menos ruido en rafagas de mensajes seguidos.
                          muestraNombre: anterior?.autorId != m.autorId,
                        );
                      },
                    ),
            ),
          ),

          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(EspaciadoPrevia.s + 2),
              decoration: const BoxDecoration(
                color: ColoresPrevia.superficie,
                border: Border(top: BorderSide(color: ColoresPrevia.borde)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _texto,
                      maxLines: 4,
                      minLines: 1,
                      maxLength: 1000,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _enviar(),
                      decoration: const InputDecoration(
                        hintText: 'Escribe algo…',
                        counterText: '',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: EspaciadoPrevia.m,
                          vertical: EspaciadoPrevia.s + 4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: EspaciadoPrevia.s),
                  IconButton.filled(
                    onPressed: _enviando ? null : _enviar,
                    style: IconButton.styleFrom(
                      backgroundColor: ColoresPrevia.primario,
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Burbuja extends StatelessWidget {
  const _Burbuja({
    required this.mensaje,
    required this.esMio,
    required this.nombre,
    required this.muestraNombre,
  });

  final Mensaje mensaje;
  final bool esMio;
  final String nombre;
  final bool muestraNombre;

  @override
  Widget build(BuildContext context) {
    final hora = DateFormat('HH:mm').format(mensaje.enviadoEn);

    return Padding(
      padding: EdgeInsets.only(
        bottom: EspaciadoPrevia.xs,
        top: muestraNombre ? EspaciadoPrevia.s : 0,
      ),
      child: Column(
        crossAxisAlignment:
            esMio ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (muestraNombre && !esMio)
            Padding(
              padding: const EdgeInsets.only(
                left: EspaciadoPrevia.s + 4,
                bottom: 2,
              ),
              child: Text(
                nombre,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ColoresPrevia.textoSuave,
                ),
              ),
            ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: EspaciadoPrevia.m,
              vertical: EspaciadoPrevia.s + 2,
            ),
            decoration: BoxDecoration(
              color: esMio ? ColoresPrevia.primario : ColoresPrevia.superficieAlta,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(EspaciadoPrevia.radio),
                topRight: const Radius.circular(EspaciadoPrevia.radio),
                bottomLeft: Radius.circular(esMio ? EspaciadoPrevia.radio : 4),
                bottomRight: Radius.circular(esMio ? 4 : EspaciadoPrevia.radio),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  mensaje.texto,
                  style: TextStyle(
                    color: esMio ? Colors.white : ColoresPrevia.texto,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hora,
                  style: TextStyle(
                    fontSize: 10,
                    color: esMio
                        ? Colors.white.withValues(alpha: 0.7)
                        : ColoresPrevia.textoTenue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatVacio extends StatelessWidget {
  const _ChatVacio();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(EspaciadoPrevia.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.forum_outlined,
                size: 40, color: ColoresPrevia.textoTenue),
            const SizedBox(height: EspaciadoPrevia.m),
            Text('Todavía no ha escrito nadie',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: EspaciadoPrevia.xs),
            Text(
              'Rompe el hielo: di quién eres y a qué hora llegáis.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
