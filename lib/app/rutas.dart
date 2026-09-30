import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/repositories/repositorio_auth.dart';
import '../features/auth/pantalla_bienvenida.dart';
import '../features/auth/pantalla_entrar.dart';
import '../features/auth/pantalla_registro.dart';
import '../features/map/pantalla_inicio.dart';
import '../features/onboarding/pantalla_onboarding.dart';
import '../features/onboarding/servicio_onboarding.dart';
import '../features/chat/pantalla_chat.dart';
import '../features/juegos/pantalla_hub_juegos.dart';
import '../features/party/pantalla_crear_previa.dart';
import '../features/party/pantalla_detalle_previa.dart';
import '../features/profile/pantalla_ajustes.dart';
import '../features/profile/pantalla_editar_perfil.dart';
import '../features/ratings/pantalla_por_valorar.dart';
import '../features/ratings/pantalla_valorar.dart';
import '../features/requests/pantalla_mis_solicitudes.dart';
import '../features/requests/pantalla_solicitudes.dart';

abstract final class Rutas {
  static const bienvenida = '/bienvenida';
  static const entrar = '/entrar';
  static const registro = '/registro';
  static const onboarding = '/bienvenida-tarjetas';
  static const inicio = '/';
  static const crearPrevia = '/crear';
  static const previa = '/previa';
  static const misSolicitudes = '/mis-solicitudes';
  static const editarPerfil = '/editar-perfil';
  static const porValorar = '/por-valorar';
  static const ajustes = '/ajustes';
  static const juegos = '/juegos';
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
    redirect: (context, estado) async {
      final haySesion = cliente.auth.currentUser != null;
      final ruta = estado.matchedLocation;
      final enZonaPublica =
          ruta == Rutas.bienvenida ||
          ruta == Rutas.entrar ||
          ruta == Rutas.registro;

      if (!haySesion && !enZonaPublica) return Rutas.bienvenida;
      // Primera vez en este dispositivo: onboarding antes del inicio, tanto
      // con sesion recien creada como con una sesion ya guardada.
      if (haySesion &&
          (enZonaPublica || ruta == Rutas.inicio) &&
          !await ServicioOnboarding.yaVisto()) {
        return Rutas.onboarding;
      }
      if (haySesion && enZonaPublica) return Rutas.inicio;
      return null;
    },

    routes: [
      GoRoute(
        path: Rutas.bienvenida,
        pageBuilder: (_, e) => _pagina(e, const PantallaBienvenida()),
      ),
      GoRoute(
        path: Rutas.entrar,
        pageBuilder: (_, e) => _pagina(e, const PantallaEntrar()),
      ),
      GoRoute(
        path: Rutas.registro,
        pageBuilder: (_, e) => _pagina(e, const PantallaRegistro()),
      ),
      GoRoute(
        path: Rutas.onboarding,
        pageBuilder: (_, e) => _pagina(e, const PantallaOnboarding()),
      ),
      GoRoute(
        path: Rutas.inicio,
        pageBuilder: (_, e) => _pagina(e, const PantallaInicio()),
      ),
      GoRoute(
        path: Rutas.crearPrevia,
        pageBuilder: (_, e) => _pagina(e, const PantallaCrearPrevia()),
      ),
      GoRoute(
        path: Rutas.misSolicitudes,
        pageBuilder: (_, e) => _pagina(e, const PantallaMisSolicitudes()),
      ),
      GoRoute(
        path: Rutas.editarPerfil,
        pageBuilder: (_, e) => _pagina(e, const PantallaEditarPerfil()),
      ),
      GoRoute(
        path: '${Rutas.previa}/:id',
        pageBuilder: (_, estado) => _pagina(
          estado,
          PantallaDetallePrevia(previaId: estado.pathParameters['id']!),
        ),
        routes: [
          GoRoute(
            path: 'solicitudes',
            pageBuilder: (_, estado) => _pagina(
              estado,
              PantallaSolicitudes(previaId: estado.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: 'chat',
            pageBuilder: (_, estado) => _pagina(
              estado,
              PantallaChat(
                previaId: estado.pathParameters['id']!,
                titulo: estado.uri.queryParameters['titulo'],
              ),
            ),
          ),
          GoRoute(
            path: 'valorar',
            pageBuilder: (_, estado) => _pagina(
              estado,
              PantallaValorar(
                previaId: estado.pathParameters['id']!,
                titulo: estado.uri.queryParameters['titulo'],
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: Rutas.porValorar,
        pageBuilder: (_, e) => _pagina(e, const PantallaPorValorar()),
      ),
      GoRoute(
        path: Rutas.ajustes,
        pageBuilder: (_, e) => _pagina(e, const PantallaAjustes()),
      ),
      GoRoute(
        path: Rutas.juegos,
        pageBuilder: (_, e) =>
            _pagina(e, const PantallaHubJuegos(conAtras: true)),
      ),
    ],
  );
});

/// Pagina con transicion comun a toda la app: fundido con un ligero
/// desplazamiento vertical (estilo "fade-through").
///
/// Se centraliza aqui para que todas las pantallas se muevan igual; antes
/// cada una usaba la transicion por defecto de la plataforma. Con "reducir
/// movimiento" del sistema la pantalla aparece sin animar.
CustomTransitionPage<void> _pagina(GoRouterState estado, Widget hijo) {
  return CustomTransitionPage<void>(
    key: estado.pageKey,
    child: hijo,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animacion, secundaria, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;

      final curva = CurvedAnimation(
        parent: animacion,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      // La pantalla que queda debajo se atenua un poco para dar profundidad.
      final atenuada = Tween<double>(
        begin: 1,
        end: 0.85,
      ).animate(CurvedAnimation(parent: secundaria, curve: Curves.easeOut));
      return FadeTransition(
        opacity: atenuada,
        child: FadeTransition(
          opacity: curva,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curva),
            child: child,
          ),
        ),
      );
    },
  );
}
