# 5. Seguridad, privacidad y protección de las personas usuarias

Este documento existe porque Previa reúne tres elementos delicados a la vez: **personas
desconocidas**, **ubicación física** y un **contexto asociado al consumo de alcohol**.

Un tribunal va a preguntar por esto. Tenerlo resuelto por escrito convierte el que sería
el punto débil del proyecto en uno de sus capítulos más sólidos.

## Principios de diseño

### 1. La ubicación exacta es un secreto hasta que deja de serlo

Nadie ve dónde vives por el hecho de abrir la aplicación.

- La tabla de previas guarda dos ubicaciones: la exacta y una **difuminada**.
- La difuminada se genera aplicando un desplazamiento aleatorio de unos 300 metros,
  **fijo para cada previa**. Que sea fijo es importante: si se recalculara en cada
  consulta, sería posible deducir el centro real promediando varias lecturas.
- La ubicación exacta solo se revela a los miembros aceptados, y la regla se aplica
  mediante una política de seguridad a nivel de fila en el servidor, no mediante una
  comprobación en el cliente.

### 2. Solo para mayores de edad

- Se solicita la fecha de nacimiento en el registro y se bloquea el acceso a menores.
- La fecha de nacimiento nunca se envía al cliente: se expone únicamente la edad.
- Existe un motivo de reporte específico para sospecha de usuario menor de edad.

> Conviene ser honesto en la memoria: una verificación de edad robusta requiere
> comprobación documental, que queda fuera del alcance de un TFG. Reconocer la
> limitación y describir cómo se resolvería en un producto real vale más que fingir
> que el problema no existe.

### 3. El control lo tiene siempre el anfitrión

Nadie entra en una previa sin aprobación explícita. No hay acceso automático.

### 4. Bloquear es inmediato y total

Al bloquear a alguien, desaparece por completo: sus previas dejan de verse, no puede
solicitar plaza y no puede escribir. La regla se aplica en las propias consultas SQL.

### 5. Toda interacción es reportable

Perfiles, previas y mensajes disponen de un botón de reporte. Los reportes se almacenan
con su contexto para poder ser revisados.

## Cumplimiento del RGPD y la LOPDGDD

| Requisito | Cómo se cumple en Previa |
|---|---|
| **Base legitimadora** | Consentimiento explícito en el registro, con casilla no premarcada |
| **Minimización de datos** | Solo se pide lo necesario. Sin teléfono, sin dirección postal, sin apellidos |
| **Limitación de la finalidad** | La ubicación se usa exclusivamente para mostrar previas cercanas |
| **Limitación del plazo** | Las previas caducan y se eliminan pasadas 48 horas |
| **Derecho de acceso** | Exportación del perfil propio en formato JSON |
| **Derecho de supresión** | Botón de eliminación de cuenta con borrado en cascada |
| **Seguridad del tratamiento** | Cifrado en tránsito mediante TLS, seguridad a nivel de fila en la base de datos, contraseñas con hash gestionadas por Supabase |
| **Transparencia** | Política de privacidad redactada en lenguaje claro, accesible desde los ajustes |

**La ubicación es un dato personal** conforme al RGPD. La aplicación:

- La solicita solo cuando se necesita, no al arrancar
- Explica para qué la quiere antes de pedir el permiso
- Funciona en modo degradado si se deniega, permitiendo buscar por zona escrita a mano
- No la almacena de forma continuada: solo se guarda la del punto de la previa

## Medidas técnicas

- Todas las tablas con seguridad a nivel de fila activada; **ninguna** consulta confía
  en el cliente
- Limitación de frecuencia **en la base de datos** (disparadores, no solo cliente), por
  usuario y ventana móvil: 5 previas por día, 20 solicitudes de plaza por hora, 30
  mensajes de chat por minuto y 10 reportes por día. Al superarlo la operación falla con
  el error `program_limit_exceeded`. Es un control de mejor esfuerzo: dos inserciones
  exactamente simultáneas podrían colarse. No se limita a operaciones sin sesión de
  usuario (service role, SQL, tareas programadas). No hay límite de peticiones HTTP
  generales ni de intentos de inicio de sesión más allá del que aplique Supabase Auth.
- **Fecha de nacimiento**: una vez fijada no puede borrarse ni cambiarse desde la app
  (disparador); solo se admite pasar de vacía a un valor (registro con Google) o un
  cambio administrativo sin sesión de usuario.
- **Cautela automática por reportes**: con reportes abiertos de 3 personas distintas,
  una previa deja de verse para extraños y en las búsquedas, y una persona no puede
  crear previas, pedir plaza ni escribir en chats. No borra nada y solo la levanta el
  equipo de moderación con el service role (función `levantar_cautela`; la vista
  `revision_reportes` permite revisarlos). Limitación: tres cuentas falsas podrían
  ocultar una previa ajena hasta la revisión.
- **Caducidad**: `caducar_previas()` se ejecuta cada hora con pg_cron (minuto 7):
  cierra las previas pasadas a las 8 h y las borra a las 48 h.
- **Borrado de cuenta**: `eliminar_mi_cuenta()` borra de forma explícita los datos de
  Previa de la persona, libera sus plazas en previas ajenas, elimina su foto de
  `avatars` y la cuenta. Los reportes que otras personas hayan hecho contra ella se
  eliminan con la cuenta.
- Validación del contenido tanto en cliente como en servidor
- Las claves de API nunca se incluyen en el repositorio: variables de entorno y fichero
  de configuración excluido del control de versiones
- Sesiones con expiración y renovación automática de credenciales

## Limitaciones asumidas

Declararlas es preferible a que las descubra el tribunal:

1. La verificación de edad se basa en una declaración del usuario, no en documentación.
2. No existe moderación automática de contenido: solo la cautela por número de reportes
   descrita arriba; el resto de reportes se revisaría manualmente.
3. La aplicación no puede garantizar la seguridad física de un encuentro presencial.
4. No hay verificación de identidad, por lo que caben perfiles falsos.

Cada una lleva asociada en la memoria una propuesta de cómo se abordaría en un producto
real, lo que demuestra criterio profesional más allá del código entregado.
