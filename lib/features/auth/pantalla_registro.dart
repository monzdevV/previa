import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';
import '../../data/repositories/repositorio_auth.dart';
import '../profile/pantallas_legales.dart'
    show PantallaCondiciones, PantallaPrivacidad;
import 'piezas_acceso.dart';

/// Registro en tres pasos cortos: nombre, fecha de nacimiento y cuenta.
///
/// "Primero deja entrar; despues deja completar el perfil." Antes se pedian
/// seis cosas en una sola pantalla y cada campo era una razon para irse.
/// Ahora solo se pregunta lo que hace falta para crear la cuenta: el nombre
/// (para que los demas te vean), la fecha (la mayoria de edad es obligacion
/// legal y la exige el servidor) y con que vas a entrar. El nombre de usuario
/// se inventa solo y la foto, la bio y lo demas se ponen luego en el perfil.
class PantallaRegistro extends ConsumerStatefulWidget {
  const PantallaRegistro({super.key});

  @override
  ConsumerState<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends ConsumerState<PantallaRegistro> {
  static const _pasos = 3;

  /// Entre 250 y 300 ms: lo bastante para que se lea que avanzas, lo bastante
  /// poco para que tres pasos no se sientan mas lentos que un formulario.
  static const _transicion = Duration(milliseconds: 280);

  static final _formaCorreo = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _paginas = PageController();
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  final _focoNombre = FocusNode();
  final _focoCorreo = FocusNode();
  final _focoContrasena = FocusNode();

  late final _enlaceCondiciones = TapGestureRecognizer()
    ..onTap = () => abrirDocumentoLegal(context, const PantallaCondiciones());
  late final _enlacePrivacidad = TapGestureRecognizer()
    ..onTap = () => abrirDocumentoLegal(context, const PantallaPrivacidad());

  int _paso = 0;

  /// La rueda arranca en el dia en que se cumplen 18, que es donde esta la
  /// mayoria de la gente que se registra. Pero no vale con pulsar "Siguiente"
  /// sin tocarla: el gesto por defecto no debe facilitar mentir sobre la edad.
  late DateTime _fecha = _haceDieciochoAnos();
  bool _fechaTocada = false;

  bool _aceptaCondiciones = false;
  bool _oculta = true;
  bool _cargando = false;
  String? _error;

  /// Correo al que se ha mandado la confirmacion. Mientras no sea nulo se
  /// ensena "Mira tu correo" en lugar de los pasos.
  String? _correoPendiente;
  int _esperaReenvio = 0;
  Timer? _cuentaAtras;

  @override
  void initState() {
    super.initState();
    // El boton se enciende en cuanto el paso es valido, asi que cada letra
    // tiene que volver a pintarlo.
    _focoCorreo.addListener(_repintar);
    for (final campo in [_nombre, _correo, _contrasena]) {
      campo.addListener(_repintar);
    }
  }

  void _repintar() => setState(() {});

  @override
  void dispose() {
    _cuentaAtras?.cancel();
    _paginas.dispose();
    _nombre.dispose();
    _correo.dispose();
    _contrasena.dispose();
    _focoNombre.dispose();
    _focoCorreo.dispose();
    _focoContrasena.dispose();
    _enlaceCondiciones.dispose();
    _enlacePrivacidad.dispose();
    super.dispose();
  }

  static DateTime _haceDieciochoAnos() {
    final hoy = DateTime.now();
    return DateTime(hoy.year - 18, hoy.month, hoy.day);
  }

  static int _edad(DateTime nacimiento) {
    final hoy = DateTime.now();
    final cumplido = !DateTime(
      hoy.year,
      nacimiento.month,
      nacimiento.day,
    ).isAfter(hoy);
    return hoy.year - nacimiento.year - (cumplido ? 0 : 1);
  }

  bool get _nombreValido => _nombre.text.trim().length >= 2;
  bool get _fechaValida =>
      _fechaTocada && RepositorioAuth.esMayorDeEdad(_fecha);
  bool get _correoValido => _formaCorreo.hasMatch(_correo.text.trim());
  bool get _contrasenaValida => _contrasena.text.length >= 6;
  bool get _cuentaValida =>
      _correoValido && _contrasenaValida && _aceptaCondiciones;

  bool get _pasoValido => switch (_paso) {
    0 => _nombreValido,
    1 => _fechaValida,
    _ => _cuentaValida,
  };

  // ---------------------------------------------------------------------------
  // Navegacion entre pasos

  Future<void> _irA(int paso) async {
    setState(() {
      _paso = paso;
      _error = null;
    });
    // La rueda de la fecha necesita la pantalla entera; con el teclado
    // abierto quedaria aplastada debajo.
    if (paso == 1) FocusManager.instance.primaryFocus?.unfocus();

    if (MovimientoPrevia.reducido(context)) {
      _paginas.jumpToPage(paso);
    } else {
      await _paginas.animateToPage(
        paso,
        duration: _transicion,
        curve: MovimientoPrevia.curva,
      );
    }
    if (!mounted || _paso != paso) return;

    // El foco se pide al terminar de deslizar: el campo del paso nuevo no
    // existe hasta que la pagina entra, y el teclado subiendo a media
    // animacion la hace dar un tiron.
    if (paso == 0) _focoNombre.requestFocus();
    if (paso == 2 && !_correoValido) _focoCorreo.requestFocus();
  }

  void _siguiente() {
    if (!_pasoValido || _cargando) return;
    if (_paso < _pasos - 1) {
      HapticFeedback.lightImpact();
      _irA(_paso + 1);
    } else {
      _registrar();
    }
  }

  void _atras() {
    if (_cargando) return;
    if (_paso > 0) {
      _irA(_paso - 1);
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go(Rutas.bienvenida);
    }
  }

  // ---------------------------------------------------------------------------
  // Llamadas al servidor

  Future<void> _registrar() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final haySesion = await ref
          .read(repositorioAuthProvider)
          .registrar(
            correo: _correo.text,
            contrasena: _contrasena.text,
            nombre: _nombre.text,
            fechaNacimiento: _fecha,
          );
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      if (haySesion) {
        context.go(Rutas.inicio);
      } else {
        setState(() => _correoPendiente = _correo.text.trim());
      }
    } on ErrorPrevia catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Con el correo ya confirmado se entra con lo que se acaba de escribir,
  /// sin hacer teclearlo otra vez en otra pantalla.
  Future<void> _entrarTrasConfirmar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await ref
          .read(repositorioAuthProvider)
          .entrar(correo: _correo.text, contrasena: _contrasena.text);
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      context.go(Rutas.inicio);
    } on ErrorPrevia catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _reenviar() async {
    final correo = _correoPendiente;
    if (correo == null || _esperaReenvio > 0) return;
    // Supabase limita los reenvios; la cuenta atras evita que un toque
    // impaciente se gaste el cupo y acabe en un error incomprensible.
    setState(() {
      _esperaReenvio = 30;
      _error = null;
    });
    _cuentaAtras?.cancel();
    _cuentaAtras = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _esperaReenvio <= 1) t.cancel();
      if (mounted) setState(() => _esperaReenvio--);
    });
    try {
      await ref.read(repositorioAuthProvider).reenviarConfirmacion(correo);
      HapticFeedback.selectionClick();
    } on ErrorPrevia catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    }
  }

  void _corregirCorreo() {
    _cuentaAtras?.cancel();
    setState(() {
      _correoPendiente = null;
      _esperaReenvio = 0;
      _error = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focoCorreo.requestFocus();
    });
  }

  // ---------------------------------------------------------------------------
  // Interfaz

  @override
  Widget build(BuildContext context) {
    final esperandoCorreo = _correoPendiente != null;
    return PopScope(
      canPop: esperandoCorreo || (_paso == 0 && !_cargando),
      onPopInvokedWithResult: (hecho, _) {
        if (!hecho) _atras();
      },
      child: Scaffold(
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: MovimientoPrevia.normal,
            switchInCurve: MovimientoPrevia.curva,
            child: esperandoCorreo
                ? _MiraTuCorreo(
                    key: const ValueKey('correo'),
                    correo: _correoPendiente!,
                    error: _error,
                    cargando: _cargando,
                    esperaReenvio: _esperaReenvio,
                    onEntrar: _entrarTrasConfirmar,
                    onReenviar: _reenviar,
                    onCorregir: _corregirCorreo,
                  )
                : KeyedSubtree(
                    key: const ValueKey('pasos'),
                    child: _pasosDelRegistro(context),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _pasosDelRegistro(BuildContext context) {
    final c = context.colores;
    final esUltimo = _paso == _pasos - 1;

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              EspaciadoPrevia.xs,
              EspaciadoPrevia.xs,
              EspaciadoPrevia.l,
              0,
            ),
            child: Row(
              children: [
                VolverAcceso(onPressed: _atras),
                const SizedBox(width: EspaciadoPrevia.xs),
                Expanded(
                  child: Semantics(
                    label: 'Paso ${_paso + 1} de $_pasos',
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: (_paso + 1) / _pasos),
                      duration: _transicion,
                      curve: MovimientoPrevia.curva,
                      builder: (_, valor, _) => LinearProgressIndicator(
                        value: valor,
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                        color: c.primario,
                        backgroundColor: c.superficieActiva,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: EspaciadoPrevia.m),
                ExcludeSemantics(
                  child: Text(
                    '${_paso + 1}/$_pasos',
                    style: TextStyle(
                      color: c.textoTenue,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: PageView(
              controller: _paginas,
              // Solo se avanza con el boton: deslizar dejaria saltarse un
              // paso sin validarlo.
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _conFundido(0, _pasoNombre(context)),
                _conFundido(1, _pasoFecha(context)),
                _conFundido(2, _pasoCuenta(context)),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              EspaciadoPrevia.l,
              EspaciadoPrevia.s,
              EspaciadoPrevia.l,
              EspaciadoPrevia.m,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedSize(
                  duration: MovimientoPrevia.rapido,
                  curve: MovimientoPrevia.curva,
                  child: _error == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(
                            bottom: EspaciadoPrevia.s + EspaciadoPrevia.xs,
                          ),
                          child: AvisoError(_error!),
                        ),
                ),
                BotonAcceso(
                  texto: esUltimo ? 'Crear cuenta' : 'Siguiente',
                  cargando: _cargando,
                  onPressed: _pasoValido ? _siguiente : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// El `PageView` ya desliza; ademas, cada pagina se funde segun lo lejos
  /// que esta del centro, para que el paso que se va no compita con el que
  /// llega.
  Widget _conFundido(int indice, Widget pagina) => AnimatedBuilder(
    animation: _paginas,
    builder: (_, hijo) {
      final posicion = _paginas.hasClients && _paginas.position.haveDimensions
          ? _paginas.page ?? _paso.toDouble()
          : _paso.toDouble();
      final distancia = (posicion - indice).abs().clamp(0.0, 1.0);
      return Opacity(opacity: 1 - distancia, child: hijo);
    },
    child: pagina,
  );

  Widget _pasoNombre(BuildContext context) => _Paso(
    titulo: '¿Cómo te llaman?',
    bajada: 'Tu nombre o como te conoce la gente. Es lo que verán los demás.',
    children: [
      TextField(
        controller: _nombre,
        focusNode: _focoNombre,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        autofillHints: const [AutofillHints.name],
        textInputAction: TextInputAction.next,
        inputFormatters: [LengthLimitingTextInputFormatter(40)],
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        decoration: const InputDecoration(
          labelText: 'Nombre',
          hintText: 'Lucía, Dani, la Rubia…',
        ),
        // Sustituye al "pasar al siguiente campo" por defecto: aqui el
        // siguiente campo esta en otra pagina.
        onEditingComplete: _siguiente,
      ),
    ],
  );

  Widget _pasoFecha(BuildContext context) {
    final c = context.colores;
    final hoy = DateTime.now();
    final mayor = RepositorioAuth.esMayorDeEdad(_fecha);

    final Widget lectura;
    if (!_fechaTocada) {
      lectura = Text(
        'Mueve la rueda hasta tu fecha',
        key: const ValueKey('sin-tocar'),
        style: TextStyle(color: c.textoTenue, fontSize: 16),
      );
    } else if (mayor) {
      lectura = Titular(
        '${_edad(_fecha)} años',
        key: const ValueKey('edad'),
        tamano: 40,
        color: c.primarioTexto,
      );
    } else {
      lectura = Row(
        key: const ValueKey('menor'),
        children: [
          Icon(Icons.block_rounded, color: c.error, size: 20),
          const SizedBox(width: EspaciadoPrevia.s),
          Expanded(
            child: Text(
              'Previa es solo para mayores de 18 años.',
              style: TextStyle(
                color: c.error,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    return _Paso(
      titulo: '¿Cuándo naciste?',
      bajada: 'Solo guardamos tu edad. Nadie ve tu fecha de nacimiento.',
      children: [
        SizedBox(
          height: 44,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              liveRegion: true,
              child: AnimatedSwitcher(
                duration: MovimientoPrevia.rapido,
                child: lectura,
              ),
            ),
          ),
        ),
        const SizedBox(height: EspaciadoPrevia.m),
        Container(
          height: 216,
          decoration: BoxDecoration(
            color: c.superficie,
            borderRadius: BorderRadius.circular(EspaciadoPrevia.radioGrande),
          ),
          clipBehavior: Clip.antiAlias,
          // La rueda en linea y no el calendario en dialogo: para ir a 1998
          // el calendario obliga a abrir el selector de ano, buscar y
          // volver; la rueda es un solo gesto con el pulgar.
          child: CupertinoTheme(
            data: CupertinoThemeData(
              brightness: Theme.of(context).brightness,
              textTheme: CupertinoTextThemeData(
                dateTimePickerTextStyle: TextStyle(
                  color: c.texto,
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // El orden y los nombres de los meses salen de la localizacion
            // de la app (es_ES): dia, mes, ano.
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: _fecha,
              minimumDate: DateTime(hoy.year - 100),
              maximumDate: DateTime(hoy.year, hoy.month, hoy.day),
              onDateTimeChanged: (fecha) => setState(() {
                _fecha = fecha;
                _fechaTocada = true;
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _pasoCuenta(BuildContext context) {
    final c = context.colores;
    final textos = Theme.of(context).textTheme;
    final enlace = TextStyle(
      color: c.primarioTexto,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: c.primarioTexto,
    );

    Widget pegatina = const Pegatina('🔑', tamano: 48, giro: 0.25);
    if (!MovimientoPrevia.reducido(context)) {
      // Aparece al llegar al ultimo paso: un guiño de "ya casi", no un
      // adorno que este ahi desde el principio.
      pegatina = pegatina
          .animate(target: _paso == 2 ? 1 : 0)
          .fadeIn(delay: _transicion * 0.5, duration: MovimientoPrevia.rapido)
          .scaleXY(
            delay: _transicion * 0.5,
            begin: 0.6,
            end: 1,
            duration: MovimientoPrevia.normal,
            curve: Curves.easeOutBack,
          )
          .rotate(
            delay: _transicion * 0.5,
            begin: -0.04,
            end: 0,
            duration: MovimientoPrevia.normal,
            curve: MovimientoPrevia.curva,
          );
    }

    return _Paso(
      titulo: 'Última cosa',
      bajada: 'Con esto entrarás la próxima vez.',
      pegatina: pegatina,
      children: [
        TextField(
          controller: _correo,
          focusNode: _focoCorreo,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          onEditingComplete: _focoContrasena.requestFocus,
          decoration: InputDecoration(
            labelText: 'Correo',
            prefixIcon: const Icon(Icons.mail_outline_rounded),
            // Se avisa del formato solo cuando ya ha escrito algo con
            // pinta de correo a medias, no desde la primera letra.
            errorText:
                _correo.text.contains('@') &&
                    !_correoValido &&
                    !_focoCorreo.hasFocus
                ? 'Revisa el correo'
                : null,
          ),
        ),
        const SizedBox(height: EspaciadoPrevia.m),
        TextField(
          controller: _contrasena,
          focusNode: _focoContrasena,
          obscureText: _oculta,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.done,
          onEditingComplete: () {
            if (_cuentaValida) {
              _registrar();
            } else {
              // Sin cerrar el teclado la casilla de abajo queda tapada y no
              // se entiende por que el boton sigue apagado.
              FocusManager.instance.primaryFocus?.unfocus();
            }
          },
          decoration: InputDecoration(
            labelText: 'Contraseña',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            helperText: _contrasenaValida ? 'Perfecto' : 'Mínimo 6 caracteres',
            helperStyle: TextStyle(
              color: _contrasenaValida ? c.disponible : c.textoTenue,
            ),
            suffixIcon: IconButton(
              tooltip: _oculta ? 'Mostrar contraseña' : 'Ocultar contraseña',
              icon: Icon(
                _oculta
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () => setState(() => _oculta = !_oculta),
            ),
          ),
        ),
        const SizedBox(height: EspaciadoPrevia.s),

        // Consentimiento explicito y sin premarcar (RGPD, art. 7): tiene que
        // ser un gesto de la persona, no algo que haya que desmarcar.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _aceptaCondiciones,
              semanticLabel:
                  'Acepto las condiciones de uso y la política de privacidad',
              activeColor: c.primario,
              checkColor: c.sobrePrimario,
              side: BorderSide(color: c.textoTenue, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              onChanged: (v) {
                HapticFeedback.selectionClick();
                setState(() => _aceptaCondiciones = v ?? false);
              },
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _aceptaCondiciones = !_aceptaCondiciones);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Text.rich(
                    TextSpan(
                      text: 'Acepto las ',
                      children: [
                        TextSpan(
                          text: 'condiciones de uso',
                          style: enlace,
                          recognizer: _enlaceCondiciones,
                        ),
                        const TextSpan(text: ' y la '),
                        TextSpan(
                          text: 'política de privacidad',
                          style: enlace,
                          recognizer: _enlacePrivacidad,
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                    style: textos.bodyMedium?.copyWith(color: c.textoSuave),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Un paso del registro: titular grande, una frase y lo que se pregunta.
class _Paso extends StatelessWidget {
  const _Paso({
    required this.titulo,
    required this.bajada,
    required this.children,
    this.pegatina,
  });

  final String titulo;
  final String bajada;
  final List<Widget> children;
  final Widget? pegatina;

  @override
  Widget build(BuildContext context) {
    // Se mide el hueco real de la pagina y no el teclado: el Scaffold ya
    // descuenta el teclado y aqui dentro `viewInsets` siempre vale cero.
    // Con poco alto (teclado fuera en un movil pequeno) el titular encoge y
    // la frase se va, que es lo unico que no hace falta para responder.
    return LayoutBuilder(
      builder: (context, limites) =>
          _contenido(context, apretado: limites.maxHeight < 360),
    );
  }

  Widget _contenido(BuildContext context, {required bool apretado}) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        EspaciadoPrevia.l,
        apretado ? EspaciadoPrevia.m : EspaciadoPrevia.l,
        EspaciadoPrevia.l,
        EspaciadoPrevia.m,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Titular(titulo, tamano: apretado ? 34 : 42),
                ),
              ),
              if (pegatina != null) ...[
                const SizedBox(width: EspaciadoPrevia.s),
                pegatina!,
              ],
            ],
          ),
          if (!apretado) ...[
            const SizedBox(height: EspaciadoPrevia.s + EspaciadoPrevia.xs),
            Text(bajada, style: Theme.of(context).textTheme.bodyLarge),
          ],
          SizedBox(height: apretado ? EspaciadoPrevia.l : EspaciadoPrevia.xl),
          ...children,
        ],
      ),
    );
  }
}

/// Final del registro cuando Supabase pide confirmar el correo.
///
/// No es un error, es el ultimo paso: por eso tiene su propia pantalla con
/// pegatina en lugar de un aviso rojo debajo del formulario.
class _MiraTuCorreo extends StatelessWidget {
  const _MiraTuCorreo({
    super.key,
    required this.correo,
    required this.error,
    required this.cargando,
    required this.esperaReenvio,
    required this.onEntrar,
    required this.onReenviar,
    required this.onCorregir,
  });

  final String correo;
  final String? error;
  final bool cargando;
  final int esperaReenvio;
  final VoidCallback onEntrar;
  final VoidCallback onReenviar;
  final VoidCallback onCorregir;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final textos = Theme.of(context).textTheme;

    Widget pegatina = const Pegatina('📬', tamano: 88, giro: -0.15);
    if (!MovimientoPrevia.reducido(context)) {
      pegatina = pegatina
          .animate(delay: MovimientoPrevia.escalon * 3)
          .fadeIn(duration: MovimientoPrevia.rapido)
          .scaleXY(
            begin: 0.6,
            end: 1,
            duration: MovimientoPrevia.normal,
            curve: Curves.easeOutBack,
          );
    }

    return LayoutBuilder(
      builder: (context, limites) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          EspaciadoPrevia.l,
          EspaciadoPrevia.l,
          EspaciadoPrevia.l,
          EspaciadoPrevia.m,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight:
                limites.maxHeight - EspaciadoPrevia.l - EspaciadoPrevia.m,
          ),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Align(alignment: Alignment.centerLeft, child: pegatina),
                const SizedBox(height: EspaciadoPrevia.l),
                Semantics(
                  header: true,
                  child: const Titular('Mira tu correo', tamano: 48),
                ),
                const SizedBox(height: EspaciadoPrevia.m),
                Text.rich(
                  TextSpan(
                    text: 'Te hemos mandado un enlace a ',
                    children: [
                      TextSpan(
                        text: correo,
                        style: TextStyle(
                          color: c.texto,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(
                        text: '. Tócalo para activar la cuenta y vuelve aquí.',
                      ),
                    ],
                  ),
                  style: textos.bodyLarge,
                ),
                const SizedBox(height: EspaciadoPrevia.s),
                Text(
                  'Si en un par de minutos no ha llegado, mira en spam.',
                  style: textos.bodyMedium?.copyWith(color: c.textoTenue),
                ),
                const Spacer(flex: 2),
                const SizedBox(height: EspaciadoPrevia.l),
                if (error != null) ...[
                  AvisoError(error!),
                  const SizedBox(
                    height: EspaciadoPrevia.s + EspaciadoPrevia.xs,
                  ),
                ],
                BotonAcceso(
                  texto: 'Ya lo he confirmado',
                  cargando: cargando,
                  onPressed: onEntrar,
                ),
                const SizedBox(height: EspaciadoPrevia.s),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: onCorregir,
                      style: TextButton.styleFrom(
                        foregroundColor: c.textoSuave,
                        minimumSize: const Size(48, 48),
                      ),
                      child: const Text('Cambiar correo'),
                    ),
                    TextButton(
                      onPressed: esperaReenvio > 0 ? null : onReenviar,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      child: Text(
                        esperaReenvio > 0
                            ? 'Reenviado · ${esperaReenvio}s'
                            : 'Reenviar',
                        style: const TextStyle(
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
