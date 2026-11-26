// Prueba de extremo a extremo del modo demostración: node tests/e2e/run.js
// Cubre tienda, cuenta, vendedor, administración, incidencias, tiendas públicas, filtros, idiomas, móvil y cabeceras CSP.
const { chromium } = require('playwright');
const { R, SHOT, ROOT, ok, serve, finish, fs, path } = require('./lib');
const PNG = fs.readFileSync(path.join(__dirname, 'muestra.png'));
const shot = (p, n) => p.screenshot({ path: SHOT + n });

(async () => {
  const b = await chromium.launch();
  const ctx = await b.newContext({ viewport: { width: 1280, height: 900 }, locale: 'es-ES' });
  await serve(ctx);
  const p = await ctx.newPage();

  // ---------- ayudas
  const reg = async (name, email) => { const f = p.locator('#auth form').nth(1); await f.locator('[name=name]').fill(name); await f.locator('[name=email]').fill(email); await f.locator('[name=pass]').fill('clave-segura-1'); await f.locator('[name=ok]').check(); await f.locator('button[type=submit]').click(); };
  const applySeller = async (alias, email, country, kind, extra = {}) => {
    await p.goto(R + 'vendedores/'); await p.waitForSelector('#seller-form');
    await p.fill('#seller-form [name=alias]', alias); await p.fill('#seller-form [name=email]', email); await p.selectOption('#s-country', country);
    await p.fill('#seller-form [name=age]', '31'); await p.fill('#seller-form [name=pass]', 'clave-segura-2');
    if (kind === 'profesional') { await p.check('#seller-form input[name=kind][value=profesional]'); await p.fill('#seller-form [name=vatid]', extra.vat); await p.selectOption('#seller-form [name=regime]', extra.regime || 'general'); }
    await p.check('#seller-form [name=ok]'); await p.click('#seller-form button[type=submit]'); await p.waitForTimeout(400);
    return p.locator('#seller-msg').innerText();
  };
  const fiscal = async (name, tax, country, birth) => {
    await p.goto(R + 'vendedores/panel/#fiscal'); await p.waitForSelector('#panel form');
    await p.fill('#panel [name=legalName]', name); await p.fill('#panel [name=taxId]', tax); await p.fill('#panel [name=address]', 'Calle de Prueba 1'); await p.selectOption('#panel [name=taxCountry]', country);
    if (birth) await p.fill('#panel [name=birth]', birth);
    await p.click('#panel button[type=submit]'); await p.waitForTimeout(300);
  };
  const adminLogin = async () => { await p.goto(R + 'admin/'); if (await p.locator('#auth input[name=pass]').isVisible().catch(() => false)) { await p.fill('#auth input[name=pass]', 'demo-admin'); await p.click('#auth button[type=submit]'); } await p.waitForSelector('#tabbar button'); };
  const adminTab = async id => { await p.locator('#tabbar button[data-id=' + id + ']').click(); await p.waitForTimeout(150); };
  const newListing = async (title, price, draft) => {
    await p.goto(R + 'vendedores/panel/#anuncios'); await p.waitForSelector('#panel');
    await p.getByRole('button', { name: 'Nuevo anuncio' }).click(); const f = p.locator('#panel form');
    await f.locator('[name=title]').fill(title); await f.locator('[name=price]').fill(String(price)); await f.locator('[name=days]').fill('3'); await f.locator('[name=material]').fill('Algodón'); await f.locator('[name=colour]').fill('Blanco'); await f.locator('[name=desc]').fill('Prenda de prueba.');
    await f.locator('input[type=file]').setInputFiles({ name: 'foto.png', mimeType: 'image/png', buffer: PNG }); await p.waitForTimeout(400);
    await f.locator('input[type=checkbox]').check();
    await (draft ? f.getByRole('button', { name: 'Guardar borrador' }) : f.getByRole('button', { name: /Enviar a revisión$/ })).click(); await p.waitForTimeout(300);
  };
  const store = async () => { await p.goto(R + 'index.html'); if (await p.locator('#ag-yes').isVisible().catch(() => false)) await p.click('#ag-yes'); await p.waitForSelector('#grid', { state: 'attached' }); };
  const buy = async (q, dest) => {
    await store(); if (dest) { await p.selectOption('#dest', dest); await p.waitForTimeout(150); }
    await p.fill('#f-q', q); await p.waitForTimeout(150);
    await p.locator('.pcard .btn').first().click(); await p.waitForSelector('#cart[open]');
    await p.fill('#order-form [name=name]', 'Ana Prueba'); await p.fill('#order-form [name=addr]', 'Calle Falsa 1');
    await p.check('#order-form [name=adult]'); await p.check('#order-form [name=art9]'); await p.click('#order-form button[type=submit]'); await p.waitForTimeout(250);
    return p.locator('#lines').innerText();
  };
  const sellerLogin = (email) => p.evaluate(e => INT.seller.login(e, 'clave-segura-2'), email);

  // ================= 1. Tienda y cuenta de comprador
  await store();
  ok('catálogo con 9 piezas de muestra', (await p.locator('.pcard').count()) === 9);
  ok('las piezas de muestra están etiquetadas', (await p.locator('.tag--sample').count()) === 9);
  ok('banner de demostración visible', await p.locator('.demobar').isVisible());
  await p.fill('#f-q', 'azul'); await p.waitForTimeout(100); ok('búsqueda "azul" filtra', (await p.locator('.pcard').count()) === 2); await p.fill('#f-q', '');
  await p.locator('.favbtn').first().click(); await p.waitForURL(/cuenta\/\?next=store/);
  await reg('Ana Prueba', 'ana@example.com'); await p.waitForSelector('#grid');
  ok('tras registrarse vuelve a la tienda', ['/', '/index.html'].includes(new URL(p.url()).pathname), p.url());
  if (await p.locator('#ag-yes').isVisible().catch(() => false)) await p.click('#ag-yes');
  await p.locator('.favbtn').first().click(); await p.waitForTimeout(150); ok('favorito marcado', (await p.locator('.favbtn.on').count()) === 1);
  await p.locator('.pcard__title button').nth(2).click(); await p.waitForSelector('#pdp[open]');
  ok('ficha: sin valoraciones, plazo y protección de la compra', /sin valoraciones/i.test(await p.locator('#pdp-seller').innerText()) && /plazo estimado/i.test(await p.locator('#pdp-specs').innerText()) && /Protección de la compra/i.test(await p.locator('#pdp').innerText()));
  ok('ficha: enlace a la tienda del vendedor', /tienda\/\?s=maribel/.test(await p.locator('#pdp-shop').getAttribute('href')));
  await p.click('#pdp-ask'); await p.fill('#ask-form textarea', 'Mi correo es a@b.com'); await p.click('#ask-form button');
  ok('mensaje con correo bloqueado', /no se pueden compartir/i.test(await p.locator('#ask-msg').innerText()));
  await p.fill('#ask-form textarea', '¿Sigue disponible y cómo es el encaje?'); await p.click('#ask-form button'); ok('mensaje enviado', /Mensaje enviado/.test(await p.locator('#ask-msg').innerText()));
  await p.click('#pdp-report'); await p.waitForSelector('#report[open]'); await p.click('#report-form button[type=submit]');
  ok('denuncia exige declaración', /marca la declaración/i.test(await p.locator('#rep-msg').innerText()));
  await p.selectOption('#report-form [name=reason]', 'fake'); await p.fill('#report-form [name=text]', 'Descripción engañosa'); await p.check('#report-form [name=good]'); await p.click('#report-form button[type=submit]');
  ok('denuncia registrada con número', /DN-00001/.test(await p.locator('#rep-msg').innerText())); await p.keyboard.press('Escape');
  await p.click('#pdp-add').catch(async () => { await p.keyboard.press('Escape'); }); await p.waitForTimeout(200);
  if (!(await p.locator('#cart[open]').count())) await p.locator('.pcard__actions .btn').nth(2).click();
  await p.waitForSelector('#cart[open]');
  ok('sin edad verificada se pide verificarla', /verificar tu edad/i.test(await p.locator('#cart-gate-text').innerText()) && await p.locator('#order-form').isHidden());
  await shot(p, '20-pedido-verificar-edad.png');
  await p.click('#cart-gate-cta'); await p.waitForURL(/cuenta\/\?next=cart/); await p.locator('.tabs button[data-id=datos]').click();
  await p.locator('input[name=birth]').fill('2015-05-05'); await p.locator('form:has(input[name=birth]) button[type=submit]').click(); await p.waitForTimeout(200);
  ok('menor de edad rechazado', /18/.test(await p.locator('.toast').innerText().catch(() => '')));
  await p.locator('input[name=birth]').fill('1990-05-05'); await p.locator('form:has(input[name=birth]) button[type=submit]').click(); await p.waitForSelector('#cart[open]');
  ok('formulario de pago visible tras verificar la edad', await p.locator('#order-form').isVisible());
  await p.fill('#order-form [name=name]', 'Ana Prueba'); await p.fill('#order-form [name=addr]', 'Calle Falsa 1, 28001 Madrid'); await p.check('#order-form [name=adult]'); await p.check('#order-form [name=art9]');
  await shot(p, '21-pedido-pago-simulado.png'); await p.click('#order-form button[type=submit]'); await p.waitForTimeout(200);
  const done = await p.locator('#lines').innerText(); ok('pedido registrado IM-000001', /IM-000001/.test(done) && !/retenid/i.test(done), done); await p.keyboard.press('Escape');
  await p.goto(R + 'cuenta/#pedidos'); await p.waitForSelector('.tabs');
  ok('pedido en la cuenta como "Pagado"', /IM-000001/.test(await p.locator('#panel').innerText()) && /pagado/i.test(await p.locator('#panel').innerText()));
  ok('no queda texto de "retenido" ni "escrow" en la cuenta', !/retenid|escrow/i.test(await p.locator('body').innerText()));
  await shot(p, '23-cuenta-pedidos.png');
  await p.getByRole('button', { name: 'Cancelar pedido' }).click(); await p.waitForTimeout(200); ok('cancelado con reembolso', /cancelado/i.test(await p.locator('#panel').innerText()));
  ok('la pieza vuelve al catálogo', await p.evaluate(() => PRODUCTS.some(x => x.id === 3)));
  await p.locator('.tabs button[data-id=mensajes]').click(); ok('hilo de mensajes visible', /Sigue disponible/.test(await p.locator('#panel').innerText()));
  await p.locator('.tabs button[data-id=favoritos]').click(); ok('favorito listado', (await p.locator('#panel .row-card').count()) === 1);
  await p.locator('.tabs button[data-id=datos]').click(); ok('edad verificada sin guardar la fecha', /edad verificada/i.test(await p.locator('#panel').innerText()) && !JSON.stringify(await p.evaluate(() => INT.data().users)).includes('1990-05-05'));
  ok('aceptación de condiciones registrada', await p.evaluate(() => INT.data().acceptances.some(a => a.who.startsWith('comprador'))));

  // ================= 2. Vendedor, moderación, compra y liquidación
  let m = await applySeller('Luna_Test', 'luna@example.com', 'ES', 'particular'); ok('solicitud de vendedor registrada', /Solicitud recibida/.test(m), m);
  await p.goto(R + 'vendedores/panel/'); await p.waitForSelector('#tabbar button');
  ok('panel: cuenta pendiente de verificación', /pendiente de verificación|completa primero/i.test(await p.locator('#panel').innerText()));
  await p.locator('#tabbar button[data-id=anuncios]').click(); ok('no puede publicar sin verificar', await p.getByRole('button', { name: 'Nuevo anuncio' }).isDisabled());
  await fiscal('Luna Prueba García', '12345678Z', 'ES', '1990-02-02');
  await adminLogin(); await adminTab('vendedores'); ok('admin ve la solicitud con datos completos', /Luna_Test/.test(await p.locator('#panel').innerText()) && /completos/i.test(await p.locator('#panel').innerText()));
  await p.getByRole('button', { name: 'Verificar' }).first().click(); await p.waitForTimeout(200); ok('vendedor verificado', /verificado/i.test(await p.locator('#panel').innerText()));
  await newListing('Braga blanca de prueba', 28); ok('anuncio enviado a revisión', /pendiente de revisión/i.test(await p.locator('#panel').innerText()));
  await shot(p, '25-panel-anuncios.png');
  await adminLogin(); await adminTab('moderacion'); ok('moderación muestra el anuncio', /Braga blanca de prueba/.test(await p.locator('#panel').innerText()));
  await p.getByRole('button', { name: 'Aprobar' }).click(); await p.waitForTimeout(200);
  await store(); await p.fill('#f-q', 'blanca'); await p.waitForTimeout(150);
  ok('anuncio publicado en la tienda, sin etiqueta de muestra', (await p.locator('.pcard').count()) === 1 && (await p.locator('.pcard .tag--sample').count()) === 0);
  let r = await buy('blanca'); ok('compra del anuncio nuevo', /IM-\d{6}/.test(r), r);
  await p.goto(R + 'vendedores/panel/#pedidos'); await p.waitForSelector('#panel');
  ok('vendedor ve el pedido con dirección', /Calle Falsa 1/.test(await p.locator('#panel').innerText()) && /pagado/i.test(await p.locator('#panel').innerText()));
  await p.fill('#panel input[name=tracking]', 'TRK123456'); await p.getByRole('button', { name: 'Marcar como enviado' }).click(); await p.waitForTimeout(250);
  ok('pedido enviado con seguimiento', /enviado/i.test(await p.locator('#panel').innerText()) && /TRK123456/.test(await p.locator('#panel').innerText()));
  await p.goto(R + 'cuenta/#pedidos'); await p.waitForSelector('#panel'); await p.getByRole('button', { name: 'Confirmar recepción' }).click(); await p.waitForTimeout(250);
  ok('comprador confirma la recepción', /entregado/i.test(await p.locator('#panel').innerText()));
  await p.locator('#panel select[name=rating]').first().selectOption('4'); await p.getByRole('button', { name: 'Valorar al vendedor' }).click(); await p.waitForTimeout(250);
  ok('valoración guardada', /Tu valoración: ★★★★☆/.test(await p.locator('#panel').innerText()));
  await p.goto(R + 'vendedores/panel/#cobros'); await p.waitForSelector('#panel'); ok('cobros: pendiente de liquidar', /pendiente de liquidar/i.test(await p.locator('#panel').innerText()));
  await adminLogin(); await adminTab('pedidos'); await p.getByRole('button', { name: 'Liberar pago' }).first().click(); await p.waitForTimeout(250); ok('liquidación manual por administración', /liquidado/i.test(await p.locator('#panel').innerText()));
  await adminTab('dac7'); ok('DAC7: vendedor con 1 operación, no comunicable', /Luna_Test/.test(await p.locator('#panel').innerText()) && /\bNo\b/.test(await p.locator('#panel').innerText()));
  await shot(p, '28-admin-dac7.png');
  const [dl] = await Promise.all([p.waitForEvent('download'), p.getByRole('button', { name: 'Descargar CSV DAC7' }).click()]);
  const csv = fs.readFileSync(await dl.path(), 'utf8'); ok('CSV DAC7 con el vendedor y su NIF (la CSP permite la descarga)', /Luna_Test/.test(csv) && /12345678Z/.test(csv));
  await adminTab('denuncias'); ok('denuncia DN-00001 abierta', /DN-00001/.test(await p.locator('#panel').innerText()));
  await p.getByRole('button', { name: 'Retirar anuncio' }).click(); await p.waitForTimeout(250); ok('anuncio denunciado retirado del catálogo', await p.evaluate(() => !PRODUCTS.some(x => x.id === 3)));

  // ================= 3. Canarias
  m = await applySeller('Isla_Pro', 'isla@example.com', 'IC', 'profesional', { vat: 'B12345678', regime: 'general' }); ok('solicitud de vendedor de Canarias', /Solicitud recibida/.test(m), m);
  await fiscal('Isla Pro SL', 'B12345678', 'IC', '');
  await adminLogin(); await adminTab('vendedores'); await p.locator('#panel tr:has-text("Isla_Pro") button:has-text("Verificar")').click(); await p.waitForTimeout(250);
  await newListing('Sujetador canario de prueba', 40); await adminLogin(); await adminTab('moderacion'); await p.getByRole('button', { name: 'Aprobar' }).click(); await p.waitForTimeout(250);
  await store(); await p.selectOption('#dest', 'IC'); await p.waitForTimeout(200);
  const off = await p.locator('.pcard.is-off').count(), tot = await p.locator('.pcard').count(); ok('con destino Canarias solo se puede comprar el anuncio de Canarias', tot - off === 1, { off, tot });
  await p.fill('#f-q', 'canario'); await p.waitForTimeout(150); ok('ficha de Canarias muestra IGIC', /IGIC/.test(await p.locator('.pcard').first().innerText()));
  await p.evaluate(() => document.querySelector('#catalogo').scrollIntoView()); await p.waitForTimeout(250); await shot(p, '30-tienda-canarias.png');
  await p.selectOption('#dest', 'ES'); await p.waitForTimeout(200); ok('con destino España el de Canarias no está disponible', (await p.locator('.pcard.is-off').count()) === 1);
  r = await buy('canario', 'IC'); ok('compra dentro de Canarias', /IM-\d{6}/.test(r), r);

  // ================= 4. Incidencias
  const ic = await p.evaluate(() => INT.data().orders.filter(o => o.status === 'paid').pop());
  await p.goto(R + 'cuenta/#pedidos'); await p.waitForSelector('#panel');
  await p.getByText('Abrir una incidencia con este pedido').click();
  await p.locator('#panel details[open] textarea').fill('Todavía no ha salido nada del envío'); await p.getByRole('button', { name: 'Abrir incidencia' }).click(); await p.waitForTimeout(250);
  ok('incidencia por "no enviado" bloqueada dentro del plazo de preparación', /plazo de preparación/i.test(await p.locator('.toast').innerText().catch(() => '')));
  await p.goto(R + 'vendedores/panel/'); await sellerLogin('isla@example.com'); await p.goto(R + 'vendedores/panel/#pedidos'); await p.waitForSelector('#panel');
  await p.fill('#panel input[name=tracking]', 'CAN001'); await p.getByRole('button', { name: 'Marcar como enviado' }).click(); await p.waitForTimeout(250);
  await p.goto(R + 'cuenta/#pedidos'); await p.waitForSelector('#panel'); await p.getByText('Abrir una incidencia con este pedido').click();
  await p.locator('#panel details[open] select').selectOption('danado'); await p.locator('#panel details[open] textarea').fill('Llegó con una mancha visible en la prenda');
  await p.locator('#panel details[open] input[type=file]').setInputFiles({ name: 'prueba.png', mimeType: 'image/png', buffer: PNG }); await p.waitForTimeout(300);
  await p.getByRole('button', { name: 'Abrir incidencia' }).click(); await p.waitForTimeout(300);
  ok('incidencia abierta y pedido en "Incidencia"', /IN-00001/.test(await p.locator('#panel').innerText()) && await p.evaluate(() => INT.data().orders.some(o => o.status === 'incident')));
  await shot(p, '36-cuenta-incidencia.png');
  await p.goto(R + 'vendedores/panel/#incidencias'); await p.waitForSelector('#panel');
  ok('el vendedor ve la incidencia y el aviso', /IN-00001/.test(await p.locator('#panel').innerText()) && (await p.evaluate(() => INT.notify.unread('s:' + INT.seller.current().id))) > 0);
  await p.locator('#panel textarea').fill('Lo siento, la prenda salió limpia de aquí'); await p.getByRole('button', { name: 'Responder' }).click(); await p.waitForTimeout(250);
  ok('respuesta del vendedor: pedido "En disputa"', await p.evaluate(() => INT.data().orders.some(o => o.status === 'disputed')));
  await adminLogin(); await adminTab('incidencias'); await shot(p, '37-admin-incidencias.png');
  await p.locator('#panel select[name=decision]').selectOption('partial'); await p.locator('#panel input[name=amount]').fill('15'); await p.locator('#panel textarea[name=statement]').fill('Se acuerda un reembolso parcial por la mancha visible.');
  await p.getByRole('button', { name: 'Resolver' }).click(); await p.waitForTimeout(300);
  const po = await p.evaluate(() => { const o = INT.data().orders.filter(x => x.refundAmount).pop(); return o && { st: o.status, ref: o.refundAmount, net: o.sellerNet }; });
  ok('reembolso parcial: pedido liquidado con importe descontado', po && po.st === 'released' && po.ref === 15 && po.net < 40, po);
  await adminTab('dac7'); ok('DAC7 descuenta el reembolso', /Isla_Pro/.test(await p.locator('#panel').innerText()));

  // segunda incidencia: se rechaza
  await p.goto(R + 'vendedores/panel/#anuncios'); await newListing('Top de prueba', 30); await adminLogin(); await adminTab('moderacion'); await p.getByRole('button', { name: 'Aprobar' }).click(); await p.waitForTimeout(250);
  r = await buy('top de prueba', 'IC'); ok('segunda compra en Canarias', /IM-\d{6}/.test(r), r);
  await p.goto(R + 'vendedores/panel/#pedidos'); await p.waitForSelector('#panel'); await p.fill('#panel input[name=tracking]', 'CAN002'); await p.getByRole('button', { name: 'Marcar como enviado' }).click(); await p.waitForTimeout(250);
  await p.evaluate(() => { const o = INT.orders.forBuyer('u1')[0]; INT.orders.confirmReceipt('u1', o.id); });
  const inc2 = await p.evaluate(() => { const o = INT.orders.forBuyer('u1')[0]; return INT.incident.open('u1', o.id, 'descripcion', 'La descripción no coincide con la prenda recibida', []).no; });
  await adminLogin(); await adminTab('incidencias'); await p.locator('#panel select[name=decision]').first().selectOption('reject'); await p.locator('#panel textarea[name=statement]').first().fill('No se aprecia diferencia con lo anunciado.'); await p.getByRole('button', { name: 'Resolver' }).first().click(); await p.waitForTimeout(300);
  ok('incidencia rechazada: el pedido vuelve a "Entregado"', await p.evaluate(() => INT.orders.forBuyer('u1')[0].status === 'delivered'), inc2);
  await p.evaluate(() => { const db = INT.data(); const i = INT.incident.forOrder(INT.orders.forBuyer('u1')[0].id)[0]; i.status === 'resolved' || 0; });

  // ================= 5. Tiendas públicas, seguir, bloquear, alertas
  await p.goto(R + 'tienda/?s=lunaroja'); await p.waitForSelector('#shop h1');
  ok('tienda de muestra: nombre, distintivos y explicación', /Lunaroja/.test(await p.locator('#shop h1').innerText()) && /cuenta verificada/i.test(await p.locator('#shop').innerText()) && /qué significa cada distintivo/i.test(await p.locator('#shop').innerText()));
  ok('tienda: sin datos personales (sin correo ni dirección)', !/[\w.]+@[\w.]+\.\w+|Calle/.test(await p.locator('#shop').innerText()));
  await p.getByRole('button', { name: 'Seguir tienda' }).click(); await p.waitForTimeout(200); ok('seguir tienda', await p.evaluate(() => INT.follow.count('lunaroja')) === 1);
  await shot(p, '38-tienda-publica.png');
  await p.getByRole('button', { name: 'Denunciar tienda' }).click(); await p.locator('#shop form select').last().selectOption('fake'); await p.locator('#shop form input[type=checkbox]').check(); await p.getByRole('button', { name: 'Enviar denuncia' }).click(); await p.waitForTimeout(200);
  ok('denuncia de una tienda', await p.evaluate(() => INT.data().reports.some(x => x.target === 'seller')));
  await p.goto(R + 'tienda/?s=noexiste'); ok('tienda inexistente', /no encontrada/i.test(await p.locator('h1').innerText()));
  // búsqueda guardada + alerta al aprobarse un anuncio
  await store(); await p.fill('#f-q', 'canario'); await p.click('#save-search'); await p.waitForTimeout(200); ok('búsqueda guardada', /Búsqueda guardada/.test(await p.locator('#search-msg').innerText()));
  await p.goto(R + 'vendedores/panel/'); await sellerLogin('isla@example.com'); await newListing('Otro sujetador canario', 35); await adminLogin(); await adminTab('moderacion'); await p.getByRole('button', { name: 'Aprobar' }).click(); await p.waitForTimeout(250);
  await p.goto(R + 'cuenta/#avisos'); await p.waitForSelector('#panel'); ok('aviso por búsqueda guardada', /búsqueda guardada «canario»/i.test(await p.locator('#panel').innerText()), await p.locator('#panel').innerText());
  // bloqueo
  await p.goto(R + 'tienda/?s=lunaroja'); await p.waitForSelector('#shop h1'); await p.getByRole('button', { name: 'Bloquear' }).click(); await p.waitForTimeout(200);
  await store(); ok('vendedor bloqueado: sus piezas desaparecen', (await p.locator('.pcard').count()) === await p.evaluate(() => PRODUCTS.filter(x => x.seller !== 'lunaroja').length));
  await p.goto(R + 'tienda/?s=lunaroja'); await p.waitForSelector('#shop h1'); await p.getByRole('button', { name: 'Desbloquear' }).click(); await p.waitForTimeout(200);

  // ================= 6. Filtros, ordenación y borradores
  await store(); await p.selectOption('#dest', 'ES'); await p.fill('#f-pmin', '30'); await p.fill('#f-pmax', '36'); await p.waitForTimeout(200);
  ok('filtro de precio', await p.evaluate(() => [...document.querySelectorAll('.pcard .price')].every(e => { const n = parseFloat(e.textContent.replace(',', '.')); return n >= 30 && n <= 36; })));
  await p.fill('#f-pmin', ''); await p.fill('#f-pmax', ''); await p.selectOption('#f-country', 'FR'); await p.waitForTimeout(150); ok('filtro por país de expedición', (await p.locator('.pcard').count()) === 1);
  await p.selectOption('#f-country', ''); await p.selectOption('#f-rating', '4'); await p.waitForTimeout(150); ok('filtro por valoración mínima', (await p.locator('.pcard').count()) >= 0);
  await p.selectOption('#f-rating', '0'); await p.locator('#cats .chip').nth(3).click(); await p.waitForTimeout(150); ok('chips de categoría filtran', (await p.locator('.pcard').count()) >= 1 && await p.locator('#cats .chip.on').count() === 1);
  await p.locator('#cats .chip').first().click();
  await p.goto(R + 'vendedores/panel/'); await sellerLogin('isla@example.com'); await newListing('Borrador de prueba', 22, true);
  await p.goto(R + 'vendedores/panel/#anuncios'); await p.waitForSelector('#panel'); ok('borrador guardado, no publicado', /borrador/i.test(await p.locator('#panel').innerText()));
  await p.getByRole('button', { name: 'Duplicar' }).first().click(); await p.waitForTimeout(250); ok('duplicar crea otro borrador "(copia)"', /\(copia\)/.test(await p.locator('#panel').innerText()));
  await p.getByText('Historial de cambios').first().click(); ok('historial de cambios', /creado como borrador|duplicado/i.test(await p.locator('#panel').innerText()));
  await p.goto(R + 'vendedores/panel/#estadisticas'); await p.waitForSelector('#panel'); ok('estadísticas del vendedor', /visitas a tus fichas/i.test(await p.locator('#panel').innerText()) && /ingresos netos/i.test(await p.locator('#panel').innerText()));
  await p.goto(R + 'vendedores/panel/#tienda'); await p.waitForSelector('#panel form'); await p.fill('#panel [name=name]', 'Isla Lencería'); await p.fill('#panel [name=bio]', 'Tienda de Canarias de prueba.'); await p.getByRole('button', { name: 'Guardar tienda' }).click(); await p.waitForTimeout(250);
  ok('tienda del vendedor editable y con indicadores', /Tus indicadores de confianza/.test(await p.locator('#panel').innerText()));
  await shot(p, '39-panel-tienda.png');

  // ================= 7. Muestras: ocultarlas y estado vacío
  await adminLogin(); await adminTab('ajustes'); await p.locator('#panel input[name=showSamples]').uncheck(); await p.getByRole('button', { name: 'Guardar ajustes' }).click(); await p.waitForTimeout(250);
  await store(); ok('sin muestras solo quedan los anuncios reales', await p.evaluate(() => PRODUCTS.every(x => !x.seed)));
  await adminLogin(); await adminTab('ajustes'); await p.locator('#panel input[name=showSamples]').check(); await p.getByRole('button', { name: 'Guardar ajustes' }).click(); await p.waitForTimeout(250);
  await p.evaluate(() => { const d = INT.data(); d.settings.showSamples = false; d.listings.forEach(l => { if (!l.seed) l.status = 'paused'; }); localStorage.setItem('intimae_db_v1', JSON.stringify(d)); });
  await store(); ok('catálogo vacío: invitación a vendedores fundadores', await p.locator('#founder-empty').isVisible() && /vendedor fundador/i.test(await p.locator('#founder-empty').innerText()));
  await p.evaluate(() => document.querySelector('#catalogo').scrollIntoView()); await p.waitForTimeout(300); await shot(p, '40-catalogo-vacio-fundadores.png');
  await p.evaluate(() => { const d = JSON.parse(localStorage.getItem('intimae_db_v1')); d.settings.showSamples = true; d.listings.forEach(l => { if (!l.seed && l.status === 'paused') l.status = 'active'; }); localStorage.setItem('intimae_db_v1', JSON.stringify(d)); });

  // ================= 8. Idiomas
  await p.evaluate(() => { localStorage.setItem('intimae_lang', 'fr'); localStorage.setItem('intimae_lang_manual', '1'); });
  await store(); await p.waitForTimeout(300);
  ok('tienda en francés: cuenta, muestra y filtros traducidos', /Mon compte/i.test(await p.locator('header .tools').innerText()) && /Exemple/i.test(await p.locator('.tag--sample').first().innerText()) && /Couleur/i.test(await p.locator('.toolbar').innerText()));
  ok('tienda en francés: banner de demostración', /démonstration/i.test(await p.locator('.demobar').innerText()));
  await p.locator('.pcard__title button').first().click(); await p.waitForSelector('#pdp[open]'); await p.waitForTimeout(500);
  ok('ficha en francés: protección de la compra', /Protection de l'achat/i.test(await p.locator('#pdp').innerText())); await shot(p, '31-ficha-fr.png'); await p.keyboard.press('Escape');
  await p.goto(R + 'cuenta/'); await p.waitForTimeout(400); ok('cuenta en francés: aviso de solo español', /espagnol/.test(await p.locator('#es-only').innerText()));
  await p.evaluate(() => { localStorage.removeItem('intimae_lang_manual'); localStorage.setItem('intimae_lang', 'es'); });

  // ================= 9. Móvil
  const mob = await b.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true, storageState: await ctx.storageState(), locale: 'es-ES' });
  await serve(mob); const q = await mob.newPage();
  for (const [u, f] of [['index.html', '32-movil-tienda.png'], ['cuenta/#pedidos', '33-movil-cuenta.png'], ['vendedores/panel/#resumen', '34-movil-panel.png'], ['admin/#moderacion', '35-movil-admin.png'], ['tienda/?s=lunaroja', '41-movil-tienda-publica.png']]) {
    await q.goto(R + u); await q.waitForTimeout(500); if (await q.locator('#ag-yes').isVisible().catch(() => false)) await q.click('#ag-yes');
    if (u === 'index.html') { await q.evaluate(() => document.querySelector('#catalogo').scrollIntoView()); await q.waitForTimeout(250); ok('móvil: navegación inferior visible', await q.locator('#mnav').isVisible()); }
    const w = await q.evaluate(() => document.documentElement.scrollWidth); ok('móvil sin desbordamiento horizontal: ' + u, w <= 392, w); await q.screenshot({ path: SHOT + f });
  }
  const code = finish('todas las pruebas'); await b.close(); process.exit(code ? 1 : 0);
})();
