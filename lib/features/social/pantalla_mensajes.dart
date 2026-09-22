import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';
import '../../data/models/publicacion.dart';
import '../../data/repositories/repositorio_social.dart';
import '../feed/pantalla_feed.dart' show AvatarPerfil;

final conversacionesProvider = FutureProvider<List<Conversacion>>(
  (ref) => ref.watch(repositorioSocialProvider).misConversaciones(),
);

final _mensajesProvider = StreamProvider.family<List<MensajeDirecto>, String>(
  (ref, otroId) => ref.watch(repositorioSocialProvider).flujoDeMensajes(otroId),
);

/// La bandeja de mensajes.
class PantallaMensajes extends ConsumerWidget {
  const PantallaMensajes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversaciones = ref.watch(conversacionesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mensajes')),
      body: conversaciones.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: context.colores.primarioTexto),
        ),
        error: (e, _) => const _Mensaje(texto: 'No se ha podido cargar.'),
        data: (lista) => lista.isEmpty
            ? const _Mensaje(
                texto: 'Aquí aparecerán tus conversaciones.\n'
                    'Solo puedes escribir a quien sigues o te sigue.',
              )
            : RefreshIndicator(
                color: context.colores.primario,
                backgroundColor: context.colores.superficie,
                onRefresh: () async => ref.refresh(conversacionesProvider.future),
                child: ListView.builder(
                  itemCount: lista.length,
                  itemBuilder: (_, i) => _Fila(conversacion: lista[i]),
                ),
              ),
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.conversacion});

  final Conversacion conversacion;

  @override
  Widget build(BuildContext context) {
    final c = conversacion;
    final textos = Theme.of(context).textTheme;
    final sinLeer = c.sinLeer > 0;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: EspaciadoPrevia.m,
        vertical: EspaciadoPrevia.xs,
      ),
      leading: AvatarPerfil(url: c.avatar, inicial: c.nombre, lado: 52),
      title: Text(c.nombre, style: textos.titleMedium),
      subtitle: Text(
        c.ultimo == null
            ? ''
            : c.ultimoMio
            ? 'Tú: ${c.ultimo}'
            : c.ultimo!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textos.bodyMedium?.copyWith(
          color: sinLeer ? context.colores.texto : context.colores.textoTenue,
          fontWeight: sinLeer ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _cuando(c.ultimoEn),
            style: textos.labelMedium?.copyWith(
              color: context.colores.textoTenue,
            ),
          ),
          if (sinLeer) ...[
            const SizedBox(height: EspaciadoPrevia.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: context.colores.primario,
                borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
              ),
              child: Text(
                '${c.sinLeer}',
                style: TextStyle(
                  color: context.colores.sobrePrimario,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
      onTap: () => context.push('${Rutas.conversacion}/${c.otroId}'),
    );
  }
}

/// Una conversacion con alguien.
class PantallaConversacion extends ConsumerStatefulWidget {
  const PantallaConversacion({super.key, required this.otroId});

  final String otroId;

  @override
  ConsumerState<PantallaConversacion> createState() =>
      _PantallaConversacionState();
}

class _PantallaConversacionState extends ConsumerState<PantallaConversacion> {
  final _campo = TextEditingController();
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    // Al abrir se marcan como leidos: si esperase a cerrar, el contador
    // seguiria en rojo mientras lees.
    ref.read(repositorioSocialProvider).marcarLeidos(widget.otroId);
  }

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final texto = _campo.text;
    if (texto.trim().isEmpty || _enviando) return;

    setState(() => _enviando = true);
    _campo.clear();
    try {
      await ref
          .read(repositorioSocialProvider)
          .enviarMensaje(widget.otroId, texto);
      ref.invalidate(conversacionesProvider);
    } catch (e) {
      if (mounted) {
        _campo.text = texto;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se ha podido enviar. Solo puedes escribir a quien sigues '
              'o te sigue.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mensajes = ref.watch(_mensajesProvider(widget.otroId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversación'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Ver perfil',
            onPressed: () =>
                context.push('${Rutas.perfilDe}/${widget.otroId}'),
          ),
          const SizedBox(width: EspaciadoPrevia.s),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: mensajes.when(
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: context.colores.primarioTexto,
                ),
              ),
              error: (e, _) =>
                  const _Mensaje(texto: 'No se ha podido cargar el chat.'),
              data: (lista) => lista.isEmpty
                  ? const _Mensaje(texto: 'Aún no os habéis escrito.')
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(EspaciadoPrevia.m),
                      itemCount: lista.length,
                      // Se pinta al reves para que lo nuevo quede abajo sin
                      // tener que mover el scroll a mano en cada mensaje.
                      itemBuilder: (_, i) =>
                          _Burbuja(mensaje: lista[lista.length - 1 - i]),
                    ),
            ),
          ),

          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                EspaciadoPrevia.m,
                EspaciadoPrevia.s,
                EspaciadoPrevia.m,
                EspaciadoPrevia.s,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _campo,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Escribe algo',
                      ),
                      onSubmitted: (_) => _enviar(),
                    ),
                  ),
                  const SizedBox(width: EspaciadoPrevia.s),
                  IconButton.filled(
                    onPressed: _enviando ? null : _enviar,
                    icon: const Icon(Icons.send_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: context.colores.primario,
                      foregroundColor: context.colores.sobrePrimario,
                      minimumSize: const Size(48, 48),
                    ),
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
  const _Burbuja({required this.mensaje});

  final MensajeDirecto mensaje;

  @override
  Widget build(BuildContext context) {
    final mio = mensaje.mio;

    return Align(
      alignment: mio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: EspaciadoPrevia.s),
        padding: const EdgeInsets.symmetric(
          horizontal: EspaciadoPrevia.m,
          vertical: EspaciadoPrevia.s + EspaciadoPrevia.xs,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          color: mio ? context.colores.primario : context.colores.superficieAlta,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(EspaciadoPrevia.radio),
            topRight: const Radius.circular(EspaciadoPrevia.radio),
            bottomLeft: Radius.circular(mio ? EspaciadoPrevia.radio : 4),
            bottomRight: Radius.circular(mio ? 4 : EspaciadoPrevia.radio),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              mensaje.texto,
              style: TextStyle(
                color: mio ? context.colores.sobrePrimario : context.colores.texto,
                fontSize: 15,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('HH:mm').format(mensaje.enviadoEn),
              style: TextStyle(
                fontSize: 10,
                color: mio
                    ? context.colores.sobrePrimario.withValues(alpha: 0.6)
                    : context.colores.textoTenue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _cuando(DateTime momento) {
  final d = DateTime.now().difference(momento);
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  if (d.inHours < 24) return '${d.inHours} h';
  if (d.inDays < 7) return '${d.inDays} d';
  return DateFormat('d MMM', 'es_ES').format(momento);
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(EspaciadoPrevia.xl),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    ),
  );
}
