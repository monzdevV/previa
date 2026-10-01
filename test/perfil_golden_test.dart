import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:previa/data/models/noche.dart';
import 'package:previa/data/models/perfil.dart';
import 'package:previa/data/models/publicacion.dart';
import 'package:previa/data/repositories/repositorio_auth.dart';
import 'package:previa/data/repositories/repositorio_calendario.dart';
import 'package:previa/features/map/proveedores_mapa.dart';
import 'package:previa/features/profile/pantalla_perfil.dart';
import 'package:previa/features/profile/proveedores_perfil.dart';

import 'apoyo_visual.dart';

/// El perfil propio de una cuenta recien creada: sin foto, con Instagram y
/// unas cuantas noches este mes. Es el caso que mas se va a ver al principio
/// y el que mas facil queda pobre.
void main() {
  setUpAll(() async {
    simularCarpetasDelSistema();
    await cargarTipografias();
    await initializeDateFormatting('es_ES');
  });

  testWidgets('el perfil pone la cara, las redes y las noches delante', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final hoy = DateTime.now();
    DateTime dia(int d) => DateTime(hoy.year, hoy.month, d);
    const yo = Perfil(
      id: 'yo',
      username: 'lucia_3812',
      nombre: 'Lucía Pardo',
      onboarded: true,
      instagram: 'luciapardo',
      tiktok: 'lu.pardo',
      ciudad: 'Zaragoza',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          miPerfilProvider.overrideWith((ref) async => yo),
          miFichaProvider.overrideWith(
            (ref, id) async => const PerfilPublico(
              perfil: PerfilResumen(id: 'yo', nombre: 'Lucía Pardo'),
              seguidores: 128,
              siguiendo: 96,
            ),
          ),
          misPublicacionesProvider.overrideWith((ref) async => const []),
          deEsasNochesProvider.overrideWith((ref) async => const []),
          misPreviasProvider.overrideWith((ref) async => const []),
          rachaProvider.overrideWith(
            (ref) async => const Racha(semanas: 3, saliEstaSemana: true),
          ),
          calendarioProvider.overrideWith(
            (ref, clave) async => [
              NocheDelCalendario(noche: dia(1), sitios: const ['Oasis']),
              NocheDelCalendario(noche: dia(2), sitios: const ['Kembo']),
              NocheDelCalendario(noche: dia(8), sitios: const ['Sala López']),
              NocheDelCalendario(noche: dia(9), sitios: const ['Oasis']),
              NocheDelCalendario(noche: dia(15), sitios: const ['Marearock']),
            ],
          ),
        ],
        child: MaterialApp(
          theme: temaDePrueba(),
          home: const PantallaPerfil(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(padding: const EdgeInsets.only(top: 47, bottom: 34)),
            child: child!,
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 350));
    }

    expect(find.text('LUCÍA PARDO'), findsOneWidget);
    await expectLater(
      find.byType(PantallaPerfil),
      matchesGoldenFile('goldens/perfil.png'),
    );
  });
}
