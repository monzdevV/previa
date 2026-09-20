# 4. Plan de desarrollo

Entrega en **junio de 2026**. El plan reserva de forma deliberada los dos últimos meses
para pulido, pruebas y memoria, porque esa es la parte que siempre se come el margen.

## Fases

### Fase 0 — Cimientos · *septiembre*
- [x] Decidir tecnología y justificar la elección
- [x] Documentación inicial del proyecto
- [ ] Entorno de desarrollo completo (Flutter, Android Studio, emulador)
- [ ] Repositorio privado en GitHub
- [ ] Proyecto Flutter generado y compilando
- [ ] Proyecto de Supabase creado y conectado

### Fase 1 — Identidad · *octubre*
- [ ] Registro e inicio de sesión con correo electrónico
- [ ] Inicio de sesión con Google
- [ ] Verificación de mayoría de edad en el registro
- [ ] Creación y edición de perfil, con subida de foto
- [ ] Esquema de base de datos aplicado con sus políticas RLS
- [ ] Navegación general y tema visual de la aplicación

**Hito:** un usuario puede registrarse, entrar y tener perfil.

### Fase 2 — El mapa · *noviembre y diciembre*
- [ ] Permisos de ubicación y obtención de posición
- [ ] Mapa con previas cercanas
- [ ] Difuminado de ubicación implementado en base de datos
- [ ] Formulario de creación de previa
- [ ] Ficha de detalle de una previa
- [ ] Filtros por zona, hora, plazas y ambiente

**Hito:** publicar una previa y verla aparecer en el mapa de otro usuario.

### Fase 3 — Lo social · *enero y febrero*
- [ ] Solicitar plaza para un grupo
- [ ] Bandeja de solicitudes del anfitrión, con aceptar y rechazar
- [ ] Revelado de ubicación exacta al aceptar
- [ ] Chat en tiempo real por previa
- [ ] Notificaciones push
- [ ] Contador de plazas actualizado automáticamente

**Hito:** el recorrido completo funciona de principio a fin.

### Fase 4 — Confianza · *marzo*
- [ ] Reportar usuarios y previas
- [ ] Bloquear usuarios
- [ ] Valoraciones tras el evento y reputación
- [ ] Caducidad automática de previas pasadas
- [ ] Textos legales: privacidad y condiciones de uso

**Hito:** la aplicación es defendible desde el punto de vista de la seguridad.

### Fase 5 — Pulido · *abril*
- [ ] Diseño visual definitivo
- [ ] Animaciones y transiciones
- [ ] Estados vacíos, de carga y de error
- [ ] Accesibilidad
- [ ] Rendimiento y optimización

### Fase 6 — Cierre · *mayo y primeros de junio*
- [ ] Pruebas unitarias de la lógica de negocio
- [ ] Pruebas de interfaz sobre los recorridos principales
- [ ] Memoria del TFG
- [ ] Presentación y guion de la defensa
- [ ] Compilación final firmada y vídeo demostrativo

## Método de trabajo

- **Una rama por funcionalidad**, con fusión a la rama principal mediante pull request.
  Esto deja un historial que demuestra el proceso, algo que los tribunales valoran.
- **Commits en español**, describiendo el qué y no el cómo.
- **Documentación al día**: cada decisión técnica relevante se anota cuando se toma, no
  en mayo intentando recordarla.
- **Cada fase termina con algo que funciona**, aunque sea feo. Nunca se avanza dejando
  la aplicación rota.

## Riesgos identificados

| Riesgo | Impacto | Mitigación |
|---|---|---|
| Las consultas geográficas se complican | Alto | Prototipar PostGIS pronto, en fase 2 |
| El chat en tiempo real falla en móvil real | Alto | Probar en dispositivo físico desde el principio |
| Las notificaciones push consumen demasiado tiempo | Medio | Están clasificadas como deseables, no imprescindibles |
| El proyecto crece sin control | Alto | El alcance está cerrado por escrito en el documento de concepto |
| Pérdida de trabajo | Crítico | Subida a GitHub tras cada sesión de trabajo |
