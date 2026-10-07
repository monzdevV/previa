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
      appBar: conAtras
          ? AppBar(title: const Titular('Juegos de previa', tamano: 24))
          : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(EspaciadoPrevia.m),
          children: [
            if (!conAtras) ...[
              Semantics(
                header: true,
                child: const Titular('Juegos de previa', tamano: 36),
              ),
              const SizedBox(height: EspaciadoPrevia.s),
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
              if (juego == TipoJuego.noHayHuevos) ...[
                const SizedBox(height: EspaciadoPrevia.s),
                const _TambienEnElLocal(),
              ],
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
      label:
          '${juego.tituloLeido}. ${juego.descripcion}'
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
                          Titular(juego.titulo, tamano: principal ? 30 : 22),
                          const SizedBox(height: EspaciadoPrevia.xs),
                          Text(juego.descripcion, style: texto.bodyMedium),
                        ],
                      ),
                    ),
                    const SizedBox(width: EspaciadoPrevia.s),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: context.colores.primarioTexto,
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

/// La otra cara de No hay 🥚: en el local el reto es con alguien que esta
/// alli y se cumple con una foto. Se entra por el sticker de la sala, no
/// desde aqui, porque hace falta saber en que local estas.
class _TambienEnElLocal extends StatelessWidget {
  const _TambienEnElLocal();

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Container(
      padding: const EdgeInsets.all(EspaciadoPrevia.m),
      decoration: BoxDecoration(
        color: c.superficieAlta,
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
      ),
      child: Row(
        children: [
          const Pegatina('📍', tamano: 28, giro: -0.12),
          const SizedBox(width: EspaciadoPrevia.m),
          Expanded(
            child: Text(
              'Ya en el local, busca el sticker $nombreDelJuego en la sala '
              'del sitio al que vas: te toca un reto con alguien que está '
              'allí.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
