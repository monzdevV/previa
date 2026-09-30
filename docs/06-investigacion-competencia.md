# 6. Investigación de competencia: NOTT (antes NOX)

Fecha de la investigación: 30 de septiembre de 2026.

## 0. Qué se pudo y qué no se pudo verificar

**Verificado directamente**
- El vídeo de TikTok de La 7 (@la7tele, 95 s) se descargó y se revisaron sus fotogramas. La app que aparece es **NOTT — Tu noche**. El rótulo del vídeo dice: "La nueva aplicación murciana Nott permite localizar el plan y decidir dónde seguir la noche". Su creador es Juan Ruiz, de 20 años.
- Ficha de App Store (API pública de iTunes, país ES): descripción, versión, clasificación por edad, valoraciones, notas de versión, capturas y reseñas.
- Web oficial nott.es y sus páginas de privacidad, términos y seguridad infantil. Estas tres se leyeron mediante un resumidor automático, no literalmente, así que conviene releerlas antes de citarlas en la memoria.

**No verificado**
- No se instaló la app y no se probó el registro, la verificación de edad real ni los flujos completos.
- Google Play: la web dice que Android está "próximamente", así que no hay ficha.
- Prensa: aparte del reportaje de La 7 no se encontró ninguna otra noticia (las búsquedas web no devolvieron nada sobre NOTT).
- No se transcribió el audio del reportaje, solo se leyeron rótulos e imágenes.
- Modelo de negocio: es una **inferencia**, no un dato. La web dice que es gratis y sin anuncios, y hay enlaces a entradas de terceros, pero no declara de dónde saca ingresos.
- Reseñas: solo hay 10 valoraciones (todas 5,0), con textos muy cortos. No hay quejas de usuarios que analizar. Los puntos débiles de abajo son análisis propio, no opiniones de usuarios.

## 1. Qué es NOTT

- Nombre actual: **NOTT — Tu noche**. Se llamaba **NOX** y cambió de nombre en la versión 1.2.0 (23/09/2026). Bundle id `com.juanruiz.nox`.
- Desarrollador: Juan Ruiz Fernández, una sola persona. Lanzamiento en App Store el 14/09/2026.
- Plataforma: solo iOS (iOS 15.1 o superior). Android "próximamente". Gratis. Categoría "Redes sociales". Clasificación **17+** en App Store y **18+** según su propia política.
- Nace en Murcia y usa esa ciudad como mercado de lanzamiento. Dominio nott.es, contacto soporte@nott.es.
- Eslogan: "Tu noche, con tu gente".

**Propuesta.** Es una red social de **salir de noche con amigos ya existentes**. El eje son los **locales** (discotecas y bares), no las casas particulares.

Pantallas y funciones vistas en la ficha, la web y el vídeo:

| Sección | Qué hace |
|---|---|
| **Ahora** | Pestañas "Amigos" y "Descubrir". Muestra los planes de tus amigos sin tener que preguntar. Si no hay planes, propone un local ("Templo de la zona"). Botón principal "Voy a ir". |
| **Sitios** | Mapa oscuro con agrupación de marcadores y una hoja inferior con la lista ("21 sitios por aquí"). Filtros: "En vivo", "Ahora", "Hasta tarde", "Con amigos". Cada local muestra distancia, horario ("hasta 03:30") y etiqueta "entradas". |
| **Ficha de local** | Tipo, distancia, horario, etiquetas, selector de día ("¿Qué noche?"), botones "Voy a ir", "Cómo llegar", "Invitar amigos" y "Comprar entradas" (enlace a la taquilla oficial del local). |
| **La Sala** | Una foto de tu noche hecha **desde el local**. Se verifica con GPS, se permite una por noche y caduca a las 12:00 del día siguiente (la web habla de 12 h; la política de privacidad habla de hasta 180 días de conservación, así que hay cierta ambigüedad). |
| **Amigos** y **Perfil** | Comentarios y respuestas en planes y momentos. Perfil con Instagram opcional. Visibilidad elegible: solo amigos, amigos de amigos o todos. |

