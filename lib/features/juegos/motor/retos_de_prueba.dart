import '../modelo_juegos.dart';

/// Cartas mínimas para desarrollar y probar el motor sin depender del
/// contenido real. Siguen la misma convención de texto que datos/: el motor
/// antepone la fórmula de cada juego (ver `formatearTextoCarta`).
const List<Reto> retosDePrueba = [
  Reto(id: 'p-nhh-s-1', juego: TipoJuego.noHayHuevos, nivel: NivelReto.suave, texto: 'Cuenta tu peor cita en 30 segundos'),
  Reto(id: 'p-nhh-s-2', juego: TipoJuego.noHayHuevos, nivel: NivelReto.suave, texto: 'Imita a {otro} hasta que alguien lo adivine', necesitaOtraPersona: true),
  Reto(id: 'p-nhh-s-3', juego: TipoJuego.noHayHuevos, nivel: NivelReto.suave, texto: 'Baila sin música durante 15 segundos', sorbos: 1),
  Reto(id: 'p-nhh-s-4', juego: TipoJuego.noHayHuevos, nivel: NivelReto.suave, texto: 'Habla como un presentador de telediario el resto de la ronda'),
  Reto(id: 'p-nhh-a-1', juego: TipoJuego.noHayHuevos, nivel: NivelReto.atrevido, texto: 'Deja que {otro} publique una story con tu móvil', sorbos: 3, necesitaOtraPersona: true),
  Reto(id: 'p-nhh-a-2', juego: TipoJuego.noHayHuevos, nivel: NivelReto.atrevido, texto: 'Dale un abrazo de 10 segundos a {otro}', contactoFisico: true, necesitaOtraPersona: true),
  Reto(id: 'p-nhh-f-1', juego: TipoJuego.noHayHuevos, nivel: NivelReto.sinFiltro, texto: 'Lee en voz alta tu último chat con tu ex', sorbos: 3),
  Reto(id: 'p-yn-s-1', juego: TipoJuego.yoNunca, nivel: NivelReto.suave, texto: 'he fingido estar enfermo para no ir a clase', sorbos: 1),
  Reto(id: 'p-yn-a-1', juego: TipoJuego.yoNunca, nivel: NivelReto.atrevido, texto: 'he stalkeado a alguien durante horas', sorbos: 1),
  Reto(id: 'p-mp-s-1', juego: TipoJuego.masProbable, nivel: NivelReto.suave, texto: 'llegue tarde a su propia boda', sorbos: 1),
  Reto(id: 'p-vr-s-1', juego: TipoJuego.verdadOReto, nivel: NivelReto.suave, texto: 'Verdad: ¿cuál es tu mayor miedo irracional?'),
  Reto(id: 'p-vr-a-1', juego: TipoJuego.verdadOReto, nivel: NivelReto.atrevido, texto: 'Reto: llama a {otro} por un apodo ridículo el resto de la noche', necesitaOtraPersona: true),
];
