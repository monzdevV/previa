import 'dart:math';

const int minJugadoresTabu = 4;
const int segundosTurnoTabu = 60;
const int rondasPorDefectoTabu = 3;

/// Carta: la palabra a describir y las 4 que no se pueden decir.
class CartaTabu {
  const CartaTabu(this.objetivo, this.prohibidas);
  final String objetivo;
  final List<String> prohibidas;
}

/// Solo palabras cotidianas y neutras: sin alcohol, drogas, sexo ni personas
/// reales, porque se juega también en grupos mixtos y sin beber.
const List<CartaTabu> cartasTabu = [
  CartaTabu('Paraguas', ['Lluvia', 'Mojarse', 'Abrir', 'Mango']),
  CartaTabu('Playa', ['Arena', 'Mar', 'Sol', 'Toalla']),
  CartaTabu('Cumpleaños', ['Tarta', 'Velas', 'Años', 'Regalo']),
  CartaTabu('Despertador', ['Dormir', 'Sonar', 'Hora', 'Mañana']),
  CartaTabu('Bicicleta', ['Ruedas', 'Pedales', 'Pedalear', 'Manillar']),
  CartaTabu('Pizza', ['Italia', 'Queso', 'Masa', 'Horno']),
  CartaTabu('Biblioteca', ['Libros', 'Silencio', 'Leer', 'Prestar']),
  CartaTabu('Cepillo de dientes', ['Boca', 'Pasta', 'Limpiar', 'Dentista']),
  CartaTabu('Aeropuerto', ['Avión', 'Maleta', 'Vuelo', 'Embarcar']),
  CartaTabu('Reloj', ['Hora', 'Muñeca', 'Agujas', 'Tiempo']),
  CartaTabu('Nieve', ['Frío', 'Blanco', 'Esquiar', 'Muñeco']),
  CartaTabu('Gafas', ['Ver', 'Ojos', 'Cristales', 'Montura']),
  CartaTabu('Zapatillas', ['Pies', 'Correr', 'Cordones', 'Calzado']),
  CartaTabu('Cine', ['Película', 'Palomitas', 'Pantalla', 'Entrada']),
  CartaTabu('Ascensor', ['Subir', 'Piso', 'Botón', 'Escaleras']),
  CartaTabu('Espejo', ['Reflejo', 'Mirar', 'Cristal', 'Cara']),
  CartaTabu('Cafetera', ['Café', 'Taza', 'Desayuno', 'Cápsula']),
  CartaTabu('Mochila', ['Espalda', 'Colegio', 'Llevar', 'Cremallera']),
  CartaTabu('Linterna', ['Luz', 'Pilas', 'Oscuro', 'Encender']),
  CartaTabu('Semáforo', ['Rojo', 'Verde', 'Calle', 'Cruzar']),
  CartaTabu('Helado', ['Frío', 'Cucurucho', 'Verano', 'Sabor']),
  CartaTabu('Gato', ['Maullar', 'Bigotes', 'Ratón', 'Mascota']),
  CartaTabu('Perro', ['Ladrar', 'Hueso', 'Paseo', 'Cachorro']),
  CartaTabu('Lavadora', ['Ropa', 'Lavar', 'Jabón', 'Centrifugar']),
  CartaTabu('Tijeras', ['Cortar', 'Papel', 'Pelo', 'Filo']),
  CartaTabu('Cama', ['Dormir', 'Colchón', 'Almohada', 'Sábanas']),
  CartaTabu('Teléfono', ['Llamar', 'Móvil', 'Pantalla', 'Número']),
  CartaTabu('Supermercado', ['Comprar', 'Carrito', 'Caja', 'Comida']),
  CartaTabu('Hospital', ['Médico', 'Enfermo', 'Urgencias', 'Camilla']),
  CartaTabu('Tren', ['Vías', 'Estación', 'Vagón', 'Billete']),
  CartaTabu('Piscina', ['Agua', 'Nadar', 'Bañador', 'Cloro']),
  CartaTabu('Escuela', ['Profesor', 'Clase', 'Alumno', 'Pizarra']),
  CartaTabu('Cocina', ['Fuego', 'Cocinar', 'Nevera', 'Receta']),
  CartaTabu('Tormenta', ['Rayo', 'Trueno', 'Lluvia', 'Nubes']),
  CartaTabu('Montaña', ['Alta', 'Subir', 'Cumbre', 'Senderismo']),
  CartaTabu('Fotografía', ['Cámara', 'Imagen', 'Foto', 'Retrato']),
  CartaTabu('Guitarra', ['Cuerdas', 'Tocar', 'Música', 'Rasgar']),
  CartaTabu('Vacaciones', ['Descanso', 'Viaje', 'Hotel', 'Maleta']),
  CartaTabu('Pañuelo', ['Nariz', 'Mocos', 'Papel', 'Resfriado']),
  CartaTabu('Escoba', ['Barrer', 'Suelo', 'Bruja', 'Limpiar']),
  CartaTabu('Maleta', ['Viaje', 'Ropa', 'Ruedas', 'Equipaje']),
  CartaTabu('Paella', ['Arroz', 'Valencia', 'Marisco', 'Sartén']),
  CartaTabu('Tortilla', ['Huevo', 'Patata', 'Cebolla', 'Sartén']),
  CartaTabu('Calendario', ['Fecha', 'Mes', 'Días', 'Año']),
  CartaTabu('Impresora', ['Papel', 'Tinta', 'Imprimir', 'Folio']),
  CartaTabu('Ordenador', ['Teclado', 'Ratón', 'Pantalla', 'Internet']),
  CartaTabu('Cargador', ['Enchufe', 'Batería', 'Cable', 'Móvil']),
  CartaTabu('Recreo', ['Colegio', 'Niños', 'Patio', 'Jugar']),
  CartaTabu('Dentista', ['Dientes', 'Muela', 'Boca', 'Taladro']),
  CartaTabu('Peluquería', ['Pelo', 'Cortar', 'Tijeras', 'Champú']),
  CartaTabu('Camping', ['Tienda', 'Naturaleza', 'Acampar', 'Saco']),
  CartaTabu('Mercado', ['Fruta', 'Puesto', 'Comprar', 'Verdura']),
  CartaTabu('Estrella', ['Cielo', 'Noche', 'Brillar', 'Luna']),
  CartaTabu('Reloj de arena', ['Tiempo', 'Granos', 'Girar', 'Minuto']),
  CartaTabu('Sombrilla', ['Sombra', 'Sol', 'Arena', 'Clavar']),
  CartaTabu('Globo', ['Aire', 'Hinchar', 'Fiesta', 'Explotar']),
  CartaTabu('Pastel', ['Dulce', 'Tarta', 'Horno', 'Postre']),
  CartaTabu('Corbata', ['Cuello', 'Traje', 'Nudo', 'Camisa']),
  CartaTabu('Bufanda', ['Cuello', 'Frío', 'Lana', 'Invierno']),
  CartaTabu('Autobús', ['Parada', 'Conductor', 'Pasajeros', 'Línea']),
  CartaTabu('Carretera', ['Coche', 'Asfalto', 'Camino', 'Señal']),
  CartaTabu('Museo', ['Cuadros', 'Arte', 'Visitar', 'Exposición']),
  CartaTabu('Telescopio', ['Estrellas', 'Mirar', 'Lejos', 'Espacio']),
  CartaTabu('Mapa', ['Perderse', 'Ciudad', 'Camino', 'Plano']),
  CartaTabu('Karaoke', ['Cantar', 'Micrófono', 'Letra', 'Canción']),
];

