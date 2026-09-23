import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/reto.dart';
import 'repositorio_auth.dart';

final repositorioRetosProvider = Provider<RepositorioRetos>(
  (ref) => RepositorioRetos(ref.watch(clienteSupabaseProvider)),
);

/// El minijuego "No hay 🥚".
///
/// Pedir un reto pasa por la funcion de borde y no por la base de datos
/// directamente: es la que guarda la clave de la IA y la unica que puede
/// decidir a quien te toca. Lo demas (ver, cumplir, rajarse) son funciones
/// de la base de datos que ya comprueban que el reto es tuyo.
class RepositorioRetos {
  RepositorioRetos(this._cliente);

  final SupabaseClient _cliente;

  /// El reto abierto que tienes en este local, si lo hay.
  Future<Reto?> miReto(String localId) async {
    final filas = await _cliente.rpc('mi_reto', params: {'local': localId});
    final lista = filas as List;
    if (lista.isEmpty) return null;
    return Reto.desdeJson(Map<String, dynamic>.from(lista.first as Map));
  }

  /// Pide un reto nuevo. La posicion solo se usa para comprobar que estas
  /// dentro del local y no se guarda.
  Future<void> pedirReto(String localId, {double? lat, double? lng}) async {
    try {
      await _cliente.functions.invoke(
        'no-hay-huevos',
        body: {
          'local_id': localId,
          if (lat != null && lng != null) ...{'lat': lat, 'lng': lng},
        },
      );
    } on FunctionException catch (e) {
      final detalles = e.details;
      throw ErrorReto(
        MotivoSinReto.desdeCodigo(
          detalles is Map ? detalles['codigo'] as String? : null,
        ),
      );
    }
  }

  Future<void> completar(String retoId, String publicacionId) => _cliente.rpc(
    'completar_reto',
    params: {'reto': retoId, 'publicacion': publicacionId},
  );

  Future<void> rajarse(String retoId) =>
      _cliente.rpc('rajarse', params: {'reto': retoId});

  /// El reto cumplido de una foto en la que sales. Null si no hay ninguno
  /// o si ya se quito.
  Future<RetoConmigo?> retoDeLaFoto(String publicacionId) async {
    final fila = await _cliente
        .from('challenges')
        .select('id, prompt')
        .eq('post_id', publicacionId)
        .eq('target_id', _cliente.auth.currentUser!.id)
        .maybeSingle();
    if (fila == null) return null;
    return RetoConmigo(id: fila['id'] as String, texto: fila['prompt'] as String);
  }

  Future<void> quitarFoto(String retoId) =>
      _cliente.rpc('quitar_foto_de_reto', params: {'reto': retoId});

  /// Si sales en los retos de los demas.
  Future<bool> juego() async {
    final fila = await _cliente
        .from('profiles')
        .select('plays_challenges')
        .eq('id', _cliente.auth.currentUser!.id)
        .single();
    return fila['plays_challenges'] as bool? ?? true;
  }

  Future<void> cambiarJuego({required bool juego}) => _cliente
      .from('profiles')
      .update({'plays_challenges': juego})
      .eq('id', _cliente.auth.currentUser!.id);
}
