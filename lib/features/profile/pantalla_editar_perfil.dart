import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../app/tema.dart';
import '../../data/models/perfil.dart';
import '../../data/repositories/repositorio_auth.dart';
import '../../data/repositories/repositorio_social.dart';
import 'proveedores_perfil.dart';

class PantallaEditarPerfil extends ConsumerStatefulWidget {
  const PantallaEditarPerfil({super.key});

  @override
  ConsumerState<PantallaEditarPerfil> createState() =>
      _PantallaEditarPerfilState();
}

class _PantallaEditarPerfilState extends ConsumerState<PantallaEditarPerfil> {
  final _formulario = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _bio = TextEditingController();
  final _instagram = TextEditingController();
  final _tiktok = TextEditingController();
  final _x = TextEditingController();
  final _usuario = TextEditingController();
  final _ciudad = TextEditingController();

  DateTime? _fechaNacimiento;
  String? _avatar;
  bool _subiendoAvatar = false;
  bool _cargandoDatos = true;
  bool _falloAlCargar = false;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    // Solo al reintentar: la primera vez ya se parte del estado de carga.
    if (_falloAlCargar) {
      setState(() {
        _cargandoDatos = true;
        _falloAlCargar = false;
      });
    }
    final repo = ref.read(repositorioAuthProvider);
    final Perfil? perfil;
    final DateTime? fecha;
    try {
      perfil = await repo.miPerfil();
      // La fecha de nacimiento no viene en el perfil: no es legible por
      // SELECT. Hay que pedirla por su funcion, que solo responde al titular.
      fecha = await repo.miFechaNacimiento();
    } catch (_) {
      // Sin esto un fallo de red deja la ruleta girando para siempre y el
      // formulario vacio no se puede enseñar: guardaria el perfil en blanco.
      if (mounted) {
        setState(() {
          _cargandoDatos = false;
          _falloAlCargar = true;
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _nombre.text = perfil?.nombre ?? '';
      _bio.text = perfil?.bio ?? '';
      _instagram.text = perfil?.instagram ?? '';
      _tiktok.text = perfil?.tiktok ?? '';
      _x.text = perfil?.xUsuario ?? '';
      _usuario.text = perfil?.username ?? '';
      _ciudad.text = perfil?.ciudad ?? '';
      _avatar = perfil?.avatarUrl;
      _fechaNacimiento = fecha;
      _cargandoDatos = false;
    });
  }

  @override
  void dispose() {
    _nombre.dispose();
    _bio.dispose();
    _instagram.dispose();
    _tiktok.dispose();
    _x.dispose();
    _usuario.dispose();
    _ciudad.dispose();
    super.dispose();
  }

  Future<void> _cambiarFoto() async {
    final elegida = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      // Un avatar no necesita mas: se ve a 44 px en la mayoria de sitios.
      maxWidth: 800,
      imageQuality: 85,
    );
    if (elegida == null) return;

    setState(() => _subiendoAvatar = true);
    try {
      final bytes = await elegida.readAsBytes();
      final punto = elegida.name.lastIndexOf('.');
      final url = await ref
          .read(repositorioSocialProvider)
          .subirAvatar(
            bytes: bytes,
            extension: punto > 0
                ? elegida.name.substring(punto + 1).toLowerCase()
                : 'jpg',
          );
      // Sin esto, se sube la foto y la cabecera del perfil sigue enseñando
      // la anterior hasta que se reinicia la aplicacion.
      refrescarPerfil(ref);
      if (mounted) setState(() => _avatar = url);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se ha podido subir la foto.');
    } finally {
      if (mounted) setState(() => _subiendoAvatar = false);
    }
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate:
          _fechaNacimiento ?? DateTime(hoy.year - 18, hoy.month, hoy.day),
      firstDate: DateTime(hoy.year - 100),
      lastDate: hoy,
      locale: const Locale('es', 'ES'),
      helpText: 'Tu fecha de nacimiento',
    );
    if (elegida != null) setState(() => _fechaNacimiento = elegida);
  }

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;

    // Sin fecha de nacimiento el servidor no da el perfil por completo, y sin
    // perfil completo no se pueden abrir previas. Si se deja guardar sin
    // ella, la cuenta queda bloqueada sin que nada lo explique.
    if (_fechaNacimiento == null) {
      setState(
        () => _error = 'Pon tu fecha de nacimiento: sin ella no podrás abrir '
            'previas.',
      );
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      await ref
          .read(repositorioAuthProvider)
          .actualizarPerfil(
            nombre: _nombre.text,
            bio: _bio.text,
            fechaNacimiento: _fechaNacimiento,
            instagram: _instagram.text,
            tiktok: _tiktok.text,
            xUsuario: _x.text,
            username: _usuario.text,
            ciudad: _ciudad.text,
          );
      refrescarPerfil(ref);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Perfil actualizado.')));
    } on ErrorPrevia catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se ha podido guardar. Inténtalo otra vez.');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoDatos) {
      // Con barra desde el principio: sin ella no hay forma de volver atras
      // si la carga se atasca.
      return Scaffold(
        appBar: AppBar(title: const Text('Editar perfil')),
        body: Center(
          child: CircularProgressIndicator(
            color: context.colores.primarioTexto,
          ),
        ),
      );
    }

    if (_falloAlCargar) {
      return Scaffold(
        appBar: AppBar(title: const Text('Editar perfil')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(EspaciadoPrevia.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No se ha podido cargar tu perfil.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: EspaciadoPrevia.m),
                OutlinedButton(
                  onPressed: _cargar,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final textos = Theme.of(context).textTheme;
    final formatoFecha = DateFormat('d MMMM y', 'es_ES');

    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: SafeArea(
        child: Form(
          key: _formulario,
          child: ListView(
            padding: const EdgeInsets.all(EspaciadoPrevia.l),
            children: [
              // La foto primero y grande: es lo que mas cambia como te ven.
              Center(
                child: Semantics(
                  button: true,
                  label: 'Cambiar foto de perfil',
                  child: Pulsable(
                    onTap: _subiendoAvatar ? null : _cambiarFoto,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AvatarPerfil(
                          url: _avatar,
                          inicial: _nombre.text.isEmpty ? '?' : _nombre.text,
                          lado: 132,
                          anillo: context.colores.primario,
                        ),
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Container(
                            width: 42,
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: context.colores.primario,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: context.colores.fondo,
                                width: 3,
                              ),
                            ),
                            child: _subiendoAvatar
                                ? SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: context.colores.sobrePrimario,
                                    ),
                                  )
                                : Icon(
                                    Icons.photo_camera_rounded,
                                    size: 20,
                                    color: context.colores.sobrePrimario,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: EspaciadoPrevia.s),
              Center(
                child: TextButton(
                  onPressed: _subiendoAvatar ? null : _cambiarFoto,
                  child: Text(_avatar == null ? 'Añadir foto' : 'Cambiar foto'),
                ),
              ),
              const SizedBox(height: EspaciadoPrevia.m),

              TextFormField(
                controller: _nombre,
                textCapitalization: TextCapitalization.words,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: 'Cómo te llamas',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Escribe al menos 2 caracteres'
                    : null,
              ),
              TextFormField(
                controller: _usuario,
                autocorrect: false,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
                  LengthLimitingTextInputFormatter(20),
                ],
                decoration: const InputDecoration(
                  labelText: 'Nombre de usuario',
                  prefixText: '@',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                  helperText: 'Minúsculas, números y _. Así te encuentran.',
                ),
                validator: (v) =>
                    (v == null || !RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(v))
                    ? 'Entre 3 y 20: minúsculas, números o _'
                    : null,
              ),

              const SizedBox(height: EspaciadoPrevia.xl),
              const Titular('Tus redes', tamano: 22),
              const SizedBox(height: EspaciadoPrevia.xs),
              Text(
                'Salen en tu perfil a la vista. Todas opcionales.',
                style: textos.bodyMedium,
              ),
              const SizedBox(height: EspaciadoPrevia.m),
              _CampoRed(
                controlador: _instagram,
                etiqueta: 'Instagram',
                icono: FontAwesomeIcons.instagram,
              ),
              const SizedBox(height: EspaciadoPrevia.s),
              _CampoRed(
                controlador: _tiktok,
                etiqueta: 'TikTok',
                icono: FontAwesomeIcons.tiktok,
              ),
              const SizedBox(height: EspaciadoPrevia.s),
              _CampoRed(
                controlador: _x,
                etiqueta: 'X',
                icono: FontAwesomeIcons.xTwitter,
              ),

              const SizedBox(height: EspaciadoPrevia.xl),
              const Titular('Más sobre ti', tamano: 22),
              const SizedBox(height: EspaciadoPrevia.m),
              TextFormField(
                controller: _bio,
                maxLines: 3,
                maxLength: 280,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Sobre ti',
                  hintText: 'Dos líneas para que sepan quién eres.',
                  alignLabelWithHint: true,
                ),
              ),
              TextFormField(
                controller: _ciudad,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Ciudad',
                  hintText: 'Zaragoza',
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
              ),
              const SizedBox(height: EspaciadoPrevia.m),
              InkWell(
                onTap: _elegirFecha,
                borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha de nacimiento',
                    prefixIcon: Icon(Icons.cake_outlined),
                  ),
                  child: Text(
                    _fechaNacimiento == null
                        ? 'Toca para elegir'
                        : formatoFecha.format(_fechaNacimiento!),
                    style: TextStyle(
                      color: _fechaNacimiento == null
                          ? context.colores.textoTenue
                          : context.colores.texto,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: EspaciadoPrevia.xs),
              Text(
                'Nadie más puede verla. Solo se publica tu edad, y sin ella '
                'no puedes abrir previas.',
                style: textos.bodyMedium?.copyWith(
                  fontSize: 12,
                  color: context.colores.textoTenue,
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: EspaciadoPrevia.m),
                Container(
                  padding: const EdgeInsets.all(EspaciadoPrevia.m),
                  decoration: BoxDecoration(
                    color: context.colores.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
                    border: Border.all(
                      color: context.colores.error.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: context.colores.error),
                  ),
                ),
              ],

              const SizedBox(height: EspaciadoPrevia.l),
              FilledButton(
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: context.colores.sobrePrimario,
                        ),
                      )
                    : const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un campo de usuario de una red, con su logo delante.
class _CampoRed extends StatelessWidget {
  const _CampoRed({
    required this.controlador,
    required this.etiqueta,
    required this.icono,
  });

  final TextEditingController controlador;
  final String etiqueta;
  final FaIconData icono;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controlador,
    autocorrect: false,
    keyboardType: TextInputType.url,
    decoration: InputDecoration(
      labelText: etiqueta,
      prefixText: '@',
      prefixIcon: Padding(
        padding: const EdgeInsets.all(14),
        child: FaIcon(icono, size: 18, color: context.colores.textoSuave),
      ),
    ),
  );
}
