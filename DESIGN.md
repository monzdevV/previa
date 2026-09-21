---
name: Previa
description: Callejero nocturno impreso: índice de renglones, retícula de celdas y un solo ámbar para lo que está vivo ahora.
colors:
  fondo: "#0E1619"
  fondo-profundo: "#070D0F"
  superficie: "#162226"
  superficie-alta: "#1E2E32"
  superficie-activa: "#27383C"
  ambar-sodio: "#E8A33D"
  ambar-suave: "#F2C27E"
  letra-mapa: "#E8E4D9"
  letra-suave: "#9AA6A1"
  letra-tenue: "#7E8C87"
  filete: "#2E3E3A"
  error: "#E05B44"
typography:
  display:
    fontFamily: "Archivo Narrow, sans-serif-condensed"
    fontSize: "42px"
    fontWeight: 700
    lineHeight: 1.0
    letterSpacing: "-0.8px"
    fontFeature: "tnum"
  headline:
    fontFamily: "Archivo Narrow, sans-serif-condensed"
    fontSize: "30px"
    fontWeight: 700
    lineHeight: 1.06
    letterSpacing: "-0.4px"
    fontFeature: "tnum"
  title:
    fontFamily: "Archivo Narrow, sans-serif-condensed"
    fontSize: "19px"
    fontWeight: 600
    lineHeight: 1.18
    letterSpacing: "normal"
  title-small:
    fontFamily: "Archivo Narrow, sans-serif-condensed"
    fontSize: "16px"
    fontWeight: 600
    letterSpacing: "normal"
  body:
    fontFamily: "system-ui"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.45
  body-small:
    fontFamily: "system-ui"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.45
  label:
    fontFamily: "Archivo Narrow, sans-serif-condensed"
    fontSize: "15px"
    fontWeight: 600
    letterSpacing: "0.6px"
  label-mapa:
    fontFamily: "Archivo Narrow, sans-serif-condensed"
    fontSize: "11px"
    fontWeight: 500
    letterSpacing: "1.2px"
rounded:
  radio: "0px"
  radio-grande: "0px"
spacing:
  xs: "4px"
  s: "8px"
  m: "16px"
  l: "24px"
  xl: "32px"
  xxl: "48px"
components:
  boton-primario:
    backgroundColor: "{colors.ambar-sodio}"
    textColor: "{colors.fondo-profundo}"
    typography: "{typography.label}"
    rounded: "{rounded.radio}"
    padding: "0 24px"
    height: "52px"
  boton-primario-desactivado:
    backgroundColor: "{colors.superficie-activa}"
    textColor: "{colors.letra-tenue}"
    rounded: "{rounded.radio}"
    height: "52px"
  boton-contorno:
    backgroundColor: "transparent"
    textColor: "{colors.letra-mapa}"
    typography: "{typography.label}"
    rounded: "{rounded.radio}"
    height: "52px"
  boton-texto:
    backgroundColor: "transparent"
    textColor: "{colors.letra-mapa}"
    rounded: "{rounded.radio}"
  campo-texto:
    backgroundColor: "{colors.superficie}"
    textColor: "{colors.letra-mapa}"
    rounded: "{rounded.radio}"
    padding: "16px"
  campo-texto-foco:
    backgroundColor: "{colors.superficie}"
    textColor: "{colors.letra-mapa}"
    rounded: "{rounded.radio}"
  ficha-filtro:
    backgroundColor: "transparent"
    textColor: "{colors.letra-mapa}"
    rounded: "{rounded.radio}"
  ficha-filtro-activa:
    backgroundColor: "{colors.superficie-activa}"
    textColor: "{colors.letra-mapa}"
    rounded: "{rounded.radio}"
  renglon-indice:
    backgroundColor: "{colors.fondo}"
    textColor: "{colors.letra-mapa}"
    rounded: "{rounded.radio}"
    padding: "16px"
  renglon-indice-agotado:
    backgroundColor: "{colors.fondo}"
    textColor: "{colors.letra-tenue}"
    rounded: "{rounded.radio}"
    padding: "16px"
  placa-plazas:
    backgroundColor: "{colors.ambar-sodio}"
    textColor: "{colors.fondo-profundo}"
    rounded: "{rounded.radio}"
    size: "30px"
  placa-plazas-completa:
    backgroundColor: "{colors.superficie}"
    textColor: "{colors.letra-tenue}"
    rounded: "{rounded.radio}"
    size: "30px"
  boton-mapa:
    backgroundColor: "{colors.superficie}"
    textColor: "{colors.letra-mapa}"
    rounded: "{rounded.radio}"
    size: "48px"
  boton-mapa-activo:
    backgroundColor: "{colors.ambar-sodio}"
    textColor: "{colors.fondo-profundo}"
    rounded: "{rounded.radio}"
    size: "48px"
  barra-navegacion:
    backgroundColor: "{colors.fondo-profundo}"
    textColor: "{colors.letra-tenue}"
    rounded: "{rounded.radio}"
  barra-navegacion-activa:
    backgroundColor: "{colors.superficie-activa}"
    textColor: "{colors.letra-mapa}"
    rounded: "{rounded.radio}"
