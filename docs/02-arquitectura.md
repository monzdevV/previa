# 2. Arquitectura

## Visión general

```
┌─────────────────────────────────────────┐
│           APLICACIÓN FLUTTER            │
│                                         │
│  Presentación  →  pantallas y widgets   │
│  Estado        →  Riverpod              │
│  Dominio       →  entidades y casos uso │
│  Datos         →  repositorios          │
└──────────────────┬──────────────────────┘
                   │  HTTPS / WebSocket
┌──────────────────┴──────────────────────┐
│                SUPABASE                 │
│                                         │
│  Auth       →  sesiones y JWT           │
│  PostgreSQL →  datos + PostGIS          │
│  RLS        →  seguridad por fila       │
│  Realtime   →  chat y solicitudes       │
│  Storage    →  fotos de perfil          │
│  Functions  →  lógica sensible          │
└─────────────────────────────────────────┘
```

## Decisiones técnicas y su justificación

Esta sección es la que más valor tiene en la defensa: no basta con decir qué se usa,
hay que poder defender **por qué** frente a las alternativas.

### Flutter en lugar de Android nativo

- Un solo código base para Android e iOS, lo que en un proyecto individual con plazo
  cerrado duplica el alcance alcanzable.
- Recarga en caliente, que acelera muchísimo el trabajo sobre la interfaz.
- *Contrapartida:* menor integración con APIs específicas de cada sistema. Para las
  funcionalidades de Previa (mapa, GPS, notificaciones) existen paquetes maduros, así
  que la contrapartida no llega a materializarse.

### Supabase en lugar de Firebase

- **PostgreSQL con PostGIS**, imprescindible aquí: la consulta central de la aplicación
  es "dame las previas abiertas en un radio de N kilómetros", que PostGIS resuelve de
  forma nativa y eficiente. Firestore, al ser NoSQL, obliga a simular esto con geohashes.
- **Row Level Security**: las reglas de privacidad viven en la base de datos, no en la
  aplicación. Un cliente manipulado no puede saltárselas.
- Es SQL estándar, que es lo que se estudia en el ciclo — el tribunal lo puede evaluar.
- *Contrapartida:* menos integrado con notificaciones push, que se resuelven con Firebase
  Cloud Messaging por separado.

### Riverpod en lugar de BLoC

- Menos código repetitivo que BLoC para un proyecto de este tamaño.
- Inyección de dependencias y gestión de estado en una sola herramienta.
- Permite probar la lógica sin necesidad de levantar la interfaz.

### flutter_map en lugar de Google Maps

- OpenStreetMap no requiere tarjeta de crédito ni clave de API con facturación asociada,
  algo relevante en un proyecto académico sin presupuesto.
- Suficiente para mostrar marcadores y círculos de zona.
- *Contrapartida:* estéticamente menos pulido que Google Maps. Se compensa aplicando un
  estilo de teselas personalizado acorde a la identidad visual de la aplicación.

## Estructura de carpetas

```
lib/
├── main.dart
├── app/                    configuración global, rutas y tema
├── core/                   utilidades, constantes y errores
├── data/
│   ├── models/             modelos serializables
│   ├── repositories/       acceso a Supabase
│   └── services/           ubicación, notificaciones, almacenamiento
├── domain/
│   ├── entities/           entidades puras de negocio
│   └── usecases/           casos de uso
└── features/
    ├── auth/               registro, login, verificación de edad
    ├── profile/            perfil propio y ajenos
    ├── map/                mapa y exploración
    ├── party/              crear, ver y gestionar previas
    ├── requests/           solicitudes de plaza
    ├── chat/               mensajería en tiempo real
    └── safety/             reportes, bloqueos y valoraciones
```

## Flujo principal de datos

Ejemplo: **un usuario solicita plaza en una previa.**

1. La pantalla dispara `requestJoinUseCase(partyId, groupSize, mensaje)`.
2. El caso de uso valida las reglas de negocio: el usuario no está bloqueado, quedan
   plazas suficientes y no existe ya una solicitud pendiente.
3. El repositorio inserta una fila en `join_requests` a través de Supabase.
4. Las políticas RLS verifican en el servidor que el usuario puede insertar esa fila.
5. Realtime notifica al anfitrión, cuya pantalla se actualiza sin recargar.
6. Al aceptar, un *trigger* crea la pertenencia y habilita el acceso al chat y a la
   ubicación exacta.

El punto clave: **la validación crítica ocurre en el servidor.** La comprobación en el
cliente existe solo para dar una respuesta rápida al usuario.
