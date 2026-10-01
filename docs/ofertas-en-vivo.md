# Ofertas en vivo

Idea del profesor socio: un local lanza una oferta de tiempo limitado para la
gente que está dentro **ahora** ("30 min, entrada gratis para quien llegue ya").
En el MVP no depende de Fourvenues ni de Nyxell: el local la escribe en la app
y la canjea en la puerta o en la barra de servicio, sin integrarse con su caja.

## Límites legales (innegociables)

Salen del informe legal del proyecto y se aplican en tres capas:

1. **Producto**: solo hay plantillas de *entrada, mesa/zona, foto, guardarropa,
   comida y experiencias*. No existe plantilla de bebida.
2. **Copy**: la app no dice "bebe", "barra libre" ni "2x1". El texto libre se
   limita a 60 + 140 caracteres.
3. **Base de datos**: una categoría cerrada (`kind`) y un disparador que
   rechaza título o detalle con palabras de consumo de alcohol (barra libre,
   open bar, 2x1, copa, chupito, cubata, bebe...). Es una red de seguridad, no
   un filtro perfecto: la responsabilidad de la oferta es del local (condiciones
   de uso) y el informe de moderación puede cancelarla.

+18 siempre: la base de datos solo muestra y canjea ofertas a perfiles con
`birth_date` de al menos 18 años, aunque la app ya lo exija al registrarse.

## Flujo local → usuario

1. El dueño (fila en `venue_owners`, que da de alta el equipo del proyecto, no
   la app) abre "Lanzar oferta" desde la ficha de su local y elige plantilla,
   duración (15, 30, 45 o 60 min) y cupos (10 a 200).
2. La oferta nace activa y caduca sola a `ends_at`; no hay que apagarla.
3. Quien ha dicho **"estoy aquí"** en ese local esta noche ve un banner en
   ¿Vas? con cuenta atrás y cupos restantes. Toca "Canjear" y recibe un código
   corto y un QR.
4. En la puerta o en la barra de servicio el personal ve el código. Opcional en
   el MVP: el local lo marca como *validado*.

## Cómo se confirma la presencia

Se combinan dos señales, de más débil a más fuerte:

- **"Estoy aquí"** (ya existe, `venue_plans.status = 'aqui'`). Es declarativo,
  así que sola no basta para ofertas valiosas. La app solo deja marcarlo si la
  ubicación aproximada del móvil está a menos de **300 m** del local; el cálculo
  se hace en el teléfono y la posición **no se envía** al servidor (misma regla
  de privacidad que la distancia en ¿Vas?). Es un freno, no una prueba: se
  puede falsear.
- **QR en la puerta** (`verificacion = 'qr'`). El local imprime el QR de esa
  oferta (contiene `door_code`, aleatorio y solo visible para el dueño). Quien
  lo escanea demuestra estar físicamente allí. El servidor compara el código al
  canjear.

Cada oferta declara cuál exige: `aqui` (ofertas pequeñas: foto, guardarropa) o
`qr` (entrada gratis, mesa). Decisión abierta: si usar siempre `qr` en producción.

## Duración, límites y anti-abuso

- Duración: mínimo 5 min, máximo 120 min; las plantillas ofrecen 15-60.
- Máximo **2 ofertas activas a la vez** por local y **6 por noche**.
- Cupos 1-500, aplicados con bloqueo de fila: no se pasa de cupo aunque canjeen
  a la vez.
- **Un canje por persona y oferta**: `unique (offer_id, profile_id)`.
- Canjear exige RPC (`canjear_oferta`); no hay INSERT directo en la tabla de
  canjes. La RPC comprueba edad, bloqueo, que estés "aquí" esta noche, ventana
  de tiempo, cupo y código QR si procede.
- Sin pasar del límite por abuso de peticiones: reutiliza `privado.limitar`
  si se necesita más adelante.

## Qué ve el usuario

- Banner/tarjeta en ¿Vas? (en la foto del local y en su ficha): título,
  cuenta atrás `mm:ss`, cupos, botón "Canjear" (≥48 dp, `Semantics`, escala de
  texto al 200%). Al canjear, hoja con el QR y el código en grande.
- **Push futura**: aviso a quien dijo "voy" o "estoy aquí" cuando se lanza una
  oferta de su local. Hace falta Firebase (pendiente del proyecto); mientras
  tanto la oferta se ve al abrir ¿Vas?. Debe respetar un ajuste "avisos de
  ofertas" desactivable.

## Qué ve el local (panel mínimo)

Pantalla "Lanzar oferta": plantillas seguras, duración y cupos; debajo, sus
ofertas de la noche con **canjes / cupos** y botón "Cancelar". Validar un
código: campo de texto (v2: escáner con `mobile_scanner`).

## Métricas

Por oferta: canjes, cupos agotados (sí/no), minutos hasta agotar, y validados
frente a canjeados (no-show). Por local y noche: ofertas lanzadas y canjes
totales. Son agregados: el local ve cuántos, y solo ve *quién* para validar su
propio código. Sin analítica de terceros.

## RGPD

Un canje es dato personal (quién, dónde, cuándo): base legal ejecución del
servicio solicitado; se borra con la cuenta (`on delete cascade`) y los canjes
de noches pasadas se pueden purgar a los 90 días (decisión abierta).

## Estado

Migración `20260930240000_ofertas_en_vivo.sql` escrita y **sin aplicar**. La app
usa un repositorio en memoria solo en depuración; en producción no enseña
ofertas hasta que exista la implementación contra Supabase.