---

# Design System: Previa

## Overview

**Creative North Star: "El callejero plegable y su índice de calles"**

Previa no dibuja la noche: la indexa. Un callejero impreso nunca enseña un portal, enseña la celda de cuadrícula donde cae ese portal, y esa es exactamente la regla de privacidad del producto. El mundo visual y la restricción técnica dicen lo mismo, así que la interfaz puede explicar la privacidad sin un párrafo legal: se ve la celda, no la puerta.

La pantalla la manda el índice, no el mapa. Cada previa es un renglón —nombre a la izquierda, puntos conductores cruzando el ancho, hora en condensada tabular cerrando la línea, y debajo la referencia de cuadrícula con la distancia—, y los renglones se encadenan con filetes a sangre en lugar de encerrarse en tarjetas, porque encajonar cada previa rompe la lectura vertical que hace instantánea la comparación. El mapa vive detrás como lámina plegada y sube con el pulgar por detentes. Sobre la carta acromática tinta-pizarra solo hay una tinta viva, un ámbar de vapor de sodio, y solo aparece donde significa algo: lo que está disponible ahora y la acción que compromete.

Se rechaza explícitamente el reparto por defecto de la categoría —mapa de chinchetas arriba, feed de tarjetas redondeadas debajo— y se rechaza el registro festivo: nada infantil, nada de emojis, nada de confeti. La densidad es alta y la temperatura baja; el objetivo declarado es una decisión de un vistazo a las dos de la mañana, con el móvil a una mano.

**Key Characteristics:**
- Radio cero real en toda la interfaz; nada redondo, ni siquiera el avatar del anfitrión.
- Carta acromática con un solo color vivo, el ámbar de vapor de sodio.
- Índice de renglones con puntos conductores y filetes, no rejilla de tarjetas.
- Estados como marcas impresas: filete en reposo, macizo al estar vivo, tachado si está agotado.
- Referencia de cuadrícula donde iría una dirección, derivada siempre de la posición ya difuminada.
- Condensada con cifras tabulares para display, rótulos y números; cuerpo en la cara del sistema.

## Colors

Paleta de carta nocturna: cinco grises verdosos de papel-pizarra, tres niveles de letra de mapa, un filete y una única tinta viva.

### Primary
- **Ámbar de vapor de sodio** (`{colors.ambar-sodio}`): la única tinta viva del sistema. Marca lo que está disponible ahora (marca de plazas, placa de plazas sobre el mapa, celda teñida de una previa) y la acción que compromete (botón primario relleno, botón de filtro con filtros puestos, ancla "ABRIR PREVIA"). Nunca decora.
- **Ámbar apagado** (`{colors.ambar-suave}`): contorno del círculo de la previa en la ficha de detalle, donde el ámbar pleno cerraría demasiado la mancha sobre las teselas.

