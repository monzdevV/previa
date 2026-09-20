import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/entorno.dart';
import '../models/previa.dart';
import 'repositorio_auth.dart';

final repositorioPreviasProvider = Provider<RepositorioPrevias>(
  (ref) => RepositorioPrevias(ref.watch(clienteSupabaseProvider)),
);

/// Criterios de busqueda del mapa.
class FiltrosBusqueda {
  const FiltrosBusqueda({
    required this.centro,
    this.radioMetros = Entorno.radioBusquedaPorDefecto,
    this.horas = Entorno.horasPorDefecto,
    this.plazasMinimas = 1,
  });

  final LatLng centro;
  final int radioMetros;
  final int horas;
  final int plazasMinimas;
}

class RepositorioPrevias {
  RepositorioPrevias(this._cliente);

  final SupabaseClient _cliente;

  static const _camposConAnfitrion = '''
    id, host_id, title, description, vibe, area_label, location_fuzzed,
    starts_at, spots_total, spots_taken, min_age, max_age, status,
    profiles!parties_host_id_fkey ( display_name, avatar_url, reputation )
  ''';

  /// Busqueda geografica. Toda la filtracion ocurre en el servidor, que
  /// devuelve unicamente ubicaciones difuminadas.
  Future<List<Previa>> buscarCerca(FiltrosBusqueda filtros) async {
    final filas = await _cliente.rpc('previas_cerca', params: {
      'p_lat': filtros.centro.latitude,
      'p_lng': filtros.centro.longitude,
      'p_radio_m': filtros.radioMetros,
      'p_horas': filtros.horas,
      'p_plazas_min': filtros.plazasMinimas,
    });

    return (filas as List)
        .map((f) => Previa.desdeBusqueda(Map<String, dynamic>.from(f as Map)))
        .toList();
  }

  Future<Previa> detalle(String previaId) async {
    final fila = await _cliente
        .from('parties')
        .select(_camposConAnfitrion)
        .eq('id', previaId)
        .single();
    return Previa.desdeTabla(fila);
  }

  Future<List<Previa>> misPrevias() async {
    final id = _cliente.auth.currentUser?.id;
    if (id == null) return [];

    final filas = await _cliente
        .from('parties')
        .select(_camposConAnfitrion)
        .eq('host_id', id)
        .order('starts_at');

    return (filas as List)
        .map((f) => Previa.desdeTabla(Map<String, dynamic>.from(f as Map)))
        .toList();
  }

  /// Crea una previa. `location_fuzzed` se manda igual que `location` porque
  /// la columna es NOT NULL, pero un disparador la sobrescribe de inmediato
  /// con el punto desplazado. El valor enviado nunca llega a leerse.
  Future<String> crear({
    required String titulo,
    required String zona,
    required LatLng ubicacionExacta,
    required DateTime empiezaEn,
    required int plazas,
    String? descripcion,
    List<String> ambiente = const [],
    int edadMinima = 18,
    int? edadMaxima,
  }) async {
    final id = _cliente.auth.currentUser?.id;
    if (id == null) throw const ErrorPrevia('No hay sesión iniciada.');

    final punto = 'SRID=4326;POINT(${ubicacionExacta.longitude} '
        '${ubicacionExacta.latitude})';

    try {
      final fila = await _cliente
          .from('parties')
          .insert({
            'host_id': id,
            'title': titulo.trim(),
            'description': descripcion?.trim(),
            'vibe': ambiente,
            'area_label': zona.trim(),
            'location': punto,
            'location_fuzzed': punto,
            'starts_at': empiezaEn.toUtc().toIso8601String(),
            'spots_total': plazas,
            'min_age': edadMinima,
            'max_age': edadMaxima,
          })
          .select('id')
          .single();
      return fila['id'] as String;
    } on PostgrestException catch (e) {
      throw ErrorPrevia(_traducir(e.message));
    }
  }

  Future<void> cancelar(String previaId) async {
    await _cliente.from('parties').update({'status': 'cancelled'}).eq('id', previaId);
  }

  /// Direccion exacta. Falla a proposito si no eres asistente aceptado:
  /// la comprobacion la hace el servidor, no esta aplicacion.
  Future<LatLng> ubicacionExacta(String previaId) async {
    try {
      final filas = await _cliente.rpc('ubicacion_exacta', params: {
        'p_party': previaId,
      });
      final lista = filas as List;
      if (lista.isEmpty) throw const ErrorPrevia('No se encontró la previa.');
      final f = Map<String, dynamic>.from(lista.first as Map);
      return LatLng((f['lat'] as num).toDouble(), (f['lng'] as num).toDouble());
    } on PostgrestException {
      throw const ErrorPrevia(
        'Solo los asistentes aceptados pueden ver la dirección exacta.',
      );
    }
  }

  /// Si soy asistente aceptado de esta previa. Determina si puedo ver la
  /// direccion exacta y entrar al chat.
  Future<bool> soyMiembro(String previaId) async {
    final id = _cliente.auth.currentUser?.id;
    if (id == null) return false;

    final fila = await _cliente
        .from('party_members')
        .select('profile_id')
        .eq('party_id', previaId)
        .eq('profile_id', id)
        .maybeSingle();

    return fila != null;
  }

  /// Mi solicitud en esta previa, si la hay.
  Future<Solicitud?> miSolicitudEn(String previaId) async {
    final id = _cliente.auth.currentUser?.id;
    if (id == null) return null;

    final fila = await _cliente
        .from('join_requests')
        .select()
        .eq('party_id', previaId)
        .eq('requester_id', id)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return fila == null ? null : Solicitud.desdeJson(fila);
  }

