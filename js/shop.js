/* Intimae · tienda pública de un vendedor (modo demostración). Sin datos personales del vendedor. */
(function () {
  "use strict";
  var U = window.UI, el = U.el, add = U.add, root = document.getElementById("shop");
  I18N.mountSelect(document.getElementById("lang"));
  I18N.onChange(function (l) { var n = document.getElementById("es-only"); n.hidden = l === "es"; n.textContent = I18N.t("app.es_only"); });
  I18N.start();

  var id = new URLSearchParams(location.search).get("s");
  var s = INT.data().sellers.filter(function (x) { return x.id === id && x.status === "verified" && (INT.settings().showSamples !== false || !x.seed); })[0];
  if (!s) { root.appendChild(el("h1", null, "Tienda no encontrada")); root.appendChild(el("p", "app-sub", "Esta tienda no existe o todavía no está verificada.")); return; }
  document.title = (s.shop && s.shop.name || s.alias) + " · Intimae";

  function render() {
    U.clear(root);
    var u = INT.buyer.current(), tr = INT.seller.trust(s.id), sh = s.shop || {}, rt = tr.rating, followers = INT.follow.count(s.id);
    var head = el("div", "shop-head"), av = el("span", "shop__av", s.alias.charAt(0).toUpperCase()), info = el("div");
    av.style.cssText = "width:72px;height:72px;font-size:2rem";
    add(info, el("h1", null, sh.name || s.alias), el("p", "app-sub", "@" + s.alias + " · " + I18N.country(s.country) + " · " + (s.type === "particular" ? "Particular" : "Profesional") + " · en Intimae desde " + tr.memberSince + " · " + followers + (followers === 1 ? " seguidor" : " seguidores")));
    if (s.seed) info.appendChild(U.pill("warn", "Tienda de muestra"));
    add(head, av, info); head.style.cssText = "display:flex;gap:18px;align-items:center;flex-wrap:wrap"; root.appendChild(head);
    var bio = sh.bio || s.bio; if (bio) root.appendChild(el("p", null, bio)).style.cssText = "max-width:64ch;margin:14px 0";

    // acciones
    var acts = el("div"); acts.style.cssText = "display:flex;gap:10px;flex-wrap:wrap;margin:16px 0 22px";
    var login = function () { location.href = "../cuenta/?next=store"; };
    var fol = u && INT.follow.has(u.id, s.id);
    acts.appendChild(U.btn(fol ? "Siguiendo" : "Seguir tienda", function () { if (!u) return login(); INT.follow.toggle(u.id, s.id); render(); }, fol ? "btn--line" : ""));
    var box = el("div"); box.hidden = true;
    acts.appendChild(U.btn("Contactar", function () { box.hidden = !box.hidden; }, "btn--line"));
    acts.appendChild(U.btn("Denunciar tienda", function () { rep.hidden = !rep.hidden; }, "btn--line"));
    var blocked = u && INT.block.has(u.id, s.id);
    acts.appendChild(U.btn(blocked ? "Desbloquear" : "Bloquear", function () { if (!u) return login(); if (blocked || confirm("No verás sus anuncios ni podrás intercambiar mensajes. ¿Bloquear a este vendedor?")) { INT.block.toggle(u.id, s.id); render(); } }, "btn--line"));
    root.appendChild(acts);

    // contactar
    var first = INT.listing.mine(s.id).filter(function (l) { return l.status === "active"; })[0] || INT.listing.mine(s.id)[0];
    if (!u) add(box, el("p", "hint", "Inicia sesión como comprador para escribir a esta tienda."));
    else if (!first) add(box, el("p", "hint", "Esta tienda aún no tiene anuncios sobre los que escribir."));
    else {
      var f = el("form", "inline-form"), ta = el("textarea"); ta.required = true; ta.maxLength = 600; ta.placeholder = "Tu mensaje. No compartas datos personales."; ta.style.minHeight = "44px"; var b = U.btn("Enviar", function () {}); b.type = "submit"; add(f, ta, b);
      f.addEventListener("submit", function (e) { e.preventDefault(); U.run(function () { try { return INT.msg.start(u.id, first.id, ta.value); } catch (err) { if (err.message === "blocked") err.message = "Por seguridad, no se pueden compartir correos, teléfonos ni enlaces."; throw err; } }, "Mensaje enviado. Verás la respuesta en tu cuenta.").then(function () { ta.value = ""; box.hidden = true; }, function () {}); });
      box.appendChild(f);
    }
    root.appendChild(box);

    // denunciar
    var rep = el("form", "card form stack"); rep.hidden = true; rep.style.margin = "0 0 22px";
    var why = U.select("reason", [["illegal", "Contenido ilegal"], ["minor", "Menores"], ["consent", "Imágenes sin consentimiento"], ["fake", "Engaño o suplantación"], ["other", "Otro"]]), tx = el("textarea"); tx.maxLength = 600; tx.name = "text"; tx.style.minHeight = "70px";
    var ok = el("label", "check"), cb = el("input"); cb.type = "checkbox"; cb.required = true; add(ok, cb, el("span", null, "Declaro que esta denuncia se hace de buena fe y es exacta y completa."));
    var sb = el("button", "btn btn--sm", "Enviar denuncia"); sb.type = "submit"; add(rep, el("h3", null, "Denunciar esta tienda"), U.field("Motivo", why), U.field("Explicación", tx), ok, sb);
    rep.addEventListener("submit", function (e) { e.preventDefault(); U.run(function () { return INT.report.create({ seller: s.id, reason: why.value, text: tx.value, good: true }); }, "Denuncia recibida.").then(function () { rep.hidden = true; }, function () {}); });
    root.appendChild(rep);

    // confianza
    var t = el("section", "card stack"); t.appendChild(el("h2", null, "Confianza"));
    var row = el("div"); row.style.cssText = "display:flex;gap:8px;flex-wrap:wrap";
    tr.badges.forEach(function (x) { var pill = U.pill(x.ok ? "ok" : "", (x.ok ? "✓ " : "· ") + x.label); pill.title = x.help; row.appendChild(pill); });
    t.appendChild(row);
    t.appendChild(el("p", "muted-s", (rt.n ? "Valoración " + rt.avg + " / 5 (" + rt.n + " compras verificadas)" : "Sin valoraciones todavía") + " · Pedidos completados: " + tr.completed + (tr.sentPct == null ? "" : " · Enviados: " + tr.sentPct + " %") + (tr.prepHours == null ? "" : " · Preparación media: " + tr.prepHours + " h") + (tr.cancelPct == null ? "" : " · Cancelaciones: " + tr.cancelPct + " %")));
    var d = el("details"); d.appendChild(el("summary", null, "Qué significa cada distintivo"));
    var ul = el("ul", "history"); tr.badges.forEach(function (x) { ul.appendChild(el("li", null, x.label + ": " + x.help)); }); d.appendChild(ul);
    d.appendChild(el("p", "muted-s", "No hay una puntuación única: son indicadores separados y comprobables, para que una valoración aislada no destruya la reputación de una tienda."));
    t.appendChild(d); root.appendChild(t);
    if (sh.policy) { var pc = el("section", "card"); pc.style.marginTop = "18px"; add(pc, el("h3", null, "Políticas de la tienda"), el("p", null, sh.policy)); root.appendChild(pc); }

    // piezas
    var items = blocked ? [] : window.PRODUCTS.filter(function (p) { return p.seller === s.id; });
    var h = el("h2", null, "Piezas disponibles (" + items.length + ")"); h.style.cssText = "font-size:1.8rem;margin:34px 0 14px"; root.appendChild(h);
    if (!items.length) root.appendChild(el("p", "empty-s", blocked ? "Has bloqueado a este vendedor." : "No hay piezas publicadas ahora mismo."));
    var grid = el("div", "grid");
    items.forEach(function (p) {
      var a = el("a", "pcard"); a.href = "../?p=" + p.id; a.style.textDecoration = "none"; a.style.color = "inherit";
      var m = el("div", "pcard__media"), im = new Image(); im.src = p.img.indexOf("data:") === 0 ? p.img : p.img + "?auto=format&fit=crop&w=480&h=600&q=70"; im.alt = p.title; im.loading = "lazy"; m.appendChild(im);
      var bd = el("div", "pcard__body"); add(bd, el("h3", "pcard__title", p.title), el("div", "pcard__price", U.money(p.price))); add(a, m, bd); grid.appendChild(a);
    });
    root.appendChild(grid);

    // valoraciones
    var rv = INT.review.forSeller(s.id).slice().reverse();
    if (rv.length) {
      var hr = el("h2", null, "Valoraciones de compras verificadas"); hr.style.cssText = "font-size:1.8rem;margin:34px 0 14px"; root.appendChild(hr);
      rv.forEach(function (r) { var c = el("div", "thread"); add(c, el("header", null, "★".repeat(r.rating) + "☆".repeat(5 - r.rating)), el("p", null, r.text || "(sin comentario)"), el("p", "muted-s", U.date(r.at))); if (r.reply) c.appendChild(el("p", "muted-s", "Respuesta de la tienda: " + r.reply.text)); root.appendChild(c); });
    }
  }
  INT.onChange(function () { /* cambios desde otra pestaña */ });
  render();
})();