**Onboarding.** Es un carrusel con "Saltar" y "Siguiente". Cada tarjeta tiene una etiqueta pequeña en mayúsculas ("AHORA", "SITIOS"), un titular grande ("Esta noche, en un vistazo", "El mapa de la noche") y una frase. Incluye captura de la pantalla real. Hay una campaña de vídeo vertical con el lema "Tu gente ya sale. / Toda Murcia en un mapa. / Y tú dices: SALGO". Esto último es marketing y no tiene por qué coincidir con los textos actuales de la app.

## 2. Interfaz: patrones, paleta y tipografía

La web publica sus tokens de diseño, que dicen coincidir con los de la app (`src/theme/tokens.ts`, lo que sugiere React Native). La coincidencia exacta no se comprobó.

- **Concepto visual:** "Después de medianoche". Modo oscuro único (`color-scheme: dark`).
- **Paleta:**
  - Fondo `#0c0a10`, un "plum-ink" cálido, nunca negro puro.
  - Superficies `#17131f` y `#211b2c`.
  - Texto `#f3eee6`, un hueso, nunca blanco puro.
  - **Oro `#f4b740`** como marca y acción, con texto `#1a1206` encima.
  - **Ember `#ff4d6d`** solo para "está pasando ahora".
  - Éxito `#58c9a0`.
- **Tipografía:** Bricolage Grotesque (titulares, 600 a 700) y Hanken Grotesk (texto). Usa monoespaciada para datos como horarios, distancias y etiquetas. Fuentes servidas desde su propio dominio (sin llamar a Google).
- **Patrones de UI:**
  - Tab bar de 4 pestañas con icono y texto: Ahora, Sitios, Amigos, Perfil.
  - **Una única acción primaria dorada por pantalla.** El secundario es una superficie con borde fino.
  - Botón flotante "+" para crear plan.
  - Hoja inferior arrastrable sobre el mapa.
  - Chips de filtro sobre el mapa.
  - Selector de noche por chips horizontales (Hoy, Mañana, mié 9...).
  - Letra inicial gigante como ilustración del local cuando no hay foto.
- **Accesibilidad visible en la web:** botones de al menos 48 px, `:focus-visible` con contorno dorado, texto solo para lector de pantalla, `font-display: swap` y `prefers-reduced-motion` probable (no comprobado). En la app solo se ve lo que muestran las capturas. No puedo afirmar nada sobre VoiceOver, Dynamic Type o contraste real.
- **Confianza y seguridad visibles:** insignia 17+ y aviso "Solo para mayores de 18 años. Bebe con cabeza". Además: visibilidad configurable, borrado de cuenta dentro de la app, política de seguridad infantil propia y respuesta a denuncias en menos de 24 h.

## 3. Seguridad y privacidad (según sus textos)

- **Verificación de edad:** es una **autodeclaración** ("confirma que eres mayor de 18"). Según la política de privacidad no hay verificación proactiva. Las cuentas de menores se borran cuando se detectan.
- **Ubicación:** aproximada para el mapa y GPS preciso **solo al publicar en La Sala**. Dicen que no guardan historial.
- **Retención:** mensajes mientras exista la conversación o 12 meses de inactividad. Fotos de La Sala hasta 180 días. Analítica hasta 12 meses.
- **Moderación:** denuncia dentro de la app con motivo. Varias denuncias ocultan el contenido automáticamente. Revisión en menos de 24 h. Sanciones de suspensión o cierre. Material de abuso infantil supone cierre inmediato y aviso a las autoridades. Bloqueo disponible (según la política de seguridad infantil y los términos).
- **Descargo:** la app se ofrece "tal cual" y no se responsabilizan de las interacciones entre usuarios.

## 4. Qué hace bien

1. Identidad visual muy coherente. Un solo color de acción, modo oscuro adecuado al contexto nocturno y tokens documentados.
2. Propuesta clara en una frase ("a dónde va tu gente esta noche") y onboarding de tarjetas cortas con captura real.
3. Un solo botón primario por pantalla y una acción de negocio clara ("Voy a ir").
4. Contenido efímero y verificado por GPS (La Sala): genera el momento "ahora" sin crear un archivo permanente.
5. Política pública de seguridad infantil y moderación con plazo concreto (24 h), poco habitual en un proyecto de un solo desarrollador.
6. Privacidad explícita: sin historial de ubicación, borrado en la app y visibilidad por niveles.
7. Utilidad inmediata aunque haya pocos usuarios: el mapa de locales funciona sin amigos y las entradas enlazan a la taquilla oficial.

