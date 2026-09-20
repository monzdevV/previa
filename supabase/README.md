# Backend de Previa

Proyecto de Supabase: **previa** · región `eu-west-3` (París) · plan gratuito.

La URL y la clave publicable están en el `.env` local, que no se sube. Para
preparar un equipo nuevo se copia `.env.example` a `.env` y se rellenan los
valores desde *Project Settings → API Keys* en el panel de Supabase.

## Contenido

```
supabase/
├── migrations/   el esquema completo, en orden
└── tests/        bateria de pruebas del modelo de seguridad
```

## Migraciones

Se aplican en orden alfabético, que coincide con el cronológico.

| # | Migración | Qué hace |
|---|---|---|
| 1 | `extensiones_tipos_y_perfiles` | PostGIS, tipos enumerados, perfiles, barrera de mayoría de edad |
| 2 | `previas_y_difuminado_de_ubicacion` | Tabla de previas y difuminado de coordenadas |
| 3 | `solicitudes_miembros_y_mensajes` | Solicitudes de grupo, miembros, chat |
| 4 | `seguridad_bloqueos_reportes_valoraciones` | Bloqueos, reportes, valoraciones, reputación |
| 5 | `politicas_rls_y_privilegios_de_columna` | Seguridad a nivel de fila y de columna |
| 6 | `funciones_busqueda_y_derechos_rgpd` | Búsqueda geográfica y derechos RGPD |
| 7 | `reducir_superficie_de_api` | Funciones internas fuera de la API pública |
| 8 | `cerrar_ejecucion_anonima` | Retirada del acceso anónimo |
| 9 | `corregir_privilegios_del_difuminado` | Corrección detectada por las pruebas |

Para aplicarlas en un proyecto nuevo, pegar cada fichero en orden en el editor
SQL de Supabase.

## Las tres decisiones que sostienen la seguridad

**1. La ubicación exacta no es legible.** El rol `authenticated` no tiene
privilegio `SELECT` sobre la columna `parties.location`. No es una política que
se pueda esquivar: es un privilegio que no existe. La única vía es la función
`ubicacion_exacta()`, que comprueba la pertenencia antes de responder.

**2. El difuminado se calcula una sola vez.** Si el desplazamiento se
recalculase en cada consulta, promediar varias lecturas revelaría el centro
real. Al guardarse fijo, eso es imposible.

**3. Las funciones internas no son endpoints.** PostgREST publica como API REST
toda función del esquema `public`. Las auxiliares de RLS viven en el esquema
`privado`, que no se publica.

## Pruebas

El fichero `tests/seguridad.sql` crea tres usuarios ficticios, ejerce las
políticas desde el punto de vista de cada uno y borra los datos al terminar.
Se pega en el editor SQL de Supabase y debe devolver **16 filas, todas PASA**.

Ya ha servido para algo: destapó que blindar los privilegios había roto la
creación de previas, porque el disparador del difuminado se quedaba sin permiso
para llamar a la función que difumina. Esa es la migración 9.

## Pendiente

- [ ] Programar `caducar_previas()` con pg_cron, cada hora
- [ ] Bucket de Storage para las fotos de perfil, con sus políticas
- [ ] Inicio de sesión con Google en el panel de autenticación
- [ ] Plantillas de correo en español