### Neutral
- **Carta** (`{colors.fondo}`): fondo de toda la aplicación y del hueco del mapa mientras no llegan las teselas —el blanco de carga deslumbra en una app que se abre de noche.
- **Carta profunda** (`{colors.fondo-profundo}`): barra de navegación, pantalla de bienvenida y texto sobre ámbar.
- **Celda** (`{colors.superficie}`): superficie de paneles, campos de texto, placas del mapa y la ficha de dirección retenida.
- **Celda alta** (`{colors.superficie-alta}`): realce al pulsar un renglón, avatar cuadrado del anfitrión, snackbar.
- **Celda teñida** (`{colors.superficie-activa}`): la pestaña activa de navegación, la ficha de filtro seleccionada y las barras de la dirección censurada. Es el mismo gesto con el que el mapa marca la zona que estás mirando.
- **Letra de mapa** (`{colors.letra-mapa}`): primer nivel de texto, navegación activa, contorno de la lámina y de la celda resaltada.
- **Letra suave** (`{colors.letra-suave}`): datos secundarios, valoraciones, estados pendientes, rótulos de mapa.
- **Letra tenue** (`{colors.letra-tenue}`): renglón agotado, etiquetas de ambiente, puntos conductores (al 65 %), pestaña inactiva.
- **Filete** (`{colors.filete}`): línea impresa de 1 px que separa bandas de información en lugar de encerrarlas. Es el borde de todo: campos, fichas, paneles, divisores.
- **Error** (`{colors.error}`): solo borde y texto de fallo de formulario.

### Named Rules
**La regla del único ámbar.** El ámbar está reservado a dos cosas: hay sitio ahora, o pulsa esto y te comprometes. Nada más se pinta de ámbar. El aviso, la reputación, el estado pendiente, tu propia posición en el mapa y el radio de búsqueda son letra de mapa a propósito: gastar el ámbar en ellos hace que deje de responder a "¿queda sitio?".

**La regla de la celda teñida.** Lo activo no estrena color: sube de tinta sobre el mismo gris. La pestaña seleccionada, la previa resaltada y la ficha de filtro puesta se distinguen subiendo de superficie o encorchetándose en letra de mapa, nunca coloreándose.

## Typography

**Display Font:** Archivo Narrow, empaquetada en el proyecto en 500, 600 y 700 (fallback: condensada del sistema).
**Body Font:** la cara del sistema (San Francisco en iOS, Roboto en Android), sin declarar familia.
**Label Font:** Archivo Narrow en caja alta y muy espaciada para el rótulo de mapa.

**Character:** una grotesca condensada de rótulo callejero contra la voz neutra de la plataforma. La condensada da la mancha de tinta y la autoridad de plano impreso; el cuerpo en la cara del sistema es lo que exige la guía de plataforma y lo que sobrevive a "letra grande" sin romper el renglón.

### Hierarchy
- **Display** (700, 42 px, interlínea 1.0, tabulares): el titular de bienvenida. Una vez por pantalla como mucho.
- **Headline** (700, 30 px, tabulares): la hora del renglón —bajada a 26 px en el índice—, que es la mayor mancha de tinta de la línea.
- **Title** (600, 19 px): nombre de la previa, encabezados de sección, título de barra superior (21 px).
- **Title-small** (600, 16 px): subtítulos dentro de fichas.
- **Body** (400, 16 px, interlínea 1.45): texto corrido, descripciones largas, explicaciones de privacidad.
- **Body-small** (400, 14 px, letra suave): descripción del renglón, notas al pie de ficha.
- **Label** (600, 15 px, +0.6): texto de botón, siempre en mayúsculas escritas en el copy.
- **Label-mapa** (500, 11 px, +1.2, caja alta): referencia de cuadrícula, distancia, ambiente, "RETENIDA", resumen del mapa. Es el rótulo impreso sobre el plano.

