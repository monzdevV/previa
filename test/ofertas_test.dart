import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:previa/data/models/oferta.dart';
import 'package:previa/data/repositories/repositorio_auth.dart'
    show ErrorPrevia;
import 'package:previa/data/repositories/repositorio_ofertas.dart';
import 'package:previa/features/ofertas/pantalla_lanzar_oferta.dart';
import 'package:previa/features/ofertas/tarjeta_oferta.dart';

import 'apoyo_visual.dart';

void main() {
  var ahora = DateTime(2026, 10, 1, 1, 0);
  DateTime reloj() => ahora;

  setUp(() => ahora = DateTime(2026, 10, 1, 1, 0));

  Oferta oferta({
    int cupos = 2,
    int canjes = 0,
    VerificacionOferta verificacion = VerificacionOferta.aqui,
    int minutos = 30,
    String? miCodigo,
  }) => Oferta(
    id: 'o1',
    localId: 'l1',
    categoria: CategoriaOferta.foto,
    titulo: 'Foto de grupo gratis',
    inicio: ahora,
    fin: ahora.add(Duration(minutes: minutos)),
    cupos: cupos,
    canjes: canjes,
    verificacion: verificacion,
    miCodigo: miCodigo,
  );

  group('Oferta', () {
    test('cuenta atras y actividad', () {
      final o = oferta();
      expect(o.activa(ahora), isTrue);
      expect(o.restante(ahora), const Duration(minutes: 30));
      final despues = ahora.add(const Duration(minutes: 31));
      expect(o.activa(despues), isFalse);
      expect(o.restante(despues), Duration.zero);
    });

    test('una cancelada o agotada no se puede canjear', () {
      expect(oferta().canjeable(ahora), isTrue);
      expect(oferta(cupos: 2, canjes: 2).canjeable(ahora), isFalse);
      expect(oferta().copiaCon(cancelada: true).canjeable(ahora), isFalse);
      expect(oferta(miCodigo: 'ABC123').canjeable(ahora), isFalse);
    });

    test('el texto de la cuenta atras', () {
      expect(
        textoCuentaAtras(const Duration(minutes: 12, seconds: 5)),
        '12:05',
      );
      expect(textoCuentaAtras(const Duration(minutes: 75)), '1:15:00');
      expect(textoCuentaAtras(const Duration(seconds: -4)), '00:00');
    });

    test('desdeJson lee lo que manda el servidor', () {
      final o = Oferta.desdeJson({
        'id': 'x',
        'venue_id': 'l',
        'kind': 'guardarropa',
        'title': 'Guardarropa gratis',
        'starts_at': '2026-10-01T00:00:00Z',
        'ends_at': '2026-10-01T00:30:00Z',
        'max_redemptions': 60,
        'verification': 'aqui',
        'canjes': 4,
      });
      expect(o.categoria, CategoriaOferta.guardarropa);
      expect(o.cuposRestantes, 56);
      expect(o.verificacion, VerificacionOferta.aqui);
      expect(o.cancelada, isFalse);
    });
  });

  group('contenido legal', () {
    test('ninguna plantilla promueve alcohol', () {
      for (final p in PlantillaOferta.todas) {
        expect(
          promueveAlcohol('${p.titulo} ${p.detalle}'),
          isFalse,
          reason: p.id,
        );
      }
    });

    test('ninguna categoria es de bebida', () {
      expect(
        CategoriaOferta.values.map((c) => c.clave),
        isNot(anyOf(contains('bebida'), contains('copa'), contains('alcohol'))),
      );
    });

    test('se detecta el consumo de alcohol', () {
      for (final t in [
        'Barra libre hasta las 3',
        '2x1 en copas',
        'Bebe más, paga menos',
        'Chupitos gratis',
        'OPEN BAR',
        'Dos por uno en cubatas',
      ]) {
        expect(promueveAlcohol(t), isTrue, reason: t);
      }
      expect(promueveAlcohol('Entrada gratis si llegas ya'), isFalse);
    });
  });

  group('RepositorioOfertasEnMemoria', () {
    RepositorioOfertasEnMemoria repo({
      bool dueno = true,
      List<Oferta> ini = const [],
    }) => RepositorioOfertasEnMemoria(
      duenoDe: dueno ? {'l1'} : {},
      reloj: reloj,
      iniciales: ini,
    );

    test('solo el dueño lanza y cancela', () async {
      final r = repo(dueno: false);
      expect(
        () => r.lanzar(
          localId: 'l1',
          plantilla: PlantillaOferta.todas.first,
          duracion: const Duration(minutes: 30),
          cupos: 20,
        ),
        throwsA(isA<ErrorPrevia>()),
      );
    });

    test('maximo de dos ofertas activas', () async {
      final r = repo();
      for (var i = 0; i < 2; i++) {
        await r.lanzar(
          localId: 'l1',
          plantilla: PlantillaOferta.todas[2],
          duracion: const Duration(minutes: 15),
          cupos: 10,
        );
      }
      expect(
        () => r.lanzar(
          localId: 'l1',
          plantilla: PlantillaOferta.todas[3],
          duracion: const Duration(minutes: 15),
          cupos: 10,
        ),
        throwsA(isA<ErrorPrevia>()),
      );
      // Al caducar, se libera hueco.
      ahora = ahora.add(const Duration(minutes: 16));
      await r.lanzar(
        localId: 'l1',
        plantilla: PlantillaOferta.todas[3],
        duracion: const Duration(minutes: 15),
        cupos: 10,
      );
    });

    test('canje unico por persona y respeta el cupo', () async {
      final r = repo(ini: [oferta(cupos: 1)]);
      final a = await r.canjear('o1');
      final b = await r.canjear('o1');
      expect(b, a, reason: 'repetir no gasta cupo');
      expect((await r.activasDe('l1')).single.canjes, 1);
    });

    test('con QR hace falta el codigo de la puerta', () async {
      final r = repo(ini: [oferta(verificacion: VerificacionOferta.qr)]);
      expect(() => r.canjear('o1'), throwsA(isA<ErrorPrevia>()));
      expect(await r.canjear('o1', codigoPuerta: ' puerta '), isNotEmpty);
    });

    test('una oferta caducada no se canjea ni se lista', () async {
      final r = repo(ini: [oferta(minutos: 5)]);
      ahora = ahora.add(const Duration(minutes: 6));
      expect(await r.activasDe('l1'), isEmpty);
      expect(() => r.canjear('o1'), throwsA(isA<ErrorPrevia>()));
    });

    test('cancelar la quita de las activas', () async {
      final r = repo(ini: [oferta()]);
      await r.cancelar('o1');
      expect(await r.activasDe('l1'), isEmpty);
    });
  });

  group('TarjetaOferta', () {
    setUpAll(simularCarpetasDelSistema);

    Widget envoltorio(Widget hijo, {double escala = 1}) => MaterialApp(
      theme: temaDePrueba(),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(escala)),
        child: Scaffold(body: SingleChildScrollView(child: hijo)),
      ),
    );

    testWidgets('muestra la cuenta atras y avanza', (tester) async {
      await tester.pumpWidget(
        envoltorio(
          TarjetaOferta(oferta: oferta(), onCanjear: () {}, ahora: reloj),
        ),
      );
      expect(find.text('Termina en 30:00'), findsOneWidget);
      ahora = ahora.add(const Duration(seconds: 90));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Termina en 28:30'), findsOneWidget);
      expect(find.text('Quedan 2 de 2'), findsOneWidget);
    });

    testWidgets('con texto al 200% no desborda y el boton cumple 48 dp', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var pulsado = false;
      await tester.pumpWidget(
        envoltorio(
          TarjetaOferta(
            oferta: oferta(),
            onCanjear: () => pulsado = true,
            ahora: reloj,
          ),
          escala: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      final boton = tester.getSize(find.byType(FilledButton));
      expect(boton.height, greaterThanOrEqualTo(48));
      expect(boton.width, greaterThanOrEqualTo(48));
      await tester.tap(find.byType(FilledButton));
      expect(pulsado, isTrue);
    });

    testWidgets('agotada o caducada desactiva el boton', (tester) async {
      await tester.pumpWidget(
        envoltorio(
          TarjetaOferta(
            oferta: oferta(cupos: 1, canjes: 1),
            onCanjear: () {},
            ahora: reloj,
          ),
        ),
      );
      expect(find.text('Agotada'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    });

    testWidgets('el lector de pantalla recibe un resumen, no cada segundo', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await tester.pumpWidget(
        envoltorio(
          TarjetaOferta(oferta: oferta(), onCanjear: () {}, ahora: reloj),
        ),
      );
      expect(
        find.bySemanticsLabel(
          RegExp('Oferta en vivo: Foto de grupo gratis.*30 minutos.*2 de 2'),
        ),
        findsOneWidget,
      );
      semantica.dispose();
    });
  });

  group('HojaCanje', () {
    setUpAll(simularCarpetasDelSistema);

    Widget app(RepositorioOfertas repo, Oferta o) => ProviderScope(
      overrides: [repositorioOfertasProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: temaDePrueba(),
        home: Scaffold(body: HojaCanje(oferta: o)),
      ),
    );

    testWidgets('sin QR canjea y ensena el codigo y su QR', (tester) async {
      final repo = RepositorioOfertasEnMemoria(
        reloj: reloj,
        iniciales: [oferta()],
      );
      await tester.pumpWidget(app(repo, oferta()));
      await tester.pumpAndSettle();
      expect(find.text('Enséñalo al personal del local.'), findsOneWidget);
      expect(find.text('Solo para mayores de 18 años.'), findsOneWidget);
      expect((await repo.activasDe('l1')).single.canjes, 1);
    });

    testWidgets('con QR pide el codigo de la puerta y avisa si falla', (
      tester,
    ) async {
      final o = oferta(verificacion: VerificacionOferta.qr);
      final repo = RepositorioOfertasEnMemoria(reloj: reloj, iniciales: [o]);
      await tester.pumpWidget(app(repo, o));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'mal');
      await tester.tap(find.text('CANJEAR'));
      await tester.pumpAndSettle();
      expect(find.text('Escanea el QR de la puerta.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'PUERTA');
      await tester.tap(find.text('CANJEAR'));
      await tester.pumpAndSettle();
      expect(find.text('Enséñalo al personal del local.'), findsOneWidget);
    });
  });

  group('PantallaLanzarOferta', () {
    setUpAll(simularCarpetasDelSistema);

    testWidgets('lanza una plantilla y aparece en el panel', (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = RepositorioOfertasEnMemoria(duenoDe: {'l1'}, reloj: reloj);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositorioOfertasProvider.overrideWithValue(repo)],
          child: MaterialApp(
            theme: temaDePrueba(),
            home: PantallaLanzarOferta(
              localId: 'l1',
              nombreLocal: 'Oasis',
              ahora: reloj,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Aún no has lanzado ninguna.'), findsOneWidget);
      // Ninguna plantilla de la pantalla habla de beber.
      expect(
        find.textContaining(
          RegExp('barra libre|2x1|bebe', caseSensitive: false),
        ),
        findsNothing,
      );

      await tester.tap(find.text('LANZAR AHORA'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Activa · 0 / 30 canjes'), findsOneWidget);
      expect((await repo.activasDe('l1')), hasLength(1));
    });
  });
}
