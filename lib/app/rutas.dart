import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/repositories/repositorio_auth.dart';
import '../features/auth/pantalla_bienvenida.dart';
import '../features/auth/pantalla_entrar.dart';
import '../features/auth/pantalla_registro.dart';
import '../features/map/pantalla_inicio.dart';
import '../features/party/pantalla_crear_previa.dart';
import '../features/party/pantalla_detalle_previa.dart';

abstract final class Rutas {
  static const bienvenida = '/bienvenida';
  static const entrar = '/entrar';
  static const registro = '/registro';
  static const inicio = '/';
  static const crearPrevia = '/crear';
  static const previa = '/previa';
}

/// Puente entre el flujo de sesion de Supabase y go_router, que espera un
/// Listenable para saber cuando reevaluar las redirecciones.
class _AvisoDeSesion extends ChangeNotifier {
  _AvisoDeSesion(Stream<AuthState> flujo) {
    notifyListeners();
    _suscripcion = flujo.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _suscripcion;

  @override
  void dispose() {
    _suscripcion.cancel();
    super.dispose();
  }
}

final enrutadorProvider = Provider<GoRouter>((ref) {
  final cliente = ref.watch(clienteSupabaseProvider);
  final aviso = _AvisoDeSesion(cliente.auth.onAuthStateChange);
  ref.onDispose(aviso.dispose);

  return GoRouter(
    initialLocation: Rutas.inicio,
    refreshListenable: aviso,

    // Un guardia unico en lugar de comprobaciones repartidas por las
    // pantallas: asi es imposible que a una se le olvide.
    redirect: (context, estado) {
      final haySesion = cliente.auth.currentUser != null;
      final ruta = estado.matchedLocation;
      final enZonaPublica = ruta == Rutas.bienvenida ||
          ruta == Rutas.entrar ||
          ruta == Rutas.registro;

      if (!haySesion && !enZonaPublica) return Rutas.bienvenida;
      if (haySesion && enZonaPublica) return Rutas.inicio;
      return null;
    },

    routes: [
      GoRoute(
        path: Rutas.bienvenida,
        builder: (_, _) => const PantallaBienvenida(),
      ),
      GoRoute(
        path: Rutas.entrar,
        builder: (_, _) => const PantallaEntrar(),
      ),
      GoRoute(
        path: Rutas.registro,
        builder: (_, _) => const PantallaRegistro(),
      ),
      GoRoute(
        path: Rutas.inicio,
        builder: (_, _) => const PantallaInicio(),
      ),
      GoRoute(
        path: Rutas.crearPrevia,
        builder: (_, _) => const PantallaCrearPrevia(),
      ),
      GoRoute(
        path: '${Rutas.previa}/:id',
        builder: (_, estado) => PantallaDetallePrevia(
          previaId: estado.pathParameters['id']!,
        ),
      ),
    ],
  );
});