### Named Rules
**La regla de la condensada reservada.** La condensada entra en display, rótulos y cifras. El cuerpo se queda en la cara del sistema. Un párrafo en condensada convierte la app en un cartel y pierde el soporte de accesibilidad de la plataforma.

**La regla de las cifras tabulares.** Horas, plazas y capacidades llevan `tabularFigures`. Se leen en columna y no pueden bailar de ancho al cambiar de dígito.

**La regla de la hora dominante.** En un renglón la hora es la mayor mancha de tinta, por encima del nombre. Lo que falta para empezar no se repite en el renglón: decirlo dos veces roba el ancho que necesita la referencia de cuadrícula cuando el sistema agranda la letra.

## Layout

El ritmo es una escala de 4: `{spacing.xs}` 4, `{spacing.s}` 8, `{spacing.m}` 16, `{spacing.l}` 24, `{spacing.xl}` 32, `{spacing.xxl}` 48. El acolchado estándar de renglón y de ficha es 16; los márgenes de pantalla completa (bienvenida, formularios) son 24.

El modelo espacial es el índice: una columna única de renglones a sangre, separados por un filete de 1 px que llega de borde a borde. No hay canaletas laterales ni tarjetas flotando sobre un fondo; el filete es la única estructura.

Sobre el mapa, el índice vive en una lámina arrastrable con tres detentes reales (0,16 / 0,66 / 0,94, con arranque en 0,66 y ajuste por salto). No hay posiciones intermedias: un plano se dobla por su raya, y una lámina a medias arrastrada con prisa y a una mano es una lámina inservible. La barra superior del mapa (resumen + dos botones cuadrados de 48) flota dentro del área segura; la acción primaria se ancla al borde inferior, al alcance del pulgar, y no flota sobre la lámina para no taparla nunca.

La retícula del mapa dibuja exactamente las celdas que nombra la referencia del índice (0,0047° de ancho por 0,0036° de alto, unos 400 m), en letra de mapa al 10 %, y desaparece por debajo de zoom 12,5, donde deja de orientar y se vuelve trama. La lámina de bienvenida usa la misma gramática a 7×7 celdas y baja de 280 a 230 px de alto por debajo de 520 px de ancho.

## Elevation & Depth

No hay sombras en ningún sitio. Cada tema de componente lleva `elevation: 0` y `surfaceTintColor` transparente; la profundidad es tonal y se consigue subiendo de superficie sobre la carta (`{colors.superficie}` → `{colors.superficie-alta}` → `{colors.superficie-activa}`) o cambiando el peso del filete. Lo que en otros sistemas sería una sombra, aquí es un filete: la lámina del índice se separa del mapa con una línea de letra de mapa en su borde superior, no con un desenfoque.

La única "luz" del sistema es el encendido escalonado de las celdas vivas en la lámina de bienvenida (1600 ms, `easeOutExpo`, cada celda con retardo propio, de alfa 0,20 a 0,90). Arranca desde un estado ya legible y respeta `disableAnimations`: con las animaciones del sistema apagadas la lámina se ve completa.

### Named Rules
**La regla del plano sin sombra.** Ninguna superficie proyecta sombra. Si algo tiene que separarse de lo que hay debajo, se separa con un filete de 1 px o subiendo un escalón de superficie.

**La regla del dato impreso.** Nada brilla sobre el mapa. Una marca con halo se lee como un efecto; lo que hace falta es que se lea como un dato impreso encima.

## Shapes

Radio cero de verdad: `{rounded.radio}` y `{rounded.radio-grande}` valen ambos 0. En cartografía impresa nada es redondo, y en cuanto una esquina se ablanda vuelve la tarjeta y el mundo se cae. La consecuencia se lleva hasta el final: el avatar del anfitrión es un cuadrado de 22 px con inicial, la placa de plazas del mapa es un cuadrado de 30 px, el indicador de pestaña activa es un rectángulo a sangre y no una pastilla.

