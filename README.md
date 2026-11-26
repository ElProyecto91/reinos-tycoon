# Intimae

Mercado europeo de prendas íntimas de segunda mano entre adultos. Web estática (HTML, CSS y JavaScript sin dependencias ni build).

## Estructura

| Ruta | Contenido |
|---|---|
| `index.html` | Tienda (solo compradores): catálogo, búsqueda, ficha, favoritos, mensajes, denuncias, pago simulado |
| `cuenta/` | Cuenta de comprador: pedidos, favoritos, mensajes, verificación de edad (simulada), datos y privacidad |
| `vendedores/` | Área de vendedores, separada: portada, solicitud, condiciones, guía de impuestos |
| `vendedores/panel/` | Panel de vendedor: anuncios con fotos, pedidos y envíos, cobros, mensajes, datos fiscales (DAC7) |
| `admin/` | Administración: moderación, denuncias, vendedores, pedidos, DAC7, ajustes, auditoría |
| `js/core.js` | Capa de datos del **modo demostración** (almacenamiento local del navegador) con la API que sustituirá un backend real |
| `js/ui.js`, `js/cuenta.js`, `js/panel.js`, `js/admin.js` | Interfaz de cuenta, panel y administración |
| `tienda/` | Tienda pública de cada vendedor: distintivos de confianza, piezas, valoraciones, seguir, contactar, denunciar y bloquear |
| `vercel.json`, `robots.txt` | Cabeceras de seguridad (CSP, anti-framing…) y bloqueo de indexación mientras sea una demostración |
| `tests/e2e/` | Pruebas de navegador (`node tests/e2e/run.js`); ver su README |
| `db/schema.sql` | Esquema PostgreSQL/Supabase con RLS para el backend real (**borrador sin ejecutar**) |
| `css/` | `fonts.css` (tipografías propias), `styles.css` (sistema de diseño), `legal.css` |
| `js/products.js` | Catálogo y vendedores de demostración |
| `js/tax.js` | Motor de IVA orientativo: tipos por país, regímenes, destinos |
| `js/app.js` | Interfaz de la tienda |
| `js/seller.js` | Interfaz del área de vendedores |
| `js/i18n.js`, `i18n/` | Idiomas: detección por navegador y país, diccionarios (es, en, fr, de, it, pt, nl) |
| `tools/i18n/` | Fuentes de traducción y generador/validador (`python3 tools/i18n/build.py`) |
| `tools/legal/` | Generador de las páginas legales (`python3 tools/legal/generate.py`) |
| `fonts/` | Cormorant Garamond e Inter (licencia SIL OFL), alojadas en el propio sitio |
| `*.html` | Páginas legales (borrador, pendientes de titularidad) y guía de IVA |
| `docs/ESTUDIO-LEGAL-Y-MERCADO.md` | Estudio legal, IVA, competencia y hoja de ruta |
| `docs/AUDITORIA-INTIMAE.md` | Auditoría del estado real, competencia, riesgos y plan por fases |
| `.vercelignore` | Excluye `docs/`, `tools/` y `screenshots/` del sitio publicado |
| `screenshots/` | Capturas de la última versión |

## Modo demostración

Todo funciona, pero **sin servidor**: cuentas, anuncios, pedidos, mensajes y favoritos se guardan solo en el navegador de cada persona (`localStorage`), la verificación de edad y los pagos son simulados y las contraseñas no están protegidas de verdad. Sirve para probar el flujo completo, no para operar. Contraseña de administración de demostración: `demo-admin` (en `/admin/`).

Política de producto: Intimae es intermediario y no es parte de la compraventa, pero ofrece un **procedimiento de incidencias** (comprador → vendedor → administración, con reembolso total, parcial o rechazo) y la liquidación al vendedor queda en pausa mientras haya una abierta. Antes del envío se puede cancelar con reembolso íntegro. No se promete ninguna protección fuera de ese procedimiento y de las reglas del proveedor de pagos.

Muestras: los artículos y tiendas de ejemplo se etiquetan como «Muestra»; la administración puede ocultarlos (Ajustes) y entonces la tienda muestra el estado vacío con la invitación a vendedores fundadores.

Canarias (código `IC`): IGIC (tipo general 7 %, estimación pendiente de validar por un asesor fiscal) y envíos solo dentro de Canarias.

Idiomas: la tienda y el alta de vendedores están en 7 idiomas; cuenta, panel y administración, por ahora solo en español.

## Antes de publicar

1. Completar los campos resaltados de las páginas legales (titularidad, correos, comisión, plazos).
2. Cambiar el correo de contacto (campos `{{EMAIL ...}}` de las páginas legales).
3. Sustituir productos y vendedores de demostración, y las fotos de muestra de Unsplash.
4. Revisar con un abogado y un asesor fiscal (ver preguntas en el estudio).
5. Comprobar que el hosting y el medio de cobro admiten contenido para adultos (ver `docs/CONSULTA-PROCESADORES.md`).
6. Sustituir `js/core.js` por un backend real (esquema en `db/schema.sql`), un proveedor real de pagos y de verificación de edad.

## Probar en local

```bash
python3 -m http.server 8000
```
