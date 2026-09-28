import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/perfil.dart';

final clienteSupabaseProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final repositorioAuthProvider = Provider<RepositorioAuth>(
  (ref) => RepositorioAuth(ref.watch(clienteSupabaseProvider)),
);

/// Estado de sesion, emitido cada vez que el usuario entra o sale.
final estadoSesionProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(clienteSupabaseProvider).auth.onAuthStateChange,
);

/// Identificador de quien tiene la sesion abierta, o null si no hay nadie.
///
/// Los repositorios dependen de esto y no de [estadoSesionProvider] porque
/// la sesion emite tambien al renovar el token cada hora, y eso reconstruiria
/// todas las pantallas sin motivo. Un `Provider` solo avisa si el valor
/// cambia, asi que aqui solo salta al entrar, salir o cambiar de cuenta, que
/// es justo cuando hay que tirar los datos de la cuenta anterior.
final uidActualProvider = Provider<String?>((ref) {
  ref.watch(estadoSesionProvider);
  return ref.watch(clienteSupabaseProvider).auth.currentUser?.id;
});

/// Perfil de la persona que ha iniciado sesion, o null si no hay sesion.
final miPerfilProvider = FutureProvider<Perfil?>((ref) async {
  ref.watch(estadoSesionProvider);
  return ref.watch(repositorioAuthProvider).miPerfil();
});

