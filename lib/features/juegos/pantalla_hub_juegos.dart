import 'package:flutter/material.dart';

import '../../app/tema.dart';
import 'ilustraciones.dart';
import 'modelo_juegos.dart';
import 'pantalla_preparacion.dart';

/// Pantalla con una tarjeta grande por juego. Sirve tanto de pestaña de la
/// navegación principal (sin botón atrás) como de pantalla independiente
/// abierta con `abrirJuegos` ([conAtras]).
class PantallaHubJuegos extends StatelessWidget {
  const PantallaHubJuegos({
    super.key,
    this.jugadoresIniciales = const [],
    this.conAtras = false,
  });

  final List<String> jugadoresIniciales;
  final bool conAtras;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Scaffold(
      appBar: conAtras ? AppBar(title: const Text('Juegos de previa')) : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(EspaciadoPrevia.m),
          children: [
            if (!conAtras) ...[
              Semantics(
                header: true,
                child: Text('Juegos de previa', style: texto.headlineMedium),
              ),
              const SizedBox(height: EspaciadoPrevia.xs),
            ],
            Text(
              'Un solo móvil, pasándolo de mano en mano. Sin conexión.',
              style: texto.bodyMedium,
            ),
            const SizedBox(height: EspaciadoPrevia.s),
            Text(
              'Contenido +18. Nadie está obligado a beber ni a hacer nada.',
              style: texto.bodySmall,
            ),
            const SizedBox(height: EspaciadoPrevia.m),
            for (final juego in TipoJuego.values) ...[
              _TarjetaJuego(
                juego: juego,
                principal: juego == TipoJuego.noHayHuevos,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PantallaPreparacion(
                      juego: juego,
                      jugadoresIniciales: jugadoresIniciales,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: EspaciadoPrevia.m),
            ],
          ],
        ),
      ),
    );
  }
}

class _TarjetaJuego extends StatelessWidget {
  const _TarjetaJuego({
    required this.juego,
    required this.principal,
    required this.onTap,
  });

  final TipoJuego juego;
  final bool principal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    // El juego principal es más alto para que se note cuál es "el" juego.
    final altoIlustracion = principal ? 168.0 : 112.0;
    return Semantics(
      button: true,
      label: '${juego.titulo}. ${juego.descripcion}'
          '${principal ? ' Juego principal.' : ''}',
      excludeSemantics: true,
      onTap: onTap,
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: altoIlustracion,
                child: IlustracionJuego(juego: juego),
              ),
              Padding(
                padding: const EdgeInsets.all(EspaciadoPrevia.m),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            juego.titulo,
                            style: principal
                                ? texto.headlineMedium
                                : texto.titleLarge,
                          ),
                          const SizedBox(height: EspaciadoPrevia.xs),
                          Text(juego.descripcion, style: texto.bodyMedium),
                        ],
                      ),
                    ),
                    const SizedBox(width: EspaciadoPrevia.s),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: ColoresPrevia.primarioSuave,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
