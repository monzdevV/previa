# Lanzamiento: de TFG a una primera noche con gente de verdad

Plan para poner Previa en manos de 15–30 personas en Zaragoza gastando lo
mínimo. Sale de la auditoría de septiembre de 2026.

## Canal principal: la web instalable (0 €)

Llega a iPhone y Android con un enlace o un QR, sin tiendas ni pagos.

1. `flutter build web --release`
2. Desplegar la carpeta ya compilada: `npx vercel deploy build/web --prod`.
   Vercel no tiene Flutter ni el `.env`, así que se compila en local.
3. Comprobar que `https://<dominio>/assets/.env` responde 200. Solo lleva la
   clave publicable; la seguridad está en las políticas de la base de datos.
4. En Supabase → Authentication → URL Configuration: poner la URL de Vercel
   como Site URL y en Redirect URLs.

Limitaciones: sin notificaciones push (tampoco las hay en móvil todavía) y la
primera carga pesa unos 6 MB. Probarla con 4G antes de la noche.

## Android para quien lo prefiera (0 €)

- **Firebase App Distribution**: `flutter build apk --release`, subir el APK
  y los testers lo instalan desde un correo. El mismo proyecto de Firebase
  sirve luego para las push.
- Antes hay que crear una clave de firma propia (`keytool`), guardarla en
  `android/key.properties` (fuera del repositorio) y usarla en
  `android/app/build.gradle.kts`: ahora firma con la de depuración.
- **Google Play** (25 $ una vez): la prueba interna admite 100 testers casi al
  momento. Para publicar de verdad, una cuenta personal nueva necesita antes
  una prueba cerrada con **12 testers durante 14 días seguidos**. Conviene
  empezarla con margen.

## iOS (99 $/año)

TestFlight necesita la cuenta de Apple Developer y un Mac (o un servicio de
compilación como Codemagic). Para la primera noche, los de iPhone usan la web.

## Bloqueantes antes de invitar a nadie de fuera

- [ ] Correo de confirmación: el SMTP de Supabase gratis solo envía a los
      miembros del equipo. Configurar uno propio (Resend tiene plan gratuito)
      o desactivar la confirmación de correo durante la beta.
- [ ] Rellenar `Titular` en `lib/features/profile/pantallas_legales.dart`.
- [ ] Activar la protección de contraseñas filtradas (Auth → Passwords).
- [ ] Poner la clave de la IA del juego (ver `CONTEXT.md`).
- [ ] Una prueba completa en un móvil real: registro, foto, vídeo, QR, mapa,
      pedir plaza, mensaje y un reto de No hay 🥚 entre dos personas.
- [ ] Decidir si se borran los datos de demostración (`is_demo`): con gente
      real delante pueden confundir.
- [ ] Abrir el proyecto de Supabase el mismo día: los gratuitos se pausan
      tras 7 días sin actividad.

## Para las tiendas, después

- Reportar y bloquear desde publicaciones, perfiles y mensajes (App Store lo
  exige para contenido de usuarios; hoy solo existe en la ficha de previa).
- URL pública de la política de privacidad y una página web para pedir el
  borrado de la cuenta (Google Play la exige).
- Borrar los ficheros de Storage al eliminar la cuenta.

## La primera noche

- **Quién**: compañeros de clase y sus amigos, 15–30 personas, un jueves o
  viernes. Dos anfitriones "semilla" publican una previa real esa tarde.
- **Dónde**: hablar con uno de los locales de la pestaña Noche para que su
  ficha tenga el enlace de entradas de verdad, y ofrecer algo a quien vaya con
  Previa (entrar antes, una consumición).
- **Cómo se entra**: un QR en la facultad y en stories, y un grupo de
  WhatsApp para avisos mientras no haya push.
- **Qué se hace**: perfil antes de las 22:00, seguir a tres personas, pedir
  plaza en una previa, decir a qué local vas y jugar al menos un reto de
  No hay 🥚 dentro.
- **Qué se mide** (por SQL en Supabase): registros completos, previas
  creadas, solicitudes aceptadas, publicaciones, mensajes, y retos
  repartidos, cumplidos y rajados (`challenges.status`), separando los de IA
  de los de plantilla (`challenges.source`).
- **Al día siguiente**: una encuesta de cinco preguntas y revisar los
  reportes en la pantalla de moderación.
