import 'package:flutter/material.dart';

import '../../app/tema.dart';
import '../../core/entorno.dart';

/// Datos del responsable del tratamiento.
///
/// Van aqui y no repartidos por el texto para que solo haya que tocarlos en
/// un sitio cuando el proyecto tenga titular real. Hasta entonces se enseñan
/// como lo que son: pendientes de rellenar.
abstract final class Titular {
  static const nombre = '[Nombre y apellidos del titular]';
  static const contacto = '[correo de contacto]';
  static const version = 'Versión 1.0 · septiembre de 2026';
}

/// Politica de privacidad.
class PantallaPrivacidad extends StatelessWidget {
  const PantallaPrivacidad({super.key});

  @override
  Widget build(BuildContext context) => const _Documento(
    titulo: 'Política de privacidad',
    apartados: [
      _Apartado('Quién trata tus datos', [
        'El responsable del tratamiento es ${Titular.nombre}, a quien puedes '
            'escribir en ${Titular.contacto}.',
        'Previa es un Trabajo de Fin de Grado. No hay empresa detrás ni '
            'ánimo de lucro, y eso no reduce tus derechos: esta política se '
            'aplica igual.',
      ]),
      _Apartado('Qué datos recogemos y para qué', [
        'Para crear la cuenta: tu correo, un nombre de usuario, el nombre '
            'que quieras mostrar y tu fecha de nacimiento. El correo sirve '
            'para identificarte y recuperar la cuenta; la fecha de '
            'nacimiento, únicamente para comprobar que eres mayor de edad.',
        'Si los rellenas: tu foto de perfil, una descripción, tu ciudad y tu '
            'usuario de Instagram. Los cuatro son opcionales y públicos para '
            'el resto de personas usuarias.',
        'Cuando publicas: las fotos o vídeos que subes, su texto y la zona '
            'que indiques. Cuando organizas o pides plaza en una previa: su '
            'título, descripción, hora, plazas y ubicación.',
        'Tu ubicación del dispositivo se usa en el momento para buscar '
            'previas cerca y no se almacena.',
      ]),
      _Apartado('Base legal', [
        'Tratamos los datos de la cuenta porque son necesarios para '
            'prestarte el servicio que has pedido, es decir, para ejecutar '
            'el contrato entre tú y Previa.',
        'Los datos opcionales del perfil y tus publicaciones se tratan con '
            'tu consentimiento, que puedes retirar en cualquier momento '
            'borrándolos.',
        'La comprobación de mayoría de edad responde a una obligación legal '
            'y a un interés legítimo evidente: la aplicación organiza '
            'encuentros relacionados con el ocio nocturno.',
      ]),
      _Apartado('Tu ubicación exacta', [
        'Si organizas una previa en una vivienda, tu dirección exacta no la '
            've nadie. En el mapa apareces dentro de un círculo de unos '
            '${Entorno.metrosDeDifuminado} metros desplazado al azar.',
        'La dirección exacta solo se entrega a quien tú aceptas, y esa regla '
            'se aplica en la base de datos, no en la aplicación. Ni siquiera '
            'una versión modificada de la app podría saltársela.',
        'Si marcas la previa como celebrada en un sitio público, la '
            'ubicación deja de ocultarse. Es una decisión tuya y se te avisa '
            'al crearla.',
      ]),
      _Apartado('Quién más ve tus datos', [
        'El resto de personas usuarias ven tu perfil público, tus '
            'publicaciones y las previas que organizas.',
        'Los datos se alojan en Supabase, que actúa como encargado del '
            'tratamiento, con servidores en la Unión Europea.',
        'Los mapas se sirven desde OpenStreetMap y CARTO. Al cargar el mapa, '
            'tu dirección IP llega a esos proveedores, como en cualquier web '
            'con mapas.',
        'No vendemos tus datos ni los cedemos con fines publicitarios.',
      ]),
      _Apartado('Cuánto tiempo los guardamos', [
        'Las previas se cierran unas horas después de empezar y se eliminan '
            'a las 48 horas.',
        'Tu perfil, tus publicaciones y tu reputación se conservan mientras '
            'tengas la cuenta abierta.',
        'Si eliminas la cuenta, se borra todo lo asociado a ella. Los '
            'mensajes que enviaste a otras personas pueden permanecer en sus '
            'conversaciones sin quedar ya vinculados a tu perfil.',
      ]),
      _Apartado('Tus derechos', [
        'Puedes acceder a tus datos, rectificarlos, suprimirlos, oponerte al '
            'tratamiento, limitarlo y pedir su portabilidad.',
        'Desde tu perfil puedes descargarlo todo en un fichero y eliminar la '
            'cuenta, sin tener que escribir a nadie ni esperar.',
        'Si crees que no hemos hecho las cosas bien, puedes reclamar ante la '
            'Agencia Española de Protección de Datos.',
      ]),
      _Apartado('Menores', [
        'Previa es solo para mayores de 18 años. Comprobamos la edad en el '
            'registro y cerramos las cuentas de quien no cumpla el requisito '
            'en cuanto lo detectamos.',
      ]),
      _Apartado('Datos de demostración', [
        'Mientras el proyecto está en desarrollo existen perfiles y '
            'publicaciones de ejemplo, marcados internamente como tales. No '
            'corresponden a personas reales y sus imágenes proceden de '
            'servicios públicos de fotografías de relleno.',
      ]),
    ],
  );
}

/// Condiciones de uso.
class PantallaCondiciones extends StatelessWidget {
  const PantallaCondiciones({super.key});

