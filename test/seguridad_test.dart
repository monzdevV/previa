import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:previa/data/repositories/repositorio_auth.dart';
import 'package:previa/data/repositories/repositorio_seguridad.dart';
import 'package:previa/features/safety/aviso_ubicacion_aproximada.dart';
import 'package:previa/features/safety/exportar_datos.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('traducirErrorDeSeguridad', () {
    test('conserva los ErrorPrevia tal cual', () {
      const original = ErrorPrevia('Hola');
      expect(
        traducirErrorDeSeguridad(original, accion: 'bloquear'),
        same(original),
      );
    });

    test('permiso denegado por RLS', () {
      final e = traducirErrorDeSeguridad(
        const PostgrestException(message: 'nope', code: '42501'),
        accion: 'bloquear',
      );
      expect(e.mensaje, 'No tienes permiso para bloquear.');
    });

    test('duplicado se explica sin culpar al usuario', () {
      final e = traducirErrorDeSeguridad(
        const PostgrestException(message: 'duplicate key', code: '23505'),
        accion: 'bloquear',
      );
      expect(e.mensaje, contains('Ya lo habías hecho'));
    });

    test('error desconocido de Postgrest no filtra detalles internos', () {
      final e = traducirErrorDeSeguridad(
        const PostgrestException(message: 'relation "x" blew up'),
        accion: 'enviar el reporte',
      );
      expect(
        e.mensaje,
        'No se ha podido enviar el reporte. Inténtalo de nuevo.',
      );
    });

    test('fallo de red sugiere revisar la conexion', () {
      final e = traducirErrorDeSeguridad(
        Exception('SocketException'),
        accion: 'desbloquear',
      );
      expect(e.mensaje, contains('conexión'));
      expect(e.mensaje, contains('desbloquear'));
    });
  });

  group('exportacion de datos', () {
    test('el nombre lleva la fecha con ceros', () {
      expect(
        nombreFicheroExportacion(DateTime(2026, 3, 5)),
        'previa-mis-datos-2026-03-05.json',
      );
    });

    test('el JSON es valido, con sangria y conserva los acentos', () {
      final texto = jsonDeExportacion({
        'perfil': {'display_name': 'Andrés'},
        'mensajes': <Object>[],
      });
      expect(texto, contains('\n  '));
      expect(jsonDecode(texto)['perfil']['display_name'], 'Andrés');
    });
  });

  group('UsuarioBloqueado', () {
    test('sin nombre usa una etiqueta generica', () {
      final u = UsuarioBloqueado.desdeJson({'blocked_id': 'abc'});
      expect(u.id, 'abc');
      expect(u.etiqueta, 'Usuario bloqueado');
    });

    test('con nombre de la RPC', () {
      final u = UsuarioBloqueado.desdeJson({
        'blocked_id': 'abc',
        'display_name': 'Lucía',
        'created_at': '2026-01-01T10:00:00Z',
      });
      expect(u.etiqueta, 'Lucía');
      expect(u.bloqueadoEn, isNotNull);
    });
  });

  test('motivos de reporte incluyen menor de edad', () {
    expect(motivosDeReporte.containsKey('menor_edad'), isTrue);
  });

  testWidgets('el aviso de ubicacion aproximada se muestra', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AvisoUbicacionAproximada())),
    );
    expect(
      find.textContaining('Ubicación aproximada hasta que te acepten'),
      findsOneWidget,
    );
  });
}
