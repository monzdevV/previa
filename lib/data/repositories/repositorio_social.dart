import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/local.dart';
import '../models/publicacion.dart';
import 'repositorio_auth.dart';

final repositorioSocialProvider = Provider<RepositorioSocial>(
  (ref) => RepositorioSocial(ref.watch(clienteSupabaseProvider)),
);

/// Todo lo que hace que Previa sea una red social y no solo un mapa:
/// publicaciones, likes, seguir gente y buscarla.
class RepositorioSocial {
  RepositorioSocial(this._cliente);

  final SupabaseClient _cliente;

  String get _yo => _cliente.auth.currentUser!.id;

  /// El feed.
  ///
  /// Devuelve lo reciente de todo el mundo y no solo de a quien sigues: una
  /// cuenta recien creada tiene que encontrar algo al abrir la aplicacion, o
  /// no vuelve. Filtrar por [zona] es lo que da "la noche en Zaragoza".
  Future<List<Publicacion>> feed({
    String? zona,
    int limite = 30,
    int desplazamiento = 0,
  }) async {
    final filas = await _cliente.rpc(
      'feed_publicaciones',
      params: {
        'zona': zona,
        'limite': limite,
        'desplazamiento': desplazamiento,
      },
    );
    return (filas as List)
        .map((f) => Publicacion.desdeJson(f as Map<String, dynamic>))
        .toList();
  }

  /// Sube la media y crea la publicacion.
  ///
  /// La ruta empieza por el id de quien sube porque la politica de Storage
  /// solo deja escribir dentro de la carpeta propia.
  Future<void> publicar({
    required List<int> bytes,
    required String extension,
    required bool esVideo,
    String? texto,
    String? zona,
    String? previaId,
  }) async {
    final nombre =
        '$_yo/${DateTime.now().millisecondsSinceEpoch}.$extension';

    await _cliente.storage
        .from('publicaciones')
        .uploadBinary(
          nombre,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(
            contentType: esVideo ? 'video/mp4' : 'image/jpeg',
            upsert: false,
          ),
        );

    final url = _cliente.storage.from('publicaciones').getPublicUrl(nombre);

    await _cliente.from('posts').insert({
      'author_id': _yo,
      'media_url': url,
      'media_type': esVideo ? 'video' : 'photo',
      if (texto != null && texto.trim().isNotEmpty) 'caption': texto.trim(),
      if (zona != null && zona.trim().isNotEmpty) 'area_label': zona.trim(),
      'party_id': ?previaId,
    });
  }

  Future<void> borrarPublicacion(String id) async {
    await _cliente.from('posts').delete().eq('id', id);
  }

  /// El contador lo mantiene un disparador en la base de datos, asi que aqui
  /// solo se crea o se quita la fila.
  Future<void> alternarLike(String publicacionId, {required bool teniaLike}) {
    if (teniaLike) {
      return _cliente
          .from('post_likes')
          .delete()
          .eq('post_id', publicacionId)
          .eq('user_id', _yo);
    }
    return _cliente.from('post_likes').insert({
      'post_id': publicacionId,
      'user_id': _yo,
    });
  }

  Future<void> alternarSeguimiento(String perfilId, {required bool loSeguia}) {
    if (loSeguia) {
      return _cliente
          .from('follows')
          .delete()
          .eq('follower_id', _yo)
          .eq('followee_id', perfilId);
    }
    return _cliente.from('follows').insert({
      'follower_id': _yo,
      'followee_id': perfilId,
    });
  }

  /// Busca gente por nombre o por usuario.
  Future<List<PerfilResumen>> buscarGente(String consulta) async {
    final limpia = consulta.trim();
    if (limpia.length < 2) return const [];

    final filas = await _cliente
        .from('profiles')
        .select('id, username, display_name, avatar_url, reputation')
        .or('username.ilike.%$limpia%,display_name.ilike.%$limpia%')
        .neq('id', _yo)
        .limit(30);

    final seguidos = await _idsQueSigo();
    return (filas as List).map((f) {
      final mapa = Map<String, dynamic>.from(f as Map);
      mapa['le_sigo'] = seguidos.contains(mapa['id']);
      return PerfilResumen.desdeJson(mapa);
    }).toList();
  }

  /// Busca a alguien por su usuario exacto. Es lo que lee el codigo QR.
  Future<PerfilResumen?> porUsuario(String usuario) async {
    final fila = await _cliente
        .from('profiles')
        .select('id, username, display_name, avatar_url, reputation')
        .eq('username', usuario.trim().toLowerCase())
        .maybeSingle();

    if (fila == null) return null;
    final mapa = Map<String, dynamic>.from(fila);
    mapa['le_sigo'] = (await _idsQueSigo()).contains(mapa['id']);
    return PerfilResumen.desdeJson(mapa);
  }

