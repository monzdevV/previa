import 'package:flutter/material.dart';

import '../../app/tema.dart';
import '../../core/entorno.dart';

/// Ajustes, con los textos legales.
///
/// El RGPD exige que la información sea inteligible y en lenguaje claro
/// (art. 12). Por eso está redactado como se habla, no como un contrato:
/// una política que nadie entiende no informa a nadie.
class PantallaAjustes extends StatelessWidget {
  const PantallaAjustes({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(EspaciadoPrevia.l),
        children: [
          _Apartado(
            titulo: 'Tu ubicación',
            icono: Icons.place_outlined,
            parrafos: [
              'Usamos tu ubicación para una sola cosa: enseñarte previas que '
                  'tengas cerca. No la guardamos en ningún sitio. Se usa para '
                  'hacer la búsqueda y se descarta.',
              'Pedimos únicamente precisión aproximada, no la exacta. Para un '
                  'radio de kilómetros sobra, y así gastamos menos batería.',
              'Si no nos das permiso, la app sigue funcionando: puedes mover '
                  'el mapa a mano y buscar por zona.',
            ],
          ),

          _Apartado(
            titulo: 'La dirección de las previas',
            icono: Icons.lock_outline,
            parrafos: [
              'Cuando publicas una previa, tu dirección exacta no la ve nadie. '
                  'En el mapa apareces dentro de un círculo de unos '
                  '${Entorno.metrosDeDifuminado} metros, desplazado al azar.',
              'Solo cuando aceptas a alguien, esa persona puede ver el punto '
                  'exacto. Y esa regla no vive en la app: vive en la base de '
                  'datos, donde no se puede saltar.',
              'El desplazamiento se calcula una sola vez y se queda fijo. Si '
                  'cambiara en cada consulta, alguien podría deducir el centro '
                  'real mirando varias veces.',
            ],
          ),

          _Apartado(
            titulo: 'Qué datos guardamos',
            icono: Icons.inventory_2_outlined,
            parrafos: [
              'Lo mínimo: tu nombre, un nombre de usuario, tu correo y tu fecha '
                  'de nacimiento. No pedimos teléfono, ni apellidos, ni '
                  'dirección postal.',
              'Tu fecha de nacimiento no la ve nadie, ni siquiera se envía a la '
                  'app de otras personas. Solo se publica tu edad en años.',
              'Las previas caducan: se cierran unas horas después de empezar y '
                  'se borran a las 48 horas. Lo único que permanece es tu '
                  'perfil y tu reputación.',
            ],
          ),

          _Apartado(
            titulo: 'Tus derechos',
            icono: Icons.gavel_outlined,
            parrafos: [
              'Puedes descargar todo lo que tenemos sobre ti desde tu perfil, '
                  'en un fichero que puedes llevarte a otro sitio.',
              'Puedes eliminar tu cuenta cuando quieras. Se borra todo: perfil, '
                  'previas, mensajes y valoraciones. No hay copia oculta.',
              'Si algo no te cuadra, puedes reclamar ante la Agencia Española '
                  'de Protección de Datos.',
            ],
          ),

          _Apartado(
            titulo: 'Solo mayores de 18',
            icono: Icons.verified_user_outlined,
            parrafos: [
              'Previa es para mayores de edad. Al registrarte se comprueba tu '
                  'fecha de nacimiento y los menores no pueden entrar.',
              'Si sospechas que alguien es menor, repórtalo: hay un motivo '
                  'específico para eso.',
            ],
          ),

          _Apartado(
            titulo: 'Convivencia',
            icono: Icons.handshake_outlined,
            parrafos: [
              'Nadie entra en una previa sin que el anfitrión lo acepte.',
              'Si bloqueas a alguien, desaparece del todo: no veis vuestras '
                  'previas, no puede pedirte plaza y no puede escribirte.',
              'Puedes reportar perfiles, previas y mensajes. Los reportes se '
                  'revisan.',
              'Previa no puede garantizar lo que pase en un encuentro '
                  'presencial. Usa la cabeza: queda con gente con reputación, '
                  'avisa a alguien de dónde vas y vete si algo no te gusta.',
            ],
          ),

          const SizedBox(height: EspaciadoPrevia.l),
          Center(
            child: Text(
              'Previa · versión 1.0.0\n'
              'Trabajo de Fin de Grado · 2º DAM',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    color: ColoresPrevia.textoTenue,
                  ),
            ),
          ),
          const SizedBox(height: EspaciadoPrevia.l),
        ],
      ),
    );
  }
}

class _Apartado extends StatelessWidget {
  const _Apartado({
    required this.titulo,
    required this.icono,
    required this.parrafos,
  });

  final String titulo;
  final IconData icono;
  final List<String> parrafos;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: EspaciadoPrevia.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 20, color: ColoresPrevia.primarioSuave),
              const SizedBox(width: EspaciadoPrevia.s),
              Expanded(child: Text(titulo, style: textos.titleLarge)),
            ],
          ),
          const SizedBox(height: EspaciadoPrevia.s),
          for (final p in parrafos)
            Padding(
              padding: const EdgeInsets.only(bottom: EspaciadoPrevia.s),
              child: Text(p, style: textos.bodyMedium?.copyWith(height: 1.5)),
            ),
        ],
      ),
    );
  }
}
