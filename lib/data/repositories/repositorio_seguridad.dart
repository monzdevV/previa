import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'repositorio_auth.dart';

final repositorioSeguridadProvider = Provider<RepositorioSeguridad>(
  (ref) => RepositorioSeguridad(ref.watch(clienteSupabaseProvider)),
);

/// Motivos de reporte. Las claves coinciden con el enum `report_reason` de
/// la base de datos; si se cambia uno hay que cambiar el otro.
const motivosDeReporte = <String, String>{
  'acoso': 'Acoso o comportamiento inapropiado',
  'perfil_falso': 'Parece un perfil falso',
  'menor_edad': 'Creo que es menor de edad',
  'contenido_inapropiado': 'Contenido inapropiado',
  'spam': 'Spam',
  'otro': 'Otro motivo',
};

/// Persona a la que he bloqueado.
///
/// El nombre es opcional porque la politica de `profiles` oculta el perfil
/// de quien bloqueas: sin una RPC del servidor (ver docs/pendiente-backend.md)
/// solo conocemos su identificador.
class UsuarioBloqueado {
  const UsuarioBloqueado({
    required this.id,
    this.nombre,
    this.username,
    this.avatarUrl,
    this.bloqueadoEn,
  });

  final String id;
  final String? nombre;
  final String? username;
  final String? avatarUrl;
  final DateTime? bloqueadoEn;

  String get etiqueta =>
      nombre ?? (username != null ? '@$username' : 'Usuario bloqueado');

  factory UsuarioBloqueado.desdeJson(Map<String, dynamic> json) =>
      UsuarioBloqueado(
        id: (json['blocked_id'] ?? json['id']) as String,
        nombre: json['display_name'] as String?,
        username: json['username'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        bloqueadoEn: json['created_at'] == null
            ? null
            : DateTime.tryParse(json['created_at'] as String)?.toLocal(),
      );
}

/// Convierte cualquier fallo de red o de Supabase en un mensaje que se pueda
/// ensenar tal cual. Se separa de la clase para poder probarlo sin red.
///
/// [accion] es un infinitivo en minuscula ("bloquear", "enviar el reporte"):
/// asi el mensaje dice que ha fallado en lugar de un "algo ha fallado"
/// generico.
ErrorPrevia traducirErrorDeSeguridad(Object error, {required String accion}) {
  if (error is ErrorPrevia) return error;

  if (error is PostgrestException) {
    final m = error.message.toLowerCase();
    // 23505 = unique_violation: ya estaba hecho.
    if (error.code == '23505' || m.contains('duplicate')) {
      return const ErrorPrevia('Ya lo habías hecho antes.');
    }
    // 42501 = permiso denegado por RLS.
    if (error.code == '42501' || m.contains('row-level security')) {
      return ErrorPrevia('No tienes permiso para $accion.');
    }
    if (error.code == '23514' || m.contains('check')) {
      return ErrorPrevia('Los datos no son válidos, no se ha podido $accion.');
    }
    return ErrorPrevia('No se ha podido $accion. Inténtalo de nuevo.');
  }

  if (error is AuthException) {
    return const ErrorPrevia('Tu sesión ha caducado. Vuelve a entrar.');
  }

  // Sin conexion, tiempo agotado, etc.
  return ErrorPrevia(
    'No se ha podido $accion. Comprueba tu conexión e inténtalo de nuevo.',
  );
}

/// Bloquear, reportar, salir de una previa y gestionar los bloqueos.
///
/// Vive aparte de `RepositorioPrevias` para que cada pantalla de seguridad
/// dependa de una superficie pequena y para poder probarla con un doble.
class RepositorioSeguridad {
  RepositorioSeguridad(this._cliente);

  final SupabaseClient _cliente;

  String _miId() {
    final id = _cliente.auth.currentUser?.id;
    if (id == null) throw const ErrorPrevia('No hay sesión iniciada.');
    return id;
  }

