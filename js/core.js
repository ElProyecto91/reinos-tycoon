/*
 * Intimae · capa de datos (MODO DEMOSTRACIÓN).
 *
 * Todo se guarda en el almacenamiento local del navegador. No hay servidor: no hay seguridad real, los
 * datos no se comparten entre personas y las contraseñas, la verificación de edad y los pagos son simulados.
 * La API (INT.buyer, INT.seller, INT.listing, INT.orders, INT.msg, INT.review, INT.fav, INT.report, INT.admin,
 * INT.pay, INT.age) está pensada para sustituirse por un backend real (esquema en db/schema.sql) sin tocar
 * la interfaz.
 *
 * Política del producto: Intimae es intermediario. No gestiona devoluciones, reclamaciones ni disputas entre
 * compradores y vendedores: no existe ningún estado de "disputa" ni de "devolución". Solo se admite cancelar
 * un pedido antes de que se envíe.
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
      v: 1,
      seq: { user: 0, seller: 0, listing: 0, order: 0, thread: 0, review: 0, report: 0 },
      users: [], sellers: [], listings: [], orders: [], threads: [], reviews: [], favs: [], reports: [], audit: [],
      settings: { commission: 20, autoDeliverDays: 10, autoReleaseDays: 3 }
    };
    Object.keys(SEED_SELLERS).forEach(function (k) {
      var s = SEED_SELLERS[k];
      d.sellers.push({ id: k, alias: s.alias, country: s.country, type: s.type, vat: s.vat, since: s.since, status: "verified", seed: true });
    });
    SEED_PRODUCTS.forEach(function (p) {
      var q = clone(p); q.status = "active"; q.seed = true; d.listings.push(q);
      d.seq.listing = Math.max(d.seq.listing, p.id);
    });
    return d;
  }
  function load() {
    try { var raw = localStorage.getItem(KEY); if (raw) db = JSON.parse(raw); } catch (e) { db = null; }
    if (!db || db.v !== 1) { db = seed(); save(); }
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
    var S = {};
    db.sellers.forEach(function (s) { if (s.status === "verified") S[s.id] = s; });
    window.SELLERS = S;
    window.PRODUCTS = db.listings.filter(function (p) { return p.status === "active" && S[p.seller]; })
      .sort(function (a, b) { return a.id - b.id; });
  }
  function commit() { var ok = save(); sync(); listeners.forEach(function (fn) { try { fn(); } catch (e) {} }); return ok; }

  /* ---------- tareas automáticas (envío → entrega → liberación del pago) ---------- */
  function tick() {
    var t = now(), changed = false, st = db.settings;
    db.orders.forEach(function (o) {
      if (o.status === "shipped" && t - o.shippedAt >= st.autoDeliverDays * 864e5) { move(o, "delivered", "sistema", "entrega automática"); o.deliveredAt = t; changed = true; }
      if (o.status === "delivered" && t - o.deliveredAt >= st.autoReleaseDays * 864e5) { release(o, "sistema"); changed = true; }
    });
    if (changed) commit();
  }
  function move(o, status, by, note) { o.status = status; o.history.push({ at: now(), status: status, by: by, note: note || "" }); }
  function release(o, by) { var res = pay.provider.payout(o.sellerNet, o.no); o.releasedAt = now(); o.payoutRef = res.ref; move(o, "released", by, "pago liquidado al vendedor"); log(by, "pago liberado", o.no); }

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
      if (find(db.users, function (x) { return x.email === email; })) fail("exists", "Ya existe una cuenta con ese correo.");
      var salt = newSalt();
      return sha(salt + ":" + o.pass).then(function (h) {
        var u = { id: "u" + (++db.seq.user), email: email, name: cleanText(o.name, 60), addr: "", country: "", salt: salt, hash: h, ageVerified: null, createdAt: now() };
        db.users.push(u); log("comprador " + u.id, "alta"); commit();
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
      var open = db.orders.some(function (o) { return o.buyer === u.id && ["paid_held", "shipped", "delivered"].indexOf(o.status) !== -1; });
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
      if (!window.TAX.get(o.country)) fail("country", "País no válido.");
      if (find(db.sellers, function (x) { return x.alias.toLowerCase() === alias.toLowerCase() || (x.email && x.email === email); })) fail("exists", "Ya existe una solicitud con ese correo o alias.");
      var pro = o.kind === "profesional", salt = newSalt();
      return sha(salt + ":" + o.pass).then(function (h) {
        var s = { id: "s" + (++db.seq.seller), alias: alias, email: email, salt: salt, hash: h, country: o.country, comm: o.comm || "es",
          type: pro ? "profesional" : "particular", vat: pro ? (o.regime === "margin" ? "margin" : "standard") : "none",
          vatId: pro ? cleanText(o.vatId, 20).toUpperCase() : "", about: cleanText(o.about, 400), since: new Date().getFullYear(),
          status: "pending", fiscal: {}, createdAt: now() };
        db.sellers.push(s); log("vendedor " + s.id, "solicitud", alias); commit();
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
      return { orders: mine, pending: sum(["paid_held", "shipped", "delivered"]), released: sum(["released"]) };
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
  var listing = {
    create: function (sellerId, d) {
      var s = find(db.sellers, function (x) { return x.id === sellerId; });
      if (!s || s.status !== "verified") fail("verify", "Tu cuenta debe estar verificada para publicar.");
      var v = validateListing(d), id = ++db.seq.listing;
      var l = Object.assign({ id: id, ref: pad(id, 4), seller: sellerId, date: today(), status: "pending", moderation: null }, v);
      db.listings.push(l);
      if (!commit()) { db.listings.pop(); db.seq.listing--; sync(); fail("storage", "No hay espacio en el navegador: usa fotos más pequeñas."); }
      log("vendedor " + sellerId, "anuncio creado", l.ref); commit(); return l;
    },
    update: function (sellerId, id, d) {
      var l = find(db.listings, function (x) { return x.id === id && x.seller === sellerId; });
      if (!l || ["sold", "removed"].indexOf(l.status) !== -1) fail("state", "Este anuncio no se puede editar.");
      Object.assign(l, validateListing(d)); l.status = "pending"; l.moderation = null;
      log("vendedor " + sellerId, "anuncio editado", l.ref); commit(); return l;
    },
    setStatus: function (sellerId, id, status) {
      var l = find(db.listings, function (x) { return x.id === id && x.seller === sellerId; });
      if (!l) fail("state");
      if (status === "paused" && l.status === "active") l.status = "paused";
      else if (status === "active" && l.status === "paused") l.status = "active";
      else fail("state", "Cambio de estado no permitido.");
      commit(); return l;
    },
    remove: function (sellerId, id) {
      var l = find(db.listings, function (x) { return x.id === id && x.seller === sellerId; });
      if (!l || l.status === "sold") fail("state", "No se puede eliminar un anuncio vendido.");
      db.listings.splice(db.listings.indexOf(l), 1); db.favs = db.favs.filter(function (f) { return f.listing !== id; }); commit();
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
          addr: { name: cleanText(addr.name, 60), line: cleanText(addr.line, 300), country: dest }, status: "paid_held", history: [], createdAt: now() };
        move(o, "paid_held", "comprador", "pago recibido");
        by[sid].forEach(function (l) { l.status = "sold"; });
        db.orders.push(o); out.push(o); log("comprador " + u.id, "pedido", no);
      });
      commit(); return out;
    },
    get: function (id) { return find(db.orders, function (o) { return o.id === +id; }); },
    forBuyer: function (id) { return db.orders.filter(function (o) { return o.buyer === id; }).sort(function (a, b) { return b.id - a.id; }); },
    forSeller: function (id) { return db.orders.filter(function (o) { return o.seller === id; }).sort(function (a, b) { return b.id - a.id; }); },
    ship: function (sellerId, id, carrier, tracking) {
      var o = orders.get(id); if (!o || o.seller !== sellerId || o.status !== "paid_held") fail("state", "El pedido no se puede marcar como enviado.");
      carrier = cleanText(carrier, 40); tracking = cleanText(tracking, 60);
      if (!carrier || !tracking) fail("tracking", "Indica transportista y número de seguimiento.");
      o.carrier = carrier; o.tracking = tracking; o.shippedAt = now(); move(o, "shipped", "vendedor", carrier + " " + tracking); commit(); return o;
    },
    // Solo antes del envío. No existen devoluciones ni reclamaciones en Intimae.
    cancel: function (role, actorId, id) {
      var o = orders.get(id); if (!o || o.status !== "paid_held") fail("state", "Solo se puede cancelar un pedido antes de que se envíe.");
      if ((role === "buyer" && o.buyer !== actorId) || (role === "seller" && o.seller !== actorId)) fail("auth");
      var rf = pay.provider.refund(o.total, o.no); o.refundRef = rf.ref; move(o, "cancelled", role, "cancelado antes del envío; importe devuelto íntegramente");
      o.items.forEach(function (it) { var l = listing.get(it.listing); if (l && l.status === "sold") l.status = "active"; });
      log(role + " " + actorId, "pedido cancelado", o.no); commit(); return o;
    },
    confirmReceipt: function (buyerId, id) {
      var o = orders.get(id); if (!o || o.buyer !== buyerId || o.status !== "shipped") fail("state", "El pedido no está en camino.");
      o.deliveredAt = now(); move(o, "delivered", "comprador", "recepción confirmada"); commit(); return o;
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
      var t = find(db.threads, function (x) { return x.buyer === buyerId && x.listing === l.id; });
      if (!t) { t = { id: ++db.seq.thread, listing: l.id, listingTitle: l.title, buyer: buyerId, seller: l.seller, msgs: [], readB: 0, readS: 0 }; db.threads.push(t); }
      t.msgs.push({ from: "b", text: text, at: now() }); t.readB = now(); commit(); return t;
    },
    reply: function (threadId, role, text) {
      var t = find(db.threads, function (x) { return x.id === +threadId; }); if (!t) fail("state");
      text = cleanText(text, 600); if (text.length < 2) fail("text", "Escribe un mensaje.");
      if (blocked(text)) fail("blocked", "blocked");
      t.msgs.push({ from: role === "buyer" ? "b" : "s", text: text, at: now() }); t[role === "buyer" ? "readB" : "readS"] = now(); commit(); return t;
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
      db.reviews.push({ id: ++db.seq.review, order: o.id, buyer: buyerId, seller: o.seller, rating: rating, text: cleanText(text, 300), at: now() }); commit();
    },
    forOrder: function (orderId) { return find(db.reviews, function (r) { return r.order === +orderId; }); },
    forSeller: function (sellerId) { return db.reviews.filter(function (r) { return r.seller === sellerId; }); }
  };
  var fav = {
    has: function (buyerId, id) { return !!find(db.favs, function (f) { return f.buyer === buyerId && f.listing === id; }); },
    toggle: function (buyerId, id) {
      var f = find(db.favs, function (x) { return x.buyer === buyerId && x.listing === id; });
      if (f) db.favs.splice(db.favs.indexOf(f), 1); else db.favs.push({ buyer: buyerId, listing: id });
      commit(); return !f;
    },
    list: function (buyerId) { return db.favs.filter(function (f) { return f.buyer === buyerId; }).map(function (f) { return listing.get(f.listing); }).filter(Boolean); }
  };

  /* ---------- denuncias de contenido (Reglamento (UE) 2022/2065) ---------- */
  var report = {
    create: function (o) {
      var l = listing.get(o.listing); if (!l) fail("state", "Anuncio no encontrado.");
      if (!o.good) fail("good", "Marca la declaración de buena fe.");
      var reason = cleanText(o.reason, 20), text = cleanText(o.text, 600);
      if (!reason) fail("reason", "Indica el motivo.");
      var r = { id: ++db.seq.report, no: "DN-" + pad(db.seq.report, 5), listing: l.id, listingRef: l.ref, reason: reason, text: text, email: cleanText(o.email, 120), status: "open", at: now() };
      db.reports.push(r); log("denunciante", "denuncia", r.no); commit(); return r;
    }
  };

  /* ---------- administración ---------- */
  var admin = {
    isIn: function () { return !!sess().admin; },
    login: function (pass) { return sha(ADMIN_SALT + ":" + pass).then(function (h) { if (h !== ADMIN_HASH) fail("auth", "Contraseña incorrecta."); var s = sess(); s.admin = true; setSess(s); }); },
    logout: function () { var s = sess(); delete s.admin; setSess(s); },
    need: function () { if (!admin.isIn()) fail("auth", "Acceso restringido."); },
    approve: function (id) { admin.need(); var l = listing.get(id); if (!l || l.status !== "pending") fail("state"); l.status = "active"; l.moderation = { status: "approved", at: now() }; log("admin", "anuncio aprobado", l.ref); commit(); },
    reject: function (id, reason) { admin.need(); var l = listing.get(id); if (!l || l.status !== "pending") fail("state"); reason = cleanText(reason, 300); if (!reason) fail("reason", "Indica el motivo."); l.status = "rejected"; l.moderation = { status: "rejected", reason: reason, at: now() }; log("admin", "anuncio rechazado", l.ref); commit(); },
    verifySeller: function (id) {
      admin.need(); var s = find(db.sellers, function (x) { return x.id === id; });
      if (!s || s.seed) fail("state"); if (!s.fiscal || !s.fiscal.complete) fail("fiscal", "Faltan los datos fiscales (DAC7) del vendedor.");
      s.status = "verified"; log("admin", "vendedor verificado", s.alias); commit();
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
      if (decision === "remove") { var l = listing.get(r.listing); if (l) { l.status = "removed"; l.moderation = { status: "removed", reason: statement, report: r.no, at: now() }; } }
      log("admin", "denuncia " + r.status, r.no); commit();
    },
    forceRelease: function (id) { admin.need(); var o = orders.get(id); if (!o || ["delivered"].indexOf(o.status) === -1) fail("state", "Solo se puede liberar un pedido entregado."); release(o, "admin"); commit(); },
    // Para los vendedores de demostración, que no tienen panel.
    demoShip: function (id) { admin.need(); var o = orders.get(id); if (!o || o.status !== "paid_held") fail("state"); o.carrier = "Demo"; o.tracking = "DEMO" + o.id; o.shippedAt = now(); move(o, "shipped", "admin (demo)", "envío simulado"); commit(); },
    setSettings: function (s) {
      admin.need(); var c = +s.commission, d1 = Math.round(+s.autoDeliverDays), d2 = Math.round(+s.autoReleaseDays);
      if (!(c >= 0 && c <= 50) || !(d1 >= 1 && d1 <= 60) || !(d2 >= 0 && d2 <= 30)) fail("range", "Valores fuera de rango.");
      db.settings.commission = c; db.settings.autoDeliverDays = d1; db.settings.autoReleaseDays = d2; log("admin", "ajustes", JSON.stringify(db.settings)); commit();
    },
    // DAC7: operaciones y contraprestación del año por vendedor (pedidos liquidados).
    dac7: function (year) {
      admin.need();
      return db.sellers.filter(function (s) { return !s.seed; }).map(function (s) {
        var os = db.orders.filter(function (o) { return o.seller === s.id && o.status === "released" && new Date(o.releasedAt).getFullYear() === +year; });
        var amount = r2(os.reduce(function (a, o) { return a + o.subtotal + o.shipping; }, 0)), fees = r2(os.reduce(function (a, o) { return a + o.commission; }, 0));
        var f = s.fiscal || {};
        return { id: s.id, alias: s.alias, legalName: f.legalName || "", taxId: f.taxId || "", taxCountry: f.taxCountry || "", address: f.address || "", birth: s.type === "particular" ? (f.birth || "") : "",
          country: s.country, type: s.type, vatId: s.vatId || "", ops: os.length, amount: amount, fees: fees, reportable: os.length >= DAC7.ops || amount > DAC7.amount, complete: !!f.complete };
      });
    },
    reset: function () { admin.need(); db = seed(); var s = sess(); delete s.buyer; delete s.seller; setSess(s); commit(); }
  };

  load(); sync(); tick();
  window.addEventListener("storage", function (e) { if (e.key === KEY) { load(); sync(); listeners.forEach(function (fn) { try { fn(); } catch (x) {} }); } });

  window.INT = {
    buyer: buyer, seller: seller, listing: listing, orders: orders, msg: msg, review: review, fav: fav, report: report, admin: admin, pay: pay, age: age,
    settings: function () { return db.settings; },
    data: function () { return db; },
    tick: tick, onChange: function (fn) { listeners.push(fn); }, memoryOnly: function () { return memoryOnly; },
    DAC7: DAC7, TYPES: TYPES, SIZES: SIZES
  };
})();
