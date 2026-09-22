import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/modo_de_tema.dart';
import 'app/rutas.dart';
import 'app/tema.dart';
import 'core/entorno.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Las claves viven en .env, que no se sube al repositorio.
  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: Entorno.supabaseUrl,
    publishableKey: Entorno.supabasePublishableKey,
  );

  // Fechas y nombres de mes en español.
  await initializeDateFormatting('es_ES');

  runApp(const ProviderScope(child: AplicacionPrevia()));
}

class AplicacionPrevia extends ConsumerWidget {
  const AplicacionPrevia({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Previa',
      debugShowCheckedModeBanner: false,
      theme: construirTemaPrevia(brillo: Brightness.light),
      darkTheme: construirTemaPrevia(brillo: Brightness.dark),
      themeMode: ref.watch(modoDeTemaProvider),

      // La aplicacion es en español; no hay version en otros idiomas.
      locale: const Locale('es', 'ES'),
      supportedLocales: const [Locale('es', 'ES')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      routerConfig: ref.watch(enrutadorProvider),
    );
  }
}
