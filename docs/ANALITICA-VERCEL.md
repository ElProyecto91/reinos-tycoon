# Vercel Web Analytics en Intimae

**Estado:** el código está preparado y desplegado. **Falta un paso tuyo en Vercel** (no puedo activarlo desde aquí: la herramienta de ajustes del proyecto no incluye Analytics).

## Activarlo (1 minuto, desde el móvil)
1. Abre https://vercel.com/elproyecto91s-projects/intimae/analytics (proyecto `intimae`).
2. Pulsa **Enable** en Web Analytics.
3. Abre https://intimae.vercel.app desde un navegador en el que no tengas «No rastrear» activado y navega unas páginas. Los datos tardan unos minutos.
4. Cuando me lo digas compruebo que el script responde y leo las visitas con las herramientas de Vercel.

## Qué mide y qué no
- Mide: páginas vistas, visitantes únicos, rutas, países, tipo de dispositivo, sistema, navegador y procedencia. **Sin cookies** y sin identificar personas, según Vercel. **[Fuente: documentación de Vercel; revisar con abogado]**
- **No se carga** en `/cuenta/`, `/vendedores/panel/` ni `/admin/`, ni en localhost, pruebas o dominios que no sean `*.vercel.app`. Al comprar un dominio propio hay que añadirlo a `HOSTS` en `js/analytics.js`.
- Respeta **No rastrear (DNT)**, **Global Privacy Control** y la casilla «No contar mis visitas» de la página de cookies.
- No se usan eventos personalizados: en Hobby no están disponibles; el embudo detallado sigue en la telemetría local del panel de administración.

## Límites y avisos
- El plan **Hobby es solo para uso no comercial**; vale para enseñar la demostración, no para operar. **[Fuente: Vercel]**
- Las páginas de la web están marcadas `noindex`; esto no afecta a la medición.
- **El proyecto tiene la protección de Vercel Authentication activada para todos los despliegues salvo dominios propios** (`all_except_custom_domains`). **[Probable]** Quien abra `intimae.vercel.app` sin sesión de Vercel puede ver una pantalla de acceso y no llegará a medirse. Para enseñarlo a otras personas hay que cambiarlo a protección estándar (solo previsualizaciones protegidas) en Ajustes → Deployment Protection, o comprar un dominio propio. Decisión pendiente.
- La política de cookies y privacidad ya describe la medición, pero con campos marcados para revisión jurídica (base legal y necesidad de consentimiento).