  @override
  Widget build(BuildContext context) => const _Documento(
    titulo: 'Condiciones de uso',
    apartados: [
      _Apartado('Qué es Previa', [
        'Previa es una aplicación que pone en contacto a personas que '
            'organizan un plan antes de salir con personas que buscan uno.',
        'Previa no organiza los planes, no está presente en ellos y no '
            'interviene en lo que ocurra. Solo facilita el contacto.',
      ]),
      _Apartado('Quién puede usarla', [
        'Tienes que ser mayor de 18 años. Al registrarte declaras que lo '
            'eres, y si se comprueba que no, la cuenta se cierra.',
        'Los datos que facilites deben ser veraces. Suplantar a otra persona '
            'es motivo de cierre inmediato.',
        'Tu cuenta es personal. Eres responsable de lo que se haga desde '
            'ella.',
      ]),
      _Apartado('Lo que no se puede hacer', [
        'Publicar contenido que acose, amenace, humille o discrimine a '
            'alguien.',
        'Publicar imágenes o vídeos de otras personas sin su permiso, ni '
            'contenido sexual, violento o que muestre delitos.',
        'Usar Previa para vender, promocionar o distribuir sustancias '
            'ilegales, ni para ninguna otra actividad contraria a la ley.',
        'Recopilar datos de otras personas usuarias, automatizar el acceso o '
            'intentar saltarse las medidas de seguridad, muy especialmente '
            'las que protegen la ubicación.',
      ]),
      _Apartado('Encuentros en persona', [
        'Esto es lo más importante de este documento. Previa te pone en '
            'contacto con desconocidos y los planes ocurren en domicilios '
            'particulares y en la vía pública.',
        'Comprueba con quién quedas, avisa a alguien de confianza de dónde '
            'vas, y márchate si algo no te encaja. La valoración y la '
            'reputación ayudan, pero no garantizan nada.',
        'Previa no responde de lo que suceda durante un encuentro. Quien '
            'organiza un plan es responsable del espacio en el que lo '
            'celebra y de cumplir las normas que le apliquen.',
      ]),
      _Apartado('Tu contenido', [
        'Lo que publicas sigue siendo tuyo. Al subirlo nos autorizas a '
            'mostrarlo dentro de la aplicación, que es lo justo para que el '
            'servicio funcione.',
        'Puedes borrar tus publicaciones cuando quieras.',
        'Podemos retirar contenido que incumpla estas condiciones o que nos '
            'sea reportado con motivo.',
      ]),
      _Apartado('Locales y entradas', [
        'La información de discotecas, bares y salas es orientativa y puede '
            'estar desactualizada o haber sido añadida por otras personas '
            'usuarias.',
        'Cuando enlazamos a una página de venta de entradas, la compra se '
            'hace fuera de Previa y se rige por las condiciones de quien '
            'venda. Previa no vende entradas ni responde de esa compra.',
        'Que alguien aparezca como asistente a un local significa solo que '
            'lo ha indicado en la aplicación.',
      ]),
      _Apartado('Suspensión y cierre', [
        'Podemos suspender o cerrar una cuenta que incumpla estas '
            'condiciones, avisando siempre que sea posible.',
        'Puedes cerrar la tuya cuando quieras desde tu perfil.',
      ]),
      _Apartado('Cambios y ley aplicable', [
        'Si cambiamos estas condiciones te avisaremos dentro de la '
            'aplicación antes de que se apliquen.',
        'Se rigen por la legislación española.',
      ]),
    ],
  );
}

class _Apartado {
  const _Apartado(this.titulo, this.parrafos);

  final String titulo;
  final List<String> parrafos;
}

class _Documento extends StatelessWidget {
  const _Documento({required this.titulo, required this.apartados});

  final String titulo;
  final List<_Apartado> apartados;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          EspaciadoPrevia.l,
          EspaciadoPrevia.s,
          EspaciadoPrevia.l,
          EspaciadoPrevia.xxl,
        ),
        children: [
          Text(
            Titular.version,
            style: textos.labelMedium?.copyWith(
              color: context.colores.textoTenue,
            ),
          ),
          const SizedBox(height: EspaciadoPrevia.l),

          for (final apartado in apartados) ...[
            Text(apartado.titulo, style: textos.titleLarge),
            const SizedBox(height: EspaciadoPrevia.s),
            for (final parrafo in apartado.parrafos) ...[
              Text(
                parrafo,
                style: textos.bodyLarge?.copyWith(
                  color: context.colores.textoSuave,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: EspaciadoPrevia.s + EspaciadoPrevia.xs),
            ],
            const SizedBox(height: EspaciadoPrevia.m),
          ],

          const _NotaDeRevision(),
        ],
      ),
    );
  }
}

/// Aviso honesto: esto lo ha redactado quien programa, no quien firma.
class _NotaDeRevision extends StatelessWidget {
  const _NotaDeRevision();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(EspaciadoPrevia.m),
    decoration: BoxDecoration(
      color: context.colores.superficie,
      borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
      border: Border.all(color: context.colores.borde),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 20,
          color: context.colores.textoTenue,
        ),
        const SizedBox(width: EspaciadoPrevia.s + EspaciadoPrevia.xs),
        Expanded(
          child: Text(
            'Documento redactado para un proyecto académico y pendiente de '
            'revisión jurídica. Antes de abrir la aplicación al público hay '
            'que completar los datos del titular y que lo revise alguien con '
            'formación legal.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );
}
