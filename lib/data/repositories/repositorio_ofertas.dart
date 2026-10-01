import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/oferta.dart';
import 'repositorio_auth.dart' show ErrorPrevia;

/// Lo que la app necesita de las ofertas en vivo.
///
/// Es una interfaz porque la migracion `ofertas_en_vivo` aun no esta aplicada
/// en el proyecto compartido: la pantalla se desarrolla y se prueba contra
/// [RepositorioOfertasEnMemoria], y cuando exista el backend se escribe la
/// implementacion de Supabase sin tocar ninguna pantalla.
abstract interface class RepositorioOfertas {
  /// Ofertas activas del local que la persona puede ver y canjear. El servidor
  /// ya filtra por presencia y edad (RLS); aqui solo llegan las que valen.
  Future<List<Oferta>> activasDe(String localId);

  /// Canjea y devuelve el codigo que se ensena en la puerta. [codigoPuerta] es
  /// lo que lleva el QR del local y solo se pide si la oferta lo exige.
  Future<String> canjear(String ofertaId, {String? codigoPuerta});

  /// Si quien mira lleva este local. Decide si se ofrece "Lanzar oferta".
  Future<bool> soyDueno(String localId);

  /// Las ofertas de esta noche del local, activas o no, para su panel.
  Future<List<Oferta>> delLocal(String localId);

  Future<Oferta> lanzar({
    required String localId,
    required PlantillaOferta plantilla,
    required Duration duracion,
    required int cupos,
  });

  Future<void> cancelar(String ofertaId);

  /// El codigo que lleva el QR de la puerta, para que el dueño lo imprima.
  Future<String> codigoDePuerta(String ofertaId);
}

/// Duraciones que ofrece la app. La base de datos admite de 5 a 120 minutos;
/// aqui se ofrece menos para que nadie deje una "oferta en vivo" abierta toda
/// la noche, que dejaria de ser en vivo.
const duracionesDeOferta = [
  Duration(minutes: 15),
  Duration(minutes: 30),
  Duration(minutes: 45),
  Duration(minutes: 60),
];

const maximoOfertasActivas = 2;
const cuposMinimos = 10;
const cuposMaximos = 200;

/// Implementacion para desarrollo y pruebas: nada sale del telefono.
///
/// Reproduce las reglas de la base de datos (cupos, un canje por persona,
/// maximo de ofertas activas, QR) para que la UI se pruebe contra el mismo
/// comportamiento que tendra el servidor.
class RepositorioOfertasEnMemoria implements RepositorioOfertas {
  RepositorioOfertasEnMemoria({
    this.duenoDe = const {},
    DateTime Function()? reloj,
    List<Oferta> iniciales = const [],
    this.demo = false,
  }) : _reloj = reloj ?? DateTime.now,
       _ofertas = [...iniciales];

  /// Locales de los que quien usa la app es dueño.
  final Set<String> duenoDe;

  /// Modo ensenanza: cada local tiene una oferta de muestra y quien usa la
  /// app es dueño de todos. Nunca se activa en pruebas ni en producto.
  final bool demo;
  final DateTime Function() _reloj;
  final List<Oferta> _ofertas;
  final Map<String, String> _puertas = {};
  int _siguiente = 1;

  @override
  Future<List<Oferta>> activasDe(String localId) async {
    final ahora = _reloj();
    if (demo && !_ofertas.any((o) => o.localId == localId)) {
      _ofertas.add(
        Oferta(
          id: 'demo-$localId',
          localId: localId,
          categoria: CategoriaOferta.foto,
          titulo: 'Foto de grupo gratis',
          detalle: 'Pasa por el fotomatón con tu grupo.',
          inicio: ahora,
          fin: ahora.add(const Duration(minutes: 45)),
          cupos: 40,
          canjes: 12,
          verificacion: VerificacionOferta.aqui,
        ),
      );
    }
    return [
      for (final o in _ofertas)
        if (o.localId == localId && o.activa(ahora)) o,
    ];
  }

  @override
  Future<bool> soyDueno(String localId) async =>
      demo || duenoDe.contains(localId);

  @override
  Future<List<Oferta>> delLocal(String localId) async {
    _exigirDueno(localId);
    return [
      for (final o in _ofertas.reversed)
        if (o.localId == localId) o,
    ];
  }