La única excepción de forma es cartográfica y está justificada: sobre el mapa, una previa se dibuja como **círculo** y nunca como celda cuadrada ni como chincheta. El servidor solo entrega una posición difuminada por un radio de ~300 m; una chincheta diría "esta casa exactamente" y mentiría, y un cuadrado mentiría sobre la forma del área. El círculo es honesto y explica sin texto por qué no se ve el portal.

El resto del vocabulario de forma es de imprenta: filete de 1 px, línea de puntos conductores de radio 1 cada 6 px, marca de pliegue discontinua (guión 6 / hueco 5) con el centro reforzado en 2 px donde agarra el pulgar, y barras macizas de censura para lo retenido.

## Components

### Buttons
- **Shape:** rectángulo exacto, sin radio (0 px). Altura mínima 52 px en primario y contorno.
- **Primario (relleno):** ámbar macizo sobre texto en carta profunda, condensada 700 a +0,6, acolchado horizontal 24. Es la acción que compromete; una por pantalla.
- **Desactivado:** celda teñida con letra tenue. No se apaga el ámbar, se sustituye.
- **Contorno (secundario):** transparente, filete de 1 px, texto en letra de mapa, condensada 600.
- **Texto (terciario):** un enlace secundario no estrena el ámbar. Va subrayado en color de filete, como la referencia cruzada de un índice.
- **Pulsación:** `InkSparkle` con destello ámbar al 10 % y realce en celda alta. No hay transformación ni compresión.

### Chips
- **Style:** fondo transparente, filete de 1 px, rótulo condensado 600 a 13 px. Esquinas rectas.
- **State:** seleccionada = celda teñida de fondo, mismo filete, mismo texto. La selección sube de tinta, no de color.

### Cards / Containers
- **Corner Style:** recto (0 px).
- **Background:** celda (`{colors.superficie}`) sobre carta.
- **Shadow Strategy:** ninguna; ver Elevation & Depth.
- **Border:** filete de 1 px en todo el contorno. En listados no hay contenedor: solo un divisor a sangre entre renglones.
- **Internal Padding:** 16.

### Inputs / Fields
- **Style:** relleno en celda, filete de 1 px, sin radio, acolchado 16 en ambos ejes. Placeholder en letra tenue, etiqueta en letra suave, iconos afijos en letra suave.
- **Focus:** el filete sube a 2 px y se pinta de ámbar. Es la única vez que el ámbar aparece sin haber sitio ni haber acción: aquí marca dónde está escribiendo el dedo.
- **Error:** filete en rojo de error (1 px; 2 px con el foco puesto).

### Navigation
- Barra inferior sobre carta profunda. Pestaña activa: celda teñida rectangular a modo de indicador, icono y rótulo en letra de mapa (11 px, 600, +1,0); inactiva en letra tenue. La barra superior es transparente, sin elevación, alineada a la izquierda, con título en condensada 600 a 21 px.

### Renglón de índice (componente firma)
El componente que define el sistema. Un renglón, nunca una tarjeta.

- **Línea 1:** nombre en título 600 a 19 px · puntos conductores (radio 1, paso 6, letra tenue al 65 %, dibujados de derecha a izquierda para que el último punto quede pegado a la hora) · hora en condensada 700 a 26 px con tabulares, alineada a la línea base del nombre.
- **Línea 2:** localizador en rótulo de mapa —`ZONA + referencia de cuadrícula · distancia`, todo en caja alta, hasta dos líneas para que la referencia no se corte con la letra del sistema agrandada— y, cerrando el renglón, la marca de ocupación.
- **Marca de ocupación:** una barra de 22×10 más un rótulo. `abierta` = rectángulo macizo de ámbar + "N PLAZAS"; `llenándose` (≤2 libres) = rectángulo en filete con el 35 % izquierdo macizo; `completa` = rectángulo en filete tachado en diagonal, todo en letra tenue y el rótulo "COMPLETA" con línea de tachado. La ocupación es una condición visible, no un número: a las dos de la mañana nadie compara cifras.
- **Renglón agotado:** nombre y hora bajan a letra tenue. El renglón sigue ahí, apagado.
- **Pie:** avatar cuadrado de 22 px con la inicial sobre celda alta, nombre del anfitrión en cuerpo pequeño, y reputación siempre como `4,8/5` —un número suelto al lado de un nombre no se sabe si son estrellas, euros o veces.
- **Variante compacta:** oculta la descripción; caben tres o cuatro previas de golpe, y la tarea es comparar varias.

