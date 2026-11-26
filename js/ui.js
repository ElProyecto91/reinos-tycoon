/* Intimae · utilidades de interfaz para cuenta, panel y administración. Solo textContent: nada de innerHTML. */
(function () {
  "use strict";

  var STATUS = {
    paid: ["Pagado", "warn"], shipped: ["Enviado", "warn"], delivered: ["Entregado", "ok"], released: ["Liquidado", "ok"], cancelled: ["Cancelado", "bad"],
    incident: ["Incidencia", "bad"], disputed: ["En disputa", "bad"], refunded: ["Reembolsado", ""],
    pending: ["Pendiente de revisión", "warn"], draft: ["Borrador", ""], active: ["Publicado", "ok"], paused: ["En pausa", ""], sold: ["Vendido", "ok"], rejected: ["Rechazado", "bad"], removed: ["Retirado", "bad"],
    verified: ["Verificado", "ok"], suspended: ["Suspendido", "bad"], open: ["Abierta", "warn"], dismissed: ["Desestimada", ""], resolved: ["Resuelta", "ok"]
  };

  var REASONS = { no_enviado: "Pedido no enviado", no_recibido: "Pedido no recibido", distinto: "Producto distinto al anunciado", danado: "Producto dañado", descripcion: "Descripción engañosa", fraude: "Posible fraude", pago: "Problema con el pago", privacidad: "Problema de privacidad" };
  var WHO = { b: "Comprador", s: "Vendedor", a: "Intimae" };

  function el(tag, cls, text) { var n = document.createElement(tag); if (cls) n.className = cls; if (text != null) n.textContent = text; return n; }
  function add(parent) { for (var i = 1; i < arguments.length; i++) if (arguments[i]) parent.appendChild(arguments[i]); return parent; }
  function pill(status, textOverride) { var s = STATUS[status] || [status, ""]; return el("span", "pill " + s[1], textOverride || s[0]); }
  function date(ts) { return ts ? new Date(ts).toLocaleString("es-ES", { day: "2-digit", month: "2-digit", year: "numeric", hour: "2-digit", minute: "2-digit" }) : "—"; }
  function money(n) { return I18N.money(n); }
  function btn(text, fn, cls) { var b = el("button", "btn btn--sm " + (cls || ""), text); b.type = "button"; b.addEventListener("click", fn); return b; }
  function field(label, input, hint) {
    var l = el("label", "f"); l.appendChild(el("span", "label", label)); l.appendChild(input);
    if (hint) l.appendChild(el("span", "hint", hint)); return l;
  }
  function input(name, type, attrs) { var i = el("input"); i.name = name; i.type = type || "text"; Object.keys(attrs || {}).forEach(function (k) { i.setAttribute(k, attrs[k]); }); return i; }
  function select(name, options, value) {
    var s = el("select"); s.name = name;
    options.forEach(function (o) { var op = el("option", null, Array.isArray(o) ? o[1] : o); op.value = Array.isArray(o) ? o[0] : o; s.appendChild(op); });
    if (value != null) s.value = value; return s;
  }
  function table(headers, rows) {
    var w = el("div", "tbl-wrap"), t = el("table", "tbl"), th = el("thead"), tr = el("tr");
    headers.forEach(function (h) { tr.appendChild(el("th", null, h)); }); th.appendChild(tr); t.appendChild(th);
    var tb = el("tbody");
    rows.forEach(function (r) {
      var row = el("tr");
      r.forEach(function (c) { var td = el("td"); if (c && c.nodeType) td.appendChild(c); else td.textContent = c == null ? "" : String(c); row.appendChild(td); });
      tb.appendChild(row);
    });
    t.appendChild(tb); w.appendChild(t); return w;
  }
  function clear(n) { while (n.firstChild) n.removeChild(n.firstChild); return n; }

  var toastTimer;
  function toast(text, err) {
    var t = document.querySelector(".toast");
    if (!t) { t = el("div", "toast"); document.body.appendChild(t); }
    t.className = "toast" + (err ? " err" : ""); t.textContent = text; t.setAttribute("role", "status");
    clearTimeout(toastTimer); toastTimer = setTimeout(function () { if (t.parentNode) t.parentNode.removeChild(t); }, 4200);
  }
  // Ejecuta una acción (síncrona o promesa), muestra el error en pantalla y devuelve la promesa.
  function run(fn, ok) {
    return Promise.resolve().then(fn).then(function (r) { if (ok) toast(ok); return r; }, function (e) { toast(e && e.message ? e.message : "Ha ocurrido un error.", true); throw e; });
  }
  function download(name, text, mime) {
    var a = el("a"); a.href = URL.createObjectURL(new Blob([text], { type: mime || "text/plain;charset=utf-8" })); a.download = name;
    document.body.appendChild(a); a.click(); setTimeout(function () { URL.revokeObjectURL(a.href); a.remove(); }, 500);
  }
  function csv(rows) {
    return "﻿" + rows.map(function (r) { return r.map(function (c) { c = c == null ? "" : String(c); return /[",;\n]/.test(c) ? '"' + c.replace(/"/g, '""') + '"' : c; }).join(";"); }).join("\r\n");
  }
  // Reduce la foto a un máximo de 900 px y la devuelve como JPEG en base64 (menos peso y sin metadatos EXIF).
  function resizeImage(file) {
    return new Promise(function (resolve, reject) {
      if (!/^image\/(jpeg|png|webp)$/.test(file.type)) return reject(new Error("Formato no admitido. Usa JPG, PNG o WebP."));
      var url = URL.createObjectURL(file), img = new Image();
      img.onload = function () {
        var max = 900, k = Math.min(1, max / Math.max(img.width, img.height)), c = el("canvas");
        c.width = Math.round(img.width * k); c.height = Math.round(img.height * k);
        c.getContext("2d").drawImage(img, 0, 0, c.width, c.height); URL.revokeObjectURL(url);
        resolve(c.toDataURL("image/jpeg", 0.72));
      };
      img.onerror = function () { URL.revokeObjectURL(url); reject(new Error("No se ha podido leer la imagen.")); };
      img.src = url;
    });
  }
  // Pestañas con hash en la URL. defs: [{id,label,badge(),render(panel)}]
  function tabs(bar, panel, defs, first) {
    function show(id) {
      var d = defs.filter(function (x) { return x.id === id; })[0] || defs[0];
      Array.prototype.forEach.call(bar.children, function (b) { b.setAttribute("aria-selected", String(b.dataset.id === d.id)); });
      clear(panel); d.render(panel);
      if (location.hash !== "#" + d.id) history.replaceState(null, "", "#" + d.id);
    }
    function build() {
      clear(bar); bar.setAttribute("role", "tablist");
      defs.forEach(function (d) {
        var b = el("button", null, d.label); b.type = "button"; b.dataset.id = d.id; b.setAttribute("role", "tab");
        var n = d.badge && d.badge(); if (n) b.appendChild(el("span", "n", String(n)));
        b.addEventListener("click", function () { build(); show(d.id); }); bar.appendChild(b);
      });
    }
    var cur = (location.hash || "").slice(1) || first || defs[0].id;
    build(); show(cur);
    // Enlaces con #pestaña dentro de la misma página
    if (window.__tabsHash) window.removeEventListener("hashchange", window.__tabsHash);
    window.__tabsHash = function () { var id = (location.hash || "").slice(1); if (defs.some(function (d) { return d.id === id; })) { build(); show(id); } };
    window.addEventListener("hashchange", window.__tabsHash);
    return { refresh: function () { var id = (location.hash || "").slice(1) || defs[0].id; build(); show(id); } };
  }

  // Conversación de una incidencia: me = "b" | "s" | "a" (quien la mira)
  function bubbles(msgs, me) {
    var box = el("div", "bubbles");
    msgs.forEach(function (m) { var b = el("div", "bubble" + (m.from === me ? " me" : ""), m.text); b.appendChild(el("small", null, (m.from === me ? "Tú" : WHO[m.from]) + " · " + date(m.at))); box.appendChild(b); });
    return box;
  }
  function evidence(list) {
    var th = el("div", "thumbs"); (list || []).forEach(function (d) { var i = el("img"); i.src = d; i.alt = "Prueba adjunta"; th.appendChild(i); }); return th;
  }

  window.UI = { REASONS: REASONS, bubbles: bubbles, evidence: evidence, el: el, add: add, pill: pill, date: date, money: money, btn: btn, field: field, input: input, select: select, table: table, clear: clear, toast: toast, run: run, download: download, csv: csv, resizeImage: resizeImage, tabs: tabs, STATUS: STATUS };
})();
