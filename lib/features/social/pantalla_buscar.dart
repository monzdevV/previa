import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';
import '../../data/models/publicacion.dart';
import '../../data/repositories/repositorio_auth.dart';
import '../../data/repositories/repositorio_social.dart';
import '../feed/pantalla_feed.dart' show AvatarPerfil;

/// Prefijo del codigo QR. Tener un esquema propio permite distinguir un QR
/// de Previa de cualquier otro que apunte a una web.
const _esquemaQr = 'previa://u/';

final _miPerfilProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final cliente = ref.watch(clienteSupabaseProvider);
  final id = cliente.auth.currentUser?.id;
  if (id == null) return null;
  return cliente
      .from('profiles')
      .select('id, username, display_name, avatar_url')
      .eq('id', id)
      .maybeSingle();
});

final _amigosProvider = FutureProvider<List<PerfilResumen>>(
  (ref) => ref.watch(repositorioSocialProvider).aQuienSigo(),
);

/// Buscar gente, ver a quien sigues y añadirse por QR.
class PantallaBuscar extends ConsumerWidget {
  const PantallaBuscar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gente'),
          bottom: TabBar(
            indicatorColor: context.colores.primario,
            labelColor: context.colores.texto,
            unselectedLabelColor: context.colores.textoTenue,
            tabs: [
              Tab(text: 'Buscar'),
              Tab(text: 'Siguiendo'),
              Tab(text: 'Mi código'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_Buscador(), _Siguiendo(), _MiCodigo()],
        ),
      ),
    );
  }
}

class _Buscador extends ConsumerStatefulWidget {
  const _Buscador();

  @override
  ConsumerState<_Buscador> createState() => _BuscadorState();
}

class _BuscadorState extends ConsumerState<_Buscador> {
  final _campo = TextEditingController();
  Timer? _espera;
  List<PerfilResumen> _resultados = const [];
  bool _buscando = false;

  @override
  void dispose() {
    _espera?.cancel();
    _campo.dispose();
    super.dispose();
  }

  /// Se espera a que deje de escribir: lanzar una consulta por tecla
  /// castiga la base de datos sin que el usuario gane nada.
  void _alEscribir(String valor) {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 350), () => _buscar(valor));
  }

  Future<void> _buscar(String valor) async {
    if (valor.trim().length < 2) {
      setState(() => _resultados = const []);
      return;
    }
    setState(() => _buscando = true);
    try {
      final gente = await ref
          .read(repositorioSocialProvider)
          .buscarGente(valor);
      if (mounted) setState(() => _resultados = gente);
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(EspaciadoPrevia.m),
          child: TextField(
            controller: _campo,
            autocorrect: false,
            onChanged: _alEscribir,
            decoration: InputDecoration(
              hintText: 'Nombre o usuario',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _buscando
                  ? Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.colores.textoTenue,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ),
        if (!kIsWeb)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: EspaciadoPrevia.m,
            ),
            child: OutlinedButton.icon(
              onPressed: () => _escanear(context, ref),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Escanear un código'),
            ),
          ),
        Expanded(
          child: _resultados.isEmpty
              ? const _Vacio(
                  texto: 'Busca a alguien por su nombre o su usuario.',
                )
              : ListView.builder(
                  itemCount: _resultados.length,
                  itemBuilder: (_, i) => _FilaPersona(perfil: _resultados[i]),
                ),
        ),
      ],
    );
  }
}

/// Abre la camara, lee un QR de Previa y lleva al perfil que contiene.
Future<void> _escanear(BuildContext context, WidgetRef ref) async {
  final usuario = await Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => const _Escaner()),
  );
  if (usuario == null || !context.mounted) return;

  final perfil = await ref
      .read(repositorioSocialProvider)
      .porUsuario(usuario);

  if (!context.mounted) return;
  if (perfil == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ese código no corresponde a nadie.')),
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    builder: (_) => Padding(
      padding: const EdgeInsets.all(EspaciadoPrevia.m),
      child: _FilaPersona(perfil: perfil),
    ),
  );
}