### Dirección retenida
El vocabulario de lo retenido. Panel en celda con filete, rótulo "DIRECCIÓN EXACTA" a la izquierda y "RETENIDA" en letra tenue a la derecha, y debajo cinco barras macizas en celda teñida (anchos fijos 96/54/128/38/72, alto 13) que censuran el renglón. Las barras son un patrón fijo y no derivan de la dirección real: el cliente nunca llega a recibirla, así que aquí no hay nada que filtrar, ni siquiera su longitud. Debajo sí se dice lo que se puede decir: `CELDA <referencia> · ZONA`. El dato se dibuja tachado en lugar de omitirse porque no es lo mismo que un dato no exista a que exista y todavía no te corresponda.

### Lámina del callejero
La retícula del mapa, la lámina de bienvenida y la marca de pliegue comparten gramática. La marca de pliegue (22 px de alto, discontinua, centro reforzado) sustituye la agarradera genérica de hoja inferior: en un plano, por donde se dobla hay una raya, y esa raya es justamente por donde se agarra.

## Do's and Don'ts

### Do:
- **Do** poner a cero cualquier radio nuevo: `{rounded.radio}` y `{rounded.radio-grande}` valen 0 y el valor no se negocia por componente.
- **Do** reservar el ámbar `{colors.ambar-sodio}` a lo disponible ahora y a la acción que compromete; para lo demás hay tres niveles de letra de mapa.
- **Do** encadenar listados con un divisor a sangre y renglones de acolchado 16, no con tarjetas.
- **Do** usar cifras tabulares en cualquier hora, plaza o capacidad.
- **Do** expresar los estados como marcas impresas: filete en reposo, macizo si está vivo, tachado si está agotado.
- **Do** derivar toda referencia de cuadrícula de la posición ya difuminada, y dibujar en el mapa exactamente esas mismas celdas.
- **Do** dejar la condensada para display, rótulos y cifras, y el cuerpo en la cara del sistema.
- **Do** probar cada pantalla con la letra del sistema agrandada: el localizador admite dos líneas precisamente por eso.

### Don't:
- **Don't** redondear nada, ni siquiera avatares, indicadores de pestaña o placas del mapa.
- **Don't** añadir sombras, halos ni desenfoques; la profundidad es tonal y el separador es un filete de 1 px.
- **Don't** marcar una previa del mapa con una chincheta ni con una celda cuadrada: el difuminado del servidor es un radio y solo el círculo dice la verdad sobre el área.
- **Don't** gastar ámbar en avisos, reputación, estados pendientes, tu propia posición o el radio de búsqueda.
- **Don't** introducir un segundo color vivo: lo activo sube de superficie o se encorcheta en letra de mapa.
- **Don't** escribir párrafos en condensada ni cuerpo de texto fuera de la cara del sistema.
- **Don't** usar emojis ni registro festivo en ningún copy ni icono; la señal de error declarada del producto es "que parezca infantil".
- **Don't** repetir el mismo dato dos veces en un renglón (la hora y lo que falta para empezar): el ancho que sobra es el que necesita la referencia de cuadrícula.
- **Don't** dibujar una barra maciza a todo el ancho para la acción anclada: el macizo está reservado a las plazas vivas, y si no hay acción a la que llevar, la banda no se dibuja.
