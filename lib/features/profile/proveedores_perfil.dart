import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/noche.dart';
import '../../domain/racha/regla_de_racha.dart';
import '../../data/models/publicacion.dart';
import '../../data/repositories/repositorio_auth.dart';
import '../../data/repositories/repositorio_calendario.dart';
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

/// Tu racha, calculada en el teléfono con las fechas de tus noches (sin
/// migración ni RPC: ver `regla_de_racha.dart`). Dos años de historia
/// sobran para el récord y acotan lo que se descarga.
final rachaProvider = FutureProvider<Racha>((ref) async {
  final uid = ref.watch(uidActualProvider);
  if (uid == null) return const Racha();
  final ahora = DateTime.now();
  final noches = await ref
      .watch(repositorioCalendarioProvider)
      .fechasDeNoches(uid, desde: DateTime(ahora.year - 2, ahora.month));
  return calcularRacha(noches, ahora: ahora);
});

final resumenProvider = FutureProvider.family<ResumenDeNoche, DateTime>(
  (ref, noche) => ref.watch(repositorioSocialProvider).resumenDeNoche(noche),
);

/// Las noches de una persona en un mes, para el calendario social.
///
/// La clave es el mes y no un rango: al deslizar de mes en mes cada pagina
/// se pide una vez y se queda en memoria mientras el perfil siga abierto.
final calendarioProvider =
    FutureProvider.family<List<NocheDelCalendario>, (String, DateTime)>((
      ref,
      clave,
    ) {
      final (perfilId, mes) = clave;
      return ref
          .watch(repositorioCalendarioProvider)
          .nochesDe(
            perfilId,
            desde: DateTime(mes.year, mes.month),
            hasta: DateTime(mes.year, mes.month + 1, 0),
          );
    });

/// Vuelve a pedirlo todo. Se llama al guardar el perfil, al subir una foto y
/// al tirar hacia abajo.
void refrescarPerfil(WidgetRef ref) {
  ref.invalidate(miPerfilProvider);
  ref.invalidate(misPublicacionesProvider);
  ref.invalidate(miFichaProvider);
  ref.invalidate(misSalidasProvider);
  ref.invalidate(deEsasNochesProvider);
  ref.invalidate(rachaProvider);
  ref.invalidate(calendarioProvider);
}