class _Escaner extends StatelessWidget {
  const _Escaner();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear')),
      body: MobileScanner(
        onDetect: (captura) {
          for (final codigo in captura.barcodes) {
            final valor = codigo.rawValue;
            if (valor != null && valor.startsWith(_esquemaQr)) {
              Navigator.of(context).pop(valor.substring(_esquemaQr.length));
              return;
            }
          }
        },
      ),
    );
  }
}

class _Siguiendo extends ConsumerWidget {
  const _Siguiendo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amigos = ref.watch(_amigosProvider);

    return amigos.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: context.colores.primarioTexto),
      ),
      error: (e, _) => const _Vacio(texto: 'No se ha podido cargar.'),
      data: (lista) => lista.isEmpty
          ? const _Vacio(
              texto: 'Todavía no sigues a nadie. Busca gente o escanea '
                  'su código.',
            )
          : ListView.builder(
              itemCount: lista.length,
              itemBuilder: (_, i) => _FilaPersona(perfil: lista[i]),
            ),
    );
  }
}

class _MiCodigo extends ConsumerWidget {
  const _MiCodigo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(_miPerfilProvider);

    return perfil.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: context.colores.primarioTexto),
      ),
      error: (e, _) => const _Vacio(texto: 'No se ha podido cargar tu perfil.'),
      data: (datos) {
        final usuario = datos?['username'] as String?;
        if (usuario == null) {
          return const _Vacio(
            texto: 'Elige un nombre de usuario en tu perfil para tener '
                'código.',
          );
        }

        return ListView(
          padding: const EdgeInsets.all(EspaciadoPrevia.l),
          children: [
            const SizedBox(height: EspaciadoPrevia.m),
            Center(
              child: Container(
                padding: const EdgeInsets.all(EspaciadoPrevia.l),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(
                    EspaciadoPrevia.radioGrande,
                  ),
                ),
                // Fondo blanco obligatorio: un QR sobre negro no lo lee
                // ninguna camara.
                child: QrImageView(
                  data: '$_esquemaQr$usuario',
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: EspaciadoPrevia.l),
            Text(
              '@$usuario',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: EspaciadoPrevia.s),
            Text(
              'Enseña este código para que te añadan al instante.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        );
      },
    );
  }
}

class _FilaPersona extends ConsumerStatefulWidget {
  const _FilaPersona({required this.perfil});

  final PerfilResumen perfil;

  @override
  ConsumerState<_FilaPersona> createState() => _FilaPersonaState();
}

class _FilaPersonaState extends ConsumerState<_FilaPersona> {
  late bool _siguiendo = widget.perfil.leSigo;
  bool _ocupado = false;

  Future<void> _alternar() async {
    final antes = _siguiendo;
    setState(() {
      _siguiendo = !antes;
      _ocupado = true;
    });
    try {
      await ref
          .read(repositorioSocialProvider)
          .alternarSeguimiento(widget.perfil.id, loSeguia: antes);
      ref.invalidate(_amigosProvider);
    } catch (_) {
      if (mounted) setState(() => _siguiendo = antes);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.perfil;

    return ListTile(
      onTap: () => context.push('${Rutas.perfilDe}/${p.id}'),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: EspaciadoPrevia.m,
        vertical: EspaciadoPrevia.xs,
      ),
      leading: AvatarPerfil(url: p.avatar, inicial: p.nombre, lado: 44),
      title: Text(p.nombre, style: Theme.of(context).textTheme.titleMedium),
      subtitle: p.usuario == null ? null : Text('@${p.usuario}'),
      trailing: _siguiendo
          ? OutlinedButton(
              onPressed: _ocupado ? null : _alternar,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(104, 38),
              ),
              child: const Text('Siguiendo'),
            )
          : FilledButton(
              onPressed: _ocupado ? null : _alternar,
              style: FilledButton.styleFrom(
                minimumSize: const Size(104, 38),
              ),
              child: const Text('Seguir'),
            ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.texto});

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
