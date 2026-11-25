/* Intimae · administración (modo demostración, sin seguridad real) */
(function () {
  "use strict";
  var U = window.UI, el = U.el, add = U.add, $ = function (s) { return document.querySelector(s); };
  var ctl = null, A = INT.admin;
  I18N.start();

  function D() { return INT.data(); }
  function sellerOf(id) { return D().sellers.filter(function (s) { return s.id === id; })[0]; }
  function refresh() { ctl.refresh(); }
  function thumb(l) { return l.img && l.img.indexOf("data:") === 0 ? l.img : l.img + "?auto=format&fit=crop&w=160&h=200&q=70"; }
  function kpi(label, value) { var k = el("div", "kpi"); add(k, el("span", "eyebrow", label), el("b", "num", String(value))); return k; }
  function ask(text) { var v = prompt(text); return v == null ? null : v.trim(); }

  function renderAuth() {
    var box = U.clear($("#auth")); box.hidden = false; $("#app").hidden = true; $("#logout").hidden = true;
    var f = el("form", "card form stack"); f.style.maxWidth = "420px";
    add(f, el("h2", null, "Acceso"), U.field("Contraseña de demostración", U.input("pass", "password", { required: "", autocomplete: "off" }), "Contraseña de demostración: demo-admin"));
    var b = el("button", "btn btn--block", "Entrar"); b.type = "submit"; f.appendChild(b);
    f.addEventListener("submit", function (e) { e.preventDefault(); var d = new FormData(f); U.run(function () { return A.login(d.get("pass")); }).then(render, function () {}); });
    box.appendChild(f);
  }

  function tabModeration(p) {
    var list = D().listings.filter(function (l) { return l.status === "pending"; });
    var k = el("div", "kpis"); add(k, kpi("Anuncios pendientes", list.length), kpi("Publicados", D().listings.filter(function (l) { return l.status === "active"; }).length), kpi("Pedidos", D().orders.length), kpi("Vendedores", D().sellers.filter(function (s) { return !s.seed; }).length)); p.appendChild(k);
    if (!list.length) return p.appendChild(el("p", "empty-s", "No hay anuncios pendientes de revisión."));
    list.forEach(function (l) {
      var r = el("div", "row-card"), im = el("img"); im.src = thumb(l); im.alt = ""; im.width = 72; im.height = 90;
      var info = el("div"), s = sellerOf(l.seller);
      add(info, el("h3", null, l.title), el("small", null, "N.º " + l.ref + " · " + l.type + " · " + l.size + " · " + l.days + " días · " + U.money(l.price) + " · Vendedor " + (s ? s.alias : l.seller)), el("p", "muted-s", l.desc || ""));
      var th = el("div", "thumbs"); (l.imgs || []).forEach(function (d) { var i = el("img"); i.src = d; i.alt = ""; th.appendChild(i); }); info.appendChild(th);
      var acts = el("div", "acts");
      add(acts, U.btn("Aprobar", function () { U.run(function () { return A.approve(l.id); }, "Anuncio publicado.").then(refresh, function () {}); }), U.btn("Rechazar", function () { var m = ask("Motivos del rechazo (se comunican al vendedor):"); if (m) U.run(function () { return A.reject(l.id, m); }, "Anuncio rechazado.").then(refresh, function () {}); }, "btn--line"));
      info.appendChild(acts); add(r, im, info, U.pill("pending")); p.appendChild(r);
    });
  }

  function tabReports(p) {
    var rs = D().reports.slice().sort(function (a, b) { return b.id - a.id; });
    p.appendChild(el("p", "app-sub", "Denuncias de contenido (Reglamento (UE) 2022/2065). Al retirar un anuncio se registran y se comunican al vendedor los motivos de la decisión."));
    if (!rs.length) return p.appendChild(el("p", "empty-s", "No hay denuncias."));
    rs.forEach(function (r) {
      var c = el("div", "thread"), h = el("header"); add(h, el("span", null, r.no + " · anuncio N.º " + r.listingRef + " · " + r.reason), U.pill(r.status === "open" ? "open" : r.status === "removed" ? "removed" : "dismissed")); c.appendChild(h);
      add(c, el("p", null, r.text || "(sin texto)"), el("p", "muted-s", U.date(r.at) + (r.email ? " · contacto: " + r.email : " · sin contacto")));
      if (r.statement) c.appendChild(el("p", "muted-s", "Decisión: " + r.statement));
      if (r.status === "open") {
        var acts = el("div", "acts"); acts.style.cssText = "display:flex;gap:10px;margin-top:10px";
        add(acts, U.btn("Retirar anuncio", function () { var m = ask("Motivos de la retirada (se comunican al vendedor):"); if (m) U.run(function () { return A.resolveReport(r.id, "remove", m); }, "Anuncio retirado.").then(refresh, function () {}); }), U.btn("Desestimar", function () { var m = ask("Motivos para desestimar:"); if (m) U.run(function () { return A.resolveReport(r.id, "dismiss", m); }, "Denuncia desestimada.").then(refresh, function () {}); }, "btn--line"));
        c.appendChild(acts);
      }
      p.appendChild(c);
    });
  }

  function tabSellers(p) {
    var list = D().sellers.filter(function (s) { return !s.seed; });
    if (!list.length) return p.appendChild(el("p", "empty-s", "No hay solicitudes de vendedores."));
    p.appendChild(U.table(["Alias", "Correo", "País", "Tipo", "Datos fiscales", "Estado", "Acciones"], list.map(function (s) {
      var acts = el("div", "acts"); acts.style.cssText = "display:flex;gap:6px;flex-wrap:wrap";
      if (s.status !== "verified") acts.appendChild(U.btn("Verificar", function () { U.run(function () { return A.verifySeller(s.id); }, "Vendedor verificado.").then(refresh, function () {}); }));
      if (s.status === "verified") acts.appendChild(U.btn("Suspender", function () { U.run(function () { return A.setSellerStatus(s.id, "suspended"); }).then(refresh, function () {}); }, "btn--line"));
      if (s.status === "suspended") acts.appendChild(U.btn("Reactivar", function () { U.run(function () { return A.setSellerStatus(s.id, "verified"); }).then(refresh, function () {}); }, "btn--line"));
      return [s.alias, s.email, s.country, s.type + (s.vat === "margin" ? " (margen)" : ""), s.fiscal && s.fiscal.complete ? "Completos" : "Incompletos", U.pill(s.status), acts];
    })));
  }

  function tabOrders(p) {
    INT.tick(); var list = D().orders.slice().sort(function (a, b) { return b.id - a.id; });
    if (!list.length) return p.appendChild(el("p", "empty-s", "No hay pedidos."));
    p.appendChild(U.table(["Pedido", "Fecha", "Vendedor", "Total", "Comisión", "Estado", "Acciones"], list.map(function (o) {
      var s = sellerOf(o.seller), acts = el("div", "acts"); acts.style.cssText = "display:flex;gap:6px;flex-wrap:wrap";
      if (o.status === "paid_held" && s && s.seed) acts.appendChild(U.btn("Enviar (demo)", function () { U.run(function () { return A.demoShip(o.id); }).then(refresh, function () {}); }, "btn--line"));
      if (o.status === "shipped" && s && s.seed) acts.appendChild(U.btn("Entregar (demo)", function () { U.run(function () { var x = INT.orders.get(o.id); return INT.orders.confirmReceipt(x.buyer, o.id); }).then(refresh, function () {}); }, "btn--line"));
      if (o.status === "delivered") acts.appendChild(U.btn("Liberar pago", function () { U.run(function () { return A.forceRelease(o.id); }, "Pago liquidado.").then(refresh, function () {}); }));
      return [o.no, U.date(o.createdAt), s ? s.alias : o.seller, U.money(o.total), U.money(o.commission), U.pill(o.status), acts];
    })));
  }

  function tabDac7(p) {
    var year = new Date().getFullYear(), sel = U.select("year", [year, year - 1].map(String), String(year)), host = el("div");
    function paint() {
      U.clear(host); var rows = A.dac7(sel.value);
      host.appendChild(el("p", "app-sub", "Umbrales DAC7 (exención por debajo): menos de " + INT.DAC7.ops + " operaciones y hasta " + INT.DAC7.amount + " € de contraprestación al año. Solo cuentan pedidos liquidados en el año."));
      if (!rows.length) return host.appendChild(el("p", "empty-s", "No hay vendedores registrados."));
      host.appendChild(U.table(["Vendedor", "Nombre", "NIF", "País fiscal", "Operaciones", "Importe", "Comisiones", "Comunicable"], rows.map(function (r) { return [r.alias, r.legalName || "—", r.taxId || "—", r.taxCountry || "—", r.ops, U.money(r.amount), U.money(r.fees), r.reportable ? U.pill("warn", "Sí") : "No"]; })));
      host.appendChild(U.btn("Descargar CSV DAC7", function () {
        U.download("dac7-" + sel.value + ".csv", U.csv([["id", "alias", "nombre", "nif", "pais_fiscal", "domicilio", "fecha_nacimiento", "pais", "tipo", "iva", "operaciones", "importe", "comisiones", "comunicable", "datos_completos"]]
          .concat(rows.map(function (r) { return [r.id, r.alias, r.legalName, r.taxId, r.taxCountry, r.address, r.birth, r.country, r.type, r.vatId, r.ops, r.amount, r.fees, r.reportable ? "si" : "no", r.complete ? "si" : "no"]; }))), "text/csv;charset=utf-8");
      }, "btn--line"));
    }
    sel.addEventListener("change", paint); add(p, U.field("Año", sel), host); paint();
  }

  function tabSettings(p) {
    var s = INT.settings(), f = el("form", "card form stack"); f.style.maxWidth = "520px"; f.appendChild(el("h2", null, "Ajustes"));
    add(f, U.field("Comisión sobre el precio de los artículos (%)", U.input("commission", "number", { min: "0", max: "50", step: "0.5", value: s.commission }), "Propuesta pendiente de confirmar. Se aplica a los pedidos nuevos."),
      U.field("Días desde el envío hasta la entrega automática", U.input("autoDeliverDays", "number", { min: "1", max: "60", value: s.autoDeliverDays })),
      U.field("Días desde la entrega hasta liquidar al vendedor", U.input("autoReleaseDays", "number", { min: "0", max: "30", value: s.autoReleaseDays })));
    var b = el("button", "btn", "Guardar ajustes"); b.type = "submit"; f.appendChild(b);
    f.addEventListener("submit", function (e) { e.preventDefault(); var d = new FormData(f); U.run(function () { return A.setSettings({ commission: d.get("commission"), autoDeliverDays: d.get("autoDeliverDays"), autoReleaseDays: d.get("autoReleaseDays") }); }, "Ajustes guardados.").then(refresh, function () {}); });
    p.appendChild(f);
    var z = el("div", "card stack"); z.style.cssText = "max-width:520px;margin-top:18px"; add(z, el("h2", null, "Restablecer demostración"), el("p", "muted-s", "Borra cuentas, anuncios, pedidos y mensajes de este navegador y vuelve a los datos de ejemplo."), U.btn("Restablecer", function () { if (confirm("Se borrará todo lo guardado en este navegador. ¿Continuar?")) U.run(function () { return A.reset(); }, "Datos restablecidos.").then(refresh, function () {}); }, "btn--line")); p.appendChild(z);
  }

  function tabAudit(p) {
    var rows = D().audit.slice().reverse().slice(0, 100).map(function (a) { return [U.date(a.at), a.actor, a.action, a.detail]; });
    if (!rows.length) return p.appendChild(el("p", "empty-s", "Sin registros."));
    p.appendChild(U.table(["Fecha", "Actor", "Acción", "Detalle"], rows));
  }

  function render() {
    if (!A.isIn()) return renderAuth();
    INT.tick(); $("#auth").hidden = true; $("#app").hidden = false; $("#logout").hidden = false;
    var pend = function () { return D().listings.filter(function (l) { return l.status === "pending"; }).length; };
    var open = function () { return D().reports.filter(function (r) { return r.status === "open"; }).length; };
    ctl = U.tabs($("#tabbar"), $("#panel"), [
      { id: "moderacion", label: "Moderación", badge: pend, render: tabModeration },
      { id: "denuncias", label: "Denuncias", badge: open, render: tabReports },
      { id: "vendedores", label: "Vendedores", render: tabSellers },
      { id: "pedidos", label: "Pedidos", render: tabOrders },
      { id: "dac7", label: "DAC7", render: tabDac7 },
      { id: "ajustes", label: "Ajustes", render: tabSettings },
      { id: "auditoria", label: "Auditoría", render: tabAudit }
    ]);
  }
  $("#logout").addEventListener("click", function () { A.logout(); render(); });
  render();
})();
