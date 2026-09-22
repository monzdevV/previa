import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/noche.dart';
import '../../data/models/publicacion.dart';
import '../../data/repositories/repositorio_auth.dart';
import '../../data/repositories/repositorio_social.dart';

/// Todo lo que alimenta la pantalla de perfil, junto.
///
/// Estaba repartido entre tres ficheros y cada sitio refrescaba solo lo suyo:
/// se subia una foto y la cabecera seguia enseñando la anterior, se guardaba
/// el perfil y los contadores no se movian. Teniendolo aqui, [refrescarPerfil]
/// no se puede dejar ninguno por el camino.

final misPublicacionesProvider = FutureProvider<List<Publicacion>>((ref) async {
  final yo = ref.watch(repositorioAuthProvider).usuarioActual?.id;
  if (yo == null) return const [];
  return ref.watch(repositorioSocialProvider).publicacionesDe(yo);
});

final miFichaProvider = FutureProvider.family<PerfilPublico, String>(
  (ref, id) => ref.watch(repositorioSocialProvider).perfilPublico(id),
);

final misSalidasProvider = FutureProvider<List<Salida>>(
  (ref) => ref.watch(repositorioSocialProvider).misUltimasSalidas(),
);

final deEsasNochesProvider = FutureProvider<List<Publicacion>>(
  (ref) => ref.watch(repositorioSocialProvider).fotosDeMisNoches(),
);

final rachaProvider = FutureProvider<Racha>(
  (ref) => ref.watch(repositorioSocialProvider).miRacha(),
);

final resumenProvider = FutureProvider.family<ResumenDeNoche, DateTime>(
  (ref, noche) => ref.watch(repositorioSocialProvider).resumenDeNoche(noche),
);

/// Vuelve a pedirlo todo. Se llama al guardar el perfil, al subir una foto y
/// al tirar hacia abajo.
void refrescarPerfil(WidgetRef ref) {
  ref.invalidate(miPerfilProvider);
  ref.invalidate(misPublicacionesProvider);
  ref.invalidate(miFichaProvider);
  ref.invalidate(misSalidasProvider);
  ref.invalidate(deEsasNochesProvider);
  ref.invalidate(rachaProvider);
}
