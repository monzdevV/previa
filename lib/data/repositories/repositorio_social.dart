import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/local.dart';
import '../models/noche.dart';
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

  /// Sube la foto de perfil y la deja apuntada en el perfil.
  ///
  /// Siempre el mismo nombre de fichero, asi que reemplaza en lugar de
  /// acumular. Como la URL publica no cambia, se le anade una marca de
  /// tiempo: sin ella se seguiria viendo la foto anterior durante horas.
  Future<String> subirAvatar({
    required List<int> bytes,
    required String extension,
  }) async {
    final nombre = '$_yo/avatar.$extension';

    await _cliente.storage
        .from('avatares')
        .uploadBinary(
          nombre,
          Uint8List.fromList(bytes),
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

    final url =
        '${_cliente.storage.from('avatares').getPublicUrl(nombre)}'
        '?v=${DateTime.now().millisecondsSinceEpoch}';

    await _cliente.from('profiles').update({'avatar_url': url}).eq('id', _yo);
    return url;
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

  /// Las ultimas veces que saliste, con su resumen resuelto.
  Future<List<Salida>> misUltimasSalidas({int limite = 20}) async {
    final filas = await _cliente.rpc(
      'mis_ultimas_salidas',
      params: {'limite': limite},
    );
    return (filas as List)
        .map((f) => Salida.desdeJson(f as Map<String, dynamic>))
        .toList();
  }

  /// Lo que subio la gente que estuvo donde tu esa noche.
  Future<List<Publicacion>> fotosDeMisNoches({int limite = 40}) async {
    final filas = await _cliente.rpc(
      'fotos_de_mis_noches',
      params: {'limite': limite},
    );
    return (filas as List)
        .map((f) => Publicacion.desdeJson(f as Map<String, dynamic>))
        .toList();
  }

  /// Tu racha de findes.
  Future<Racha> miRacha() async {
    final filas = await _cliente.rpc('mi_racha');
    final lista = filas as List;
    if (lista.isEmpty) return const Racha();
    return Racha.desdeJson(lista.first as Map<String, dynamic>);
  }

  /// El resumen de una noche, para la tarjeta del final.
  Future<ResumenDeNoche> resumenDeNoche(DateTime noche) async {
    final fecha = _comoNoche(noche);
    final filas = await _cliente.rpc(
      'resumen_de_noche',
      params: {'noche': fecha},
    );
    final lista = filas as List;
    final dia = DateTime.parse(fecha);
    if (lista.isEmpty) return ResumenDeNoche(noche: dia);
    return ResumenDeNoche.desdeJson(
      lista.first as Map<String, dynamic>,
      dia,
    );
  }

  // --- La sala de un local durante la noche ---

  /// Los mensajes de la sala. Solo responde si has dicho que vas.
  Future<List<MensajeDeSala>> salaMensajes(String localId, {DateTime? noche}) async {
    final filas = await _cliente.rpc(
      'sala_mensajes',
      params: {
        'local': localId,
        'noche': _comoNoche(noche ?? DateTime.now()),
      },
    );
    return (filas as List)
        .map((f) => MensajeDeSala.desdeJson(f as Map<String, dynamic>, _yo))
        .toList();
  }

  /// Escucha la sala en vivo. Se filtra en el cliente porque el flujo de
  /// Supabase no acepta condiciones sobre dos columnas a la vez.
  Stream<List<String>> flujoDeSala(String localId, {DateTime? noche}) {
    final fecha = _comoNoche(noche ?? DateTime.now());
    return _cliente
        .from('venue_messages')
        .stream(primaryKey: ['id'])
        .map(
          (filas) => filas
              .where((f) => f['venue_id'] == localId && f['night'] == fecha)
              .map((f) => f['id'] as String)
              .toList(),
        );
  }

  Future<void> escribirEnSala(String localId, String texto, {DateTime? noche}) async {
    final limpio = texto.trim();
    if (limpio.isEmpty) return;
    await _cliente.from('venue_messages').insert({
      'venue_id': localId,
      'night': _comoNoche(noche ?? DateTime.now()),
      'sender_id': _yo,
      'body': limpio,
    });
  }

  Future<List<Publicacion>> salaFotos(String localId, {DateTime? noche}) async {
    final filas = await _cliente.rpc(
      'sala_fotos',
      params: {
        'local': localId,
        'noche': _comoNoche(noche ?? DateTime.now()),
      },
    );
    return (filas as List)
        .map((f) => Publicacion.desdeJson(f as Map<String, dynamic>))
        .toList();
  }

  /// Sube una foto directamente a la sala del local.
  Future<void> publicarEnSala({
    required String localId,
    required List<int> bytes,
    required String extension,
    required bool esVideo,
    String? texto,
    String? zona,
    DateTime? noche,
  }) async {
    final nombre = '$_yo/${DateTime.now().millisecondsSinceEpoch}.$extension';

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

    await _cliente.from('posts').insert({
      'author_id': _yo,
      'media_url': _cliente.storage.from('publicaciones').getPublicUrl(nombre),
      'media_type': esVideo ? 'video' : 'photo',
      'venue_id': localId,
      'night': _comoNoche(noche ?? DateTime.now()),
      if (texto != null && texto.trim().isNotEmpty) 'caption': texto.trim(),
      if (zona != null && zona.trim().isNotEmpty) 'area_label': zona.trim(),
    });
  }

  /// La bandeja de mensajes: una fila por persona con lo ultimo dicho.
  Future<List<Conversacion>> misConversaciones() async {
    final filas = await _cliente.rpc('mis_conversaciones');
    return (filas as List)
        .map((f) => Conversacion.desdeJson(f as Map<String, dynamic>))
        .toList();
  }

  /// Los mensajes con alguien, del mas antiguo al mas nuevo.
  Future<List<MensajeDirecto>> mensajesCon(String otroId) async {
    final filas = await _cliente
        .from('direct_messages')
        .select('id, sender_id, recipient_id, body, read_at, created_at')
        .or(
          'and(sender_id.eq.$_yo,recipient_id.eq.$otroId),'
          'and(sender_id.eq.$otroId,recipient_id.eq.$_yo)',
        )
        .order('created_at')
        .limit(200);

    return (filas as List)
        .map((f) => MensajeDirecto.desdeJson(f as Map<String, dynamic>, _yo))
        .toList();
  }

  /// Escucha en vivo la conversacion. Es lo que hace que un chat se sienta
  /// como un chat y no como una bandeja que hay que recargar.
  Stream<List<MensajeDirecto>> flujoDeMensajes(String otroId) => _cliente
      .from('direct_messages')
      .stream(primaryKey: ['id'])
      .order('created_at')
      .map(
        (filas) => filas
            .where(
              (f) =>
                  (f['sender_id'] == _yo && f['recipient_id'] == otroId) ||
                  (f['sender_id'] == otroId && f['recipient_id'] == _yo),
            )
            .map((f) => MensajeDirecto.desdeJson(f, _yo))
            .toList(),
      );

  Future<void> enviarMensaje(String paraId, String texto) async {
    final limpio = texto.trim();
    if (limpio.isEmpty) return;
    await _cliente.from('direct_messages').insert({
      'sender_id': _yo,
      'recipient_id': paraId,
      'body': limpio,
    });
  }

  Future<void> marcarLeidos(String deId) async {
    await _cliente
        .from('direct_messages')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('sender_id', deId)
        .eq('recipient_id', _yo)
        .isFilter('read_at', null);
  }

  /// Ficha publica de alguien, con sus contadores y si le sigues.
  Future<PerfilPublico> perfilPublico(String perfilId) async {
    final fila = await _cliente
        .from('profiles')
        .select(
          'id, username, display_name, avatar_url, bio, city, instagram, '
          'reputation, ratings_count, is_demo',
        )
        .eq('id', perfilId)
        .single();

    // Tres consultas cortas en paralelo salen mas baratas que una vista con
    // subconsultas, y cada una usa su propio indice.
    final seguidores = _cliente
        .from('follows')
        .count()
        .eq('followee_id', perfilId);
    final siguiendo = _cliente
        .from('follows')
        .count()
        .eq('follower_id', perfilId);
    final loSigo = _cliente
        .from('follows')
        .select('followee_id')
        .eq('follower_id', _yo)
        .eq('followee_id', perfilId)
        .maybeSingle();

    return PerfilPublico(
      perfil: PerfilResumen.desdeJson({
        ...Map<String, dynamic>.from(fila),
        'le_sigo': await loSigo != null,
      }),
      bio: fila['bio'] as String?,
      ciudad: fila['city'] as String?,
      instagram: fila['instagram'] as String?,
      esDemo: fila['is_demo'] as bool? ?? false,
      seguidores: await seguidores,
      siguiendo: await siguiendo,
    );
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
