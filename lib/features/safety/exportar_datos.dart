import 'dart:convert';

import 'package:share_plus/share_plus.dart';

/// JSON legible (con sangria): el RGPD pide un formato "estructurado y de uso
/// comun", y una persona tiene que poder abrirlo y entenderlo.
String jsonDeExportacion(Map<String, dynamic> datos) =>
    const JsonEncoder.withIndent('  ').convert(datos);

/// Nombre del fichero con la fecha, para que dos descargas no se pisen.
String nombreFicheroExportacion(DateTime ahora) {
  String dos(int n) => n.toString().padLeft(2, '0');
  return 'previa-mis-datos-${ahora.year}-${dos(ahora.month)}-${dos(ahora.day)}.json';
}

/// Entrega el JSON como fichero real.
///
/// Se usa `XFile.fromData` (en memoria) y no un fichero temporal en disco:
/// asi el mismo codigo sirve en web (donde no hay sistema de ficheros y
/// share_plus dispara una descarga) y en movil (hoja de compartir del
/// sistema, desde la que se puede guardar en Archivos o enviar por correo).
/// Devuelve false si el usuario cerro la hoja sin hacer nada.
Future<bool> entregarExportacion(
  Map<String, dynamic> datos, {
  DateTime? ahora,
}) async {
  final nombre = nombreFicheroExportacion(ahora ?? DateTime.now());
  final bytes = utf8.encode(jsonDeExportacion(datos));

  final resultado = await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(bytes, mimeType: 'application/json', name: nombre),
      ],
      fileNameOverrides: [nombre],
      subject: 'Mis datos de Previa',
    ),
  );
  return resultado.status != ShareResultStatus.dismissed;
}
