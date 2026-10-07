---
name: Previa
description: Red social de la noche. Amarillo sobre negro, titulares gordos en mayúsculas, bloques de color y las caras siempre delante.
fuente-de-verdad: lib/app/colores.dart, lib/app/tema.dart, lib/app/movimiento.dart
colors:
  oscuro:
    fondo: "#000000"
    superficie: "#0E0E0E"
    superficie-alta: "#1A1A1A"
    superficie-activa: "#262626"
    primario: "#FFE500"
    primario-texto: "#FFE500"
    secundario: "#FF9F1C"
    disponible: "#35E07F"
    sobre-primario: "#000000"
    texto: "#FFFFFF"
    texto-suave: "#B0B0B0"
    texto-tenue: "#878787"
    borde: "#262626"
    borde-campo: "#666666"
    error: "#FF4757"
    acento: "#35E07F"
    aviso: "#FF9F1C"
  claro:
    fondo: "#FFFFFF"
    superficie: "#F5F5F7"
    primario: "#FFE500"
    primario-texto: "#806500"
    disponible: "#00A055"
    texto: "#0A0A0B"
    texto-suave: "#56565E"
    texto-tenue: "#6B6B73"
    borde: "#E0E0E6"
    borde-campo: "#85858C"
    error: "#C8233A"
    acento: "#007A3D"
    aviso: "#A35400"
rounded:
  radio: 16
  radio-grande: 24
  pastilla: 999
spacing: [4, 8, 16, 24, 32, 48]
motion:
  curva: "cubic-bezier(0.22, 1, 0.36, 1)"
  rapido: 160ms
  normal: 320ms
  lento: 700ms
  escalon: 40ms
  pagina: 280ms
  pagina-vuelta: 220ms
  pulsado: 0.97
---

# Sistema visual de Previa

