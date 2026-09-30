import 'package:flutter/material.dart';

import '../../app/tema.dart';

/// Aspecto de una previa según su ambiente: gradiente + icono.
///
/// Las previas no tienen foto (por privacidad del piso), así que el ambiente es
/// lo único que puede dar personalidad a la tarjeta. Se genera con gradientes
/// en vez de imágenes para no pesar nada y funcionar sin conexión.
class EstiloAmbiente {
  const EstiloAmbiente(this.colores, this.icono);

  final List<Color> colores;
  final IconData icono;
}

// Colores locales de esta carpeta (no existen en ColoresPrevia). Todos son
// oscuros/saturados para que el texto blanco encima mantenga el contraste.
const _porDefecto = EstiloAmbiente([
  Color(0xFF3A1F8F),
  Color(0xFF7C4DFF),
], Icons.nightlife);

const _estilos = <String, EstiloAmbiente>{
  'reggaeton': EstiloAmbiente([
    Color(0xFF8E0E5B),
    Color(0xFFD9480F),
  ], Icons.speaker_group),
  'techno': EstiloAmbiente([
    Color(0xFF1B1464),
    Color(0xFF00708F),
  ], Icons.graphic_eq),
  'tranqui': EstiloAmbiente([Color(0xFF0F4C5C), Color(0xFF2F7D62)], Icons.spa),
  'indie': EstiloAmbiente([
    Color(0xFF5A2A82),
    Color(0xFFB0426F),
  ], Icons.headphones),
  'latino': EstiloAmbiente([
    Color(0xFFA3270F),
    Color(0xFFB9780B),
  ], Icons.music_note),
  'pop': EstiloAmbiente([
    Color(0xFFA51C82),
    Color(0xFF5B3DD6),
  ], Icons.star_rounded),
  'rock': EstiloAmbiente([
    Color(0xFF33090F),
    Color(0xFF9E1B2D),
  ], Icons.electric_bolt),
  'cachondeo': EstiloAmbiente([
    Color(0xFF8A5200),
    Color(0xFFC2427A),
  ], Icons.celebration),
  'cartas': EstiloAmbiente([Color(0xFF0E4D3A), Color(0xFF1B6E52)], Icons.style),
  'terraza': EstiloAmbiente([
    Color(0xFF0B5D7A),
    Color(0xFFB5692A),
  ], Icons.wb_twilight),
};

/// Estilo de la primera etiqueta conocida; si no hay, el violeta de marca.
EstiloAmbiente estiloDeAmbiente(List<String> ambiente) {
  for (final a in ambiente) {
    final estilo = _estilos[a];
    if (estilo != null) return estilo;
  }
  return _porDefecto;
}

/// Etiqueta de Hero compartida por tarjeta y detalle. Centralizada para que
/// las dos pantallas no se desincronicen y la transición se rompa en silencio.
String tagCabeceraPrevia(String previaId) => 'cabecera-previa-$previaId';

/// Ilustración generada del ambiente. Puramente decorativa: se excluye de la
/// semántica (el ambiente ya se lee en las etiquetas de texto).
///
/// No lleva texto dentro para poder usarse como hijo de un [Hero] sin exigir
/// un ancestro `Material` durante el vuelo.
class CabeceraAmbiente extends StatelessWidget {
  const CabeceraAmbiente({
    super.key,
    required this.ambiente,
    this.altura = 96,
    this.radio = const BorderRadius.vertical(
      top: Radius.circular(EspaciadoPrevia.radio),
    ),
  });

  final List<String> ambiente;
  final double altura;
  final BorderRadius radio;

  @override
  Widget build(BuildContext context) {
    final estilo = estiloDeAmbiente(ambiente);
    final foco = Colors.white.withValues(alpha: 0.09);

    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: radio,
        child: Container(
          height: altura,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: estilo.colores,
            ),
          ),
          // Círculos translúcidos = focos de sala; el icono grande, la firma.
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                right: -altura * 0.2,
                top: -altura * 0.4,
                child: _Circulo(altura * 1.1, foco),
              ),
              Positioned(
                left: altura * 0.35,
                bottom: -altura * 0.55,
                child: _Circulo(altura * 0.9, foco),
              ),
              Positioned(
                right: EspaciadoPrevia.m,
                bottom: -altura * 0.08,
                child: Icon(
                  estilo.icono,
                  size: altura * 0.7,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Circulo extends StatelessWidget {
  const _Circulo(this.diametro, this.color);
  final double diametro;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: diametro,
    height: diametro,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// Pastilla con icono y texto: plazas, hora, zona, distancia.
///
/// El texto hace `Flexible` y puede pasar a varias líneas: con `textScaler`
/// grande no desborda la fila.
class ChipDato extends StatelessWidget {
  const ChipDato({
    super.key,
    required this.icono,
    required this.texto,
    this.color,
    this.leer,
  });

  final IconData icono;
  final String texto;

  /// Color de acento (plazas libres). Sin él, tono neutro.
  final Color? color;

  /// Frase alternativa para el lector cuando el texto solo no basta.
  final String? leer;

  @override
  Widget build(BuildContext context) {
    final c = color ?? ColoresPrevia.textoSuave;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: EspaciadoPrevia.s + 2,
        vertical: EspaciadoPrevia.xs + 1,
      ),
      decoration: BoxDecoration(
        color: (color ?? ColoresPrevia.superficieAlta).withValues(
          alpha: color == null ? 1 : 0.14,
        ),
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radioGrande),
        border: Border.all(
          color: color == null
              ? ColoresPrevia.borde
              : c.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: Icon(icono, size: 15, color: c)),
          const SizedBox(width: EspaciadoPrevia.xs + 1),
          Flexible(
            child: Text(
              texto,
              semanticsLabel: leer,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color ?? ColoresPrevia.texto,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra de plazas: un segmento por plaza libre (hasta [maximo]).
///
/// No conocemos el aforo total (solo las libres), así que la barra enseña
/// "cuánto sitio queda" y no un porcentaje. Decorativa: el dato ya está en
/// el texto que la acompaña.
class BarraPlazas extends StatelessWidget {
  const BarraPlazas({super.key, required this.libres, this.maximo = 10});

  final int libres;
  final int maximo;

  @override
  Widget build(BuildContext context) {
    final total = maximo;
    final llenos = libres.clamp(0, total);
    final color = libres <= 0 ? ColoresPrevia.textoTenue : ColoresPrevia.acento;

    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                height: 6,
                decoration: BoxDecoration(
                  color: i < llenos ? color : ColoresPrevia.borde,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Entrada escalonada: cada elemento aparece un poco después que el anterior.
///
/// Solo anima los primeros [limite] (luego sería ruido al hacer scroll) y se
/// desactiva si el usuario pide reducir animaciones en el sistema.
class EntradaEscalonada extends StatelessWidget {
  const EntradaEscalonada({
    super.key,
    required this.indice,
    required this.child,
    this.limite = 8,
  });

  final int indice;
  final int limite;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (indice >= limite || MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      // Más índice = más duración: el resultado visual es una cascada sin
      // necesidad de controladores ni temporizadores.
      duration: Duration(milliseconds: 280 + indice * 70),
      curve: Curves.easeOutCubic,
      builder: (context, t, hijo) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 14),
          child: hijo,
        ),
      ),
      child: child,
    );
  }
}
