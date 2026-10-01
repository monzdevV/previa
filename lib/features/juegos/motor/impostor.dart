import 'dart:math';

/// Una categoría de palabras. El impostor la conoce y las demás personas
/// reciben la palabra concreta: así el impostor puede disimular sin que el
/// juego sea imposible.
class CategoriaImpostor {
  const CategoriaImpostor(this.nombre, this.palabras);
  final String nombre;
  final List<String> palabras;
}

/// Solo palabras cotidianas y neutras: nada de personas reales ni de
/// consumo de alcohol, porque El impostor se juega también sin beber.
const List<CategoriaImpostor> categoriasImpostor = [
  CategoriaImpostor('Comida', [
    'Tortilla de patatas',
    'Paella',
    'Croquetas',
    'Pizza',
    'Hamburguesa',
    'Sushi',
    'Ensaladilla',
    'Jamón',
    'Helado',
    'Churros',
    'Tacos',
    'Lasaña',
    'Gazpacho',
    'Palomitas',
  ]),
  CategoriaImpostor('Animales', [
    'Perro',
    'Gato',
    'Elefante',
    'Pingüino',
    'Jirafa',
    'Delfín',
    'Búho',
    'Tiburón',
    'Canguro',
    'Mapache',
    'Loro',
    'Cocodrilo',
    'Medusa',
    'Koala',
  ]),
  CategoriaImpostor('Lugares', [
    'Playa',
    'Aeropuerto',
    'Biblioteca',
    'Supermercado',
    'Gimnasio',
    'Cine',
    'Hospital',
    'Parque de atracciones',
    'Estación de tren',
    'Camping',
    'Museo',
    'Piscina',
    'Universidad',
    'Mercadillo',
  ]),
  CategoriaImpostor('Fiesta', [
    'Pista de baile',
    'Guardarropa',
    'DJ',
    'Cola de la entrada',
    'Confeti',
    'Karaoke',
    'Reservado',
    'Previa',
    'Fotomatón',
    'Altavoz',
    'Barra',
    'Cumpleaños',
    'Verbena',
    'After',
  ]),
  CategoriaImpostor('Objetos', [
    'Paraguas',
    'Cargador',
    'Llaves',
    'Espejo',
    'Mochila',
    'Auriculares',
    'Linterna',
    'Reloj',
    'Gafas de sol',
    'Tijeras',
    'Maleta',
    'Almohada',
    'Cepillo de dientes',
    'Mando de la tele',
  ]),
  CategoriaImpostor('Deportes', [
    'Fútbol',
    'Baloncesto',
    'Tenis',
    'Natación',
    'Ciclismo',
    'Pádel',
    'Balonmano',
    'Esquí',
    'Surf',
    'Boxeo',
    'Voleibol',
    'Atletismo',
    'Escalada',
    'Golf',
  ]),
  CategoriaImpostor('Profesiones', [
    'Bombero',
    'Profesor',
    'Médico',
    'Cocinero',
    'Piloto',
    'Fontanero',
    'Periodista',
    'Camarero',
    'Arquitecto',
    'Veterinario',
    'Cartero',
    'Peluquero',
    'Fotógrafo',
    'Electricista',
  ]),
  CategoriaImpostor('Películas', [
    'Titanic',
    'Shrek',
    'Harry Potter',
    'El Rey León',
    'Toy Story',
    'Frozen',
    'Matrix',
    'Jurassic Park',
    'Los Vengadores',
    'Buscando a Nemo',
    'Star Wars',
    'El Señor de los Anillos',
    'Spider-Man',
    'Coco',
  ]),
];

const int minJugadoresImpostor = 3;

/// Una ronda de El impostor: quién es el impostor y cuál es la palabra.
/// Lógica pura, sin Flutter, igual que `Partida`, para poder probarla.
class RondaImpostor {
  RondaImpostor({
    required this.jugadores,
    required this.categoria,
    Random? azar,
    String? evitar,
  }) {
    if (jugadores.length < minJugadoresImpostor) {
      throw ArgumentError('Hacen falta al menos $minJugadoresImpostor.');
    }
    final r = azar ?? Random();
    final candidatas = categoria.palabras.where((p) => p != evitar).toList();
    palabra = candidatas[r.nextInt(candidatas.length)];
    impostor = r.nextInt(jugadores.length);
    // Quien abre el debate se sortea aparte para que no sea siempre el
    // primero de la lista.
    primero = r.nextInt(jugadores.length);
  }

  final List<String> jugadores;
  final CategoriaImpostor categoria;
  late final String palabra;
  late final int impostor;
  late final int primero;

  bool esImpostor(int indice) => indice == impostor;

  /// El grupo ha acusado a [indice]: ¿era el impostor?
  bool acierta(int indice) => indice == impostor;

  String get nombreImpostor => jugadores[impostor];
}