> Este documento describe lo que hay en el código. Si no coincide, manda el
> código: `lib/app/colores.dart`, `lib/app/tema.dart` y `lib/app/movimiento.dart`.
> La versión anterior de este fichero describía otro diseño ("callejero
> nocturno", ámbar y radio cero) que ya no existe.

## Referencias

Instagram, TikTok, BeReal y Discord. No se busca ser original: se busca estar
al nivel de lo que la gente ya tiene instalado y abre cada noche.

De ahí salen tres reglas que mandan sobre todo lo demás:

1. **La imagen ocupa el marco.** Las fotos van a sangre, 4:5, sin tarjeta alrededor.
2. **Las caras están siempre presentes.** Donde hay una persona hay un avatar, nunca solo un nombre.
3. **Todo se maneja con el pulgar**, con el móvil en una mano y a las dos de la mañana.

## Color

Negro puro de fondo, porque el contenido es imagen y cualquier gris le roba
contraste. Un solo color de marca, el amarillo `#FFE500`.

- **Sobre el amarillo, siempre negro** (`sobrePrimario`). Nunca blanco.
- **El amarillo como texto o icono usa `primarioTexto`.** En oscuro es el
  mismo amarillo; en claro es un ámbar oscuro, porque el amarillo sobre
  blanco no llega al contraste mínimo.
- **Verde `disponible`** significa "queda sitio" o "está disponible". No se usa para nada más.
- **El degradado** amarillo → naranja se reserva a la marca y a la acción principal. Nunca detrás de texto.
- **`acento` y `aviso`** son `disponible` y `secundario` en versión para
  texto e iconos, igual que `primarioTexto` lo es del amarillo. En oscuro
  coinciden; en claro son más oscuros. Los rellenos siguen usando
  `disponible` y `secundario`.
- **`borde`** es decorativo (tarjetas, separadores) y casi no se ve a
  propósito. **`bordeCampo`** es el de los controles: el contorno de los
  campos de texto y lo que no está elegido. Llega a 3:1 frente al fondo.
- La paleta es una `ThemeExtension` y se lee con `context.colores`, nunca con constantes: así existe el modo claro.

### Contraste (AA en los dos temas)

`test/contraste_tema_test.dart` fija que `texto`, `textoSuave`,
`textoTenue`, `primarioTexto`, `error`, `acento` y `aviso` pasan 4,5:1 sobre
`fondo`, `superficie` y `superficieAlta` en claro y en oscuro; que el negro
pasa sobre el amarillo y el verde; y que `bordeCampo` pasa 3:1. Para
conseguirlo se tocaron, lo mínimo, estos tokens (2026-10-01):

| Token | Antes | Ahora | Por qué |
| --- | --- | --- | --- |
| oscuro `textoTenue` | #7A7A7A | #878787 | 4,05:1 sobre `superficieAlta` |
| claro `textoTenue` | #7C7C85 | #6B6B73 | 4,1:1 incluso sobre blanco |
| claro `primarioTexto` | #8A6D00 | #806500 | 4,2:1 sobre `superficieAlta` |
| claro `error` | #D62839 | #C8233A | 4,3:1 sobre `superficieAlta` |
| claro `acento` (nuevo) | = verde #00A055 | #007A3D | el verde como texto daba 3,4:1 |
| claro `aviso` (nuevo) | = naranja #E08600 | #A35400 | el naranja como texto daba 2,8:1 |
| `bordeCampo` (nuevo) | — | #666666 / #85858C | los campos eran negro sobre negro |
| oscuro `onError` | blanco | negro | blanco sobre #FF4757 daba 3,3:1 |

## Forma

Esquinas generosas: `radio` 16 para tarjetas y campos, `radioGrande` 24 para
hojas inferiores y bloques destacados, `pastilla` para etiquetas, estados,
chips y avatares (que son círculos).

## Tipografía

Dos letras, con papeles que no se cruzan:

- **Rubik 900, en mayúsculas**, para titulares, nombres de locales, la marca
  y las etiquetas de los botones. Gorda y redondeada, a lo discoteca; la
  referencia es Nyxell. Va por el widget `Titular`, que pone las mayúsculas.
- **La del sistema** para todo lo que se lee de corrido.

Cifras tabulares (`FontFeature.tabularFigures()`) donde un número cambia
delante del usuario: likes, plazas, contadores.

## Bloques, cintas y pegatinas

- **Bloques de color plano** (`BloquesPrevia`): amarillo, menta, azul, rojo y
  lila. Cada local de la pestaña Noche es un cartel de un color, rotando.
  Encima siempre `tintaSobreBloque` (casi negro), que pasa el contraste en
  todos.
- **Marquesina**: cinta de texto en mayúsculas que corre, para rotular una
  sección. Se para si el sistema pide menos movimiento.
- **Pegatina**: un emoji grande y torcido hace de ilustración.
- La bienvenida es la única pantalla con el amarillo a sangre.

## Movimiento

Una sola curva (`MovimientoPrevia.curva`, salida exponencial) y tres
duraciones. Viene de los otros proyectos del autor, ice-gym y social-studio.

- **Entrada escalonada** en listas: aparece y sube 12 px, 40 ms entre
  elementos, y solo los seis primeros para que el scroll no se sienta lento.
- **Encoger al pulsar** (`Pulsable`, escala 0,97) con vibración ligera, en
  lugar de la onda de Material sobre fotos.
- **Cambio de pantalla** (`TransicionPrevia`, en el `pageTransitionsTheme`):
  fundido con una subida del 4 %, 280 ms de ida y 220 de vuelta, con la
  curva de la casa en las dos direcciones (nunca un arranque lento). Vale
  para las rutas de go_router y para cualquier `Navigator.push`. En iOS y
  macOS se queda la del sistema por el gesto de volver desde el borde.
- **Doble toque para dar like**, con el corazón que salta en el centro.
- **Esqueletos con brillo** en lugar de ruedas de carga donde se sabe la
  forma de lo que llega.
- **Vibraciones**: `selectionClick` al cambiar de pestaña o de estado,
  `lightImpact` en el like, `heavyImpact` cuando algo importante sale bien.
- Si el sistema pide menos movimiento (`MediaQuery.disableAnimations`), no hay animaciones.

## Tacto y foco

- **48 dp como mínimo** para todo lo que se pulsa: el tema fija
  `MaterialTapTargetSize.padded`, densidad estándar, 48 en `TextButton`,
  `IconButton` y el FAB pequeño, y 48 de alto en `PastillaCristal` y en el
  `Conmutador`.
- **Foco visible.** Con teclado, mando o acceso por interruptor, los botones
  del tema y todo lo que va por `Pulsable` pintan un contorno de 3 px en el
  color del texto (en el botón con contorno, en `primarioTexto`). No aparece
  al tocar con el dedo. `Pulsable` además responde a Intro y Espacio.

## Emojis

Sí, con medida. El minijuego se llama **No hay 🥚** y el huevo es la gracia
del nombre. Es un solo juego con dos momentos, en un solo módulo
(`lib/features/juegos/`): en la previa, cartas que pasan de mano en mano
(hub de juegos, `/juegos`); en el local, el sticker de la sala da un reto con
alguien que está allí y se cumple con foto. Cada uno remite al otro. Fuera del juego, los emojis los pone la gente, no la interfaz.

## Componentes con carácter propio

- **Sticker de No hay 🥚.** Pastilla amarilla con borde blanco grueso,
  inclinada y con sombra: tiene que parecer un sticker pegado encima del
  chat, no un botón más. Se menea cada pocos segundos.
- **Ficha del objetivo de un reto.** Avatar de 120 px con anillo amarillo,
  nombre, usuario y biografía. En un local lleno el nombre solo no sirve
  para encontrar a nadie.
- **Barra inferior.** Cápsula de vidrio flotante con cinco pestañas con
  etiqueta corta. En el centro, un disco amarillo con la pregunta escrita,
  "¿VAS?": es el único amarillo de la barra. La pestaña "Tú" lleva tu cara.
- **Una acción arriba.** Cada pestaña tiene como mucho un control en la
  cabecera: el "+" de crear, buscar gente, el engranaje, la ciudad o la
  pastilla de filtros del mapa.
- **Vidrio** (`Cristal`, `BotonCristal`, `PastillaCristal` en
  `lib/app/cristal.dart`). Solo para lo que flota sobre foto o mapa: la
  barra, los controles del mapa y sus tarjetas. Sobre el fondo negro no
  aporta nada. Con "más contraste" en el sistema se vuelve opaco.
- **Hojas.** Todas se abren con `mostrarHoja`: mismo asa, misma forma, zona
  segura respetada.
- **Caras.** `AvatarPerfil` sin foto toma el bloque de color de esa persona
  con la inicial en Rubik; `PilaDeCaras` solapa caras para decir "va gente"
  antes de leer un número.
- **¿Vas?** Cada local es un cartel de color con el nombre enorme, las caras
  de quien va y la pastilla "¿VAS?". Al apuntarte salta una pegatina y tu
  cara entra en la pila; en los locales a los que vas se pega el sticker de
  No hay 🥚, como un sello.
- **Calendario social.** Mes en rejilla que empieza en lunes; cada noche es
  su foto (o el bloque del sitio con su inicial). Se desliza de mes en mes y
  cada día abre su noche en una hoja.
- **Conmutador.** Pastillas con un fondo amarillo que se desliza a la
  elegida (buzón, fotos del perfil).
- **Estados vacíos.** `EstadoVacio`: pegatina, titular y, si hay algo que
  hacer, el botón que lo hace. `Cargando` para cuando no se sabe la forma.
- **Avisos flotantes.** `SnackBar` flotante con borde y radio 16, separado del filo.

## Privacidad visible

En el mapa las previas son **círculos, nunca chinchetas**: las coordenadas
que llegan al cliente están desplazadas unos 300 m y solo un círculo dice la
verdad sobre el área. La dirección exacta solo aparece a quien tiene derecho
a verla, y eso lo decide la base de datos.