## 5. Qué hace mal o dónde es débil

Es análisis propio a partir de sus textos y capturas, no quejas de usuarios (solo hay 10 valoraciones).

1. **Arranque en frío:** el valor central ("qué hace tu gente") depende de tener amigos dentro. Solo hay 10 valoraciones, así que la masa crítica es mínima. La pantalla de local muestra "Sé el primero de tus amigos en apuntarte".
2. **Edad por autodeclaración,** sin verificación real. Es el mismo punto débil que tendría Previa si no lo mejora.
3. **Solo iOS;** Android "próximamente". Excluye a una parte grande del público.
4. **Discrepancias en sus propios textos:** 17+ en App Store y 18+ en la política. "Caduca a las 12:00" en la web, "12 horas" en seguridad infantil y "hasta 180 días" en privacidad. La política de privacidad no menciona el bloqueo, mientras que los términos y la política de seguridad infantil sí lo hacen.
5. **Datos de local dudosos:** se ve "Templo de la zona" con "Alter Ego 2.834 reseñas" y etiquetas técnicas en inglés ("nightclub", "entertainment", "dance"), lo que sugiere datos importados de un proveedor de mapas.
6. **Fomenta el consumo nocturno** (clasificación con "consumo de alcohol frecuente/intenso"), sin herramientas de seguridad personales visibles (compartir trayecto, contacto de confianza). No se vio nada de eso en capturas ni texto.
7. **Mucho texto pequeño monoespaciado** en tonos apagados sobre fondo oscuro. Puede tener problemas de contraste (no medido).
8. **Modelo de negocio sin declarar,** dependiente de acuerdos con locales.

## 6. Diferencias con Previa

| | NOTT | Previa |
|---|---|---|
| Unidad social | Tú y **tus amigos existentes** | **Desconocidos** que se encuentran (grupos) |
| Destino | **Locales públicos** (discotecas y bares) | **Casas particulares** (la previa) |
| Mapa | Locales exactos + amigos | Zonas **aproximadas**; dirección exacta solo tras aceptar |
| Interacción | "Voy a ir", compartir plan, fotos efímeras | Solicitud por grupo, **decisión del anfitrión**, chat, **valoraciones** |
| Reputación | No visible | Central (valoraciones mutuas) |
| Riesgo principal | Bajo (sitios públicos) | **Alto** (quedar con desconocidos en un domicilio), así que seguridad es el producto |
| Plataforma | Solo iOS | Android e iOS (Flutter) |
| Monetización | No declarada, probable acuerdo con locales | Fuera de alcance del TFG |

**Conclusión:** NOTT **no es un competidor directo**. Resuelve "a qué local va mi gente" y no "con quién hago la previa". Coinciden en público (jóvenes, Murcia, salir de noche) y en que son nocturnas y de proximidad. El mensaje para la defensa del TFG es que Previa ocupa un hueco distinto y más delicado, y que la seguridad y las valoraciones son su diferenciador frente a NOTT. NOTT muestra además cómo debe verse y comunicarse una app de este tipo.

## 7. Mejoras propuestas para Previa (priorizadas)

Prioridad: **A** = hacer ya (seguridad o riesgo legal), **B** = alto valor, **C** = pulido o deseable.

