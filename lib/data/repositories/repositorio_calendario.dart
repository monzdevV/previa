import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'repositorio_auth.dart';

final repositorioCalendarioProvider = Provider<RepositorioCalendario>((ref) {
  ref.watch(uidActualProvider);
  return RepositorioCalendario(ref.watch(clienteSupabaseProvider));
});

/// Una noche en el calendario de alguien.
class NocheDelCalendario {
  const NocheDelCalendario({
    required this.noche,
    this.sitios = const [],
    this.fotos = 0,
    this.portada,
  });

  final DateTime noche;
  final List<String> sitios;

  /// Cuantas fotos subio esa persona esa noche.
  final int fotos;

  /// Su ultima foto de esa noche; si no subio, la de alguien que estuvo en
  /// el mismo sitio. Nula si nadie subio nada.
  final String? portada;

  String get donde => sitios.isEmpty ? 'Noche suelta' : sitios.join(' · ');
}

/// El calendario social: cuando salio alguien y con que foto.
///
/// Se arma con lecturas normales de planes y publicaciones, no con una
/// funcion del servidor: las politicas de esas tablas ya esconden a quien te
/// ha bloqueado, asi que el calendario hereda la misma privacidad sin
/// escribir ninguna regla nueva que pudiera quedarse desfasada.
class RepositorioCalendario {
  RepositorioCalendario(this._cliente);

  final SupabaseClient _cliente;

  /// Solo las fechas de las noches de alguien, sin fotos ni locales, para
  /// calcular la racha en el teléfono. Unión de "voy" y publicaciones: basta
  /// una de las dos para que la noche cuente. Se pide poco (una columna) y
  /// con tope, porque la racha solo necesita las últimas semanas.
  ///
  /// Se calcula aquí y no en una función del servidor por la misma razón que
  /// el calendario: las políticas de lectura ya aplican los bloqueos y no hay
  /// que repetir esa regla (ni migrar nada) para una cuenta de semanas.
  Future<List<DateTime>> fechasDeNoches(
    String perfilId, {
    required DateTime desde,
  }) async {
    final d = _fecha(desde);
    final resultados = await Future.wait<dynamic>([
      _cliente
          .from('venue_plans')
          .select('night')
          .eq('profile_id', perfilId)
          .gte('night', d)
          .limit(1000),
      _cliente
          .from('posts')
          .select('night')
          .eq('author_id', perfilId)
          .gte('night', d)
          .limit(1000),
    ]);
    return [
      for (final lista in resultados)
        for (final f in lista as List)
          DateTime.parse((f as Map)['night'] as String),
    ];
  }

  Future<List<NocheDelCalendario>> nochesDe(
    String perfilId, {
    required DateTime desde,
    required DateTime hasta,
  }) async {
    final d = _fecha(desde);
    final h = _fecha(hasta);

    final resultados = await Future.wait<dynamic>([
      _cliente
          .from('venue_plans')
          .select('night, venue_id, venues ( name )')
          .eq('profile_id', perfilId)
          .gte('night', d)
          .lte('night', h),
      _cliente
          .from('posts')
          .select('night, media_url, media_type, thumbnail_url')
          .eq('author_id', perfilId)
          .gte('night', d)
          .lte('night', h)
          .order('created_at', ascending: false)
          .limit(200),
    ]);

    final sitios = <DateTime, Set<String>>{};
    final localesPorNoche = <DateTime, Set<String>>{};
    for (final f in resultados[0] as List) {
      final fila = f as Map;
      final noche = DateTime.parse(fila['night'] as String);
      final nombre = (fila['venues'] as Map?)?['name'] as String?;
      sitios.putIfAbsent(noche, () => {}).add(nombre ?? 'Un sitio');
      localesPorNoche
          .putIfAbsent(noche, () => {})
          .add(fila['venue_id'] as String);
    }

    final fotos = <DateTime, int>{};
    final portadas = <DateTime, String>{};
    for (final f in resultados[1] as List) {
      final fila = f as Map;
      final noche = DateTime.parse(fila['night'] as String);
      fotos[noche] = (fotos[noche] ?? 0) + 1;
      // Van de la mas reciente a la mas antigua: la primera foto que se ve
      // de cada noche es la ultima que subio.
      if (!portadas.containsKey(noche) && fila['media_type'] == 'photo') {
        portadas[noche] = fila['media_url'] as String;
      }
    }

    // Las noches sin foto propia toman la de alguien que estuvo en el mismo
    // sitio. Una sola consulta para todas: una por dia serian treinta.
    final sinFoto = [
      for (final n in localesPorNoche.keys)
        if (!portadas.containsKey(n)) n,
    ];
    if (sinFoto.isNotEmpty) {
      final locales = {for (final n in sinFoto) ...localesPorNoche[n]!};
      final ajenas = await _cliente
          .from('posts')
          .select('night, venue_id, media_url')
          .inFilter('venue_id', locales.toList())
          .inFilter('night', sinFoto.map(_fecha).toList())
          .eq('media_type', 'photo')
          .order('created_at', ascending: false)
          .limit(120);
      for (final f in ajenas as List) {
        final fila = f as Map;
        final noche = DateTime.parse(fila['night'] as String);
        final estuvo =
            localesPorNoche[noche]?.contains(fila['venue_id']) ?? false;
        if (estuvo && !portadas.containsKey(noche)) {
          portadas[noche] = fila['media_url'] as String;
        }
      }
    }

    final noches = {...sitios.keys, ...fotos.keys}.toList()..sort();
    return [
      for (final n in noches)
        NocheDelCalendario(
          noche: n,
          sitios: (sitios[n] ?? const <String>{}).toList()..sort(),
          fotos: fotos[n] ?? 0,
          portada: portadas[n],
        ),
    ];
  }

  static String _fecha(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
