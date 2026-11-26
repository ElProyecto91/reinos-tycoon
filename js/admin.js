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

  /* ============ Resumen, estadísticas y errores ============ */
  var TIPOS = { js: "Error de JavaScript", promise: "Promesa rechazada", resource: "Recurso que no carga", csp: "Bloqueo de seguridad (CSP)", console: "console.error", app: "Fallo de la aplicación" };
  var PAGES = { tienda: "Tienda", cuenta: "Cuenta", vendedores: "Alta de vendedores", "panel-vendedor": "Panel de vendedor", "tienda-publica": "Tienda pública", legal: "Legal (índice)" };
  function pct(a, b) { return b ? Math.round(a * 1000 / b) / 10 + " %" : "—"; }
  function eur(c) { return U.money((c || 0) / 100); }
  function days(n) { var out = []; for (var i = n - 1; i >= 0; i--) out.push(new Date(Date.now() - i * 864e5).toISOString().slice(0, 10)); return out; }
  function sum(stats, ds, key) { return ds.reduce(function (a, d) { return a + ((stats.days[d] || {})[key] || 0); }, 0); }
  function tally(stats, ds, prefix) {
    var o = {}; ds.forEach(function (d) { var day = stats.days[d] || {}; Object.keys(day).forEach(function (k) { if (k.indexOf(prefix) === 0) o[k.slice(prefix.length)] = (o[k.slice(prefix.length)] || 0) + day[k]; }); });
    return Object.keys(o).map(function (k) { return [k, o[k]]; }).sort(function (a, b) { return b[1] - a[1]; });
  }
  function rank(rows, total, label) {
    if (!rows.length) return el("p", "muted-s", "Sin datos todavía.");
    var box = el("div"); rows.slice(0, 8).forEach(function (r) { var w = el("div"); w.style.margin = "8px 0"; add(w, el("span", null, (label ? label(r[0]) : r[0]) + " · " + r[1] + (total ? " (" + pct(r[1], total) + ")" : ""))); var b = el("div", "bar-h"), i = el("i"); i.style.width = (total ? Math.min(100, r[1] * 100 / total) : 100) + "%"; b.appendChild(i); w.appendChild(b); box.appendChild(w); });
    return box;
  }
  function section(title, node) { var c = el("section", "card"); c.style.marginBottom = "18px"; var h = el("h3", null, title); h.style.cssText = "font-size:1.35rem;margin-bottom:10px"; add(c, h, node); return c; }

  function health() {
    var d = D(), st = d.settings, t = Date.now(), out = [], T = TEL.read();
    function a(level, text) { out.push([level, text]); }
    var pend = d.listings.filter(function (l) { return l.status === "pending" && t - (l.history && l.history.length ? l.history[l.history.length - 1].at : t) > 2 * 864e5; }).length;
    var late = d.orders.filter(function (o) { return o.status === "paid" && t - o.createdAt > st.shipDeadlineDays * 864e5; }).length;
    var inc = d.incidents.filter(function (i) { return i.status !== "resolved"; }), incOld = inc.filter(function (i) { return t - i.at > st.incidentReplyDays * 864e5; }).length;
    var sel = d.sellers.filter(function (s) { return !s.seed && s.status === "pending" && t - (s.createdAt || t) > 3 * 864e5; }).length;
    var rep = d.reports.filter(function (r) { return r.status === "open" && t - r.at > 2 * 864e5; }).length;
    var openErr = T.errors.list.filter(function (e) { return e.status === "open"; }), recent = openErr.filter(function (e) { return t - e.last < 864e5; }), csp = T.errors.list.filter(function (e) { return e.type === "csp" && e.status === "open"; });
    var bytes = 0; try { Object.keys(localStorage).forEach(function (k) { bytes += (localStorage.getItem(k) || "").length * 2; }); } catch (e) {}
    var usedPct = Math.round(bytes * 100 / (5 * 1024 * 1024));
    a(pend ? "warn" : "ok", pend ? pend + " anuncio(s) llevan más de 2 días pendientes de moderación." : "Moderación al día.");
    a(late ? "warn" : "ok", late ? late + " pedido(s) pagados sin enviar pasado el plazo de preparación (" + st.shipDeadlineDays + " días)." : "Ningún pedido fuera de plazo de preparación.");
    a(incOld ? "bad" : inc.length ? "warn" : "ok", inc.length ? inc.length + " incidencia(s) abierta(s)" + (incOld ? ", " + incOld + " fuera del plazo de respuesta" : "") + "." : "Sin incidencias abiertas.");
    a(sel ? "warn" : "ok", sel ? sel + " solicitud(es) de vendedor esperan verificación más de 3 días." : "Verificaciones de vendedores al día.");
    a(rep ? "warn" : "ok", rep ? rep + " denuncia(s) llevan más de 2 días sin resolver." : "Denuncias al día.");
    a(recent.length ? "bad" : openErr.length ? "warn" : "ok", recent.length ? recent.length + " error(es) abiertos con actividad en las últimas 24 h." : openErr.length ? openErr.length + " error(es) abierto(s) sin actividad reciente." : "Sin errores abiertos.");
    if (csp.length) a("warn", csp.length + " bloqueo(s) de la política de seguridad (CSP) abiertos: revisa si bloquean algo legítimo.");
    a(usedPct > 80 ? "bad" : usedPct > 50 ? "warn" : "ok", "Almacenamiento del navegador: " + usedPct + " % de unos 5 MB." + (INT.memoryOnly() ? " ATENCIÓN: el último guardado falló." : ""));
    return out;
  }

  function tabOverview(p) {
    var d = D(), os = d.orders, live = os.filter(function (o) { return ["cancelled", "refunded"].indexOf(o.status) === -1; });
    var gmv = live.reduce(function (a, o) { return a + o.total; }, 0), comm = live.reduce(function (a, o) { return a + o.commission; }, 0);
    var done = os.filter(function (o) { return o.status === "released"; }), real = d.sellers.filter(function (s) { return !s.seed; });
    var count = function (arr, k, v) { return arr.filter(function (x) { return x[k] === v; }).length; };
    var T = TEL.read(), openErr = T.errors.list.filter(function (e) { return e.status === "open"; }).length;
    var al = el("div"); health().forEach(function (h) { var r = el("div", "alert " + h[0]); add(r, U.pill(h[0] === "ok" ? "ok" : h[0] === "warn" ? "warn" : "removed", h[0] === "ok" ? "OK" : h[0] === "warn" ? "Revisar" : "Urgente"), el("span", null, h[1])); al.appendChild(r); });
    p.appendChild(section("Requiere atención", al));
    var k = el("div", "kpis");
    add(k, kpi("Compradores", d.users.filter(function (u) { return !u.deleted; }).length), kpi("Vendedores (reales)", real.length), kpi("— verificados", count(real, "status", "verified")), kpi("— pendientes", count(real, "status", "pending")), kpi("— suspendidos", count(real, "status", "suspended")),
      kpi("Anuncios publicados", count(d.listings, "status", "active")), kpi("Pendientes de revisión", count(d.listings, "status", "pending")), kpi("Borradores", count(d.listings, "status", "draft")), kpi("Vendidos", count(d.listings, "status", "sold")));
    p.appendChild(section("Comunidad y catálogo", k));
    var k2 = el("div", "kpis");
    add(k2, kpi("Pedidos", os.length), kpi("Volumen (sin cancelados)", U.money(gmv)), kpi("Comisión generada", U.money(comm)), kpi("Ticket medio", U.money(live.length ? gmv / live.length : 0)), kpi("Liquidados", done.length),
      kpi("Cancelados", pct(count(os, "status", "cancelled"), os.length)), kpi("Con incidencia", pct(d.incidents.length, os.length)), kpi("Reembolsos", U.money(os.reduce(function (a, o) { return a + (o.refundAmount || 0); }, 0))), kpi("Valoración media", (function () { var r = d.reviews; return r.length ? (Math.round(r.reduce(function (a, x) { return a + x.rating; }, 0) * 10 / r.length) / 10) + " / 5 (" + r.length + ")" : "—"; })()));
    p.appendChild(section("Pedidos y dinero (demostración)", k2));
    var by = el("div"); ["paid", "shipped", "delivered", "incident", "disputed", "released", "refunded", "cancelled"].forEach(function (st) { by.appendChild(el("span", null, "")); var r = el("span", null, " "); r.appendChild(U.pill(st)); r.appendChild(document.createTextNode(" " + count(os, "status", st) + "   ")); by.appendChild(r); });
    p.appendChild(section("Pedidos por estado", by));
    var k3 = el("div", "kpis"); add(k3, kpi("Errores abiertos", openErr), kpi("Denuncias abiertas", count(d.reports, "status", "open")), kpi("Incidencias abiertas", d.incidents.filter(function (i) { return i.status !== "resolved"; }).length), kpi("Mensajes (hilos)", d.threads.length), kpi("Seguidores totales", d.follows.length), kpi("Favoritos", d.favs.length));
    p.appendChild(section("Moderación y actividad", k3));
    var lk = el("p", "muted-s"); lk.appendChild(document.createTextNode("Despliegues y registro de compilación en Vercel: ")); var a = el("a", "link", "vercel.com/elproyecto91s-projects/intimae"); a.href = "https://vercel.com/elproyecto91s-projects/intimae"; a.target = "_blank"; a.rel = "noopener noreferrer"; lk.appendChild(a); p.appendChild(lk);
  }

  function tabStats(p) {
    var T = TEL.read(), st = T.stats, sel = U.select("range", [["7", "Últimos 7 días"], ["14", "Últimos 14 días"], ["30", "Últimos 30 días"], ["90", "Últimos 90 días"]], "14"), host = el("div");
    p.appendChild(el("div", "demo-banner", "Estas estadísticas son las de **este navegador** (modo demostración: no se envía nada a ningún servidor), así que no incluyen a las personas a las que se lo enseñes desde otros dispositivos. Para ver las visitas reales hace falta un servidor o un servicio de analítica; ver la propuesta en el informe.".replace(/\*\*/g, "")));
    add(p, U.field("Periodo", sel), host);
    function paint() {
      U.clear(host); var n = +sel.value, ds = days(n), lab = function (d) { return d.slice(8) + "/" + d.slice(5, 7); };
      var series = function (key, fmt) { return ds.map(function (d) { return { label: lab(d), value: (st.days[d] || {})[key] || 0 }; }); };
      var tot = function (k) { return sum(st, ds, k); };
      var k = el("div", "kpis"); add(k, kpi("Páginas vistas", tot("pv")), kpi("Sesiones", tot("session")), kpi("Visitantes nuevos", tot("visitor.new")), kpi("Visitantes que vuelven", tot("visitor.returning")), kpi("Pedidos", tot("order.created")), kpi("Volumen", eur(tot("order.cents"))), kpi("Comisión", eur(tot("commission.cents"))), kpi("Errores", tot("error.total")));
      host.appendChild(k);
      var ch = el("div", "charts");
      add(ch, U.bars(series("pv"), { title: "Páginas vistas por día" }), U.bars(series("session"), { title: "Sesiones por día" }), U.bars(series("order.created"), { title: "Pedidos por día" }),
        U.bars(series("order.cents").map(function (x) { return { label: x.label, value: x.value / 100 }; }), { title: "Volumen por día (€)", fmt: function (v) { return Math.round(v) + " €"; } }),
        U.bars(series("signup.buyer").map(function (x, i) { return { label: x.label, value: x.value + series("signup.seller")[i].value }; }), { title: "Registros por día (compradores + vendedores)" }), U.bars(series("error.total"), { title: "Errores por día" }));
      host.appendChild(ch);
      // embudo
      var steps = [["Sesiones", tot("session")], ["Ficha abierta", tot("pdp.open")], ["Añadido al pedido", tot("cart.add")], ["Pedido abierto", tot("cart.open")], ["Intento de pago", tot("checkout.submit")], ["Pedido creado", tot("order.ok")]];
      var fb = el("div"); steps.forEach(function (s0, i) { var w = el("div"); w.style.margin = "8px 0"; w.appendChild(el("span", null, s0[0] + " · " + s0[1] + (i ? " (" + pct(s0[1], steps[i - 1][1]) + " del paso anterior)" : ""))); var b = el("div", "bar-h"), ii = el("i"); ii.style.width = (steps[0][1] ? Math.min(100, s0[1] * 100 / steps[0][1]) : 0) + "%"; b.appendChild(ii); w.appendChild(b); fb.appendChild(w); });
      host.appendChild(section("Embudo de compra", fb));
      var sp = el("div", "split");
      var pg = tally(st, ds, "pv:"), dev = tally(st, ds, "dev."), lang = tally(st, ds, "lang."), br = tally(st, ds, "br."), dest = tally(st, ds, "dest.");
      add(sp, section("Páginas más vistas", rank(pg, tot("pv"), function (x) { return PAGES[x] || x; })), section("Dispositivos", rank(dev, tot("session"))), section("Idiomas", rank(lang, lang.reduce(function (a, r) { return a + r[1]; }, 0), function (x) { return I18N.native[x] || x; })), section("Navegadores", rank(br, tot("session"))), section("País de envío elegido", rank(dest, dest.reduce(function (a, r) { return a + r[1]; }, 0), function (x) { return I18N.country(x); })), section("Uso de filtros", rank(tally(st, ds, "filter."), 0)));
      host.appendChild(sp);
      var terms = Object.keys(st.terms || {}).map(function (k0) { return [k0, st.terms[k0]]; }), top = terms.slice().sort(function (a, b) { return b[1].n - a[1].n; }).slice(0, 10), zero = terms.filter(function (x) { return x[1].zero > 0; }).sort(function (a, b) { return b[1].zero - a[1].zero; }).slice(0, 10);
      var sp2 = el("div", "split");
      add(sp2, section("Búsquedas más frecuentes", top.length ? U.table(["Término", "Veces"], top.map(function (x) { return [x[0], x[1].n]; })) : el("p", "muted-s", "Sin búsquedas todavía.")),
        section("Búsquedas sin resultados (demanda no cubierta)", zero.length ? U.table(["Término", "Veces sin resultado"], zero.map(function (x) { return [x[0], x[1].zero]; })) : el("p", "muted-s", "Ninguna.")));
      host.appendChild(sp2);
      var fr = tally(st, ds, "validation.");
      var sp3 = el("div", "split");
      add(sp3, section("Fricción de uso: validaciones que fallan", fr.length ? U.table(["Código", "Veces"], fr.slice(0, 12).map(function (x) { return [x[0], x[1]]; })) : el("p", "muted-s", "Ninguna.")),
        section("Fallos al pagar", (function () { var f2 = tally(st, ds, "checkout.fail."); return f2.length ? U.table(["Motivo", "Veces"], f2.map(function (x) { return [x[0], x[1]]; })) : el("p", "muted-s", "Ninguno."); })()));
      host.appendChild(sp3);
      var ops = [["Altas de compradores", "signup.buyer"], ["Solicitudes de vendedor", "signup.seller"], ["Vendedores verificados", "seller.verified"], ["Anuncios creados", "listing.created"], ["Anuncios aprobados", "listing.approved"], ["Anuncios rechazados", "listing.rejected"], ["Pedidos enviados", "order.shipped"], ["Pedidos entregados", "order.delivered"], ["Pedidos liquidados", "order.released"], ["Pedidos cancelados", "order.cancelled"], ["Incidencias abiertas", "incident.opened"], ["Denuncias", "report.created"], ["Mensajes enviados", "message.sent"], ["Valoraciones", "review.created"], ["Favoritos añadidos", "fav.added"], ["Tiendas seguidas", "follow.added"], ["Búsquedas guardadas", "search.saved"], ["Cambios de idioma", "lang.change"], ["Confirmaciones de edad", "agegate.ok"]];
      host.appendChild(section("Actividad (totales del periodo)", U.table(["Concepto", "Total"], ops.map(function (o) { return [o[0], tot(o[1])]; }))));
      var inc = tally(st, ds, "incident.reason.");
      if (inc.length) host.appendChild(section("Motivos de incidencia", rank(inc, inc.reduce(function (a, r) { return a + r[1]; }, 0), function (x) { return U.REASONS[x] || x; })));
      var pf = Object.keys(st.perf || {}).sort().map(function (k0) { var pp = st.perf[k0], q = k0.split("|"), unit = q[1] === "cls1000" ? "" : " ms", val = q[1] === "cls1000" ? (pp.sum / pp.n / 1000).toFixed(3) : Math.round(pp.sum / pp.n) + unit, mx = q[1] === "cls1000" ? (pp.max / 1000).toFixed(3) : Math.round(pp.max) + unit; return [PAGES[q[0]] || q[0], { carga: "Tiempo de carga", lcp: "LCP (pintado principal)", cls1000: "CLS (saltos de diseño)" }[q[1]] || q[1], val, mx, pp.n]; });
      host.appendChild(section("Rendimiento (media y peor caso)", pf.length ? U.table(["Página", "Métrica", "Media", "Máximo", "Muestras"], pf) : el("p", "muted-s", "Sin datos todavía.")));
      var acts = el("div"); acts.style.cssText = "display:flex;gap:10px;margin-top:10px;flex-wrap:wrap";
      add(acts, U.btn("Descargar estadísticas (JSON)", function () { U.download("intimae-estadisticas.json", JSON.stringify(TEL.read().stats, null, 2), "application/json"); }, "btn--line"), U.btn("Borrar estadísticas", function () { if (confirm("Se borrarán los contadores de este navegador. ¿Continuar?")) { TEL.clearStats(); refresh(); } }, "btn--line"));
      host.appendChild(acts);
    }
    sel.addEventListener("change", paint); paint();
  }

  function tabErrors(p) {
    var T = TEL.read(), list = T.errors.list.slice().sort(function (a, b) { return (a.status === "open" ? 0 : 1) - (b.status === "open" ? 0 : 1) || b.last - a.last; });
    var f1 = U.select("status", [["", "Todos los estados"], ["open", "Abiertos"], ["resolved", "Resueltos"], ["ignored", "Ignorados"]], "open"), f2 = U.select("type", [["", "Todos los tipos"]].concat(Object.keys(TIPOS).map(function (k) { return [k, TIPOS[k]]; })), ""), host = el("div");
    var bar = el("div"); bar.style.cssText = "display:flex;gap:14px;flex-wrap:wrap;align-items:flex-end;margin-bottom:16px"; add(bar, U.field("Estado", f1), U.field("Tipo", f2),
      U.btn("Probar la captura", function () { TEL.test(); setTimeout(refresh, 400); }, "btn--line"), U.btn("Descargar errores (JSON)", function () { U.download("intimae-errores.json", JSON.stringify(TEL.read().errors.list, null, 2), "application/json"); }, "btn--line"),
      U.btn("Borrar todo", function () { if (confirm("Se borrará el registro de errores de este navegador. ¿Continuar?")) { TEL.clearErrors(); refresh(); } }, "btn--line"));
    p.appendChild(el("p", "app-sub", "Errores recogidos en este navegador: fallos de JavaScript, promesas rechazadas, recursos que no cargan, bloqueos de seguridad (CSP), console.error y fallos de la aplicación. Se agrupan por causa. Un error resuelto que vuelve a ocurrir se reabre y se marca como regresión."));
    add(p, bar, host);
    function paint() {
      U.clear(host); var rows = list.filter(function (e) { return (!f1.value || e.status === f1.value) && (!f2.value || e.type === f2.value); });
      var openN = list.filter(function (e) { return e.status === "open"; }).length;
      host.appendChild(el("p", "muted-s", rows.length + " de " + list.length + " grupos · " + openN + " abiertos · " + list.reduce(function (a, e) { return a + e.count; }, 0) + " ocurrencias en total"));
      if (!rows.length) return host.appendChild(el("p", "empty-s", list.length ? "Ningún error con ese filtro." : "No se ha registrado ningún error en este navegador."));
      rows.forEach(function (e) {
        var c = el("div", "errcard"), h = el("header");
        add(h, el("strong", null, TIPOS[e.type] || e.type), el("span", null, e.count + " vez/veces"), U.pill(e.status === "open" ? "open" : e.status === "resolved" ? "resolved" : "dismissed", e.status === "open" ? "Abierto" : e.status === "resolved" ? "Resuelto" : "Ignorado"), e.regression ? U.pill("removed", "Regresión") : null);
        add(c, h, el("p", null, e.message), el("p", "muted-s", "Primera vez " + U.date(e.first) + " · última " + U.date(e.last) + (e.source ? " · " + e.source + (e.line ? ":" + e.line : "") : "") + " · páginas: " + Object.keys(e.pages).map(function (k0) { return (PAGES[k0] || k0) + " ×" + e.pages[k0]; }).join(", ")));
        var d = el("details"); d.appendChild(el("summary", null, "Detalles técnicos")); d.appendChild(el("pre", null, (e.stack || "(sin traza)") + "\n\nNavegador: " + e.ua + "\nPantalla: " + e.viewport + " · idioma: " + e.lang)); c.appendChild(d);
        var acts = el("div"); acts.style.cssText = "display:flex;gap:8px;flex-wrap:wrap";
        if (e.status !== "resolved") acts.appendChild(U.btn("Marcar como resuelto", function () { TEL.setStatus(e.id, "resolved"); refresh(); }));
        if (e.status !== "ignored") acts.appendChild(U.btn("Ignorar", function () { TEL.setStatus(e.id, "ignored"); refresh(); }, "btn--line"));
        if (e.status !== "open") acts.appendChild(U.btn("Reabrir", function () { TEL.setStatus(e.id, "open"); refresh(); }, "btn--line"));
        acts.appendChild(U.btn("Eliminar", function () { TEL.remove(e.id); refresh(); }, "btn--line")); c.appendChild(acts); host.appendChild(c);
      });
    }
    f1.addEventListener("change", paint); f2.addEventListener("change", paint); paint();
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
      var c = el("div", "thread"), h = el("header"); add(h, el("span", null, r.no + " · " + (r.target === "seller" ? "tienda " + ((sellerOf(r.seller) || {}).alias || r.seller) : "anuncio N.º " + r.listingRef) + " · " + r.reason), U.pill(r.status === "open" ? "open" : r.status === "removed" ? "removed" : "dismissed")); c.appendChild(h);
      add(c, el("p", null, r.text || "(sin texto)"), el("p", "muted-s", U.date(r.at) + (r.email ? " · contacto: " + r.email : " · sin contacto")));
      if (r.statement) c.appendChild(el("p", "muted-s", "Decisión: " + r.statement));
      if (r.status === "open") {
        var acts = el("div", "acts"); acts.style.cssText = "display:flex;gap:10px;margin-top:10px";
        add(acts, U.btn(r.target === "seller" ? "Suspender tienda" : "Retirar anuncio", function () { var m = ask("Motivos de la decisión (se comunican al vendedor):"); if (m) U.run(function () { return A.resolveReport(r.id, "remove", m); }, "Decisión aplicada.").then(refresh, function () {}); }), U.btn("Desestimar", function () { var m = ask("Motivos para desestimar:"); if (m) U.run(function () { return A.resolveReport(r.id, "dismiss", m); }, "Denuncia desestimada.").then(refresh, function () {}); }, "btn--line"));
        c.appendChild(acts);
      }
      p.appendChild(c);
    });
  }

  function tabIncidents(p) {
    var list = D().incidents.slice().sort(function (a, b) { return b.id - a.id; });
    p.appendChild(el("p", "app-sub", "Incidencias de compradores. Se resuelven dentro de las facultades de Intimae y de las reglas del proveedor de pagos; no se prometen reembolsos fuera de ese procedimiento."));
    if (!list.length) return p.appendChild(el("p", "empty-s", "No hay incidencias."));
    list.forEach(function (inc) {
      var o = INT.orders.get(inc.order), c = el("div", "thread"), h = el("header");
      add(h, el("span", null, inc.no + " · pedido " + inc.orderNo + " · " + U.REASONS[inc.reason] + " · total " + U.money(o.total)), U.pill(inc.status === "resolved" ? "resolved" : inc.status === "open" ? "incident" : "disputed", inc.status === "open" ? "Esperando al vendedor" : inc.status === "disputed" ? "En revisión" : "Resuelta"));
      add(c, h, U.bubbles(inc.messages, "a"), U.evidence(inc.evidence));
      if (inc.status !== "resolved") {
        var f = el("form", "form stack"), dec = U.select("decision", [["refund", "Reembolso total"], ["partial", "Reembolso parcial"], ["reject", "Rechazar la incidencia"]]), amt = U.input("amount", "number", { min: "0", step: "0.01", placeholder: "Importe del reembolso parcial (€)" }), st = el("textarea");
        st.name = "statement"; st.required = true; st.maxLength = 500; st.placeholder = "Motivos de la decisión (se comunican a las dos partes)"; st.style.minHeight = "70px";
        var b = el("button", "btn btn--sm", "Resolver"); b.type = "submit"; add(f, U.field("Decisión", dec), amt, st, b);
        f.addEventListener("submit", function (e) { e.preventDefault(); U.run(function () { return A.resolveIncident(inc.id, dec.value, amt.value, st.value); }, "Incidencia resuelta.").then(refresh, function () {}); }); c.appendChild(f);
      } else c.appendChild(el("p", "muted-s", "Resolución: " + inc.resolution.decision + (inc.resolution.amount ? " · " + U.money(inc.resolution.amount) : "") + " · " + inc.resolution.statement));
      p.appendChild(c);
    });
  }

  function tabNotes(p) {
    var list = INT.notify.list("a");
    if (!list.length) return p.appendChild(el("p", "empty-s", "No hay avisos."));
    list.slice(0, 60).forEach(function (n) { var r = el("div", "thread"); add(r, el("header", null, n.text), el("p", "muted-s", U.date(n.at))); p.appendChild(r); });
    INT.notify.readAll("a");
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
      if (o.status === "paid" && s && s.seed) acts.appendChild(U.btn("Enviar (demo)", function () { U.run(function () { return A.demoShip(o.id); }).then(refresh, function () {}); }, "btn--line"));
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
      U.field("Días desde la entrega hasta liquidar al vendedor", U.input("autoReleaseDays", "number", { min: "0", max: "30", value: s.autoReleaseDays })),
      U.field("Días de plazo de preparación del vendedor (antes de poder abrir una incidencia por «no enviado»)", U.input("shipDeadlineDays", "number", { min: "1", max: "30", value: s.shipDeadlineDays })),
      U.field("Días que tiene el vendedor para responder a una incidencia", U.input("incidentReplyDays", "number", { min: "1", max: "30", value: s.incidentReplyDays })));
    var ck = el("label", "check"), cb = el("input"); cb.type = "checkbox"; cb.name = "showSamples"; cb.checked = s.showSamples !== false; add(ck, cb, el("span", null, "Mostrar artículos y tiendas de muestra en la tienda (para enseñar el proyecto)")); f.appendChild(ck);
    var b = el("button", "btn", "Guardar ajustes"); b.type = "submit"; f.appendChild(b);
    f.addEventListener("submit", function (e) { e.preventDefault(); var d = new FormData(f); U.run(function () { return A.setSettings({ commission: d.get("commission"), autoDeliverDays: d.get("autoDeliverDays"), autoReleaseDays: d.get("autoReleaseDays"), shipDeadlineDays: d.get("shipDeadlineDays"), incidentReplyDays: d.get("incidentReplyDays"), showSamples: !!d.get("showSamples") }); }, "Ajustes guardados.").then(refresh, function () {}); });
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
      { id: "resumen", label: "Resumen", badge: function () { return health().filter(function (h) { return h[0] !== "ok"; }).length; }, render: tabOverview },
      { id: "estadisticas", label: "Estadísticas", render: tabStats },
      { id: "errores", label: "Errores", badge: function () { return TEL.read().errors.list.filter(function (e) { return e.status === "open"; }).length; }, render: tabErrors },
      { id: "moderacion", label: "Moderación", badge: pend, render: tabModeration },
      { id: "denuncias", label: "Denuncias", badge: open, render: tabReports },
      { id: "incidencias", label: "Incidencias", badge: function () { return D().incidents.filter(function (i) { return i.status !== "resolved"; }).length; }, render: tabIncidents },
      { id: "vendedores", label: "Vendedores", render: tabSellers },
      { id: "pedidos", label: "Pedidos", render: tabOrders },
      { id: "dac7", label: "DAC7", render: tabDac7 },
      { id: "ajustes", label: "Ajustes", render: tabSettings },
      { id: "avisos", label: "Avisos", badge: function () { return INT.notify.unread("a"); }, render: tabNotes },
      { id: "auditoria", label: "Auditoría", render: tabAudit }
    ]);
  }
  $("#logout").addEventListener("click", function () { A.logout(); render(); });
  render();
})();
