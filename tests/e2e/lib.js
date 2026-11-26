// Utilidades comunes de las pruebas de navegador. Requiere Playwright (npm i -D playwright) y Chromium.
// Sirve el repositorio como si fuera https://intimae.test/ (con las cabeceras de vercel.json, incluida la CSP)
// sin arrancar ningún servidor: las peticiones se resuelven desde disco.
const fs = require('fs'), path = require('path');
const ROOT = path.resolve(__dirname, '..', '..');
const R = 'https://intimae.test/';
const SHOT = path.join(ROOT, 'screenshots') + '/';
const TMP = process.env.E2E_TMP || path.join(require('os').tmpdir(), 'intimae-e2e') + '/';
fs.mkdirSync(TMP, { recursive: true });
const HEADERS = {};
try { JSON.parse(fs.readFileSync(path.join(ROOT, 'vercel.json'), 'utf8')).headers[0].headers.forEach(h => HEADERS[h.key] = h.value); } catch (e) {}
const TYPES = { '.html': 'text/html; charset=utf-8', '.js': 'application/javascript', '.css': 'text/css', '.svg': 'image/svg+xml', '.woff2': 'font/woff2', '.json': 'application/json', '.txt': 'text/plain', '.png': 'image/png' };
let fails = 0; const errs = [];
const ok = (n, c, extra) => { console.log((c ? 'PASS ' : 'FAIL ') + n + (c ? '' : '  -> ' + JSON.stringify(extra))); if (!c) fails++; };
async function serve(ctx) {
  await ctx.route('https://intimae.test/**', async route => {
    const u = new URL(route.request().url()); let fp = path.join(ROOT, decodeURIComponent(u.pathname));
    if (fp.endsWith(path.sep) || u.pathname.endsWith('/')) fp = path.join(fp, 'index.html');
    if (!fs.existsSync(fp) || !fp.startsWith(ROOT)) return route.fulfill({ status: 404, body: 'not found' });
    route.fulfill({ status: 200, headers: Object.assign({ 'content-type': TYPES[path.extname(fp)] || 'application/octet-stream' }, HEADERS), body: fs.readFileSync(fp) });
  });
  ctx.on('page', pg => {
    pg.on('pageerror', e => errs.push(pg.url() + ' :: ' + e.message));
    pg.on('console', m => { if (m.type() === 'error' && !/images\.unsplash|ERR_FAILED|ERR_NAME|net::ERR/.test(m.text())) errs.push(m.text()); });
    pg.on('dialog', d => d.accept(d.type() === 'prompt' ? 'Motivo de prueba suficiente' : undefined));
  });
}
function finish(label) { console.log('\nERRORES DE CONSOLA:', errs); if (errs.length) fails++; console.log(fails ? 'FALLOS: ' + fails : 'TODO OK (' + label + ')'); return fails; }
module.exports = { R, ROOT, SHOT, TMP, ok, serve, finish, errs, fs, path };
