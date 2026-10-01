import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tema.dart';
import '../../data/repositories/repositorio_seguridad.dart';
import '../map/proveedores_mapa.dart';

void _aviso(ScaffoldMessengerState mensajero, String texto) {
  mensajero
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));
}

Future<bool> _confirmar(
  BuildContext context, {
  required String titulo,
  required String detalle,
  required String accion,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (contexto) => AlertDialog(
      backgroundColor: context.colores.superficieAlta,
      title: Text(titulo),
      content: Text(detalle),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(contexto).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(contexto).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: context.colores.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
            minimumSize: const Size(0, 48),
          ),
          child: Text(accion),
        ),
      ],
    ),
  );
  return r == true;
}

Future<String?> _elegirMotivo(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: context.colores.fondo,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(EspaciadoPrevia.radioGrande),
      ),
    ),
    builder: (contexto) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: EspaciadoPrevia.l),
            Text(
              '¿Qué ha pasado?',
              style: Theme.of(contexto).textTheme.titleLarge,
            ),
            const SizedBox(height: EspaciadoPrevia.m),
            for (final e in motivosDeReporte.entries)
              ListTile(
                title: Text(e.value),
                onTap: () => Navigator.of(contexto).pop(e.key),
              ),
            const SizedBox(height: EspaciadoPrevia.m),
          ],
        ),
      ),
    ),
  );
}

/// Flujo completo de reportar: elegir motivo, enviar y avisar del resultado
/// (con el error traducido si falla).
Future<void> flujoReportar(
  BuildContext context,
  WidgetRef ref, {
  String? perfilId,
  String? previaId,
  String? mensajeId,
}) async {
  final mensajero = ScaffoldMessenger.of(context);
  final motivo = await _elegirMotivo(context);
  if (motivo == null || !context.mounted) return;
  try {
    await ref
        .read(repositorioSeguridadProvider)
        .reportar(
          motivo: motivo,
          perfilId: perfilId,
          previaId: previaId,
          mensajeId: mensajeId,
        );
    _aviso(mensajero, 'Reporte enviado. Gracias por avisar.');
  } catch (e) {
    _aviso(mensajero, e.toString());
  }
}

/// Flujo completo de bloquear, con confirmacion. Devuelve true si se bloqueo.
Future<bool> flujoBloquear(
  BuildContext context,
  WidgetRef ref, {
  required String perfilId,
  required String nombre,
}) async {
  final mensajero = ScaffoldMessenger.of(context);
  final ok = await _confirmar(
    context,
    titulo: '¿Bloquear a $nombre?',
    detalle:
        'Dejaréis de veros por completo: sus previas desaparecerán de '
        'tu mapa y no podrá escribirte. Puedes desbloquearle en Ajustes.',
    accion: 'Bloquear',
  );
  if (!ok || !context.mounted) return false;
  try {
    await ref.read(repositorioSeguridadProvider).bloquear(perfilId);
    // El mapa cachea resultados: sin invalidar seguiria enseñando sus previas.
    ref.invalidate(previasCercaProvider);
    _aviso(mensajero, 'Bloqueado. No volveréis a veros.');
    return true;
  } catch (e) {
    _aviso(mensajero, e.toString());
    return false;
  }
}

/// Flujo de salir de la previa. Devuelve true si se salio.
Future<bool> flujoSalir(
  BuildContext context,
  WidgetRef ref, {
  required String previaId,
}) async {
  final mensajero = ScaffoldMessenger.of(context);
  final ok = await _confirmar(
    context,
    titulo: '¿Salir de la previa?',
    detalle:
        'Dejarás de ver el chat y la dirección exacta. Tendrás que '
        'volver a pedir plaza si quieres entrar otra vez.',
    accion: 'Salir',
  );
  if (!ok || !context.mounted) return false;
  try {
    await ref.read(repositorioSeguridadProvider).salirDeLaPrevia(previaId);
    _aviso(mensajero, 'Has salido de la previa.');
    return true;
  } catch (e) {
    _aviso(mensajero, e.toString());
    return false;
  }
}

/// Hoja de seguridad sobre una persona (y opcionalmente uno de sus mensajes
/// o la previa donde coincidis): reportar y bloquear a un toque.
///
/// Devuelve true si la accion elegida dejo a la persona bloqueada.
Future<void> mostrarHojaPersona(
  BuildContext context,
  WidgetRef ref, {
  required String perfilId,
  required String nombre,
  String? previaId,
  String? mensajeId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.colores.fondo,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(EspaciadoPrevia.radioGrande),
      ),
    ),
    builder: (contexto) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: EspaciadoPrevia.l),
          Text(nombre, style: Theme.of(contexto).textTheme.titleLarge),
          const SizedBox(height: EspaciadoPrevia.s),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: Text(
              mensajeId != null ? 'Reportar este mensaje' : 'Reportar',
            ),
            onTap: () {
              Navigator.of(contexto).pop();
              flujoReportar(
                context,
                ref,
                perfilId: perfilId,
                previaId: previaId,
                mensajeId: mensajeId,
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.block, color: context.colores.error),
            title: Text(
              'Bloquear',
              style: TextStyle(color: context.colores.error),
            ),
            onTap: () {
              Navigator.of(contexto).pop();
              flujoBloquear(context, ref, perfilId: perfilId, nombre: nombre);
            },
          ),
          const SizedBox(height: EspaciadoPrevia.s),
        ],
      ),
    ),
  );
}
