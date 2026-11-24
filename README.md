# Intimae

Mercado europeo de prendas íntimas de segunda mano entre adultos. Web estática (HTML, CSS y JavaScript sin dependencias ni build).

## Estructura

| Ruta | Contenido |
|---|---|
| `index.html` | Tienda: catálogo, ficha, pedido, alta de vendedores, FAQ |
| `css/` | `fonts.css` (tipografías propias), `styles.css` (sistema de diseño), `legal.css` |
| `js/products.js` | Catálogo y vendedores de demostración |
| `js/tax.js` | Motor de IVA orientativo: tipos por país, regímenes, destinos |
| `js/app.js` | Interfaz |
| `fonts/` | Cormorant Garamond e Inter (licencia SIL OFL), alojadas en el propio sitio |
| `*.html` | Páginas legales (borrador, pendientes de titularidad) y guía de IVA |
| `docs/ESTUDIO-LEGAL-Y-MERCADO.md` | Estudio legal, IVA, competencia y hoja de ruta |
| `screenshots/` | Capturas de la última versión |

## Antes de publicar

1. Completar los campos resaltados de las páginas legales (titularidad, correos, comisión, plazos).
2. Cambiar los correos de `CONFIG` en `js/app.js`.
3. Sustituir productos y vendedores de demostración, y las fotos de muestra de Unsplash.
4. Revisar con un abogado y un asesor fiscal (ver preguntas en el estudio).
5. Comprobar que el hosting y el medio de cobro admiten contenido para adultos.

## Probar en local

```bash
python3 -m http.server 8000
```
