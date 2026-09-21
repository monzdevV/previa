# Prompt para continuar el desarrollo

Pégalo entero en una sesión de Claude Code lanzada desde la carpeta del proyecto.

```
Eres el desarrollador de "Previa", mi Trabajo de Fin de Grado de 2º de DAM. Entrega en junio de 2026.

CONTEXTO
- App social de proximidad: grupos con plazas libres en una previa encuentran gente cerca antes de salir de fiesta. Mapa con ubicación aproximada, solicitudes por grupo, chat al aceptar.
- Stack: Flutter 3.47 + Supabase (PostgreSQL 17 + PostGIS).
- Proyecto: C:\Users\celia\OneDrive\Escritorio\Previa
- SDK Flutter: C:\Users\celia\dev\flutter\bin (ya está en el PATH)
- Repo privado: https://github.com/monzdevV/previa (rama main, ya autenticado con gh)
- Supabase: proyecto "previa", ref bfqzabpgtehncnbxtslg, región eu-west-3. Las claves están en .env (no versionado).
- Lee primero README.md y docs/ (01 a 05). El plan con lo hecho y lo pendiente está en docs/04-plan-desarrollo.md.

YA ESTÁ HECHO
Fases 0 a 3 completas y parte de la 4: esquema con 8 tablas y 24 políticas RLS, batería de 16 pruebas de seguridad en supabase/tests/seguridad.sql, registro/login con verificación +18, mapa con previas cercanas, filtros, crear previa, ficha de detalle, solicitar plaza, bandeja del anfitrión, chat en tiempo real, reportar, bloquear, mis solicitudes, editar perfil, y funciones RGPD de exportación y borrado de cuenta.

PENDIENTE, EN ESTE ORDEN
1. Valoraciones tras la previa y reputación (tabla ratings ya existe, con sus políticas). Falta la interfaz.
2. Subida de foto de perfil a Supabase Storage, con su bucket y sus políticas.
3. Filtro por ambiente en el mapa.
4. Caducidad automática de previas: programar caducar_previas() con pg_cron cada hora.
5. Pantalla de ajustes con política de privacidad y condiciones de uso.
6. Animaciones y transiciones entre pantallas.
7. Más pruebas unitarias y de widget.
8. Inicio de sesión con Google.
9. Notificaciones push con Firebase Cloud Messaging (lo último, es lo más costoso).

CÓMO TRABAJAR
- No me preguntes nada. Estoy durmiendo. Toma tú las decisiones y sigue.
- Todo en español: nombres de clases, variables, comentarios y mensajes de commit.
- Comentarios que expliquen POR QUÉ, no qué. Es un TFG y me van a preguntar en la defensa.
- Antes de cada commit: "flutter analyze" sin incidencias y "flutter test" en verde. Si algo falla, arréglalo antes de seguir.
- Haz commit y "git push origin main" DESPUÉS DE CADA BLOQUE TERMINADO, no al final. Si algo se corta, que no se pierda nada.
- Termina los mensajes de commit con: Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
- Marca en docs/04-plan-desarrollo.md lo que vayas completando.
- NO intentes instalar Android Studio: se queda colgado esperando permisos de administrador. Verifica con "flutter analyze", "flutter test" y "flutter build web".
- Principio de diseño que no se toca: la ubicación exacta solo la ven los asistentes aceptados, y eso se aplica en la base de datos (privilegios de columna sobre parties.location), nunca en el cliente. En el mapa las previas se dibujan como círculos, no como chinchetas, porque las coordenadas están desplazadas ~300 m.

Empieza por el punto 1 y ve bajando. Trabaja hasta que se te acaben los tokens.
```

## Cómo lanzar la sesión

Abre una terminal **nueva** (para que coja el PATH actualizado) y ejecuta:

```
cd "C:\Users\celia\OneDrive\Escritorio\Previa"
claude --dangerously-skip-permissions
```

La primera vez pedirá iniciar sesión y confiar en la carpeta. Son dos pasos que solo ocurren una vez.

> `--dangerously-skip-permissions` ejecuta cualquier comando sin preguntar, incluidos los destructivos. En esta carpeta, y con el trabajo subido a GitHub, el riesgo es asumible.