/// Reparte [jugadores] en dos equipos al azar y lo más parejos posible: si el
/// número es impar, el primer equipo lleva uno más.
List<List<String>> repartirEquipos(List<String> jugadores, Random azar) {
  final mezclados = [...jugadores]..shuffle(azar);
  final mitad = (mezclados.length + 1) ~/ 2;
  return [mezclados.sublist(0, mitad), mezclados.sublist(mitad)];
}

/// Partida de Palabra prohibida. Lógica pura, sin Flutter.
///
/// Cada ronda juega un turno cada equipo (A y luego B). En cada turno una
/// persona del equipo describe y el resto adivina; el otro equipo vigila.
class PartidaTabu {
  PartidaTabu({
    required List<String> jugadores,
    this.rondas = rondasPorDefectoTabu,
    Random? azar,
  }) : _azar = azar ?? Random() {
    if (jugadores.length < minJugadoresTabu) {
      throw ArgumentError('Hacen falta al menos $minJugadoresTabu.');
    }
    if (rondas < 1) throw ArgumentError('Al menos una ronda.');
    equipos = repartirEquipos(jugadores, _azar);
    _mazo = [...cartasTabu]..shuffle(_azar);
  }

  final Random _azar;
  final int rondas;
  late final List<List<String>> equipos;
  late final List<CartaTabu> _mazo;
  int _siguiente = 0;

  final List<int> puntos = [0, 0];

  /// Turnos ya terminados; el turno en curso es `_turnosJugados`.
  int _turnosJugados = 0;

  CartaTabu? carta;
  int aciertosTurno = 0;
  int tabusTurno = 0;
  int pasadasTurno = 0;

  int get turnosTotales => rondas * 2;
  bool get terminada => _turnosJugados >= turnosTotales;
  int get ronda => min(_turnosJugados ~/ 2 + 1, rondas);
  int get equipoActual => _turnosJugados % 2;

  /// El turno en curso es el último de la partida.
  bool get esUltimoTurno => _turnosJugados == turnosTotales - 1;

  /// Quien describe rota dentro de su equipo en cada ronda.
  String get describe {
    final e = equipos[equipoActual];
    return e[(_turnosJugados ~/ 2) % e.length];
  }

  /// Ganador: 0 o 1; `null` si hay empate.
  int? get ganador {
    if (puntos[0] == puntos[1]) return null;
    return puntos[0] > puntos[1] ? 0 : 1;
  }

  /// Saca una carta nueva. Si se acaba el mazo se vuelve a barajar: con 70
  /// cartas y 60 s por turno es muy raro, pero no debe romperse.
  CartaTabu _robar() {
    if (_siguiente >= _mazo.length) {
      _mazo.shuffle(_azar);
      _siguiente = 0;
    }
    return _mazo[_siguiente++];
  }

  void empezarTurno() {
    aciertosTurno = tabusTurno = pasadasTurno = 0;
    carta = _robar();
  }

  /// Un acierto suma 1 al equipo que juega.
  void acierto() {
    aciertosTurno++;
    puntos[equipoActual]++;
    carta = _robar();
  }

  /// Tabú: se dijo una palabra prohibida. Resta 1 sin bajar de 0 el total
  /// del equipo, para que un mal turno no deje un marcador negativo.
  void tabu() {
    tabusTurno++;
    if (puntos[equipoActual] > 0) puntos[equipoActual]--;
    carta = _robar();
  }

  void pasar() {
    pasadasTurno++;
    carta = _robar();
  }

  /// Cierra el turno en curso y pasa al siguiente equipo.
  void terminarTurno() {
    carta = null;
    _turnosJugados++;
  }
}
