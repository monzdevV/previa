import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:previa/app/tema.dart';
import 'package:previa/data/repositories/repositorio_auth.dart';
import 'package:previa/domain/racha/regla_de_racha.dart';
import 'package:previa/features/profile/proveedores_perfil.dart';
import 'package:previa/features/profile/tarjeta_racha.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Monta la tarjeta con una racha fija. [reducirMovimiento] imita el ajuste
/// del sistema, que Flutter expone como `disableAnimations`.
Widget _montar(Racha racha, {bool reducirMovimiento = false}) => ProviderScope(
  overrides: [
    rachaProvider.overrideWith((ref) async => racha),
    uidActualProvider.overrideWithValue('yo'),
  ],
  child: MaterialApp(
    theme: construirTemaPrevia(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(disableAnimations: reducirMovimiento),
      child: child!,
    ),
    home: const Scaffold(body: TarjetaRacha()),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('TarjetaRachaVista', () {
    Future<void> pintar(WidgetTester t, Racha r) => t.pumpWidget(
      MaterialApp(
        theme: construirTemaPrevia(),
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: TarjetaRachaVista(racha: r),
          ),
        ),
      ),
    );

    testWidgets('enseña semanas y lo que falta para el siguiente hito', (
      t,
    ) async {
      await pintar(t, const Racha(semanas: 4, mejor: 4, saliEstaSemana: true));
      expect(find.text('4'), findsOneWidget);
      expect(find.text('SEMANAS'), findsOneWidget);
      expect(find.text('Faltan 1 semanas para el hito de 5'), findsNothing);
      expect(find.text('Falta 1 semana para el hito de 5'), findsOneWidget);
      expect(find.text('Esta semana ya cuenta. Sigue así.'), findsOneWidget);
    });

    testWidgets('la barra refleja el avance entre hitos', (t) async {
      await pintar(t, const Racha(semanas: 4, mejor: 4, saliEstaSemana: true));
      await t.pumpAndSettle();
      final barra = t.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      // De 3 a 5, con 4: justo la mitad.
      expect(barra.widthFactor, closeTo(0.5, 1e-9));
    });

    testWidgets('en riesgo avisa de salir antes del domingo', (t) async {
      await pintar(t, const Racha(semanas: 2, mejor: 2));
      expect(
        find.text('Sal antes del domingo y sigue creciendo.'),
        findsOneWidget,
      );
    });

    testWidgets('con el comodín gastado el aviso es más urgente', (t) async {
      await pintar(t, const Racha(semanas: 2, mejor: 2, comodinGastado: true));
      expect(find.text('Sal esta semana o la pierdes.'), findsOneWidget);
    });

    testWidgets('sin racha invita a empezar y recuerda el récord', (t) async {
      await pintar(t, const Racha(mejor: 6));
      expect(find.text('0'), findsOneWidget);
      expect(
        find.text('Tu récord es de 6. Sal esta semana y empieza otra.'),
        findsOneWidget,
      );
      expect(find.text('Faltan 3 semanas para el hito de 3'), findsOneWidget);
    });

    testWidgets('pasado el último hito dice leyenda y la barra va llena', (
      t,
    ) async {
      await pintar(
        t,
        const Racha(semanas: 22, mejor: 22, saliEstaSemana: true),
      );
      await t.pumpAndSettle();
      expect(find.text('Has pasado el último hito. Leyenda.'), findsOneWidget);
      expect(
        t
            .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
            .widthFactor,
        1,
      );
    });

    testWidgets('lo lee un lector de pantalla como una sola frase', (t) async {
      final semantica = t.ensureSemantics();
      await pintar(t, const Racha(semanas: 4, mejor: 4, saliEstaSemana: true));
      expect(
        find.bySemanticsLabel(RegExp('Racha de fiestas: 4 semanas seguidas')),
        findsOneWidget,
      );
      semantica.dispose();
    });
  });

  group('animación y "reducir movimiento"', () {
    testWidgets('con movimiento la llama late sin parar', (t) async {
      await t.pumpWidget(
        _montar(const Racha(semanas: 1, saliEstaSemana: true)),
      );
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(t.hasRunningAnimations, isTrue);
      // Se desmonta para que el bucle no deje temporizadores pendientes.
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('con "reducir movimiento" no queda nada animándose', (t) async {
      await t.pumpWidget(
        _montar(
          const Racha(semanas: 1, saliEstaSemana: true),
          reducirMovimiento: true,
        ),
      );
      await t.pumpAndSettle();
      expect(t.hasRunningAnimations, isFalse);
    });
  });

  group('celebración de hitos', () {
    testWidgets('al llegar a 3 semanas sale el mensaje y se guarda', (t) async {
      await t.pumpWidget(
        _montar(
          const Racha(semanas: 3, mejor: 3, saliEstaSemana: true),
          reducirMovimiento: true,
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('3 SEMANAS SEGUIDAS'), findsOneWidget);
      expect(find.text('¡Vamos!'), findsOneWidget);

      await t.tap(find.text('¡Vamos!'));
      await t.pumpAndSettle();
      expect(find.text('3 SEMANAS SEGUIDAS'), findsNothing);

      final p = await SharedPreferences.getInstance();
      expect(p.getInt('racha_hito_celebrado_yo'), 3);
    });

    testWidgets('un hito ya celebrado no se repite', (t) async {
      SharedPreferences.setMockInitialValues({'racha_hito_celebrado_yo': 3});
      await t.pumpWidget(
        _montar(
          const Racha(semanas: 4, mejor: 4, saliEstaSemana: true),
          reducirMovimiento: true,
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('¡Vamos!'), findsNothing);
    });

    testWidgets('sin llegar a ningún hito no hay mensaje', (t) async {
      await t.pumpWidget(
        _montar(
          const Racha(semanas: 2, mejor: 2, saliEstaSemana: true),
          reducirMovimiento: true,
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('¡Vamos!'), findsNothing);
    });

    testWidgets('tras romper la racha, el 3 vuelve a celebrarse', (t) async {
      SharedPreferences.setMockInitialValues({'racha_hito_celebrado_yo': 5});
      // Racha rota (0) y rehecha hasta 3 más tarde: primero se reinicia.
      await t.pumpWidget(
        _montar(
          const Racha(semanas: 3, mejor: 5, saliEstaSemana: true),
          reducirMovimiento: true,
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('3 SEMANAS SEGUIDAS'), findsOneWidget);
    });

    testWidgets('el mensaje de un hito animado termina y es legible', (
      t,
    ) async {
      await t.pumpWidget(
        _montar(const Racha(semanas: 5, mejor: 5, saliEstaSemana: true)),
      );
      // La llama de la tarjeta late en bucle: se avanza por tiempo fijo.
      await t.pump();
      await t.pump(const Duration(seconds: 2));
      expect(find.text('5 SEMANAS SEGUIDAS'), findsOneWidget);
      expect(
        find.textContaining('Siguiente parada: 10 semanas.'),
        findsOneWidget,
      );
      await t.tap(find.text('¡Vamos!'));
      await t.pump(const Duration(seconds: 1));
      await t.pumpWidget(const SizedBox());
    });
  });
}
