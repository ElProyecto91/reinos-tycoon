/* Intimae · cuenta de comprador (modo demostración) */
(function () {
  "use strict";
  var U = window.UI, el = U.el, add = U.add, $ = function (s) { return document.querySelector(s); };
  var nextP = new URLSearchParams(location.search).get("next");
  var target = nextP === "cart" ? "../?cart=1" : nextP === "store" ? "../" : "";
  var tabsCtl = null;

  I18N.mountSelect($("#lang"));
  I18N.onChange(function (l) { var n = $("#es-only"); n.hidden = l === "es"; n.textContent = I18N.t("app.es_only"); });
  I18N.start();

  function alias(id) { var s = INT.data().sellers.filter(function (x) { return x.id === id; })[0]; return s ? s.alias : id; }
  function after() { if (target && INT.buyer.current() && (nextP !== "cart" || INT.buyer.current().ageVerified)) location.href = target; else render(); }

  function composer(placeholder, onSend, label) {
    var f = el("form", "inline-form"), ta = el("textarea"); ta.placeholder = placeholder; ta.maxLength = 600; ta.style.minHeight = "44px"; ta.required = true;
    var b = U.btn(label || "Enviar", function () {}); b.type = "submit"; add(f, ta, b);
    f.addEventListener("submit", function (e) {
      e.preventDefault();
      U.run(function () { return onSend(ta.value); }).then(function () { ta.value = ""; }, function () {});
    });
    return f;
  }
  function msgError(e) { if (e && e.message === "blocked") e.message = "Por seguridad, no se pueden compartir correos, teléfonos ni enlaces."; throw e; }

  /* ---------- acceso ---------- */
  function renderAuth() {
    var box = U.clear($("#auth")), g = el("div", "auth-grid"); box.hidden = false; $("#app").hidden = true; $("#logout").hidden = true;
    var lf = el("form", "card form stack"); lf.noValidate = false;
    add(lf, el("h2", null, "Entrar"), U.field("Correo", U.input("email", "email", { required: "", autocomplete: "email" })), U.field("Contraseña", U.input("pass", "password", { required: "", autocomplete: "current-password" })));
    var lb = el("button", "btn btn--block", "Entrar"); lb.type = "submit"; lf.appendChild(lb);
    lf.addEventListener("submit", function (e) { e.preventDefault(); var d = new FormData(lf); U.run(function () { return INT.buyer.login(d.get("email"), d.get("pass")); }).then(after, function () {}); });

    var rf = el("form", "card form stack");
    add(rf, el("h2", null, "Crear cuenta"), U.field("Nombre o alias", U.input("name", "text", { required: "", maxlength: "60", autocomplete: "nickname" })),
      U.field("Correo", U.input("email", "email", { required: "", autocomplete: "email" })),
      U.field("Contraseña", U.input("pass", "password", { required: "", minlength: "8", autocomplete: "new-password" }), "Mínimo 8 caracteres."));
    var ck = el("label", "check"), cb = el("input"); cb.type = "checkbox"; cb.name = "ok"; cb.required = true;
    add(ck, cb, el("span", null, "Soy mayor de 18 años y acepto las condiciones de compra y la política de privacidad."));
    rf.appendChild(ck);
    var rb = el("button", "btn btn--block", "Crear cuenta"); rb.type = "submit"; rf.appendChild(rb);
    rf.addEventListener("submit", function (e) { e.preventDefault(); var d = new FormData(rf); U.run(function () { return INT.buyer.register({ name: d.get("name"), email: d.get("email"), pass: d.get("pass") }); }, "Cuenta creada.").then(after, function () {}); });
    add(g, lf, rf); box.appendChild(g);
  }

  /* ---------- pedidos ---------- */
  function orderCard(o) {
    var c = el("article", "card"), head = el("div", "row-card"); head.style.cssText = "grid-template-columns:1fr auto;padding-top:0";
    var l = el("div"); add(l, el("h3", null, o.no), el("small", null, U.date(o.createdAt) + " · Vendedor: " + alias(o.seller)));
    add(head, l, U.pill(o.status)); c.appendChild(head);
    var ul = el("ul"); o.items.forEach(function (it) { ul.appendChild(el("li", null, "N.º " + it.ref + " · " + it.title + " · " + U.money(it.unit))); }); c.appendChild(ul);
    c.appendChild(el("p", "muted-s", "Subtotal " + U.money(o.subtotal) + " · Envío " + U.money(o.shipping) + " · Total " + U.money(o.total) + " · Entrega en " + I18N.country(o.dest)));
    if (o.tracking) c.appendChild(el("p", "muted-s", "Seguimiento: " + o.carrier + " " + o.tracking));
    var h = el("ul", "history"); o.history.forEach(function (x) { h.appendChild(el("li", null, U.date(x.at) + " · " + (U.STATUS[x.status] ? U.STATUS[x.status][0] : x.status) + (x.note ? " (" + x.note + ")" : ""))); }); c.appendChild(h);
    var acts = el("div", "acts"); acts.style.marginTop = "12px";
    var u = INT.buyer.current();
    if (o.status === "paid_held") acts.appendChild(U.btn("Cancelar pedido", function () { if (confirm("Se cancelará el pedido y se te devolverá el importe completo. ¿Continuar?")) U.run(function () { return INT.orders.cancel("buyer", u.id, o.id); }, "Pedido cancelado. Importe devuelto.").then(function () { tabsCtl.refresh(); }, function () {}); }, "btn--line"));
    if (o.status === "shipped") acts.appendChild(U.btn("Confirmar recepción", function () { U.run(function () { return INT.orders.confirmReceipt(u.id, o.id); }, "Recepción confirmada.").then(function () { tabsCtl.refresh(); }, function () {}); }));
    c.appendChild(acts);
    if (o.status === "delivered" || o.status === "released") {
      var rv = INT.review.forOrder(o.id);
      if (rv) c.appendChild(el("p", "muted-s", "Tu valoración: " + "★".repeat(rv.rating) + "☆".repeat(5 - rv.rating) + (rv.text ? " · " + rv.text : "")));
      else {
        var f = el("form", "inline-form"), sel = U.select("rating", [["5", "5 ★"], ["4", "4 ★"], ["3", "3 ★"], ["2", "2 ★"], ["1", "1 ★"]]), tx = el("input"); tx.placeholder = "Comentario (opcional)"; tx.maxLength = 300;
        var b = U.btn("Valorar al vendedor", function () {}); b.type = "submit"; add(f, sel, tx, b); f.style.marginTop = "12px";
        f.addEventListener("submit", function (e) { e.preventDefault(); U.run(function () { return INT.review.create(u.id, o.id, sel.value, tx.value); }, "Gracias por tu valoración.").then(function () { tabsCtl.refresh(); }, function () {}); });
        c.appendChild(f);
      }
    }
    if (["cancelled"].indexOf(o.status) === -1) {
      var d = el("details"); d.style.marginTop = "12px"; d.appendChild(el("summary", null, "Escribir al vendedor sobre este pedido"));
      d.appendChild(composer("Tu mensaje. No compartas datos personales.", function (t) { return Promise.resolve().then(function () { return INT.msg.start(u.id, o.items[0].listing, "[" + o.no + "] " + t); }).catch(msgError).then(function () { U.toast("Mensaje enviado."); }); }, "Enviar"));
      c.appendChild(d);
    }
    return c;
  }
  function tabOrders(p) {
    var u = INT.buyer.current(); INT.tick();
    p.appendChild(el("p", "app-sub", "Intimae es solo intermediario: no gestiona devoluciones, reclamaciones ni disputas. Cualquier asunto sobre una compra se resuelve con el vendedor por mensajes. Antes del envío puedes cancelar y recuperar el importe íntegro."));
    var list = INT.orders.forBuyer(u.id);
    if (!list.length) return p.appendChild(el("p", "empty-s", "Todavía no tienes pedidos."));
    list.forEach(function (o) { var c = orderCard(o); c.style.marginBottom = "14px"; p.appendChild(c); });
  }

  /* ---------- favoritos ---------- */
  function tabFavs(p) {
    var u = INT.buyer.current(), list = INT.fav.list(u.id);
    if (!list.length) return p.appendChild(el("p", "empty-s", "No tienes favoritos. Pulsa el corazón de una prenda en la tienda."));
    list.forEach(function (l) {
      var r = el("div", "row-card"), im = el("img"); im.alt = ""; im.src = l.img.indexOf("data:") === 0 ? l.img : l.img + "?auto=format&fit=crop&w=160&h=200&q=70"; im.width = 72; im.height = 90;
      var info = el("div"); add(info, el("h3", null, l.title), el("small", null, "N.º " + l.ref + " · " + alias(l.seller) + " · " + l.size), l.status === "active" ? null : U.pill(l.status, "No disponible"));
      var acts = el("div", "acts");
      if (l.status === "active") { var a = el("a", "btn btn--sm", "Ver ficha"); a.href = "../?p=" + l.id; acts.appendChild(a); }
      acts.appendChild(U.btn("Quitar", function () { INT.fav.toggle(u.id, l.id); tabsCtl.refresh(); }, "btn--line"));
      info.appendChild(acts); add(r, im, info, el("strong", "num", U.money(l.price))); p.appendChild(r);
    });
  }

  /* ---------- mensajes ---------- */
  function tabMsgs(p) {
    var u = INT.buyer.current(), list = INT.msg.forBuyer(u.id);
    if (!list.length) return p.appendChild(el("p", "empty-s", "No tienes conversaciones. Escribe a un vendedor desde la ficha de una prenda."));
    p.appendChild(el("p", "app-sub", "Por seguridad no se pueden compartir correos, teléfonos ni enlaces."));
    list.forEach(function (t) {
      var unread = INT.msg.unread(t, "buyer"), c = el("div", "thread"), h = el("header");
      add(h, el("span", null, t.listingTitle + " · " + alias(t.seller)), unread ? U.pill("warn", unread + " sin leer") : null); c.appendChild(h);
      var bb = el("div", "bubbles"); t.msgs.forEach(function (m) { var b = el("div", "bubble" + (m.from === "b" ? " me" : ""), m.text); b.appendChild(el("small", null, (m.from === "b" ? "Tú" : alias(t.seller)) + " · " + U.date(m.at))); bb.appendChild(b); }); c.appendChild(bb);
      c.appendChild(composer("Responder…", function (tx) { return Promise.resolve().then(function () { return INT.msg.reply(t.id, "buyer", tx); }).catch(msgError).then(function () { tabsCtl.refresh(); }); }, "Enviar"));
      p.appendChild(c); INT.msg.markRead(t.id, "buyer");
    });
  }

  /* ---------- datos ---------- */
  function tabData(p) {
    var u = INT.buyer.current(), g = el("div", "auth-grid");
    var f = el("form", "card form stack"); f.appendChild(el("h2", null, "Mis datos"));
    var country = U.select("country", [["", "—"]].concat(TAX.countries.filter(function (c) { return c.open; }).sort(function (a, b) { return I18N.country(a.code).localeCompare(I18N.country(b.code), "es"); }).map(function (c) { return [c.code, I18N.country(c.code)]; })), u.country);
    var addr = el("textarea"); addr.name = "addr"; addr.value = u.addr; addr.maxLength = 300;
    add(f, U.field("Nombre o alias", U.input("name", "text", { maxlength: "60", value: u.name })), U.field("Correo", U.input("email", "email", { value: u.email, readonly: "" })), U.field("Dirección de entrega", addr), U.field("País", country));
    var sb = el("button", "btn", "Guardar"); sb.type = "submit"; f.appendChild(sb);
    f.addEventListener("submit", function (e) { e.preventDefault(); var d = new FormData(f); U.run(function () { return INT.buyer.update({ name: d.get("name"), addr: d.get("addr"), country: d.get("country") }); }, "Datos guardados."); });

    var a = el("div", "card stack"); a.appendChild(el("h2", null, "Verificación de edad"));
    if (u.ageVerified) add(a, U.pill("ok", "Edad verificada"), el("p", "muted-s", "Verificada el " + U.date(u.ageVerified.at) + " (método: " + u.ageVerified.method + " — simulación). No guardamos tu fecha de nacimiento."));
    else {
      add(a, el("p", "muted-s", "SIMULACIÓN: introduce tu fecha de nacimiento. Solo comprobamos que tienes 18 años o más y no la guardamos. En la versión real lo hará un proveedor externo de verificación."));
      var af = el("form", "form stack"), di = U.input("birth", "date", { required: "" }); af.appendChild(U.field("Fecha de nacimiento", di));
      var ab = el("button", "btn", "Verificar edad"); ab.type = "submit"; af.appendChild(ab);
      af.addEventListener("submit", function (e) { e.preventDefault(); var p3 = di.value.split("-"); U.run(function () { return INT.buyer.verifyAge(p3[0], p3[1], p3[2]); }, "Edad verificada.").then(function () { if (target) location.href = target; else tabsCtl.refresh(); }, function () {}); });
      a.appendChild(af);
    }
    var pr = el("div", "card stack"); pr.style.gridColumn = "1/-1"; pr.appendChild(el("h2", null, "Privacidad"));
    add(pr, el("p", "muted-s", "Puedes descargar todos tus datos o cerrar tu cuenta. Al cerrarla se borran tus datos personales; los pedidos se conservan sin nombre ni dirección."));
    var acts = el("div", "acts"); acts.style.display = "flex"; acts.style.gap = "10px";
    add(acts, U.btn("Descargar mis datos", function () { U.download("intimae-mis-datos.json", JSON.stringify(INT.buyer.exportData(), null, 2), "application/json"); }, "btn--line"),
      U.btn("Cerrar mi cuenta", function () { if (confirm("Se eliminarán tus datos personales. Esta acción no se puede deshacer. ¿Continuar?")) U.run(function () { return INT.buyer.remove(); }, "Cuenta cerrada.").then(render, function () {}); }, "btn--line"));
    pr.appendChild(acts);
    add(g, f, a, pr); p.appendChild(g);
  }

  function render() {
    var u = INT.buyer.current(); INT.tick();
    if (!u) { $("#sub").textContent = "Entra o crea una cuenta para pagar, guardar favoritos y escribir a los vendedores."; return renderAuth(); }
    $("#auth").hidden = true; $("#app").hidden = false; $("#logout").hidden = false; $("#sub").textContent = u.name ? "Hola, " + u.name + "." : "Tus pedidos, favoritos y mensajes con vendedores.";
    var unread = function () { return INT.msg.forBuyer(u.id).reduce(function (a, t) { return a + INT.msg.unread(t, "buyer"); }, 0); };
    tabsCtl = U.tabs($("#tabbar"), $("#panel"), [
      { id: "pedidos", label: "Pedidos", render: tabOrders },
      { id: "favoritos", label: "Favoritos", render: tabFavs },
      { id: "mensajes", label: "Mensajes", badge: unread, render: tabMsgs },
      { id: "datos", label: "Mis datos", render: tabData }
    ]);
  }
  $("#logout").addEventListener("click", function () { INT.buyer.logout(); render(); });
  INT.onChange(function () { /* otra pestaña ha cambiado los datos */ });
  render();
})();
