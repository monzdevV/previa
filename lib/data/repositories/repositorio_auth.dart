import 'dart:typed_data';

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
  Future<void> registrar({
    required String correo,
    required String contrasena,
    required String username,
    required String nombre,
    required DateTime fechaNacimiento,
  }) async {
    if (!esMayorDeEdad(fechaNacimiento)) {
      throw const ErrorPrevia('Previa es solo para mayores de 18 años.');
    }

    try {
      await _cliente.auth.signUp(
        email: correo.trim(),
        password: contrasena,
        data: {
          'username': username.trim().toLowerCase(),
          'display_name': nombre.trim(),
          'birth_date': fechaNacimiento.toIso8601String().substring(0, 10),
        },
      );
    } on AuthException catch (e) {
      throw ErrorPrevia(_traducir(e.message));
    }
  }

  Future<void> entrar({required String correo, required String contrasena}) async {
    try {
      await _cliente.auth.signInWithPassword(
        email: correo.trim(),
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

    final fila = await _cliente
        .from('profiles')
        .select('id, username, display_name, avatar_url, bio, onboarded, '
            'reputation, ratings_count')
        .eq('id', id)
        .maybeSingle();

    return fila == null ? null : Perfil.desdeJson(fila);
  }

  Future<Perfil> perfilDe(String id) async {
    final fila = await _cliente
        .from('profiles')
        .select('id, username, display_name, avatar_url, bio, onboarded, '
            'reputation, ratings_count')
        .eq('id', id)
        .single();
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
    bool quitarAvatar = false,
    DateTime? fechaNacimiento,
  }) async {
    final id = usuarioActual?.id;
    if (id == null) throw const ErrorPrevia('No hay sesión iniciada.');

    if (fechaNacimiento != null && !esMayorDeEdad(fechaNacimiento)) {
      throw const ErrorPrevia('Previa es solo para mayores de 18 años.');
    }

    final cambios = <String, dynamic>{
      if (nombre != null) 'display_name': nombre.trim(),
      if (bio != null) 'bio': bio.trim(),
      // null en un campo opcional significa "no tocar"; para borrar la foto
      // hace falta pedirlo de forma explicita.
      if (quitarAvatar) 'avatar_url': null else 'avatar_url': ?avatarUrl,
      if (fechaNacimiento != null)
        'birth_date': fechaNacimiento.toIso8601String().substring(0, 10),
    };
    if (cambios.isEmpty) return;

    await _cliente.from('profiles').update(cambios).eq('id', id);
  }

  /// Sube la foto de perfil y devuelve su URL publica.
  ///
  /// Siempre se escribe en la misma ruta (`<uid>/foto`): asi cada persona
  /// ocupa un unico fichero y no quedan fotos antiguas huerfanas. Como la
  /// URL no cambia, se le anade la hora para saltarse la cache del
  /// dispositivo y de la CDN cuando se sube una foto nueva.
  Future<String> subirAvatar(Uint8List bytes, String tipoMime) async {
    final id = usuarioActual?.id;
    if (id == null) throw const ErrorPrevia('No hay sesión iniciada.');

    final ruta = '$id/foto';
    try {
      await _cliente.storage.from('avatars').uploadBinary(
            ruta,
            bytes,
            fileOptions: FileOptions(contentType: tipoMime, upsert: true),
          );
    } on StorageException catch (e) {
      throw ErrorPrevia(e.statusCode == '413'
          ? 'La foto pesa demasiado. Elige una de menos de 2 MB.'
          : 'No se ha podido subir la foto. Inténtalo de nuevo.');
    }

    final url = _cliente.storage.from('avatars').getPublicUrl(ruta);
    return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> borrarAvatar() async {
    final id = usuarioActual?.id;
    if (id == null) return;
    await _cliente.storage.from('avatars').remove(['$id/foto']);
  }

  /// RGPD, articulos 15 y 20: derecho de acceso y portabilidad.
  Future<Map<String, dynamic>> exportarMisDatos() async {
    try {
      final datos = await _cliente.rpc('exportar_mis_datos');
      return Map<String, dynamic>.from(datos as Map);
    } on PostgrestException {
      throw const ErrorPrevia(
          'No se han podido preparar tus datos. Inténtalo de nuevo.');
    } catch (_) {
      throw const ErrorPrevia(
          'No se han podido exportar tus datos. Comprueba tu conexión.');
    }
  }

  /// RGPD, articulo 17: derecho de supresion.
  Future<void> eliminarMiCuenta() async {
    // La foto hay que quitarla desde la API de Storage: si la borrara la base
    // de datos por SQL, desapareceria la fila pero el fichero quedaria huerfano.
    // Si falla no bloqueamos el borrado de la cuenta: prima el derecho de
    // supresion.
    try {
      await borrarAvatar();
    } catch (_) {}

    try {
      await _cliente.rpc('eliminar_mi_cuenta');
    } on PostgrestException {
      throw const ErrorPrevia(
          'No se ha podido eliminar la cuenta. Inténtalo de nuevo; si sigue '
          'fallando, escríbenos.');
    } catch (_) {
      throw const ErrorPrevia(
          'No se ha podido eliminar la cuenta. Comprueba tu conexión.');
    }

    // La cuenta ya no existe: el token del servidor es invalido y un signOut
    // global devolveria 401. Se cierra solo la sesion local, y si aun asi
    // falla no se le cuenta al usuario: el borrado ya se hizo.
    try {
      await _cliente.auth.signOut(scope: SignOutScope.local);
    } catch (_) {}
  }

  static bool esMayorDeEdad(DateTime fechaNacimiento) {
    final hoy = DateTime.now();
    var edad = hoy.year - fechaNacimiento.year;
    final cumpleEsteAno = DateTime(hoy.year, fechaNacimiento.month, fechaNacimiento.day);
    if (hoy.isBefore(cumpleEsteAno)) edad--;
    return edad >= 18;
  }

  String _traducir(String mensaje) {
    final m = mensaje.toLowerCase();
    if (m.contains('invalid login')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (m.contains('already registered') || m.contains('already been registered')) {
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