  /// A quien sigo, con sus datos. Es la pestaña de amigos.
  Future<List<PerfilResumen>> aQuienSigo() async {
    final filas = await _cliente
        .from('follows')
        .select(
          'followee_id, profiles!follows_followee_id_fkey '
          '( id, username, display_name, avatar_url, reputation )',
        )
        .eq('follower_id', _yo);

    return (filas as List)
        .map((f) => (f as Map)['profiles'])
        .whereType<Map>()
        .map((p) {
          final mapa = Map<String, dynamic>.from(p);
          mapa['le_sigo'] = true;
          return PerfilResumen.desdeJson(mapa);
        })
        .toList();
  }

  Future<Set<String>> _idsQueSigo() async {
    final filas = await _cliente
        .from('follows')
        .select('followee_id')
        .eq('follower_id', _yo);
    return (filas as List)
        .map((f) => (f as Map)['followee_id'] as String)
        .toSet();
  }

  /// La noche por delante: que locales hay en una ciudad y cuanta gente va.
  ///
  /// [noche] es una fecha y no un instante a proposito: quien sale a las dos
  /// de la madrugada del sabado sigue estando en la noche del viernes.
  Future<List<Local>> localesDeLaNoche(String ciudad, {DateTime? noche}) async {
    final filas = await _cliente.rpc(
      'locales_de_la_noche',
      params: {'ciudad': ciudad, 'noche': _comoNoche(noche ?? DateTime.now())},
    );
    return (filas as List)
        .map((f) => Local.desdeJson(f as Map<String, dynamic>))
        .toList();
  }

  /// Quien va a un local. Ver caras conocidas es lo que empuja a ir.
  Future<List<PerfilResumen>> quienVa(String localId, {DateTime? noche}) async {
    final filas = await _cliente.rpc(
      'quien_va',
      params: {
        'local': localId,
        'noche': _comoNoche(noche ?? DateTime.now()),
      },
    );
    return (filas as List)
        .map((f) => PerfilResumen.desdeJson(f as Map<String, dynamic>))
        .toList();
  }

  Future<void> alternarVoy(
    String localId, {
    required bool yaIba,
    DateTime? noche,
  }) {
    final fecha = _comoNoche(noche ?? DateTime.now());
    if (yaIba) {
      return _cliente
          .from('venue_plans')
          .delete()
          .eq('venue_id', localId)
          .eq('profile_id', _yo)
          .eq('night', fecha);
    }
    return _cliente.from('venue_plans').insert({
      'venue_id': localId,
      'profile_id': _yo,
      'night': fecha,
    });
  }

  Future<Local> crearLocal({
    required String nombre,
    required String ciudad,
    String? zona,
    String? urlEntradas,
    String? instagram,
  }) async {
    final fila = await _cliente
        .from('venues')
        .insert({
          'name': nombre.trim(),
          'city': ciudad.trim(),
          'area_label': ?zona?.trim(),
          'ticket_url': ?urlEntradas?.trim(),
          'instagram': ?instagram?.trim(),
        })
        .select('id, name, city, area_label, ticket_url, instagram')
        .single();
    return Local.desdeJson(fila);
  }

  /// Las noches que has salido, para el calendario del perfil.
  Future<Map<DateTime, List<String>>> misNoches() async {
    final filas = await _cliente
        .from('venue_plans')
        .select('night, venues ( name )')
        .eq('profile_id', _yo)
        .order('night', ascending: false)
        .limit(200);

    final salida = <DateTime, List<String>>{};
    for (final f in filas as List) {
      final mapa = f as Map;
      final fecha = DateTime.parse(mapa['night'] as String);
      final dia = DateTime(fecha.year, fecha.month, fecha.day);
      final nombre = (mapa['venues'] as Map?)?['name'] as String?;
      salida.putIfAbsent(dia, () => []).add(nombre ?? 'Un sitio');
    }
    return salida;
  }

  /// Una noche empieza al anochecer: lo que pasa antes de las 6 de la
  /// manana todavia pertenece al dia anterior.
  static String _comoNoche(DateTime momento) {
    final base = momento.hour < 6
        ? momento.subtract(const Duration(days: 1))
        : momento;
    return '${base.year.toString().padLeft(4, '0')}-'
        '${base.month.toString().padLeft(2, '0')}-'
        '${base.day.toString().padLeft(2, '0')}';
  }

  /// Publicaciones de una persona, para su perfil.
  Future<List<Publicacion>> publicacionesDe(String perfilId) async {
    final filas = await _cliente
        .from('posts')
        .select(
          'id, author_id, media_url, media_type, thumbnail_url, caption, '
          'area_label, like_count, created_at, '
          'profiles!posts_author_id_fkey ( username, display_name, avatar_url )',
        )
        .eq('author_id', perfilId)
        .order('created_at', ascending: false)
        .limit(60);

    return (filas as List).map((f) {
      final mapa = Map<String, dynamic>.from(f as Map);
      final autor = mapa['profiles'] as Map?;
      mapa['username'] = autor?['username'];
      mapa['display_name'] = autor?['display_name'];
      mapa['avatar_url'] = autor?['avatar_url'];
      return Publicacion.desdeJson(mapa);
    }).toList();
  }
}
