import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:previa/app/tema.dart';
import 'package:previa/features/juegos/juegos.dart';
import 'package:previa/features/juegos/motor/partida.dart';
import 'package:previa/features/juegos/motor/retos_de_prueba.dart';
import 'package:previa/features/juegos/pantalla_partida.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget app(Widget home, {double escala = 1.0}) => MaterialApp(
      theme: construirTemaPrevia(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(escala),
        ),
        child: child!,
      ),
      home: home,
    );

void pantallaGrande(WidgetTester t) {
  t.view.physicalSize = const Size(900, 1800);
  t.view.devicePixelRatio = 2.0;
  addTearDown(t.view.reset);
}

/// Con contenido real la primera carta puede pedir confirmacion de contacto.
Future<void> aceptarContacto(WidgetTester t) async {
  if (find.text('Sí, adelante').evaluate().isNotEmpty) {
    await t.tap(find.text('Sí, adelante'));
    await t.pumpAndSettle();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('flujo completo: hub, preparacion, partida y final', (t) async {
    pantallaGrande(t);
    await t.pumpWidget(app(const PantallaHubJuegos()));
    expect(find.text(nombreDelJuego.toUpperCase()), findsOneWidget);
    expect(find.text('YO NUNCA'), findsOneWidget);

    await t.tap(find.text(nombreDelJuego.toUpperCase()));
    await t.pumpAndSettle();

    // Con menos de 2 jugadores no se puede empezar. La lista es perezosa:
    // se baja hasta el botón para que exista en el árbol.
    await t.scrollUntilVisible(find.text('Empezar'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(
      t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Empezar')).onPressed,
      isNull,
    );
    await t.drag(find.byType(ListView), const Offset(0, 2000));
    await t.pumpAndSettle();
    for (final n in ['Ana', 'Beto']) {
      await t.enterText(find.byType(TextField), n);
      await t.tap(find.byTooltip('Añadir jugador'));
      await t.pump();
    }
    // Duplicado rechazado.
    await t.enterText(find.byType(TextField), 'ana');
    await t.tap(find.byTooltip('Añadir jugador'));
    await t.pump();
    expect(find.textContaining('Ya hay alguien'), findsOneWidget);
    expect(find.byType(InputChip), findsNWidgets(2));

    await t.scrollUntilVisible(find.text('Empezar'), 300,
        scrollable: find.byType(Scrollable).first);
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Empezar'));
    await t.pumpAndSettle();
    expect(find.text('Antes de empezar'), findsOneWidget);
    await t.tap(find.text('Tengo +18 y bebo con cabeza'));
    await t.pumpAndSettle();

    await aceptarContacto(t);
    // Partida: turno, carta y seguridad visibles.
    expect(find.text('Ana'), findsWidgets);
    expect(find.text('Parar'), findsOneWidget);
    expect(find.textContaining('Nadie está obligado'), findsWidgets);
    expect(find.textContaining('¿A que no hay huevos a'), findsOneWidget);

    // Se recuerda la lista de jugadores.
    final p = await SharedPreferences.getInstance();
    expect(p.getStringList('juegos_jugadores'), ['Ana', 'Beto']);

    await aceptarContacto(t);
    await t.tap(find.text('Cumplido'));
    await t.pumpAndSettle();
    expect(find.text('Beto'), findsWidgets);

    // Parar lleva a la pantalla final con opcion de otra partida.
    await t.tap(find.text('Parar'));
    await t.pumpAndSettle();
    await t.tap(find.text('Terminar aquí'));
    await t.pumpAndSettle();
    expect(find.text('Fin de la partida'), findsOneWidget);
    expect(find.text('Otra partida'), findsOneWidget);
    expect(find.textContaining('Valiente del día'), findsOneWidget);

    await t.tap(find.text('Otra partida'));
    await t.pumpAndSettle();
    expect(find.text('Parar'), findsOneWidget);
  });

  testWidgets('recuerda la ultima lista y usa jugadores iniciales si llegan',
      (t) async {
    pantallaGrande(t);
    SharedPreferences.setMockInitialValues({
      'juegos_jugadores': ['Luz', 'Mar'],
    });
    await t.pumpWidget(app(const PantallaHubJuegos()));
    await t.tap(find.text(nombreDelJuego.toUpperCase()));
    await t.pumpAndSettle();
    expect(find.widgetWithText(InputChip, 'Luz'), findsOneWidget);

    await t.pageBack();
    await t.pumpAndSettle();
    await t.pumpWidget(app(
      const PantallaHubJuegos(jugadoresIniciales: ['Zoe', 'Noa', 'Zoe']),
    ));
    await t.tap(find.text(nombreDelJuego.toUpperCase()));
    await t.pumpAndSettle();
    expect(find.widgetWithText(InputChip, 'Zoe'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Luz'), findsNothing);
  });

  testWidgets('pausa obligatoria cada 10 cartas con cuenta atras', (t) async {
    pantallaGrande(t);
    await t.pumpWidget(app(PantallaPartida(
      config: const ConfiguracionPartida(
        juego: TipoJuego.yoNunca,
        jugadores: ['Ana', 'Beto'],
        nivel: NivelReto.atrevido,
        rondas: null,
      ),
      retos: retosDePrueba,
      duracionPausa: const Duration(seconds: 3),
    )));
    await t.pumpAndSettle();
    for (var i = 0; i < 10; i++) {
      await t.tap(find.text('Siguiente carta'));
      await t.pumpAndSettle(const Duration(milliseconds: 100));
      if (i < 9) expect(find.text('Agua y respira 1 minuto'), findsNothing);
    }
    expect(find.text('Agua y respira 1 minuto'), findsOneWidget);
    // Durante la pausa el boton esta bloqueado pero "Parar" sigue ahi.
    expect(
      t.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(find.text('Parar'), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
    await t.pump();
    await t.tap(find.text('Seguir jugando'));
    await t.pumpAndSettle();
    expect(find.text('Siguiente carta'), findsOneWidget);
  });

  testWidgets('con texto al 200% y sin animaciones no hay desbordes', (t) async {
    pantallaGrande(t);
    t.view.physicalSize = const Size(700, 1400);
    await t.pumpWidget(app(
      PantallaPartida(
        config: const ConfiguracionPartida(
          juego: TipoJuego.noHayHuevos,
          jugadores: ['Alexandra', 'Bartolome'],
          nivel: NivelReto.sinFiltro,
        ),
        retos: retosDePrueba,
      ),
      escala: 2.0,
    ));
    await t.pumpAndSettle();
    expect(find.text('Parar'), findsOneWidget);

    // Preparacion tambien.
    await t.pumpWidget(app(
      const PantallaHubJuegos(jugadoresIniciales: ['Alexandra', 'Bartolome']),
      escala: 2.0,
    ));
    // Al 200% la tarjeta queda por debajo y la lista aun no la ha
    // construido: hay que bajar hasta ella.
    await t.scrollUntilVisible(
      find.text(nombreDelJuego.toUpperCase()),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    await t.tap(find.text(nombreDelJuego.toUpperCase()));
    await t.pumpAndSettle();
  });

  testWidgets('las opciones interactivas miden al menos 48 dp', (t) async {
    pantallaGrande(t);
    await t.pumpWidget(app(PantallaPartida(
      config: const ConfiguracionPartida(
        juego: TipoJuego.noHayHuevos,
        jugadores: ['Ana', 'Beto'],
      ),
      retos: retosDePrueba,
    )));
    await t.pumpAndSettle();
    for (final f in [
      find.text('Parar'),
      find.text('Cumplido'),
      find.text('No hay huevos'),
    ]) {
      final tam = t.getSize(find.ancestor(
        of: f,
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ).first);
      expect(tam.height, greaterThanOrEqualTo(48));
    }
  });
}
