import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/repositories/repositorio_auth.dart';
import '../features/auth/pantalla_bienvenida.dart';
import '../features/auth/pantalla_entrar.dart';
import '../features/auth/pantalla_registro.dart';
import '../features/feed/pantalla_publicar.dart';
import '../features/map/pantalla_inicio.dart';
import '../features/social/pantalla_buscar.dart';
import '../features/social/pantalla_locales.dart';
import '../features/social/pantalla_mis_noches.dart';
import '../features/social/pantalla_mensajes.dart';
import '../features/social/pantalla_perfil_publico.dart';
import '../features/chat/pantalla_chat.dart';
import '../features/party/pantalla_crear_previa.dart';
import '../features/party/pantalla_detalle_previa.dart';
import '../features/profile/pantalla_ajustes.dart';
import '../features/profile/pantallas_legales.dart';
import '../features/profile/pantalla_editar_perfil.dart';
import '../features/ratings/pantalla_por_valorar.dart';
import '../features/ratings/pantalla_valorar.dart';
import '../features/requests/pantalla_mis_solicitudes.dart';
import '../features/requests/pantalla_solicitudes.dart';

abstract final class Rutas {
  static const bienvenida = '/bienvenida';
  static const entrar = '/entrar';
  static const registro = '/registro';
  static const inicio = '/';
  static const crearPrevia = '/crear';
  static const previa = '/previa';
  static const misSolicitudes = '/mis-solicitudes';
  static const editarPerfil = '/editar-perfil';
  static const porValorar = '/por-valorar';
  static const ajustes = '/ajustes';
  static const buscar = '/buscar';
  static const publicar = '/publicar';
  static const locales = '/locales';
  static const misNoches = '/mis-noches';
  static const privacidad = '/privacidad';
  static const condiciones = '/condiciones';
  static const perfilDe = '/perfil';
  static const mensajes = '/mensajes';
  static const conversacion = '/conversacion';
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
      final enZonaPublica =
          ruta == Rutas.bienvenida ||
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
      GoRoute(path: Rutas.entrar, builder: (_, _) => const PantallaEntrar()),
      GoRoute(
        path: Rutas.registro,
        builder: (_, _) => const PantallaRegistro(),
      ),
      GoRoute(path: Rutas.inicio, builder: (_, _) => const PantallaInicio()),
      GoRoute(
        path: Rutas.crearPrevia,
        builder: (_, _) => const PantallaCrearPrevia(),
      ),
      GoRoute(
        path: Rutas.misSolicitudes,
        builder: (_, _) => const PantallaMisSolicitudes(),
      ),
      GoRoute(
        path: Rutas.editarPerfil,
        builder: (_, _) => const PantallaEditarPerfil(),
      ),
      GoRoute(
        path: '${Rutas.previa}/:id',
        builder: (_, estado) =>
            PantallaDetallePrevia(previaId: estado.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'solicitudes',
            builder: (_, estado) =>
                PantallaSolicitudes(previaId: estado.pathParameters['id']!),
          ),
          GoRoute(
            path: 'chat',
            builder: (_, estado) => PantallaChat(
              previaId: estado.pathParameters['id']!,
              titulo: estado.uri.queryParameters['titulo'],
            ),
          ),
          GoRoute(
            path: 'valorar',
            builder: (_, estado) => PantallaValorar(
              previaId: estado.pathParameters['id']!,
              titulo: estado.uri.queryParameters['titulo'],
            ),
          ),
        ],
      ),
      GoRoute(
        path: Rutas.porValorar,
        builder: (_, _) => const PantallaPorValorar(),
      ),
      GoRoute(path: Rutas.ajustes, builder: (_, _) => const PantallaAjustes()),
      GoRoute(
        path: Rutas.privacidad,
        builder: (_, _) => const PantallaPrivacidad(),
      ),
      GoRoute(
        path: Rutas.condiciones,
        builder: (_, _) => const PantallaCondiciones(),
      ),
      GoRoute(path: Rutas.buscar, builder: (_, _) => const PantallaBuscar()),
      GoRoute(path: Rutas.mensajes, builder: (_, _) => const PantallaMensajes()),
      GoRoute(
        path: '${Rutas.conversacion}/:id',
        builder: (_, estado) =>
            PantallaConversacion(otroId: estado.pathParameters['id']!),
      ),
      GoRoute(
        path: '${Rutas.perfilDe}/:id',
        builder: (_, estado) =>
            PantallaPerfilPublico(perfilId: estado.pathParameters['id']!),
      ),
      GoRoute(path: Rutas.locales, builder: (_, _) => const PantallaLocales()),
      GoRoute(
        path: Rutas.misNoches,
        builder: (_, _) => const PantallaMisNoches(),
      ),
      GoRoute(
        path: Rutas.publicar,
        builder: (_, _) => const PantallaPublicar(),
      ),
    ],
  );
});