  @override
  Future<Oferta> lanzar({
    required String localId,
    required PlantillaOferta plantilla,
    required Duration duracion,
    required int cupos,
  }) async {
    _exigirDueno(localId);
    if (promueveAlcohol('${plantilla.titulo} ${plantilla.detalle}')) {
      throw const ErrorPrevia(
        'Las ofertas no pueden promover el consumo de alcohol.',
      );
    }
    final ahora = _reloj();
    final activas = _ofertas
        .where((o) => o.localId == localId && o.activa(ahora))
        .length;
    if (activas >= maximoOfertasActivas) {
      throw const ErrorPrevia('Ya hay dos ofertas activas en este local.');
    }
    if (cupos < 1 || cupos > 500) {
      throw const ErrorPrevia('Los cupos van de 1 a 500.');
    }
    final id = 'oferta-${_siguiente++}';
    final oferta = Oferta(
      id: id,
      localId: localId,
      categoria: plantilla.categoria,
      titulo: plantilla.titulo,
      detalle: plantilla.detalle,
      inicio: ahora,
      fin: ahora.add(duracion),
      cupos: cupos,
      verificacion: plantilla.verificacion,
    );
    _ofertas.add(oferta);
    _puertas[id] = 'PUERTA${id.hashCode.abs() % 100000}';
    return oferta;
  }

  @override
  Future<void> cancelar(String ofertaId) async {
    final i = _indice(ofertaId);
    _exigirDueno(_ofertas[i].localId);
    _ofertas[i] = _ofertas[i].copiaCon(cancelada: true);
  }

  @override
  Future<String> codigoDePuerta(String ofertaId) async {
    final o = _ofertas[_indice(ofertaId)];
    _exigirDueno(o.localId);
    return _puertaDe(ofertaId);
  }

  /// Las ofertas sembradas en pruebas no pasaron por [lanzar]: comparten un
  /// codigo fijo para poder ejercitar el canje con QR.
  String _puertaDe(String ofertaId) => _puertas[ofertaId] ?? 'PUERTA';

  @override
  Future<String> canjear(String ofertaId, {String? codigoPuerta}) async {
    final i = _ofertas.indexWhere((o) => o.id == ofertaId);
    if (i < 0) throw const ErrorPrevia('La oferta ya no está activa.');
    final o = _ofertas[i];
    if (!o.activa(_reloj())) {
      throw const ErrorPrevia('La oferta ya no está activa.');
    }
    // Repetir devuelve el mismo codigo, como el servidor: un segundo toque no
    // gasta cupo ni da error.
    if (o.miCodigo != null) return o.miCodigo!;
    if (o.verificacion == VerificacionOferta.qr &&
        codigoPuerta?.trim().toUpperCase() != _puertaDe(ofertaId)) {
      throw const ErrorPrevia('Escanea el QR de la puerta.');
    }
    if (o.agotada) throw const ErrorPrevia('Se han agotado los cupos.');
    final codigo = 'C${(1000 + o.canjes * 37) % 9000 + 1000}${o.canjes}';
    _ofertas[i] = o.copiaCon(canjes: o.canjes + 1, miCodigo: codigo);
    return codigo;
  }

  int _indice(String id) {
    final i = _ofertas.indexWhere((o) => o.id == id);
    if (i < 0) throw const ErrorPrevia('No encontramos esa oferta.');
    return i;
  }

  void _exigirDueno(String localId) {
    if (!demo && !duenoDe.contains(localId)) {
      throw const ErrorPrevia('Solo el dueño del local puede hacer esto.');
    }
  }
}

/// Mientras no exista la implementacion contra Supabase, en producto no hay
/// ofertas ni dueños: ni se enseña nada inventado ni se ofrece lanzar. Con
/// `--dart-define=OFERTAS_DEMO=true` se activa una demo en memoria para
/// ensenarla en desarrollo.
const _demo = bool.fromEnvironment('OFERTAS_DEMO');

final repositorioOfertasProvider = Provider<RepositorioOfertas>((ref) {
  return RepositorioOfertasEnMemoria(demo: _demo);
});

/// Ofertas activas de un local. Se recarga con `ref.invalidate`.
final ofertasActivasProvider = FutureProvider.autoDispose
    .family<List<Oferta>, String>(
      (ref, localId) =>
          ref.watch(repositorioOfertasProvider).activasDe(localId),
    );

final soyDuenoProvider = FutureProvider.autoDispose.family<bool, String>(
  (ref, localId) => ref.watch(repositorioOfertasProvider).soyDueno(localId),
);

final ofertasDelLocalProvider = FutureProvider.autoDispose
    .family<List<Oferta>, String>(
      (ref, localId) => ref.watch(repositorioOfertasProvider).delLocal(localId),
    );