  // --- Solicitudes ---------------------------------------------------------

  Future<void> solicitarPlaza({
    required String previaId,
    required int tamanoGrupo,
    String? mensaje,
  }) async {
    final id = _cliente.auth.currentUser?.id;
    if (id == null) throw const ErrorPrevia('No hay sesión iniciada.');

    try {
      await _cliente.from('join_requests').insert({
        'party_id': previaId,
        'requester_id': id,
        'group_size': tamanoGrupo,
        'message': mensaje?.trim(),
      });
    } on PostgrestException catch (e) {
      throw ErrorPrevia(_traducir(e.message));
    }
  }

  Future<List<Solicitud>> solicitudesDe(String previaId) async {
    final filas = await _cliente
        .from('join_requests')
        .select('*, profiles!join_requests_requester_id_fkey '
            '( display_name, avatar_url, reputation )')
        .eq('party_id', previaId)
        .order('created_at');

    return (filas as List)
        .map((f) => Solicitud.desdeJson(Map<String, dynamic>.from(f as Map)))
        .toList();
  }

  Future<List<Solicitud>> misSolicitudes() async {
    final id = _cliente.auth.currentUser?.id;
    if (id == null) return [];

    final filas = await _cliente
        .from('join_requests')
        .select('*, parties ( title, area_label, starts_at, status )')
        .eq('requester_id', id)
        .order('created_at', ascending: false);

    return (filas as List)
        .map((f) => Solicitud.desdeJson(Map<String, dynamic>.from(f as Map)))
        .toList();
  }

  /// Aceptar o rechazar. El recuento de plazas y el alta como miembro los
  /// hace un disparador, no esta aplicacion.
  Future<void> responderSolicitud(String solicitudId, {required bool aceptar}) async {
    try {
      await _cliente
          .from('join_requests')
          .update({'status': aceptar ? 'accepted' : 'rejected'})
          .eq('id', solicitudId);
    } on PostgrestException catch (e) {
      throw ErrorPrevia(_traducir(e.message));
    }
  }

  Future<void> cancelarSolicitud(String solicitudId) async {
    await _cliente
        .from('join_requests')
        .update({'status': 'cancelled'})
        .eq('id', solicitudId);
  }

  /// Quien va a la previa, con sus datos publicos.
  /// RLS solo lo devuelve si tu tambien eres miembro.
  Future<List<Map<String, dynamic>>> miembrosDe(String previaId) async {
    final filas = await _cliente
        .from('party_members')
        .select('profile_id, role, group_size, '
            'profiles!party_members_profile_id_fkey '
            '( display_name, avatar_url, reputation )')
        .eq('party_id', previaId);

    return (filas as List)
        .map((f) => Map<String, dynamic>.from(f as Map))
        .toList();
  }

  // --- Chat ----------------------------------------------------------------

  /// Mensajes en tiempo real. Si no eres miembro, RLS devuelve una lista
  /// vacia: no hace falta comprobar nada aqui.
  Stream<List<Mensaje>> mensajesDe(String previaId) => _cliente
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('party_id', previaId)
      .order('created_at')
      .map((filas) => filas.map(Mensaje.desdeJson).toList());

  Future<void> enviarMensaje(String previaId, String texto) async {
    final id = _cliente.auth.currentUser?.id;
    if (id == null) throw const ErrorPrevia('No hay sesión iniciada.');
    if (texto.trim().isEmpty) return;

    await _cliente.from('messages').insert({
      'party_id': previaId,
      'sender_id': id,
      'body': texto.trim(),
    });
  }

  // --- Seguridad -----------------------------------------------------------

  Future<void> bloquear(String perfilId) async {
    final id = _cliente.auth.currentUser?.id;
    if (id == null) return;
    await _cliente
        .from('blocks')
        .insert({'blocker_id': id, 'blocked_id': perfilId});
  }

  Future<void> desbloquear(String perfilId) async {
    final id = _cliente.auth.currentUser?.id;
    if (id == null) return;
    await _cliente
        .from('blocks')
        .delete()
        .eq('blocker_id', id)
        .eq('blocked_id', perfilId);
  }

  Future<void> reportar({
    required String motivo,
    String? perfilId,
    String? previaId,
    String? mensajeId,
    String? detalles,
  }) async {
    final id = _cliente.auth.currentUser?.id;
    if (id == null) throw const ErrorPrevia('No hay sesión iniciada.');

    await _cliente.from('reports').insert({
      'reporter_id': id,
      'reported_id': perfilId,
      'party_id': previaId,
      'message_id': mensajeId,
      'reason': motivo,
      'details': detalles?.trim(),
    });
  }

  String _traducir(String mensaje) {
    final m = mensaje.toLowerCase();
    if (m.contains('join_requests_una_pendiente')) {
      return 'Ya tienes una solicitud pendiente en esta previa.';
    }
    if (m.contains('no quedan plazas')) {
      return 'Ya no quedan plazas suficientes para ese grupo.';
    }
    if (m.contains('row-level security') || m.contains('violates row-level')) {
      return 'No puedes hacer eso. Revisa que tu perfil esté completo.';
    }
    if (m.contains('plazas_coherentes')) {
      return 'El número de plazas no es válido.';
    }
    return 'Algo ha fallado. Inténtalo de nuevo.';
  }
}
