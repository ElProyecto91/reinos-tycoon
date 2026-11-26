# Pruebas de navegador (modo demostración)

Requieren Playwright con Chromium (`npm i -D playwright` y `npx playwright install chromium`). No necesitan servidor: `lib.js` sirve el repositorio desde disco como `https://intimae.test/` con las cabeceras de `vercel.json` (incluida la CSP).

```
node tests/e2e/run.js
```

Escribe capturas en `screenshots/`. Cubre: tienda, cuenta, vendedor, moderación, pedidos, liquidación, DAC7, Canarias, incidencias, tiendas públicas, filtros, borradores, muestras, idiomas y móvil. Es una prueba de la **maqueta** (datos en `localStorage`); cuando exista el backend habrá que añadir pruebas de permisos, webhooks y RLS.
