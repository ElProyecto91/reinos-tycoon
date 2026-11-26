/*
 * Intimae · capa de datos (MODO DEMOSTRACIÓN).
 *
 * Todo se guarda en el almacenamiento local del navegador. No hay servidor: no hay seguridad real, los
 * datos no se comparten entre personas y las contraseñas, la verificación de edad y los pagos son simulados.
 * La API (INT.buyer, INT.seller, INT.listing, INT.orders, INT.msg, INT.review, INT.fav, INT.report, INT.admin,
 * INT.pay, INT.age) está pensada para sustituirse por un backend real (esquema en db/schema.sql) sin tocar
 * la interfaz.
 *
 * Política del producto: Intimae es intermediario y no es parte de la compraventa, pero ofrece un procedimiento de
 * incidencias (INT.incident): el comprador abre una incidencia con motivo y pruebas, el vendedor responde, y la
 * administración resuelve dentro de sus facultades y de las reglas del proveedor de pagos. Mientras hay una
 * incidencia abierta la liquidación al vendedor queda en pausa. No se promete ninguna protección fuera de ese
 * procedimiento. Los estados de pago y de pedido proceden del proveedor y del servidor; aquí se simulan.
 */
(function () {
  "use strict";

  var KEY = "intimae_db_v1", SKEY = "intimae_sess_v1";
  var SEED_SELLERS = window.SELLERS || {}, SEED_PRODUCTS = window.PRODUCTS || [];
  var ADMIN_SALT = "demo", ADMIN_HASH = "733a7a7fdaee1064ccffb81b474fb97de1c55b7b5b1694d4594ae0c54d0a78f0"; // contraseña de demostración: demo-admin
  var TYPES = ["braga", "tanga", "sujetador", "camison", "conjunto"], SIZES = ["S", "M", "L", "XL"];
  var DAC7 = { ops: 30, amount: 2000 };

  var db = null, listeners = [], memoryOnly = false;

  /* ---------- utilidades ---------- */
  function T(n, v) { try { if (window.TEL) window.TEL.track(n, v); } catch (e) {} }
  function clone(o) { return JSON.parse(JSON.stringify(o)); }
  function now() { return Date.now(); }
  function today() { return new Date().toISOString().slice(0, 10); }
  function r2(n) { return Math.round(n * 100) / 100; }
  function pad(n, l) { var s = String(n); while (s.length < l) s = "0" + s; return s; }
  function fail(code, text) { var e = new Error(text || code); e.code = code; throw e; }
  function find(arr, fn) { for (var i = 0; i < arr.length; i++) if (fn(arr[i])) return arr[i]; return null; }
  function hex(buf) { return Array.prototype.map.call(new Uint8Array(buf), function (b) { return ("0" + b.toString(16)).slice(-2); }).join(""); }
  function sha(text) {
    if (!window.crypto || !crypto.subtle) return Promise.reject(Object.assign(new Error("Este navegador no permite crear cuentas (hace falta conexión segura)."), { code: "crypto" }));
    return crypto.subtle.digest("SHA-256", new TextEncoder().encode(text)).then(hex);
  }
  function newSalt() { var a = new Uint8Array(8); crypto.getRandomValues(a); return hex(a); }
  function validEmail(e) { return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(e); }
  function cleanText(s, max) { return String(s == null ? "" : s).replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/g, "").trim().slice(0, max || 500); }

  /* ---------- persistencia ---------- */
  function seed() {
    var d = {
      v: 2,
      seq: { user: 0, seller: 0, listing: 0, order: 0, thread: 0, review: 0, report: 0, incident: 0, note: 0, search: 0 },
      users: [], sellers: [], listings: [], orders: [], threads: [], reviews: [], favs: [], reports: [], audit: [],
      incidents: [], notes: [], searches: [], follows: [], blocks: [], acceptances: [],
      settings: { commission: 20, autoDeliverDays: 10, autoReleaseDays: 7, shipDeadlineDays: 7, incidentReplyDays: 5, showSamples: true }
    };
    Object.keys(SEED_SELLERS).forEach(function (k) {
      var s = SEED_SELLERS[k];
      d.sellers.push({ id: k, alias: s.alias, country: s.country, type: s.type, vat: s.vat, since: s.since, bio: s.bio || "", status: "verified", seed: true });
    });
    SEED_PRODUCTS.forEach(function (p) {
      var q = clone(p); q.status = "active"; q.seed = true; d.listings.push(q);
      d.seq.listing = Math.max(d.seq.listing, p.id);
    });
    return d;
  }
  function load() {
    try { var raw = localStorage.getItem(KEY); if (raw) db = JSON.parse(raw); } catch (e) { db = null; }
    if (!db || db.v !== 2) { db = seed(); save(); }
  }
  function save() {
    try { localStorage.setItem(KEY, JSON.stringify(db)); memoryOnly = false; return true; }
    catch (e) { memoryOnly = true; return false; }
  }
  function sess() { try { return JSON.parse(localStorage.getItem(SKEY) || "{}") || {}; } catch (e) { return {}; } }
  function setSess(o) { try { localStorage.setItem(SKEY, JSON.stringify(o)); } catch (e) {} }

  function log(actor, action, detail) {
    db.audit.push({ at: now(), actor: actor, action: action, detail: detail || "" });
    if (db.audit.length > 500) db.audit.splice(0, db.audit.length - 500);
  }

  // Vistas que usa la tienda: vendedores verificados y anuncios activos.
  function sync() {
    var S = {}, samples = db.settings.showSamples !== false;
    db.sellers.forEach(function (s) { if (s.status === "verified" && (samples || !s.seed)) S[s.id] = s; });
    window.SELLERS = S;
    window.PRODUCTS = db.listings.filter(function (p) { return p.status === "active" && S[p.seller]; })
      .sort(function (a, b) { return a.id - b.id; });
  }
  // Avisos internos: para = "b:<comprador>", "s:<vendedor>" o "a" (administración)
  function note(to, text, link) {
    db.notes.push({ id: ++db.seq.note, to: to, text: text, link: link || "", at: now(), read: false });
    if (db.notes.length > 500) db.notes.splice(0, db.notes.length - 500);
  }
  function commit() { var ok = save(); sync(); listeners.forEach(function (fn) { try { fn(); } catch (e) {} }); return ok; }

  /* ---------- tareas automáticas (envío → entrega → liberación del pago) ---------- */
  function tick() {
    var t = now(), changed = false, st = db.settings;
    db.orders.forEach(function (o) {
      if (o.status === "shipped" && t - o.shippedAt >= st.autoDeliverDays * 864e5) { move(o, "delivered", "sistema", "entrega automática"); o.deliveredAt = t; changed = true; }
      if (o.status === "delivered" && t - o.deliveredAt >= st.autoReleaseDays * 864e5) { release(o, "sistema"); changed = true; }
    });
    db.incidents.forEach(function (i) {
      if (i.status === "open" && t - i.at >= st.incidentReplyDays * 864e5) {
        var o = orders.get(i.order); i.status = "disputed";
        i.messages.push({ from: "a", text: "El vendedor no ha respondido en plazo. La incidencia pasa a revisión.", at: t });
        if (o && o.status === "incident") move(o, "disputed", "sistema", "sin respuesta del vendedor");
        note("a", "Incidencia " + i.no + " sin respuesta del vendedor", "incidencias"); changed = true;
      }
    });
    if (changed) commit();
  }
  function move(o, status, by, note) { o.status = status; o.history.push({ at: now(), status: status, by: by, note: note || "" }); }
  function release(o, by) { var res = pay.provider.payout(o.sellerNet, o.no); o.releasedAt = now(); o.payoutRef = res.ref; move(o, "released", by, "liquidado al vendedor"); log(by, "liquidación", o.no); T("order.released"); T("payout.cents", Math.round(o.sellerNet * 100)); note("s:" + o.seller, "Pedido " + o.no + " liquidado: " + o.sellerNet.toFixed(2) + " €", "cobros"); }

  /* ---------- pagos (proveedor intercambiable) ---------- */
  var pay = {
    // Sustituir por el proveedor real cuando exista confirmación escrita (ver docs/CONSULTA-PROCESADORES.md).
    provider: {
      name: "demo",
      charge: function (amount, ref) { return { ok: true, ref: "demo_ch_" + ref }; },
      payout: function (amount, ref) { return { ok: true, ref: "demo_po_" + ref }; },
      refund: function (amount, ref) { return { ok: true, ref: "demo_rf_" + ref }; }
    },
    commissionFor: function (subtotal) { return r2(subtotal * db.settings.commission / 100); }
  };

  /* ---------- verificación de edad (proveedor intercambiable) ---------- */
  var age = {
    // SIMULACIÓN: pide la fecha de nacimiento, comprueba que hay 18 años y NO la guarda. Sustituir por un proveedor externo.
    provider: "demo",
    check: function (y, m, d) {
      var b = new Date(+y, +m - 1, +d);
      if (isNaN(b) || b.getFullYear() !== +y || b.getMonth() !== +m - 1 || b.getDate() !== +d) fail("date", "Fecha no válida.");
      var n = new Date(), a = n.getFullYear() - b.getFullYear();
      if (n.getMonth() < b.getMonth() || (n.getMonth() === b.getMonth() && n.getDate() < b.getDate())) a--;
      if (a < 18 || a > 110) fail("minor", "Debes ser mayor de 18 años.");
      return { at: now(), method: "demo" };
    }
  };

  /* ---------- compradores ---------- */
  var buyer = {
    current: function () { var id = sess().buyer; var u = id && find(db.users, function (x) { return x.id === id && !x.deleted; }); return u || null; },
    register: function (o) {
      var email = cleanText(o.email, 120).toLowerCase();
      if (!validEmail(email)) fail("email", "Correo no válido.");
      if (String(o.pass || "").length < 8) fail("pass", "La contraseña debe tener al menos 8 caracteres.");
      if (!o.accept) fail("accept", "Debes aceptar las condiciones y la política de privacidad.");
      if (find(db.users, function (x) { return x.email === email; })) fail("exists", "Ya existe una cuenta con ese correo.");
      var salt = newSalt();
      return sha(salt + ":" + o.pass).then(function (h) {
        var u = { id: "u" + (++db.seq.user), email: email, name: cleanText(o.name, 60), addr: "", country: "", salt: salt, hash: h, ageVerified: null, createdAt: now() };
        db.users.push(u); db.acceptances.push({ who: "comprador " + u.id, doc: "condiciones de compra y privacidad", version: "borrador 2026-11", at: now() }); log("comprador " + u.id, "alta"); T("signup.buyer"); commit();
        var s = sess(); s.buyer = u.id; setSess(s); listeners.forEach(function (fn) { fn(); }); return u;
      });
    },
    login: function (email, pass) {
      var u = find(db.users, function (x) { return x.email === cleanText(email, 120).toLowerCase() && !x.deleted; });
      if (!u) return Promise.reject(Object.assign(new Error("Correo o contraseña incorrectos."), { code: "auth" }));
      return sha(u.salt + ":" + pass).then(function (h) {
        if (h !== u.hash) fail("auth", "Correo o contraseña incorrectos.");
        var s = sess(); s.buyer = u.id; setSess(s); listeners.forEach(function (fn) { fn(); }); return u;
      });
    },
    logout: function () { var s = sess(); delete s.buyer; setSess(s); listeners.forEach(function (fn) { fn(); }); },
    update: function (patch) {
      var u = buyer.current(); if (!u) fail("auth");
      if (patch.name != null) u.name = cleanText(patch.name, 60);
      if (patch.addr != null) u.addr = cleanText(patch.addr, 300);
      if (patch.country != null) u.country = cleanText(patch.country, 3);
      commit(); return u;
    },
    verifyAge: function (y, m, d) {
      var u = buyer.current(); if (!u) fail("auth");
      u.ageVerified = age.check(y, m, d); log("comprador " + u.id, "edad verificada (" + age.provider + ")"); commit(); return u;
    },
    exportData: function () {
      var u = buyer.current(); if (!u) fail("auth");
      var copy = clone(u); delete copy.hash; delete copy.salt;
      return { cuenta: copy,
        pedidos: db.orders.filter(function (o) { return o.buyer === u.id; }),
        mensajes: db.threads.filter(function (t) { return t.buyer === u.id; }),
        favoritos: db.favs.filter(function (f) { return f.buyer === u.id; }),
        valoraciones: db.reviews.filter(function (r) { return r.buyer === u.id; }) };
    },
    remove: function () {
      var u = buyer.current(); if (!u) fail("auth");
      var open = db.orders.some(function (o) { return o.buyer === u.id && ["paid", "shipped", "delivered", "incident", "disputed"].indexOf(o.status) !== -1; });
      if (open) fail("open", "Tienes pedidos en curso. Podrás cerrar la cuenta cuando se completen.");
      u.deleted = true; u.email = "eliminado-" + u.id; u.name = ""; u.addr = ""; u.hash = ""; u.salt = "";
      db.favs = db.favs.filter(function (f) { return f.buyer !== u.id; });
      db.orders.forEach(function (o) { if (o.buyer === u.id) o.addr = { name: "", line: "", country: o.addr.country }; });
      log("comprador " + u.id, "cuenta eliminada"); buyer.logout(); commit();
    }
  };

  /* ---------- vendedores ---------- */
  var seller = {
    current: function () { var id = sess().seller; return (id && find(db.sellers, function (x) { return x.id === id && !x.seed; })) || null; },
    apply: function (o) {
      var email = cleanText(o.email, 120).toLowerCase(), alias = cleanText(o.alias, 30);
      if (alias.length < 3) fail("alias", "El alias debe tener al menos 3 caracteres.");
      if (!validEmail(email)) fail("email", "Correo no válido.");
      if (String(o.pass || "").length < 8) fail("pass", "La contraseña debe tener al menos 8 caracteres.");
      if (+o.age < 18) fail("minor", "Debes ser mayor de 18 años para vender.");
      if (!o.accept) fail("accept", "Debes aceptar las condiciones para vendedores.");
      if (!window.TAX.get(o.country)) fail("country", "País no válido.");
      if (find(db.sellers, function (x) { return x.alias.toLowerCase() === alias.toLowerCase() || (x.email && x.email === email); })) fail("exists", "Ya existe una solicitud con ese correo o alias.");
      var pro = o.kind === "profesional", salt = newSalt();
      return sha(salt + ":" + o.pass).then(function (h) {
        var s = { id: "s" + (++db.seq.seller), alias: alias, email: email, salt: salt, hash: h, country: o.country, comm: o.comm || "es",
          type: pro ? "profesional" : "particular", vat: pro ? (o.regime === "margin" ? "margin" : "standard") : "none",
          vatId: pro ? cleanText(o.vatId, 20).toUpperCase() : "", about: cleanText(o.about, 400), since: new Date().getFullYear(),
          status: "pending", fiscal: {}, createdAt: now() };
        db.sellers.push(s); db.acceptances.push({ who: "vendedor " + s.id, doc: "condiciones para vendedores", version: "borrador 2026-11", at: now() }); log("vendedor " + s.id, "solicitud", alias); T("signup.seller"); commit();
        var ss = sess(); ss.seller = s.id; setSess(ss); return s;
      });
    },
    login: function (email, pass) {
      var u = find(db.sellers, function (x) { return x.email && x.email === cleanText(email, 120).toLowerCase(); });
      if (!u) return Promise.reject(Object.assign(new Error("Correo o contraseña incorrectos."), { code: "auth" }));
      return sha(u.salt + ":" + pass).then(function (h) {
        if (h !== u.hash) fail("auth", "Correo o contraseña incorrectos.");
        var s = sess(); s.seller = u.id; setSess(s); return u;
      });
    },
    logout: function () { var s = sess(); delete s.seller; setSess(s); },
    // Datos para la declaración DAC7. En producción los gestiona el proveedor de verificación.
    saveFiscal: function (f) {
      var s = seller.current(); if (!s) fail("auth");
      var need = ["legalName", "taxId", "address", "taxCountry"]; if (s.type === "particular") need.push("birth");
      var clean = {}; ["legalName", "taxId", "address", "taxCountry", "birth"].forEach(function (k) { clean[k] = cleanText(f[k], 200); });
      clean.complete = need.every(function (k) { return !!clean[k]; });
      s.fiscal = clean; log("vendedor " + s.id, "datos fiscales guardados"); commit(); return s;
    },
    rating: function (sellerId) {
      var rs = db.reviews.filter(function (r) { return r.seller === sellerId; });
      if (!rs.length) return { n: 0, avg: 0 };
      return { n: rs.length, avg: r2(rs.reduce(function (a, r) { return a + r.rating; }, 0) / rs.length) };
    },
    statement: function (sellerId) {
      var mine = db.orders.filter(function (o) { return o.seller === sellerId; });
      var sum = function (st) { return r2(mine.filter(function (o) { return st.indexOf(o.status) !== -1; }).reduce(function (a, o) { return a + o.sellerNet; }, 0)); };
      return { orders: mine, pending: sum(["paid", "shipped", "delivered", "incident", "disputed"]), released: sum(["released"]) };
    }
  };

  /* ---------- anuncios ---------- */
  function validateListing(d) {
    if (TYPES.indexOf(d.type) === -1) fail("type", "Tipo de prenda no válido.");
    if (SIZES.indexOf(d.size) === -1) fail("size", "Talla no válida.");
    var title = cleanText(d.title, 80); if (title.length < 3) fail("title", "El título es demasiado corto.");
    var price = r2(+d.price); if (!(price >= 5 && price <= 500)) fail("price", "El precio debe estar entre 5 y 500 €.");
    var days = Math.round(+d.days); if (!(days >= 0 && days <= 60)) fail("days", "Los días de uso deben estar entre 0 y 60.");
    var imgs = (d.imgs || []).filter(function (x) { return /^data:image\/(jpeg|png|webp);base64,/.test(x); }).slice(0, 3);
    if (!imgs.length) fail("img", "Añade al menos una foto de la prenda.");
    return { type: d.type, size: d.size, title: title, price: price, days: days, material: cleanText(d.material, 60) || "—", colour: cleanText(d.colour, 40) || "—", desc: cleanText(d.desc, 400), imgs: imgs, img: imgs[0] };
  }
  function hist(l, action) { (l.history = l.history || []).push({ at: now(), action: action }); if (l.history.length > 40) l.history.shift(); }
  var listing = {
    create: function (sellerId, d, draft) {
      var s = find(db.sellers, function (x) { return x.id === sellerId; });
      if (!s || s.status !== "verified") fail("verify", "Tu cuenta debe estar verificada para publicar.");
      var v = validateListing(d), id = ++db.seq.listing;
      var l = Object.assign({ id: id, ref: pad(id, 4), seller: sellerId, date: today(), status: draft ? "draft" : "pending", moderation: null, views: 0, history: [] }, v);
      hist(l, draft ? "creado como borrador" : "enviado a revisión");
      db.listings.push(l);
      if (!commit()) { db.listings.pop(); db.seq.listing--; sync(); fail("storage", "No hay espacio en el navegador: usa fotos más pequeñas."); }
      log("vendedor " + sellerId, "anuncio creado", l.ref); T("listing.created"); commit(); return l;
    },
    update: function (sellerId, id, d, draft) {
      var l = find(db.listings, function (x) { return x.id === id && x.seller === sellerId; });
      if (!l || ["sold", "removed"].indexOf(l.status) !== -1) fail("state", "Este anuncio no se puede editar.");
      Object.assign(l, validateListing(d)); l.status = draft ? "draft" : "pending"; l.moderation = null;
      hist(l, draft ? "editado (borrador)" : "editado y enviado a revisión");
      log("vendedor " + sellerId, "anuncio editado", l.ref); commit(); return l;
    },
    submit: function (sellerId, id) {
      var l = find(db.listings, function (x) { return x.id === id && x.seller === sellerId; });
      if (!l || l.status !== "draft") fail("state", "Solo se puede enviar a revisión un borrador.");
      l.status = "pending"; hist(l, "enviado a revisión"); commit(); return l;
    },
    duplicate: function (sellerId, id) {
      var l = find(db.listings, function (x) { return x.id === id && x.seller === sellerId; });
      if (!l) fail("state");
      var nid = ++db.seq.listing, c = clone(l);
      Object.assign(c, { id: nid, ref: pad(nid, 4), title: (l.title + " (copia)").slice(0, 80), status: "draft", moderation: null, views: 0, date: today(), history: [], seed: false });
      hist(c, "duplicado de N.º " + l.ref); db.listings.push(c); commit(); return c;
    },
    setStatus: function (sellerId, id, status) {
      var l = find(db.listings, function (x) { return x.id === id && x.seller === sellerId; });
      if (!l) fail("state");
      if (status === "paused" && l.status === "active") l.status = "paused";
      else if (status === "active" && l.status === "paused") l.status = "active";
      else fail("state", "Cambio de estado no permitido.");
      hist(l, status === "paused" ? "pausado" : "reanudado"); commit(); return l;
    },
    remove: function (sellerId, id) {
      var l = find(db.listings, function (x) { return x.id === id && x.seller === sellerId; });
      if (!l || l.status === "sold") fail("state", "No se puede eliminar un anuncio vendido.");
      db.listings.splice(db.listings.indexOf(l), 1); db.favs = db.favs.filter(function (f) { return f.listing !== id; }); commit();
    },
    // Visita a la ficha: una por sesión del navegador y anuncio.
    view: function (id) {
      var l = listing.get(id); if (!l) return;
      try { var k = "intimae_v_" + l.id; if (sessionStorage.getItem(k)) return; sessionStorage.setItem(k, "1"); } catch (e) {}
      l.views = (l.views || 0) + 1; save();
    },
    get: function (id) { return find(db.listings, function (x) { return x.id === +id; }); },
    mine: function (sellerId) { return db.listings.filter(function (x) { return x.seller === sellerId; }); }
  };

  /* ---------- pedidos ---------- */
  var orders = {
    // listingIds: anuncios del carrito. Crea un pedido por vendedor (el envío se calcula por vendedor).
    create: function (buyerId, listingIds, dest, addr) {
      var u = find(db.users, function (x) { return x.id === buyerId && !x.deleted; });
      if (!u) fail("auth", "Inicia sesión como comprador.");
      if (!u.ageVerified) fail("age", "Verifica tu edad para pagar.");
      var c = window.TAX.get(dest); if (!c || !c.open) fail("dest", "Destino no disponible.");
      if (!addr || !cleanText(addr.name, 60) || !cleanText(addr.line, 300)) fail("addr", "Completa nombre y dirección de entrega.");
      var by = {};
      listingIds.forEach(function (id) {
        var l = listing.get(id), s = l && find(db.sellers, function (x) { return x.id === l.seller; });
        if (!l || l.status !== "active" || !s || s.status !== "verified") fail("stock", "Alguna prenda ya no está disponible.");
        var sh = window.TAX.shippable(s, dest); if (!sh.ok) fail("ship", "Alguna prenda no se puede enviar a tu país.");
        (by[l.seller] = by[l.seller] || []).push(l);
      });
      var out = [];
      Object.keys(by).forEach(function (sid) {
        var s = find(db.sellers, function (x) { return x.id === sid; }), items = [], sub = 0, vat = 0, zone = null;
        by[sid].forEach(function (l) {
          var a = window.TAX.assess(l, s, dest); zone = a.zone; sub += a.unit; vat += a.vatIncluded;
          items.push({ listing: l.id, ref: l.ref, title: l.title, unit: a.unit, taxKey: a.titleKey });
        });
        var ship = window.TAX.shippingFor(zone), total = r2(sub + ship), comm = pay.commissionFor(sub), no = "IM-" + pad(++db.seq.order, 6);
        var ch = pay.provider.charge(total, no); if (!ch.ok) fail("pay", "El pago no se ha podido completar.");
        var o = { id: db.seq.order, no: no, buyer: u.id, seller: sid, items: items, zone: zone, subtotal: r2(sub), shipping: ship, vatIncluded: r2(vat), total: total,
          commissionPct: db.settings.commission, commission: comm, sellerNet: r2(sub - comm + ship), chargeRef: ch.ref, dest: dest,
          addr: { name: cleanText(addr.name, 60), line: cleanText(addr.line, 300), country: dest }, status: "paid", history: [], createdAt: now() };
        move(o, "paid", "comprador", "pago recibido");
        by[sid].forEach(function (l) { l.status = "sold"; });
        db.orders.push(o); out.push(o); log("comprador " + u.id, "pedido", no); T("order.created"); T("order.cents", Math.round(total * 100)); T("commission.cents", Math.round(comm * 100)); note("s:" + sid, "Nuevo pedido " + no + ": prepáralo y márcalo como enviado", "pedidos");
      });
      commit(); return out;
    },
    get: function (id) { return find(db.orders, function (o) { return o.id === +id; }); },
    forBuyer: function (id) { return db.orders.filter(function (o) { return o.buyer === id; }).sort(function (a, b) { return b.id - a.id; }); },
    forSeller: function (id) { return db.orders.filter(function (o) { return o.seller === id; }).sort(function (a, b) { return b.id - a.id; }); },
    ship: function (sellerId, id, carrier, tracking) {
      var o = orders.get(id); if (!o || o.seller !== sellerId || o.status !== "paid") fail("state", "El pedido no se puede marcar como enviado.");
      carrier = cleanText(carrier, 40); tracking = cleanText(tracking, 60);
      if (!carrier || !tracking) fail("tracking", "Indica transportista y número de seguimiento.");
      o.carrier = carrier; o.tracking = tracking; o.shippedAt = now(); move(o, "shipped", "vendedor", carrier + " " + tracking); T("order.shipped"); note("b:" + o.buyer, "Tu pedido " + o.no + " ha sido enviado (" + carrier + " " + tracking + ")", "pedidos"); commit(); return o;
    },
    // Solo antes del envío. No existen devoluciones ni reclamaciones en Intimae.
    cancel: function (role, actorId, id) {
      var o = orders.get(id); if (!o || o.status !== "paid") fail("state", "Solo se puede cancelar un pedido antes de que se envíe.");
      if ((role === "buyer" && o.buyer !== actorId) || (role === "seller" && o.seller !== actorId)) fail("auth");
      var rf = pay.provider.refund(o.total, o.no); o.refundRef = rf.ref; move(o, "cancelled", role, "cancelado antes del envío; importe devuelto íntegramente");
      o.items.forEach(function (it) { var l = listing.get(it.listing); if (l && l.status === "sold") l.status = "active"; });
      log(role + " " + actorId, "pedido cancelado", o.no); T("order.cancelled"); note(role === "buyer" ? "s:" + o.seller : "b:" + o.buyer, "El pedido " + o.no + " se ha cancelado y el importe se devuelve íntegro", role === "buyer" ? "pedidos" : "pedidos"); commit(); return o;
    },
    confirmReceipt: function (buyerId, id) {
      var o = orders.get(id); if (!o || o.buyer !== buyerId || o.status !== "shipped") fail("state", "El pedido no está en camino.");
      o.deliveredAt = now(); move(o, "delivered", "comprador", "recepción confirmada"); T("order.delivered"); note("s:" + o.seller, "El comprador ha confirmado la recepción del pedido " + o.no, "pedidos"); commit(); return o;
    }
  };

  /* ---------- mensajes ---------- */
  function blocked(text) { return /@|https?:\/\/|www\.|(?:\d[ .\-]?){7,}/i.test(text); }
  var msg = {
    blocked: blocked,
    start: function (buyerId, listingId, text) {
      text = cleanText(text, 600); if (text.length < 2) fail("text", "Escribe un mensaje.");
      if (blocked(text)) fail("blocked", "blocked");
      var l = listing.get(listingId); if (!l) fail("state", "Anuncio no encontrado.");
      if (block.has(buyerId, l.seller)) fail("blockedUser", "Has bloqueado a este vendedor.");
      var t = find(db.threads, function (x) { return x.buyer === buyerId && x.listing === l.id; });
      if (!t) { t = { id: ++db.seq.thread, listing: l.id, listingTitle: l.title, buyer: buyerId, seller: l.seller, msgs: [], readB: 0, readS: 0 }; db.threads.push(t); }
      t.msgs.push({ from: "b", text: text, at: now() }); t.readB = now(); T("message.sent"); note("s:" + t.seller, "Nuevo mensaje sobre «" + t.listingTitle + "»", "mensajes"); commit(); return t;
    },
    reply: function (threadId, role, text) {
      var t = find(db.threads, function (x) { return x.id === +threadId; }); if (!t) fail("state");
      text = cleanText(text, 600); if (text.length < 2) fail("text", "Escribe un mensaje.");
      if (blocked(text)) fail("blocked", "blocked");
      if (block.has(t.buyer, t.seller)) fail("blockedUser", "La conversación está bloqueada.");
      t.msgs.push({ from: role === "buyer" ? "b" : "s", text: text, at: now() }); t[role === "buyer" ? "readB" : "readS"] = now();
      note(role === "buyer" ? "s:" + t.seller : "b:" + t.buyer, "Nuevo mensaje sobre «" + t.listingTitle + "»", "mensajes"); commit(); return t;
    },
    markRead: function (threadId, role) { var t = find(db.threads, function (x) { return x.id === +threadId; }); if (t) { t[role === "buyer" ? "readB" : "readS"] = now(); save(); } },
    forBuyer: function (id) { return db.threads.filter(function (t) { return t.buyer === id; }).sort(function (a, b) { return last(b) - last(a); }); },
    forSeller: function (id) { return db.threads.filter(function (t) { return t.seller === id; }).sort(function (a, b) { return last(b) - last(a); }); },
    unread: function (t, role) { var r = role === "buyer" ? t.readB : t.readS, other = role === "buyer" ? "s" : "b"; return t.msgs.filter(function (m) { return m.from === other && m.at > r; }).length; }
  };
  function last(t) { return t.msgs.length ? t.msgs[t.msgs.length - 1].at : 0; }

  /* ---------- valoraciones y favoritos ---------- */
  var review = {
    create: function (buyerId, orderId, rating, text) {
      var o = orders.get(orderId); if (!o || o.buyer !== buyerId || ["delivered", "released"].indexOf(o.status) === -1) fail("state", "Solo puedes valorar pedidos recibidos.");
      if (find(db.reviews, function (r) { return r.order === o.id; })) fail("exists", "Ya has valorado este pedido.");
      rating = Math.round(+rating); if (!(rating >= 1 && rating <= 5)) fail("rating", "La valoración va de 1 a 5.");
      db.reviews.push({ id: ++db.seq.review, order: o.id, buyer: buyerId, seller: o.seller, rating: rating, text: cleanText(text, 300), at: now() }); T("review.created"); note("s:" + o.seller, "Nueva valoración de " + rating + " estrellas en el pedido " + o.no, "valoraciones"); commit();
    },
    reply: function (sellerId, reviewId, text) {
      var r = find(db.reviews, function (x) { return x.id === +reviewId && x.seller === sellerId; }); if (!r) fail("state");
      if (r.reply) fail("exists", "Ya has respondido a esta valoración.");
      text = cleanText(text, 300); if (text.length < 2) fail("text", "Escribe una respuesta."); r.reply = { text: text, at: now() }; commit(); return r;
    },
    forOrder: function (orderId) { return find(db.reviews, function (r) { return r.order === +orderId; }); },
    forSeller: function (sellerId) { return db.reviews.filter(function (r) { return r.seller === sellerId; }); }
  };
  var fav = {
    has: function (buyerId, id) { return !!find(db.favs, function (f) { return f.buyer === buyerId && f.listing === id; }); },
    toggle: function (buyerId, id) {
      var f = find(db.favs, function (x) { return x.buyer === buyerId && x.listing === id; });
      if (f) db.favs.splice(db.favs.indexOf(f), 1); else db.favs.push({ buyer: buyerId, listing: id }); T(f ? "fav.removed" : "fav.added");
      commit(); return !f;
    },
    list: function (buyerId) { return db.favs.filter(function (f) { return f.buyer === buyerId; }).map(function (f) { return listing.get(f.listing); }).filter(Boolean); }
  };

  /* ---------- denuncias de contenido (Reglamento (UE) 2022/2065) ---------- */
  var report = {
    // o.listing: denuncia de un anuncio; o.seller: denuncia de una tienda/vendedor
    create: function (o) {
      var l = o.listing ? listing.get(o.listing) : null, sl = o.seller ? find(db.sellers, function (x) { return x.id === o.seller; }) : null;
      if (!l && !sl) fail("state", "Elemento no encontrado.");
      if (!o.good) fail("good", "Marca la declaración de buena fe.");
      var reason = cleanText(o.reason, 20), text = cleanText(o.text, 600);
      if (!reason) fail("reason", "Indica el motivo.");
      var r = { id: ++db.seq.report, no: "DN-" + pad(db.seq.report, 5), target: l ? "listing" : "seller", listing: l ? l.id : null, listingRef: l ? l.ref : "", seller: l ? l.seller : sl.id,
        reason: reason, text: text, email: cleanText(o.email, 120), status: "open", at: now() };
      db.reports.push(r); log("denunciante", "denuncia", r.no); T("report.created"); note("a", "Nueva denuncia " + r.no, "denuncias"); commit(); return r;
    }
  };

  /* ---------- administración ---------- */
  var admin = {
    isIn: function () { return !!sess().admin; },
    login: function (pass) { return sha(ADMIN_SALT + ":" + pass).then(function (h) { if (h !== ADMIN_HASH) fail("auth", "Contraseña incorrecta."); var s = sess(); s.admin = true; setSess(s); }); },
    logout: function () { var s = sess(); delete s.admin; setSess(s); },
    need: function () { if (!admin.isIn()) fail("auth", "Acceso restringido."); },
    approve: function (id) { admin.need(); var l = listing.get(id); if (!l || l.status !== "pending") fail("state"); l.status = "active"; l.moderation = { status: "approved", at: now() }; hist(l, "aprobado"); log("admin", "anuncio aprobado", l.ref); T("listing.approved");
      note("s:" + l.seller, "Tu anuncio N.º " + l.ref + " ha sido aprobado y ya está publicado", "anuncios");
      db.follows.forEach(function (f) { if (f.seller === l.seller) note("b:" + f.buyer, "Novedad de una tienda que sigues: «" + l.title + "»", "siguiendo"); });
      db.searches.forEach(function (q) { if (matchSearch(l, q)) note("b:" + q.buyer, "Coincide con tu búsqueda guardada «" + q.label + "»: «" + l.title + "»", "siguiendo"); });
      commit(); },
    reject: function (id, reason) { admin.need(); var l = listing.get(id); if (!l || l.status !== "pending") fail("state"); reason = cleanText(reason, 300); if (!reason) fail("reason", "Indica el motivo."); l.status = "rejected"; l.moderation = { status: "rejected", reason: reason, at: now() }; hist(l, "rechazado"); log("admin", "anuncio rechazado", l.ref); T("listing.rejected"); note("s:" + l.seller, "Tu anuncio N.º " + l.ref + " ha sido rechazado: " + reason, "resumen"); commit(); },
    verifySeller: function (id) {
      admin.need(); var s = find(db.sellers, function (x) { return x.id === id; });
      if (!s || s.seed) fail("state"); if (!s.fiscal || !s.fiscal.complete) fail("fiscal", "Faltan los datos fiscales (DAC7) del vendedor.");
      s.status = "verified"; log("admin", "vendedor verificado", s.alias); T("seller.verified"); note("s:" + s.id, "Tu cuenta ha sido verificada: ya puedes publicar", "anuncios"); commit();
    },
    setSellerStatus: function (id, status) {
      admin.need(); var s = find(db.sellers, function (x) { return x.id === id; }); if (!s || s.seed) fail("state");
      if (["suspended", "verified", "pending"].indexOf(status) === -1) fail("state"); s.status = status; log("admin", "vendedor " + status, s.alias); commit();
    },
    // Resolución de una denuncia con exposición de motivos al vendedor (art. 17 del Reglamento (UE) 2022/2065).
    resolveReport: function (id, decision, statement) {
      admin.need(); var r = find(db.reports, function (x) { return x.id === id; }); if (!r || r.status !== "open") fail("state");
      statement = cleanText(statement, 500); if (!statement) fail("statement", "Escribe los motivos de la decisión.");
      r.status = decision === "remove" ? "removed" : "dismissed"; r.statement = statement; r.resolvedAt = now();
      if (decision === "remove" && r.target === "seller") { var sl = find(db.sellers, function (x) { return x.id === r.seller; }); if (sl && !sl.seed) sl.status = "suspended"; }
      else if (decision === "remove") { var l = listing.get(r.listing); if (l) { l.status = "removed"; l.moderation = { status: "removed", reason: statement, report: r.no, at: now() }; hist(l, "retirado por denuncia " + r.no); note("s:" + l.seller, "Tu anuncio N.º " + l.ref + " ha sido retirado: " + statement, "resumen"); } }
      log("admin", "denuncia " + r.status, r.no); commit();
    },
    // Resolución de incidencias dentro de las facultades de Intimae y de las reglas del proveedor de pagos.
    resolveIncident: function (id, decision, amount, statement) {
      admin.need(); var inc = incident.get(id); if (!inc || inc.status === "resolved") fail("state");
      statement = cleanText(statement, 500); if (statement.length < 10) fail("statement", "Escribe los motivos de la decisión (mínimo 10 caracteres).");
      var o = orders.get(inc.order); if (!o) fail("state");
      if (decision === "refund") { var rf = pay.provider.refund(o.total, o.no); o.refundRef = rf.ref; o.refundAmount = o.total; move(o, "refunded", "administración", statement); }
      else if (decision === "partial") {
        var amt = r2(+amount); if (!(amt > 0 && amt < o.total)) fail("amount", "El importe parcial debe ser mayor que 0 y menor que el total del pedido.");
        var rf2 = pay.provider.refund(amt, o.no); o.refundRef = rf2.ref; o.refundAmount = amt; o.sellerNet = Math.max(0, r2(o.sellerNet - amt)); release(o, "administración");
      } else if (decision === "reject") { move(o, inc.prevStatus, "administración", "incidencia rechazada"); if (inc.prevStatus === "delivered") o.deliveredAt = now(); }
      else fail("decision", "Decisión no válida.");
      inc.status = "resolved"; inc.resolution = { decision: decision, amount: o.refundAmount || 0, statement: statement, at: now() };
      inc.messages.push({ from: "a", text: "Resolución: " + ({ refund: "reembolso total", partial: "reembolso parcial", reject: "incidencia rechazada" })[decision] + ". " + statement, at: now() });
      note("b:" + o.buyer, "Incidencia " + inc.no + " resuelta", "pedidos"); note("s:" + o.seller, "Incidencia " + inc.no + " resuelta", "incidencias"); log("admin", "incidencia " + decision, inc.no); T("incident.resolved." + decision); if (o.refundAmount) T("refund.cents", Math.round(o.refundAmount * 100)); commit();
    },
    forceRelease: function (id) { admin.need(); var o = orders.get(id); if (!o || ["delivered"].indexOf(o.status) === -1) fail("state", "Solo se puede liberar un pedido entregado."); release(o, "admin"); commit(); },
    // Para los vendedores de demostración, que no tienen panel.
    demoShip: function (id) { admin.need(); var o = orders.get(id); if (!o || o.status !== "paid") fail("state"); o.carrier = "Demo"; o.tracking = "DEMO" + o.id; o.shippedAt = now(); move(o, "shipped", "admin (demo)", "envío simulado"); commit(); },
    setSettings: function (s) {
      admin.need(); var c = +s.commission, d1 = Math.round(+s.autoDeliverDays), d2 = Math.round(+s.autoReleaseDays), d3 = Math.round(+s.shipDeadlineDays), d4 = Math.round(+s.incidentReplyDays);
      if (!(c >= 0 && c <= 50) || !(d1 >= 1 && d1 <= 60) || !(d2 >= 0 && d2 <= 30) || !(d3 >= 1 && d3 <= 30) || !(d4 >= 1 && d4 <= 30)) fail("range", "Valores fuera de rango.");
      db.settings.commission = c; db.settings.autoDeliverDays = d1; db.settings.autoReleaseDays = d2; db.settings.shipDeadlineDays = d3; db.settings.incidentReplyDays = d4; db.settings.showSamples = !!s.showSamples; sync(); log("admin", "ajustes", JSON.stringify(db.settings)); commit();
    },
    // DAC7: operaciones y contraprestación del año por vendedor (pedidos liquidados).
    dac7: function (year) {
      admin.need();
      return db.sellers.filter(function (s) { return !s.seed; }).map(function (s) {
        var os = db.orders.filter(function (o) { return o.seller === s.id && o.status === "released" && new Date(o.releasedAt).getFullYear() === +year; });
        var amount = r2(os.reduce(function (a, o) { return a + o.subtotal + o.shipping - (o.refundAmount || 0); }, 0)), fees = r2(os.reduce(function (a, o) { return a + o.commission; }, 0));
        var f = s.fiscal || {};
        return { id: s.id, alias: s.alias, legalName: f.legalName || "", taxId: f.taxId || "", taxCountry: f.taxCountry || "", address: f.address || "", birth: s.type === "particular" ? (f.birth || "") : "",
          country: s.country, type: s.type, vatId: s.vatId || "", ops: os.length, amount: amount, fees: fees, reportable: os.length >= DAC7.ops || amount > DAC7.amount, complete: !!f.complete };
      });
    },
    reset: function () { admin.need(); db = seed(); var s = sess(); delete s.buyer; delete s.seller; setSess(s); commit(); }
  };

  /* ---------- incidencias ---------- */
  var REASONS = ["no_enviado", "no_recibido", "distinto", "danado", "descripcion", "fraude", "pago", "privacidad"];
  var incident = {
    reasons: REASONS,
    get: function (id) { return find(db.incidents, function (i) { return i.id === +id; }); },
    forOrder: function (orderId) { return db.incidents.filter(function (i) { return i.order === +orderId; }); },
    forBuyer: function (id) { return db.incidents.filter(function (i) { return i.buyer === id; }).sort(function (a, b) { return b.id - a.id; }); },
    forSeller: function (id) { return db.incidents.filter(function (i) { return i.seller === id; }).sort(function (a, b) { return b.id - a.id; }); },
    open: function (buyerId, orderId, reason, text, evidence) {
      var o = orders.get(orderId); if (!o || o.buyer !== buyerId) fail("state", "Pedido no encontrado.");
      if (["paid", "shipped", "delivered"].indexOf(o.status) === -1) fail("state", "Solo se puede abrir una incidencia en un pedido en curso o entregado y aún no liquidado.");
      var days = db.settings.shipDeadlineDays;
      if (o.status === "paid" && now() - o.createdAt < days * 864e5) fail("early", "El vendedor aún está dentro del plazo de preparación (" + days + " días). Mientras tanto puedes cancelar el pedido.");
      if (REASONS.indexOf(reason) === -1) fail("reason", "Selecciona un motivo.");
      text = cleanText(text, 800); if (text.length < 10) fail("text", "Describe lo ocurrido (mínimo 10 caracteres).");
      if (db.incidents.some(function (i) { return i.order === o.id && i.status !== "resolved"; })) fail("exists", "Ya hay una incidencia abierta en este pedido.");
      var ev = (evidence || []).filter(function (x) { return /^data:image\/(jpeg|png|webp);base64,/.test(x); }).slice(0, 2);
      var id = ++db.seq.incident, inc = { id: id, no: "IN-" + pad(id, 5), order: o.id, orderNo: o.no, buyer: buyerId, seller: o.seller, reason: reason, text: text, evidence: ev,
        status: "open", messages: [{ from: "b", text: text, at: now() }], at: now(), prevStatus: o.status };
      db.incidents.push(inc); move(o, "incident", "comprador", reason);
      note("s:" + o.seller, "Incidencia " + inc.no + " abierta en el pedido " + o.no + ": responde en " + db.settings.incidentReplyDays + " días", "incidencias");
      log("comprador " + buyerId, "incidencia abierta", inc.no); T("incident.opened"); T("incident.reason." + reason); commit(); return inc;
    },
    reply: function (role, actorId, id, text) {
      var inc = incident.get(id); if (!inc || inc.status === "resolved") fail("state", "La incidencia ya está resuelta.");
      if ((role === "buyer" && inc.buyer !== actorId) || (role === "seller" && inc.seller !== actorId)) fail("auth");
      text = cleanText(text, 800); if (text.length < 2) fail("text", "Escribe un mensaje.");
      inc.messages.push({ from: role === "buyer" ? "b" : "s", text: text, at: now() });
      var o = orders.get(inc.order);
      if (role === "seller" && inc.status === "open") { inc.status = "disputed"; if (o && o.status === "incident") move(o, "disputed", "vendedor", "respuesta del vendedor"); note("a", "Incidencia " + inc.no + " lista para revisión", "incidencias"); }
      note(role === "buyer" ? "s:" + inc.seller : "b:" + inc.buyer, "Nuevo mensaje en la incidencia " + inc.no, role === "buyer" ? "incidencias" : "pedidos"); commit(); return inc;
    }
  };

  /* ---------- seguir tiendas, bloqueos y búsquedas guardadas ---------- */
  var follow = {
    has: function (b, s) { return !!find(db.follows, function (f) { return f.buyer === b && f.seller === s; }); },
    toggle: function (b, s) { var f = find(db.follows, function (x) { return x.buyer === b && x.seller === s; }); if (f) db.follows.splice(db.follows.indexOf(f), 1); else db.follows.push({ buyer: b, seller: s }); T(f ? "follow.removed" : "follow.added"); commit(); return !f; },
    list: function (b) { return db.follows.filter(function (f) { return f.buyer === b; }).map(function (f) { return find(db.sellers, function (s) { return s.id === f.seller; }); }).filter(Boolean); },
    count: function (s) { return db.follows.filter(function (f) { return f.seller === s; }).length; }
  };
  var block = {
    has: function (b, s) { return !!find(db.blocks, function (x) { return x.buyer === b && x.seller === s; }); },
    toggle: function (b, s) { var f = find(db.blocks, function (x) { return x.buyer === b && x.seller === s; }); if (f) db.blocks.splice(db.blocks.indexOf(f), 1); else { db.blocks.push({ buyer: b, seller: s }); log("comprador " + b, "bloquea al vendedor", s); } commit(); return !f; },
    list: function (b) { return db.blocks.filter(function (x) { return x.buyer === b; }).map(function (x) { return find(db.sellers, function (s) { return s.id === x.seller; }); }).filter(Boolean); }
  };
  function matchSearch(l, q) {
    var s = find(db.sellers, function (x) { return x.id === l.seller; }); if (!s) return false;
    var hay = [l.title, l.material, l.colour, l.type, l.ref].join(" ").toLowerCase();
    return (!q.q || hay.indexOf(q.q.toLowerCase()) !== -1) && (!q.type || l.type === q.type) && (!q.size || l.size === q.size) && (!q.color || String(l.colour).toLowerCase() === q.color.toLowerCase()) &&
      (!q.pmax || l.price <= +q.pmax) && (!q.pmin || l.price >= +q.pmin) && (!q.country || s.country === q.country);
  }
  var search = {
    match: matchSearch,
    save: function (b, f) {
      var q = { id: ++db.seq.search, buyer: b, q: cleanText(f.q, 60), type: cleanText(f.type, 20), size: cleanText(f.size, 3), color: cleanText(f.color, 30), pmin: +f.pmin || 0, pmax: +f.pmax || 0, country: cleanText(f.country, 3) };
      if (!q.q && !q.type && !q.size && !q.color && !q.pmin && !q.pmax && !q.country) fail("empty", "Aplica algún filtro o escribe algo antes de guardar la búsqueda.");
      q.label = [q.q, q.type, q.size, q.color, q.pmax ? "≤ " + q.pmax + " €" : "", q.country].filter(Boolean).join(" · ");
      if (db.searches.filter(function (x) { return x.buyer === b; }).length >= 10) fail("limit", "Puedes guardar hasta 10 búsquedas.");
      db.searches.push(q); T("search.saved"); commit(); return q;
    },
    list: function (b) { return db.searches.filter(function (x) { return x.buyer === b; }); },
    remove: function (b, id) { db.searches = db.searches.filter(function (x) { return !(x.id === +id && x.buyer === b); }); commit(); }
  };
  var notify = {
    list: function (to) { return db.notes.filter(function (n) { return n.to === to; }).sort(function (a, b) { return b.id - a.id; }); },
    unread: function (to) { return db.notes.filter(function (n) { return n.to === to && !n.read; }).length; },
    readAll: function (to) { db.notes.forEach(function (n) { if (n.to === to) n.read = true; }); save(); }
  };

  /* ---------- confianza y estadísticas del vendedor (indicadores verificables, sin puntuación única) ---------- */
  seller.trust = function (id) {
    var s = find(db.sellers, function (x) { return x.id === id; }); if (!s) return null;
    var os = db.orders.filter(function (o) { return o.seller === id; }), live = os.filter(function (o) { return o.status !== "cancelled"; });
    var sent = live.filter(function (o) { return o.shippedAt; }), done = os.filter(function (o) { return o.status === "released"; });
    var cancelled = os.filter(function (o) { return o.status === "cancelled" && o.history.some(function (h) { return h.by === "seller"; }); });
    var prep = sent.length ? sent.reduce(function (a, o) { return a + (o.shippedAt - o.createdAt); }, 0) / sent.length / 36e5 : null;
    var inc = db.incidents.filter(function (i) { return i.seller === id; }), upheld = inc.filter(function (i) { return i.resolution && i.resolution.decision !== "reject"; });
    var rt = seller.rating(id), active = db.listings.some(function (l) { return l.seller === id && l.status === "active"; });
    return {
      completed: done.length, sentPct: live.length ? Math.round(sent.length * 100 / live.length) : null, cancelPct: os.length ? Math.round(cancelled.length * 100 / os.length) : null,
      prepHours: prep == null ? null : Math.round(prep), incidents: inc.length, incidentsUpheld: upheld.length, rating: rt,
      memberSince: s.createdAt ? new Date(s.createdAt).getFullYear() : s.since,
      badges: [
        { id: "verified", ok: s.status === "verified", label: "Cuenta verificada", help: "Un administrador ha comprobado los datos fiscales y declarados de la cuenta." },
        { id: "age", ok: s.status === "verified", label: "Mayoría de edad confirmada", help: "El vendedor declaró ser mayor de 18 años y la cuenta fue verificada. En la versión real lo hará un proveedor externo." },
        { id: "active", ok: active, label: "Tienda activa", help: "Tiene al menos un anuncio publicado ahora mismo." },
        { id: "experienced", ok: done.length >= 5, label: "Vendedor con experiencia", help: "Ha completado 5 o más pedidos." },
        { id: "reviews", ok: rt.n >= 3, label: "Valoraciones verificadas", help: "Tiene 3 o más valoraciones de compras reales." }
      ]
    };
  };
  seller.stats = function (id) {
    var ls = db.listings.filter(function (l) { return l.seller === id; }), os = db.orders.filter(function (o) { return o.seller === id && ["cancelled", "refunded"].indexOf(o.status) === -1; });
    var views = ls.reduce(function (a, l) { return a + (l.views || 0); }, 0), favs = db.favs.filter(function (f) { return ls.some(function (l) { return l.id === f.listing; }); }).length;
    var gross = r2(os.reduce(function (a, o) { return a + o.subtotal + o.shipping; }, 0)), comm = r2(os.reduce(function (a, o) { return a + o.commission; }, 0));
    return { views: views, favs: favs, orders: os.length, conversion: views ? Math.round(os.length * 1000 / views) / 10 : 0, gross: gross, commission: comm, net: r2(os.reduce(function (a, o) { return a + o.sellerNet; }, 0)),
      top: ls.slice().sort(function (a, b) { return (b.views || 0) - (a.views || 0); }).slice(0, 5).map(function (l) { return { ref: l.ref, title: l.title, views: l.views || 0, favs: db.favs.filter(function (f) { return f.listing === l.id; }).length }; }) };
  };
  // Tienda pública: nombre, descripción y políticas que decide el vendedor (sin datos personales)
  seller.saveShop = function (f) {
    var s = seller.current(); if (!s) fail("auth");
    s.shop = { name: cleanText(f.name, 40), bio: cleanText(f.bio, 400), policy: cleanText(f.policy, 400) }; log("vendedor " + s.id, "tienda actualizada"); commit(); return s;
  };

  load(); sync(); tick();
  window.addEventListener("storage", function (e) { if (e.key === KEY) { load(); sync(); listeners.forEach(function (fn) { try { fn(); } catch (x) {} }); } });

  window.INT = {
    buyer: buyer, seller: seller, listing: listing, orders: orders, msg: msg, review: review, fav: fav, report: report, admin: admin, pay: pay, age: age,
    incident: incident, follow: follow, block: block, search: search, notify: notify,
    settings: function () { return db.settings; },
    data: function () { return db; },
    tick: tick, onChange: function (fn) { listeners.push(fn); }, memoryOnly: function () { return memoryOnly; },
    DAC7: DAC7, TYPES: TYPES, SIZES: SIZES
  };
})();