  Future<void> bloquear(String perfilId) async {
    final yo = _miId();
    if (perfilId == yo) {
      throw const ErrorPrevia('No puedes bloquearte a ti mismo.');
    }
    try {
      await _cliente.from('blocks').insert({
        'blocker_id': yo,
        'blocked_id': perfilId,
      });
    } on PostgrestException catch (e) {
      // Bloquear dos veces no es un fallo: el resultado buscado ya existe.
      if (e.code == '23505') return;
      throw traducirErrorDeSeguridad(e, accion: 'bloquear');
    } catch (e) {
      throw traducirErrorDeSeguridad(e, accion: 'bloquear');
    }
  }

  Future<void> desbloquear(String perfilId) async {
    final yo = _miId();
    try {
      await _cliente
          .from('blocks')
          .delete()
          .eq('blocker_id', yo)
          .eq('blocked_id', perfilId);
    } catch (e) {
      throw traducirErrorDeSeguridad(e, accion: 'desbloquear');
    }
  }

  Future<void> reportar({
    required String motivo,
    String? perfilId,
    String? previaId,
    String? mensajeId,
    String? detalles,
  }) async {
    final yo = _miId();
    if (perfilId == null && previaId == null && mensajeId == null) {
      // La tabla exige un objeto reportado (constraint reporte_con_objeto).
      throw const ErrorPrevia('No se sabe qué quieres reportar.');
    }
    if (perfilId == yo) {
      throw const ErrorPrevia('No puedes reportarte a ti mismo.');
    }
    final texto = detalles?.trim();
    try {
      await _cliente.from('reports').insert({
        'reporter_id': yo,
        'reported_id': perfilId,
        'party_id': previaId,
        'message_id': mensajeId,
        'reason': motivo,
        if (texto != null && texto.isNotEmpty) 'details': texto,
      });
    } catch (e) {
      throw traducirErrorDeSeguridad(e, accion: 'enviar el reporte');
    }
  }

  /// Salir de una previa siendo invitado. El anfitrion no puede: la politica
  /// de RLS solo deja borrar la fila propia si el rol es `guest`; el
  /// anfitrion debe cancelar la previa.
  Future<void> salirDeLaPrevia(String previaId) async {
    final yo = _miId();
    try {
      final borradas = await _cliente
          .from('party_members')
          .delete()
          .eq('party_id', previaId)
          .eq('profile_id', yo)
          .eq('role', 'guest')
          .select('profile_id');
      if ((borradas as List).isEmpty) {
        throw const ErrorPrevia(
          'No se ha podido salir. Si eres el anfitrión, cancela la previa.',
        );
      }
    } catch (e) {
      throw traducirErrorDeSeguridad(e, accion: 'salir de la previa');
    }
  }

  /// Si soy anfitrion de la previa (para ocultar "Salir").
  Future<bool> soyAnfitrion(String previaId) async {
    final yo = _cliente.auth.currentUser?.id;
    if (yo == null) return false;
    try {
      final fila = await _cliente
          .from('party_members')
          .select('role')
          .eq('party_id', previaId)
          .eq('profile_id', yo)
          .maybeSingle();
      return fila?['role'] == 'host';
    } catch (_) {
      return false;
    }
  }

  /// Personas bloqueadas por mi.
  ///
  /// Intenta la RPC `mis_bloqueados` (con nombres). Si el backend aun no la
  /// tiene, cae a la tabla `blocks`, que si puedo leer, y muestra solo los
  /// identificadores: es mejor poder desbloquear "Usuario bloqueado" que no
  /// poder hacerlo.
  Future<List<UsuarioBloqueado>> bloqueados() async {
    final yo = _miId();
    try {
      try {
        final filas = await _cliente.rpc('mis_bloqueados') as List;
        return filas
            .map(
              (f) => UsuarioBloqueado.desdeJson(
                Map<String, dynamic>.from(f as Map),
              ),
            )
            .toList();
      } on PostgrestException {
        final filas = await _cliente
            .from('blocks')
            .select('blocked_id, created_at')
            .eq('blocker_id', yo)
            .order('created_at', ascending: false);
        return (filas as List)
            .map(
              (f) => UsuarioBloqueado.desdeJson(
                Map<String, dynamic>.from(f as Map),
              ),
            )
            .toList();
      }
    } catch (e) {
      throw traducirErrorDeSeguridad(
        e,
        accion: 'cargar los usuarios bloqueados',
      );
    }
  }
}
