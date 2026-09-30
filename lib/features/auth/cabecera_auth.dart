import 'package:flutter/material.dart';

import '../../app/tema.dart';

/// Cabecera común de entrar y registro: insignia con degradado de marca,
/// titular y una frase. Misma jerarquía en ambas pantallas para que se
/// sientan parte de un mismo flujo.
class CabeceraAuth extends StatelessWidget {
  const CabeceraAuth({
    super.key,
    required this.icono,
    required this.titulo,
    required this.subtitulo,
  });

  final IconData icono;
  final String titulo;
  final String subtitulo;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [ColoresPrevia.primario, ColoresPrevia.acento],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
          ),
          // Decorativo: el titular ya dice lo mismo.
          child: ExcludeSemantics(
            child: Icon(icono, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: EspaciadoPrevia.m),
        Semantics(
          header: true,
          child: Text(titulo, style: textos.headlineMedium),
        ),
        const SizedBox(height: EspaciadoPrevia.s),
        Text(subtitulo, style: textos.bodyLarge?.copyWith(
          color: ColoresPrevia.textoSuave,
        )),
      ],
    );
  }
}

/// Etiqueta de sección dentro de un formulario largo.
class EtiquetaSeccion extends StatelessWidget {
  const EtiquetaSeccion(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        texto.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: ColoresPrevia.primarioSuave,
              letterSpacing: 1.4,
              fontSize: 12,
            ),
      ),
    );
  }
}
