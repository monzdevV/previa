# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

Personas adultas que planean salir por la noche y quieren descubrir u organizar una previa cerca de ellas. La acción principal es encontrar un plan que encaje, solicitar una plaza y coordinarse con el grupo.

## Product Purpose

Previa es una red social de proximidad para organizar planes antes de salir de fiesta. Debe hacer que descubrir una previa cercana y segura se sienta rápido, claro y social.

## Positioning

La experiencia combina un mapa de planes de proximidad con solicitudes de plaza, reputación y chat privado para que una previa se organice sin compartir la ubicación exacta de forma pública.

## Operating Context

Uso principalmente nocturno y móvil, a menudo en movimiento o con poca luz. Las personas exploran el mapa, filtran planes, crean previas, solicitan acceso y conversan una vez aceptadas.

## Capabilities and Constraints

- Registro e inicio de sesión mediante Supabase.
- Mapa, filtros, creación y detalle de previas, solicitudes, chat, perfil y valoraciones.
- Solo para mayores de 18 años.
- La ubicación exacta de una previa está protegida y solo se comparte con miembros autorizados.
- El proyecto Flutter se distribuye para Android, iOS y web.
- Se infiere esta ficha de la implementación existente; no hay documentación de producto confirmada por el usuario todavía.

## Evidence on Hand

- Copy y flujos reales en `lib/features/`.
- Esquema, políticas de acceso y pruebas en `supabase/`.
- No hay fotografías, testimonios ni sistema de marca aprobado que se deba preservar.

## Product Principles

- La decisión de unirse a un plan debe poder hacerse de un vistazo.
- La seguridad y la privacidad son parte de la experiencia, no texto legal escondido.
- Los datos que condicionan la noche —hora, zona, plazas y ambiente— deben dominar la jerarquía.
- La interfaz debe mantener legibilidad fiable en condiciones de poca luz.
