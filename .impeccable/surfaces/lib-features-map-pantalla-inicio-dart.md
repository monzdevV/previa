---
version: 1
slug: "lib-features-map-pantalla-inicio-dart"
primary_target: "lib/features/map/pantalla_inicio.dart"
related_targets: ["lib/app/tema.dart","lib/features/party/tarjeta_previa.dart","lib/features/map/pantalla_mapa.dart","lib/features/auth/pantalla_bienvenida.dart"]
---

Ámbito: pase visual de toda la app (Fase 5). Modo de visitante: Operate.

Público y tarea: adultos en la calle o en un piso entre las 22:00 y la 01:00, móvil a una mano y con prisa, decidiendo si caminar diez minutos hasta una previa con sitio. La tarea es comparar varias previas por hora, distancia y plazas, y pedir plaza.

Restricciones: Flutter adaptive (Android, iOS, web). Se conservan función, rutas, textos en español y modelo de datos. La ubicación exacta la impone la base de datos por privilegios de columna, nunca el cliente; en el mapa las previas son círculos, no chinchetas.

Éxito según el usuario: que la usaría gente de verdad. La expresión se subordina a decidir rápido de noche. Señal de error declarada: que parezca infantil o de fiesta con emojis.

## Direction contract

THESIS: La noche se lee por cuadrículas, nunca por portales. Rechaza el reparto por defecto de la categoría: mapa de chinchetas arriba y feed de tarjetas redondeadas debajo.

OWN-WORLD: Carta nocturna impresa. Fondo acromático tinta-pizarra con celdas teñidas, letra de mapa en blanco papel y un único ámbar de vapor de sodio reservado a lo que está vivo ahora. Radio cero en toda la interfaz. Filetes en lugar de bordes de tarjeta, puntos conductores uniendo nombre y hora, referencia de cuadrícula donde iría una dirección. Los estados son marcas impresas: filete en reposo, macizo al pulsar, tachado si está agotado. Display y cifras en una grotesca condensada con tabulares; cuerpo y controles en la cara del sistema.

STORY: Entiende que hay planes reales con sitio cerca esta noche, cree que su ubicación no se expone hasta que le aceptan, y pide plaza para su grupo.

FIRST VIEWPORT: El índice ocupa la pantalla. Cada previa es un renglón: nombre a la izquierda, puntos conductores cruzando el ancho, hora en tabulares grandes cerrando la línea, y debajo la referencia de cuadrícula con la distancia. Las plazas libres son una marca ámbar al final del renglón; llenándose y completa se distinguen sin leer la cifra. El mapa vive detrás como lámina plegada, se despliega con el pulgar por detentes y lleva dibujada la retícula que nombra esa referencia. Cada previa es un área teñida sobre su celda, nunca una chincheta; el área se dibuja como círculo porque el difuminado del servidor es un radio y un cuadrado mentiría sobre su forma. La acción primaria se ancla abajo, al alcance del dedo.

FORM: El callejero plegable y su índice de calles. Candidato 5 de mi lista ordenada por resonancia. Seed key 04c018b3.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## Elevaciones recibidas

- De la edición de referencia con rail central: estados como marcas impresas, radio cero.
- Del campo de datos en blanco y negro: las cifras mandan; la hora es la mayor mancha de tinta del renglón.
- Del servicio de teletexto: vocabulario para lo retenido, y un solo color reservado a lo vivo.
- De la columna de tensegridad: llenarse es una condición visible, no un número.
- Del borde de nube iridiscente: fondo acromático, color solo donde significa.

## Decisiones sin resolver

- Cara de display concreta y si se empaqueta en assets o se resuelve por paquete.
- Tratamiento exacto de la máscara de ubicación retenida en la ficha de detalle.
