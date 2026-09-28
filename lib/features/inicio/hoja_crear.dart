import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';

/// Lo que se puede crear, en un solo sitio.
///
/// Antes cada cosa tenia su boton en una pantalla distinta (el "+" del feed
/// para fotos, la barra ancha del mapa para previas) y el usuario tenia que
/// saber donde buscar. Ahora hay un "+" y detras las dos opciones, cada una
/// con su frase: se elige leyendo, no recordando.
///
/// Devuelve cuando lo creado ya se ha cerrado, para que quien la abre pueda
/// refrescar lo suyo.
Future<void> mostrarHojaCrear(BuildContext context) async {
  final destino = await mostrarHoja<String>(
    context,
    builder: (contexto) => Padding(
      padding: EdgeInsets.fromLTRB(
        EspaciadoPrevia.m,
        0,
        EspaciadoPrevia.m,
        EspaciadoPrevia.m + MediaQuery.paddingOf(contexto).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Titular('¿Qué vas a hacer?', tamano: 28),
          const SizedBox(height: EspaciadoPrevia.m),
          _Opcion(
            color: BloquesPrevia.amarillo,
            icono: Icons.photo_camera_rounded,
            titulo: 'Subir una foto',
            detalle: 'Cuenta tu noche. Sale en el feed y en tu calendario.',
            onTap: () => Navigator.of(contexto).pop(Rutas.publicar),
          ),
          const SizedBox(height: EspaciadoPrevia.s),
          _Opcion(
            color: BloquesPrevia.menta,
            icono: Icons.celebration_rounded,
            titulo: 'Abrir una previa',
            detalle: 'Tu casa, tus plazas. Tu dirección no la ve nadie.',
            onTap: () => Navigator.of(contexto).pop(Rutas.crearPrevia),
          ),
        ],
      ),
    ),
  );
  if (destino != null && context.mounted) await context.push(destino);
}

class _Opcion extends StatelessWidget {
  const _Opcion({
    required this.color,
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.onTap,
  });

  final Color color;
  final IconData icono;
  final String titulo;
  final String detalle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const tinta = BloquesPrevia.tintaSobreBloque;
    return Semantics(
      button: true,
      child: Pulsable(
        onTap: onTap,
        escala: 0.98,
        child: Container(
          padding: const EdgeInsets.all(EspaciadoPrevia.m),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(EspaciadoPrevia.radioGrande),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: tinta,
                  shape: BoxShape.circle,
                ),
                child: Icon(icono, color: color, size: 26),
              ),
              const SizedBox(width: EspaciadoPrevia.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Titular(titulo, tamano: 20, color: tinta),
                    const SizedBox(height: 4),
                    Text(
                      detalle,
                      style: TextStyle(
                        color: tinta.withValues(alpha: .78),
                        fontSize: 13.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: tinta),
            ],
          ),
        ),
      ),
    );
  }
}
