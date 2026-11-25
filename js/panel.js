/* Intimae · panel de vendedor (modo demostración) */
(function () {
  "use strict";
  var U = window.UI, el = U.el, add = U.add, $ = function (s) { return document.querySelector(s); };
  var ctl = null, editing = null, photos = [];

  I18N.mountSelect($("#lang"));
  I18N.onChange(function (l) { var n = $("#es-only"); n.hidden = l === "es"; n.textContent = I18N.t("app.es_only"); });
  I18N.start();

  function me() { return INT.seller.current(); }
  function msgError(e) { if (e && e.message === "blocked") e.message = "Por seguridad, no se pueden compartir correos, teléfonos ni enlaces."; throw e; }
  function thumb(l) { return l.img && l.img.indexOf("data:") === 0 ? l.img : l.img + "?auto=format&fit=crop&w=160&h=200&q=70"; }
  function refresh() { ctl.refresh(); }

  /* ---------- acceso ---------- */
  function renderAuth() {
    var box = U.clear($("#auth")); box.hidden = false; $("#app").hidden = true; $("#logout").hidden = true;
    var f = el("form", "card form stack"); f.style.maxWidth = "460px";
    add(f, el("h2", null, "Entrar"), U.field("Correo", U.input("email", "email", { required: "", autocomplete: "email" })), U.field("Contraseña", U.input("pass", "password", { required: "", autocomplete: "current-password" })));
    var b = el("button", "btn btn--block", "Entrar"); b.type = "submit"; f.appendChild(b);
    var a = el("a", "link", "¿Aún no tienes cuenta? Solicita acceso"); a.href = "../#solicitud"; f.appendChild(a);
    f.addEventListener("submit", function (e) { e.preventDefault(); var d = new FormData(f); U.run(function () { return INT.seller.login(d.get("email"), d.get("pass")); }).then(render, function () {}); });
    box.appendChild(f);
  }

  /* ---------- resumen ---------- */
  function kpi(label, value) { var k = el("div", "kpi"); add(k, el("span", "eyebrow", label), el("b", "num", value)); return k; }
  function tabHome(p) {
    var s = me(), ls = INT.listing.mine(s.id), st = INT.seller.statement(s.id), rt = INT.seller.rating(s.id);
    var k = el("div", "kpis");
    add(k, kpi("Anuncios publicados", String(ls.filter(function (l) { return l.status === "active"; }).length)), kpi("En revisión", String(ls.filter(function (l) { return l.status === "pending"; }).length)),
      kpi("Pedidos por enviar", String(st.orders.filter(function (o) { return o.status === "paid_held"; }).length)), kpi("Pago retenido", U.money(st.pending)), kpi("Pago liquidado", U.money(st.released)),
      kpi("Valoración", rt.n ? rt.avg + " / 5 (" + rt.n + ")" : "Sin valoraciones"));
    p.appendChild(k);
    if (s.status === "pending") add(p, el("div", "notice", s.fiscal && s.fiscal.complete ? "Tu cuenta está pendiente de verificación. Un administrador revisará tus datos fiscales; hasta entonces no puedes publicar." : "Para que verifiquemos tu cuenta, completa primero la pestaña «Datos fiscales». Hasta entonces no puedes publicar."));
    if (s.status === "suspended") add(p, el("div", "notice", "Tu cuenta está suspendida. No puedes publicar anuncios nuevos."));
    var bad = ls.filter(function (l) { return l.moderation && (l.status === "rejected" || l.status === "removed"); });
    if (bad.length) {
      p.appendChild(el("h2", null, "Decisiones de moderación")); p.lastChild.style.cssText = "font-size:1.5rem;margin:18px 0 8px";
      bad.forEach(function (l) { var c = el("div", "thread"); add(c, el("header", null, "N.º " + l.ref + " · " + l.title), el("p", "muted-s", (l.status === "rejected" ? "Rechazado" : "Retirado") + " el " + U.date(l.moderation.at) + ". Motivos: " + l.moderation.reason)); p.appendChild(c); });
    }
    add(p, el("p", "muted-s", "Las decisiones sobre tus anuncios se te comunican con sus motivos. Para recurrirlas, escribe a la dirección de reclamaciones que figura en «Normas y denuncias» (pendiente de titularidad)."));
  }

  /* ---------- anuncios ---------- */
  function listingForm(host, l) {
    U.clear(host); editing = l || null; photos = l ? l.imgs.slice() : [];
    var s = me(), f = el("form", "card form stack"); f.appendChild(el("h2", null, l ? "Editar anuncio N.º " + l.ref : "Nuevo anuncio"));
    var type = U.select("type", [["braga", "Braga"], ["tanga", "Tanga"], ["sujetador", "Sujetador"], ["camison", "Camisón"], ["conjunto", "Lote"]], l && l.type);
    var size = U.select("size", INT.SIZES, l && l.size), price = U.input("price", "number", { min: "5", max: "500", step: "0.5", required: "", value: l ? l.price : "30" });
    var net = el("span", "hint");
    function calc() { var v = +price.value || 0, c = INT.settings().commission; net.textContent = "Comisión " + c + " %: recibirás " + U.money(v - Math.round(v * c) / 100) + " (sin contar el envío)."; }
    price.addEventListener("input", calc); calc();
    var desc = el("textarea"); desc.name = "desc"; desc.maxLength = 400; desc.value = l ? l.desc : "";
    var row1 = el("div", "row"); add(row1, U.field("Prenda", type), U.field("Talla", size));
    var row2 = el("div", "row"); add(row2, U.field("Precio final que paga el comprador (€)", price), U.field("Días de uso", U.input("days", "number", { min: "0", max: "60", required: "", value: l ? l.days : "2" })));
    var row3 = el("div", "row"); add(row3, U.field("Material", U.input("material", "text", { maxlength: "60", value: l ? l.material : "" })), U.field("Color", U.input("colour", "text", { maxlength: "40", value: l ? l.colour : "" })));
    add(f, U.field("Título", U.input("title", "text", { required: "", maxlength: "80", value: l ? l.title : "" })), row1, row2, net, row3, U.field("Descripción", desc));
    var th = el("div", "thumbs"), fi = el("input"); fi.type = "file"; fi.accept = "image/jpeg,image/png,image/webp"; fi.multiple = true;
    function paint() { U.clear(th); photos.forEach(function (d, i) { var im = el("img"); im.src = d; im.alt = "Foto " + (i + 1); im.title = "Pulsa para quitar"; im.style.cursor = "pointer"; im.addEventListener("click", function () { photos.splice(i, 1); paint(); }); th.appendChild(im); }); }
    fi.addEventListener("change", function () {
      var files = Array.prototype.slice.call(fi.files).slice(0, 3 - photos.length);
      Promise.all(files.map(U.resizeImage)).then(function (r) { photos = photos.concat(r).slice(0, 3); paint(); fi.value = ""; }, function (e) { U.toast(e.message, true); });
    });
    add(f, U.field("Fotos (hasta 3; sin rostro ni datos identificativos)", fi, "Se reducen a 900 px y se eliminan los metadatos de la foto."), th); paint();
    var ck = el("label", "check"), cb = el("input"); cb.type = "checkbox"; cb.required = true;
    add(ck, cb, el("span", null, "La prenda es mía y la he usado yo. Las fotos son mías, no muestran a menores ni a nadie sin su consentimiento, y la descripción es veraz.")); f.appendChild(ck);
    var acts = el("div", "acts"); acts.style.cssText = "display:flex;gap:10px";
    var sb = el("button", "btn", l ? "Guardar y enviar a revisión" : "Enviar a revisión"); sb.type = "submit";
    add(acts, sb, U.btn("Cancelar", function () { U.clear(host); editing = null; }, "btn--line")); f.appendChild(acts);
    f.addEventListener("submit", function (e) {
      e.preventDefault(); var d = new FormData(f), data = { type: d.get("type"), size: d.get("size"), title: d.get("title"), price: d.get("price"), days: d.get("days"), material: d.get("material"), colour: d.get("colour"), desc: d.get("desc"), imgs: photos };
      U.run(function () { return editing ? INT.listing.update(s.id, editing.id, data) : INT.listing.create(s.id, data); }, "Anuncio enviado a revisión.").then(refresh, function () {});
    });
    host.appendChild(f); f.scrollIntoView({ block: "nearest" });
  }
  function tabListings(p) {
    var s = me(), host = el("div"), ls = INT.listing.mine(s.id).sort(function (a, b) { return b.id - a.id; });
    var top = el("div"); top.style.cssText = "display:flex;justify-content:space-between;align-items:center;gap:12px;margin-bottom:16px";
    add(top, el("p", "muted-s", "Cada anuncio nuevo o editado pasa por una revisión antes de publicarse."));
    var nb = U.btn("Nuevo anuncio", function () { listingForm(host, null); }); if (s.status !== "verified") { nb.disabled = true; nb.title = "Tu cuenta debe estar verificada"; }
    top.appendChild(nb); add(p, top, host);
    if (!ls.length) return p.appendChild(el("p", "empty-s", s.status === "verified" ? "Aún no has publicado nada." : "Cuando tu cuenta esté verificada podrás publicar."));
    ls.forEach(function (l) {
      var r = el("div", "row-card"), im = el("img"); im.src = thumb(l); im.alt = ""; im.width = 72; im.height = 90;
      var info = el("div"); add(info, el("h3", null, l.title), el("small", null, "N.º " + l.ref + " · " + l.size + " · " + l.days + " días de uso · " + (l.date || "")), U.pill(l.status));
      if (l.moderation && l.moderation.reason) info.appendChild(el("p", "muted-s", "Motivos: " + l.moderation.reason));
      var acts = el("div", "acts");
      if (["sold", "removed"].indexOf(l.status) === -1) acts.appendChild(U.btn("Editar", function () { listingForm(host, l); host.scrollIntoView({ behavior: "auto" }); }, "btn--line"));
      if (l.status === "active") acts.appendChild(U.btn("Pausar", function () { U.run(function () { return INT.listing.setStatus(s.id, l.id, "paused"); }).then(refresh, function () {}); }, "btn--line"));
      if (l.status === "paused") acts.appendChild(U.btn("Reanudar", function () { U.run(function () { return INT.listing.setStatus(s.id, l.id, "active"); }).then(refresh, function () {}); }, "btn--line"));
      if (l.status !== "sold") acts.appendChild(U.btn("Eliminar", function () { if (confirm("¿Eliminar este anuncio?")) U.run(function () { return INT.listing.remove(s.id, l.id); }).then(refresh, function () {}); }, "btn--line"));
      info.appendChild(acts); add(r, im, info, el("strong", "num", U.money(l.price))); p.appendChild(r);
    });
  }

  /* ---------- pedidos ---------- */
  function tabOrders(p) {
    var s = me(); INT.tick(); var list = INT.orders.forSeller(s.id);
    p.appendChild(el("p", "app-sub", "Envía en bolsa sellada, con embalaje neutro y sin tus datos. Intimae no gestiona devoluciones ni reclamaciones: lo que ocurra tras la entrega se resuelve entre tú y el comprador por mensajes."));
    if (!list.length) return p.appendChild(el("p", "empty-s", "Aún no tienes pedidos."));
    list.forEach(function (o) {
      var c = el("article", "card"); c.style.marginBottom = "14px";
      var h = el("div", "row-card"); h.style.cssText = "grid-template-columns:1fr auto;padding-top:0"; var l = el("div"); add(l, el("h3", null, o.no), el("small", null, U.date(o.createdAt) + " · Comprador n.º " + o.buyer.replace("u", ""))); add(h, l, U.pill(o.status)); c.appendChild(h);
      var ul = el("ul"); o.items.forEach(function (it) { ul.appendChild(el("li", null, "N.º " + it.ref + " · " + it.title + " · " + U.money(it.unit))); }); c.appendChild(ul);
      c.appendChild(el("p", "muted-s", "Subtotal " + U.money(o.subtotal) + " · Comisión (" + o.commissionPct + " %) −" + U.money(o.commission) + " · Envío " + U.money(o.shipping) + " · Recibes " + U.money(o.sellerNet)));
      if (["paid_held", "shipped"].indexOf(o.status) !== -1) c.appendChild(el("p", null, "Entrega a: " + o.addr.name + ", " + o.addr.line + " (" + I18N.country(o.addr.country) + ")"));
      if (o.tracking) c.appendChild(el("p", "muted-s", "Seguimiento: " + o.carrier + " " + o.tracking));
      if (o.status === "paid_held") {
        var f = el("form", "inline-form"), car = U.select("carrier", ["Correos", "SEUR", "DHL", "UPS", "Otro"]), tr = U.input("tracking", "text", { required: "", maxlength: "60", placeholder: "Número de seguimiento" });
        var b = U.btn("Marcar como enviado", function () {}); b.type = "submit"; add(f, car, tr, b); f.style.marginTop = "12px";
        f.addEventListener("submit", function (e) { e.preventDefault(); U.run(function () { return INT.orders.ship(s.id, o.id, car.value, tr.value); }, "Pedido marcado como enviado.").then(refresh, function () {}); });
        c.appendChild(f);
        var cb = U.btn("Cancelar pedido (se devuelve el importe)", function () { if (confirm("Se cancelará el pedido y se devolverá todo al comprador. ¿Continuar?")) U.run(function () { return INT.orders.cancel("seller", s.id, o.id); }, "Pedido cancelado.").then(refresh, function () {}); }, "btn--line"); cb.style.marginTop = "10px"; c.appendChild(cb);
      }
      if (o.status === "delivered") c.appendChild(el("p", "muted-s", "El pago se liquidará " + INT.settings().autoReleaseDays + " días después de la entrega."));
      p.appendChild(c);
    });
  }

  /* ---------- cobros ---------- */
  function tabPayouts(p) {
    var s = me(), st = INT.seller.statement(s.id), k = el("div", "kpis");
    add(k, kpi("Retenido hasta la entrega", U.money(st.pending)), kpi("Liquidado", U.money(st.released)), kpi("Comisión vigente", INT.settings().commission + " %")); p.appendChild(k);
    p.appendChild(el("p", "app-sub", "El pago queda retenido hasta que el comprador confirma la recepción o pasan " + INT.settings().autoDeliverDays + " días desde el envío; después se liquida a los " + INT.settings().autoReleaseDays + " días. No hay reclamaciones que lo congelen: Intimae no las gestiona. Los contracargos del procesador de pagos se imputan al vendedor."));
    var rows = st.orders.map(function (o) { return [o.no, U.date(o.createdAt), U.STATUS[o.status][0], U.money(o.subtotal), "−" + U.money(o.commission), U.money(o.shipping), U.money(o.status === "cancelled" ? 0 : o.sellerNet)]; });
    if (!rows.length) return p.appendChild(el("p", "empty-s", "Sin movimientos todavía."));
    p.appendChild(U.table(["Pedido", "Fecha", "Estado", "Subtotal", "Comisión", "Envío", "Neto"], rows));
    p.appendChild(U.btn("Descargar extracto (CSV)", function () {
      U.download("extracto-intimae.csv", U.csv([["pedido", "fecha", "estado", "subtotal", "comision", "envio", "neto"]].concat(st.orders.map(function (o) { return [o.no, new Date(o.createdAt).toISOString().slice(0, 10), o.status, o.subtotal, o.commission, o.shipping, o.status === "cancelled" ? 0 : o.sellerNet]; }))), "text/csv;charset=utf-8");
    }, "btn--line"));
  }

  /* ---------- mensajes ---------- */
  function tabMsgs(p) {
    var s = me(), list = INT.msg.forSeller(s.id);
    if (!list.length) return p.appendChild(el("p", "empty-s", "Aún no tienes mensajes de compradores."));
    p.appendChild(el("p", "app-sub", "Usa solo este sistema. No compartas tu dirección, teléfono ni redes sociales (se bloquean correos, teléfonos y enlaces)."));
    list.forEach(function (t) {
      var un = INT.msg.unread(t, "seller"), c = el("div", "thread"), h = el("header"); add(h, el("span", null, t.listingTitle + " · Comprador n.º " + t.buyer.replace("u", "")), un ? U.pill("warn", un + " sin leer") : null); c.appendChild(h);
      var bb = el("div", "bubbles"); t.msgs.forEach(function (m) { var b = el("div", "bubble" + (m.from === "s" ? " me" : ""), m.text); b.appendChild(el("small", null, (m.from === "s" ? "Tú" : "Comprador") + " · " + U.date(m.at))); bb.appendChild(b); }); c.appendChild(bb);
      var f = el("form", "inline-form"), ta = el("textarea"); ta.placeholder = "Responder…"; ta.required = true; ta.maxLength = 600; ta.style.minHeight = "44px"; var b = U.btn("Enviar", function () {}); b.type = "submit"; add(f, ta, b);
      f.addEventListener("submit", function (e) { e.preventDefault(); U.run(function () { return Promise.resolve().then(function () { return INT.msg.reply(t.id, "seller", ta.value); }).catch(msgError); }).then(refresh, function () {}); });
      c.appendChild(f); p.appendChild(c); INT.msg.markRead(t.id, "seller");
    });
  }

  /* ---------- datos fiscales ---------- */
  function tabFiscal(p) {
    var s = me(), fi = s.fiscal || {}, f = el("form", "card form stack"); f.style.maxWidth = "620px";
    f.appendChild(el("h2", null, "Datos fiscales (DAC7)"));
    f.appendChild(el("p", "muted-s", "La directiva DAC7 obliga a la plataforma a recoger estos datos y a comunicar a la Administración tributaria la actividad de los vendedores que superen los umbrales (30 operaciones o 2.000 € al año). Sin ellos no podemos verificar tu cuenta."));
    var tc = U.select("taxCountry", [["", "—"]].concat(TAX.countries.map(function (c) { return [c.code, I18N.country(c.code)]; })), fi.taxCountry || s.country);
    var ad = el("textarea"); ad.name = "address"; ad.maxLength = 200; ad.value = fi.address || "";
    add(f, U.field(s.type === "profesional" ? "Razón social o nombre completo" : "Nombre y apellidos", U.input("legalName", "text", { required: "", maxlength: "120", value: fi.legalName || "" })),
      U.field("NIF / identificador fiscal", U.input("taxId", "text", { required: "", maxlength: "30", value: fi.taxId || "" })),
      U.field("Domicilio", ad), U.field("País de residencia fiscal", tc));
    if (s.type === "particular") f.appendChild(U.field("Fecha de nacimiento", U.input("birth", "date", { required: "", value: fi.birth || "" })));
    var b = el("button", "btn", "Guardar datos fiscales"); b.type = "submit"; f.appendChild(b);
    f.appendChild(el("p", "muted-s", fi.complete ? "Datos completos. " + (s.status === "verified" ? "Tu cuenta está verificada." : "A la espera de la verificación por un administrador.") : "Faltan datos por completar."));
    f.addEventListener("submit", function (e) { e.preventDefault(); var d = new FormData(f); U.run(function () { return INT.seller.saveFiscal({ legalName: d.get("legalName"), taxId: d.get("taxId"), address: d.get("address"), taxCountry: d.get("taxCountry"), birth: d.get("birth") }); }, "Datos fiscales guardados.").then(refresh, function () {}); });
    p.appendChild(f);
  }

  function render() {
    var s = me(); INT.tick();
    if (!s) { $("#sub").textContent = "Entra con tu cuenta de vendedor."; return renderAuth(); }
    $("#auth").hidden = true; $("#app").hidden = false; $("#logout").hidden = false;
    var sub = $("#sub"); sub.textContent = ""; sub.appendChild(document.createTextNode(s.alias + " · ")); sub.appendChild(U.pill(s.status));
    var unread = function () { return INT.msg.forSeller(s.id).reduce(function (a, t) { return a + INT.msg.unread(t, "seller"); }, 0); };
    var toShip = function () { return INT.orders.forSeller(s.id).filter(function (o) { return o.status === "paid_held"; }).length; };
    ctl = U.tabs($("#tabbar"), $("#panel"), [
      { id: "resumen", label: "Resumen", render: tabHome },
      { id: "anuncios", label: "Anuncios", render: tabListings },
      { id: "pedidos", label: "Pedidos", badge: toShip, render: tabOrders },
      { id: "cobros", label: "Cobros", render: tabPayouts },
      { id: "mensajes", label: "Mensajes", badge: unread, render: tabMsgs },
      { id: "fiscal", label: "Datos fiscales", render: tabFiscal }
    ]);
  }
  $("#logout").addEventListener("click", function () { INT.seller.logout(); render(); });
  render();
})();