/// Error de dominio con un mensaje ya listo para enseñar al usuario.
class ErrorPrevia implements Exception {
  const ErrorPrevia(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

/// Codigo de Postgres para "esa columna no existe".
const _columnaInexistente = '42703';

const _columnasDePerfil =
    'id, username, display_name, avatar_url, bio, onboarded, '
    'reputation, ratings_count, instagram, city, is_moderator, is_demo';

/// Lee un perfil pidiendo tambien sus redes.
///
/// Las columnas `tiktok` y `x_handle` llegan con la migracion `vas_y_redes`.
/// Si el servidor aun no la tiene, se repite la lectura sin ellas en lugar de
/// dejar la app sin perfil: es la unica diferencia entre un servidor y otro,
/// y vive solo aqui.
Future<Map<String, dynamic>?> leerPerfil(
  SupabaseClient cliente,
  String id,
) async {
  try {
    return await cliente
        .from('profiles')
        .select('$_columnasDePerfil, tiktok, x_handle')
        .eq('id', id)
        .maybeSingle();
  } on PostgrestException catch (e) {
    if (e.code != _columnaInexistente) rethrow;
    return cliente
        .from('profiles')
        .select(_columnasDePerfil)
        .eq('id', id)
        .maybeSingle();
  }
}

class RepositorioAuth {
  RepositorioAuth(this._cliente);

  final SupabaseClient _cliente;

  User? get usuarioActual => _cliente.auth.currentUser;
  bool get haySesion => usuarioActual != null;

  /// Registro con correo y contraseña.
  ///
  /// La fecha de nacimiento viaja en los metadatos: el disparador
  /// `handle_new_user` crea el perfil con ella, y otro disparador rechaza
  /// a los menores de 18. La comprobacion de aqui solo sirve para dar un
  /// mensaje inmediato; la que manda es la del servidor.
  ///
  /// Devuelve si ya hay sesion. Con la confirmacion por correo activada en
  /// Supabase no la hay hasta pulsar el enlace, y la pantalla tiene que
  /// decirlo en vez de mandar a un inicio que rebota al login sin explicar.
  ///
  /// El nombre de usuario ya no se pide: es la pregunta que mas gente
  /// abandona en un registro ("ese ya esta cogido") y no hace falta para
  /// entrar. Se inventa a partir del nombre y se cambia luego en el perfil.
  /// Si choca con uno existente se reintenta con otro sufijo sin molestar.
  Future<bool> registrar({
    required String correo,
    required String contrasena,
    required String nombre,
    required DateTime fechaNacimiento,
  }) async {
    if (!esMayorDeEdad(fechaNacimiento)) {
      throw const ErrorPrevia('Previa es solo para mayores de 18 años.');
    }

    const intentos = 3;
    for (var intento = 1; ; intento++) {
      try {
        final respuesta = await _cliente.auth.signUp(
          email: correo.trim(),
          password: contrasena,
          data: {
            'username': usernameDesde(nombre),
            'display_name': nombre.trim(),
            'birth_date': fechaNacimiento.toIso8601String().substring(0, 10),
          },
        );
        return respuesta.session != null;
      } on AuthException catch (e) {
        if (intento < intentos && _esUsernameCogido(e.message)) continue;
        throw ErrorPrevia(_traducir(e.message));
      }
    }
  }

  /// Vuelve a mandar el enlace de confirmacion del registro.
  Future<void> reenviarConfirmacion(String correo) async {
    try {
      await _cliente.auth.resend(type: OtpType.signup, email: correo.trim());
    } on AuthException catch (e) {
      throw ErrorPrevia(_traducir(e.message));
    }
  }

  /// Un nombre de usuario valido para la restriccion de `profiles`
  /// (`^[a-z0-9_]+$`, de 3 a 20) sacado del nombre que ha escrito la persona.
  ///
  /// El sufijo de cuatro cifras hace que el choque sea raro sin tener que
  /// preguntar antes al servidor, que obligaria a abrir la tabla de perfiles
  /// a quien aun no tiene cuenta.
  @visibleForTesting
  static String usernameDesde(String nombre, {Random? azar}) {
    const tildes = {
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'â': 'a',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
      'ñ': 'n',
      'ç': 'c',
    };
    final limpio = nombre
        .trim()
        .toLowerCase()
        .split('')
        .map((letra) => tildes[letra] ?? letra)
        .join()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    // Sin nada aprovechable (un nombre solo de emojis, por ejemplo) se usa
    // la marca en lugar de dejar un usuario que sea solo numeros.
    final base = limpio.isEmpty ? 'previa' : limpio;
    final sufijo = 1000 + (azar ?? Random()).nextInt(9000);
    final corte = base.length > 16 ? base.substring(0, 16) : base;
    return '$corte$sufijo';
  }

  /// Supabase no deja pasar el texto de los disparadores: un choque en el
  /// `unique` de `username` llega como "Database error saving new user".
  /// El de menores de edad llega igual, pero la edad ya se ha comprobado
  /// antes de llamar, asi que aqui solo puede ser el usuario repetido.
  static bool _esUsernameCogido(String mensaje) {
    final m = mensaje.toLowerCase();
    return m.contains('duplicate') ||
        m.contains('username') ||
        m.contains('database error saving new user');
  }

  Future<void> entrar({
    required String correo,
    required String contrasena,
  }) async {
    try {
      // La pantalla permite escribir el usuario de la cuenta de demostración.
      // Supabase autentica por email, por eso se resuelve solo este alias local.
      final identificador = correo.trim().toLowerCase();
      final email = identificador == 'admin'
          ? 'admin@previa.app'
          : identificador;
      await _cliente.auth.signInWithPassword(
        email: email,
        password: contrasena,
      );
    } on AuthException catch (e) {
      throw ErrorPrevia(_traducir(e.message));
    }
  }

  Future<void> salir() => _cliente.auth.signOut();

  Future<void> recuperarContrasena(String correo) async {
    try {
      await _cliente.auth.resetPasswordForEmail(correo.trim());
    } on AuthException catch (e) {
      throw ErrorPrevia(_traducir(e.message));
    }
  }

  Future<Perfil?> miPerfil() async {
    final id = usuarioActual?.id;
    if (id == null) return null;
    final fila = await leerPerfil(_cliente, id);
    return fila == null ? null : Perfil.desdeJson(fila);
  }

  Future<Perfil> perfilDe(String id) async {
    final fila = await leerPerfil(_cliente, id);
    if (fila == null) throw const ErrorPrevia('Ese perfil no existe.');
    return Perfil.desdeJson(fila);
  }

  /// La edad la calcula el servidor a partir de una fecha que el cliente
  /// no puede leer.
  Future<int?> edadDe(String id) async {
    final valor = await _cliente.rpc('edad', params: {'p_profile': id});
    return valor as int?;
  }

  /// Unica via para que el titular consulte su propia fecha de nacimiento.
  Future<DateTime?> miFechaNacimiento() async {
    final valor = await _cliente.rpc('mi_fecha_nacimiento');
    return valor == null ? null : DateTime.parse(valor as String);
  }

  Future<void> actualizarPerfil({
    String? nombre,
    String? bio,
    String? avatarUrl,
    DateTime? fechaNacimiento,
    String? instagram,
    String? tiktok,
    String? xUsuario,
    String? ciudad,
    String? username,
  }) async {
    final id = usuarioActual?.id;
    if (id == null) throw const ErrorPrevia('No hay sesión iniciada.');

    if (fechaNacimiento != null && !esMayorDeEdad(fechaNacimiento)) {
      throw const ErrorPrevia('Previa es solo para mayores de 18 años.');
    }

    final cambios = <String, dynamic>{
      if (nombre != null) 'display_name': nombre.trim(),
      if (bio != null) 'bio': bio.trim(),
      'avatar_url': ?avatarUrl,
      if (fechaNacimiento != null)
        'birth_date': fechaNacimiento.toIso8601String().substring(0, 10),
      // Se guarda vacio como nulo: una cadena en blanco en la base de datos
      // obliga a comprobar dos cosas cada vez que se lee.
      if (instagram != null)
        'instagram': instagram.trim().replaceAll('@', '').isEmpty
            ? null
            : instagram.trim().replaceAll('@', ''),
      if (ciudad != null) 'city': ciudad.trim().isEmpty ? null : ciudad.trim(),
    };
    if (cambios.isEmpty) return;

    await _cliente.from('profiles').update(cambios).eq('id', id);
  }

  /// RGPD, articulos 15 y 20: derecho de acceso y portabilidad.
  Future<Map<String, dynamic>> exportarMisDatos() async {
    final datos = await _cliente.rpc('exportar_mis_datos');
    return Map<String, dynamic>.from(datos as Map);
  }

  /// RGPD, articulo 17: derecho de supresion.
  Future<void> eliminarMiCuenta() async {
    await _cliente.rpc('eliminar_mi_cuenta');
    await salir();
  }

  static bool esMayorDeEdad(DateTime fechaNacimiento) {
    final hoy = DateTime.now();
    var edad = hoy.year - fechaNacimiento.year;
    final cumpleEsteAno = DateTime(
      hoy.year,
      fechaNacimiento.month,
      fechaNacimiento.day,
    );
    if (hoy.isBefore(cumpleEsteAno)) edad--;
    return edad >= 18;
  }

  String _traducir(String mensaje) {
    final m = mensaje.toLowerCase();
    if (m.contains('invalid login')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (m.contains('email not confirmed')) {
      return 'Aún no has confirmado tu correo. Busca el enlace en tu bandeja '
          '(mira también en spam).';
    }
    if (m.contains('already registered') ||
        m.contains('already been registered')) {
      return 'Ese correo ya tiene cuenta. Prueba a iniciar sesión.';
    }
    if (m.contains('password') && m.contains('least')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    if (m.contains('mayores de 18')) {
      return 'Previa es solo para mayores de 18 años.';
    }
    if (m.contains('duplicate') && m.contains('username')) {
      return 'Ese nombre de usuario ya está cogido.';
    }
    if (m.contains('email') && m.contains('invalid')) {
      return 'Ese correo no parece válido.';
    }
    return 'Algo ha fallado. Inténtalo de nuevo.';
  }
}
