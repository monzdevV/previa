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
| 10 | `bucket_fotos_de_perfil` | Bucket `avatars` y sus políticas de Storage |

Endurecimiento posterior (30-sep-2026), todo aditivo y aplicado con `apply_migration`:

| # | Migración | Qué hace |
|---|---|---|
| 11 | `eliminar_cuenta_solo_previa` | Reescribe `eliminar_mi_cuenta()`: borra explícitamente solo datos de Previa, libera plazas, borra la foto de `avatars` y la cuenta |
| 12 | `caducidad_programada` | `caducar_previas()` con pg_cron cada hora (min 7); idempotente por nombre de job |
| 13 | `limitacion_de_frecuencia` | Disparadores: 5 previas/día, 20 solicitudes/hora, 30 mensajes/min, 10 reportes/día |
| 14 | `fecha_nacimiento_inmutable` | `birth_date` no se borra ni cambia tras fijarse (salvo sin sesión de usuario) |
| 15 | `moderacion_cautelar_por_reportes` | 3 reportantes distintos ocultan previa / bloquean persona; vista `revision_reportes`, `levantar_cautela`, `poner_cautela` (solo service role) |
| 16 | `permisos_revision_reportes` | `service_role` puede ejecutar `privado.bajo_cautela` (la vista lo necesita) |
| 17 | `politica_denegar_moderacion_cautelar` | Política explícita `using (false)` en la tabla de cautelas |

La migración 11 se aplicó en dos pasos en el proyecto (`eliminar_cuenta_solo_previa` y
`eliminar_cuenta_borrado_storage`, que añade el ajuste `storage.allow_delete_query`);
el fichero del repositorio contiene el resultado final de ambos.

### Notas de operación

- **Proyecto compartido**: el proyecto `bfqzabpgtehncnbxtslg` contiene también tablas y
  funciones de otra app (`posts`, `follows`, `venues`, `challenges`, `completar_reto`,
  `rajarse`, `retirar_publicacion`...), que comparten `profiles`. Estas migraciones no las
  tocan. Al eliminar una cuenta, las filas propias de la otra app para ese mismo usuario
  se borran por cascada (inevitable al borrar `auth.users`); nunca las de otras personas.
- **Storage**: borrar filas de `storage.objects` por SQL elimina la URL pública pero puede
  dejar el binario huérfano en el almacén. Lo correcto es que la app llame también a
  `storage.from('avatars').remove(['<uid>/foto'])` antes de `eliminar_mi_cuenta()`.
- **Revisar reportes** (service role o editor SQL): `select * from public.revision_reportes;`
  Levantar: `select public.levantar_cautela('previa', '<uuid>');` (o `'perfil'`). Cautela
  manual: `select public.poner_cautela('perfil', '<uuid>', 'motivo');`. Cambiar el umbral (3)
  exige editar `privado.aplicar_cautela_por_reportes()`.
- **Funciones SECURITY DEFINER (advisor 0029)**: las cinco de Previa que aparecen
  (`edad`, `eliminar_mi_cuenta`, `exportar_mis_datos`, `mi_fecha_nacimiento`,
  `ubicacion_exacta`) son las RPC que usa `lib/` y se mantienen; cada una valida
  `auth.uid()`. `completar_reto`, `rajarse` y `retirar_publicacion` son de la otra app y
  no se han tocado. Las funciones nuevas de moderación, caducidad y disparadores no son
  ejecutables por `anon` ni `authenticated`.
- **Cambio visible para el cliente**: editar la fecha de nacimiento desde el perfil ya no
  es posible una vez fijada (devuelve `insufficient_privilege`); la pantalla de edición
  debería dejarla en solo lectura.
- **Ajustes solo desde el panel** (no se pueden hacer por SQL): activar *Leaked password
  protection* y la confirmación de correo en Authentication.

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
Se pega en el editor SQL de Supabase y debe devolver **38 filas, todas PASA**
(1-16 originales; 17-38: fecha de nacimiento, límites de frecuencia, cautela por
reportes, permisos de moderación, pg_cron y `eliminar_mi_cuenta`).

Ya ha servido para algo: destapó que blindar los privilegios había roto la
creación de previas, porque el disparador del difuminado se quedaba sin permiso
para llamar a la función que difumina. Esa es la migración 9.

## Pendiente

- [x] Programar `caducar_previas()` con pg_cron, cada hora
- [x] Bucket de Storage para las fotos de perfil, con sus políticas
- [ ] Activar protección de contraseñas filtradas y confirmación de correo (panel)
- [ ] Inicio de sesión con Google en el panel de autenticación
- [ ] Plantillas de correo en español