| # | Pri. | Área | Mejora | Por qué / inspiración |
|---|---|---|---|---|
| 1 | A | Seguridad | **Pantalla de seguridad accesible en un toque** dentro del chat y de la previa: reportar, bloquear, salir, compartir ubicación con un contacto de confianza. | NOTT tiene denuncia y bloqueo, pero con desconocidos en casas hace falta más que eso. |
| 2 | A | Seguridad | **Reforzar la verificación +18:** más allá de la fecha de nacimiento, valorar verificación del DNI o un proveedor externo antes de publicar una previa (al menos para anfitriones). Documentar la limitación. | NOTT solo se autodeclara. Es el punto débil de ambas, y en Previa el riesgo es mayor. |
| 3 | A | Seguridad | **Política pública de seguridad y moderación** (página dentro de la app y en web) con plazo de respuesta (por ejemplo 24 h), ocultado automático tras N denuncias y sanciones. | NOTT lo hace y genera confianza. Es barato y suma en la defensa. |
| 4 | A | Privacidad | Mantener **ubicación aproximada hasta la aceptación** y mostrar el aviso en la UI ("Ubicación aproximada. La dirección exacta se comparte al aceptar"). No guardar historial. Una sola fuente de verdad de retención. | NOTT explica su tratamiento de ubicación. Evitar sus contradicciones entre textos. |
| 5 | A | Legal | **Mensaje de alcohol y edad** visible en onboarding y pie: "Solo para mayores de 18. Bebe con cabeza." Alinear clasificación por edad en tiendas con la política (evitar 17+/18+). | NOTT lo muestra. Las tiendas exigen coherencia. |
| 6 | B | Interfaz | **Modo oscuro** como tema principal, con fondo cálido (no negro puro) y texto hueso (no blanco puro). Un único color de acción. | Es un contexto nocturno. La paleta de NOTT es un buen referente de coherencia. |
| 7 | B | Interfaz | **Una acción primaria por pantalla** (por ejemplo "Solicitar entrar" en la previa, "Aceptar" en la solicitud) con botón lleno y el resto secundarios con borde. | Claridad de decisión. Patrón visible en todas las pantallas de NOTT. |
| 8 | B | Interfaz | **Onboarding de 3 o 4 tarjetas** con etiqueta, titular y una frase, más "Saltar": publicar, mapa aproximado, el anfitrión decide, valoraciones. Pedir permiso de ubicación **con contexto** justo después. | NOTT usa un carrusel corto. Aumenta la confianza antes de pedir permisos. |
| 9 | B | Interfaz | **Mapa con hoja inferior arrastrable** (lista de previas cercanas) y **chips de filtro** (Ahora, Hasta tarde, Ambiente, Plazas libres). Agrupar marcadores. | Patrón de NOTT. Permite usar la app sin tocar el mapa. |
| 10 | B | Funcionalidad | **Estado "ahora" en la tarjeta de previa:** hora, plazas libres y distancia aproximada, con acento de color solo para "en curso" o "queda poco". | Es el equivalente a "En vivo" de NOTT, y da urgencia sin inventar datos. |
| 11 | B | Funcionalidad | **Soluciones al arranque en frío:** modo demo o semilla de previas, y opción de invitar por enlace (deep link) para que entre un grupo entero. | NOTT depende de amigos y ya se nota con 10 valoraciones. Previa lo necesita aún más. |
| 12 | B | Accesibilidad | **Contraste y tamaño:** objetivos táctiles de al menos 48 px, texto mínimo de 14 px, contraste AA (4,5:1) también en tema oscuro, `Semantics` en el mapa y los marcadores, escalado de texto del sistema y foco visible. Evitar textos pequeños en gris sobre negro. | NOTT usa monoespaciada pequeña y atenuada. Es una oportunidad para hacerlo mejor. |
| 13 | C | Funcionalidad | **Valoraciones con etiquetas** (puntual, ambiente, respetuoso) y **insignias** ("anfitrión verificado", "10 previas sin incidencias"). | NOTT no tiene reputación. Es el diferenciador de Previa. |
| 14 | C | Funcionalidad | **Contenido efímero opcional** (por ejemplo, foto del grupo que caduca), solo entre participantes de una previa aceptada. | Inspirado en La Sala, pero sin exponer a desconocidos. Es un extra. |
| 15 | C | Interfaz | **Estados vacíos útiles** ("Aún no hay previas cerca. Publica la tuya") con un CTA, y textos en español coherentes (evitar etiquetas en inglés). | NOTT muestra "Sé el primero de tus amigos en apuntarte" como empuje. |

## 8. Fuentes

- Vídeo: https://www.tiktok.com/@la7tele/video/7691031559993920801
- App Store: https://apps.apple.com/es/app/nott-tu-noche/id6797049428
- Web: https://nott.es, con /privacidad/, /terminos/ y /seguridad-infantil/
