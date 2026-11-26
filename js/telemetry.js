/*
 * Intimae · telemetría local (MODO DEMOSTRACIÓN).
 *
 * Recoge errores y contadores técnicos ANÓNIMOS y los guarda solo en el almacenamiento local de este navegador
 * (nada se envía a ningún servidor). Los lee el panel de administración (/admin/ → Resumen, Estadísticas, Errores).
 * No guarda contenido de pedidos, mensajes ni datos personales; el identificador de visitante es un número aleatorio.
 * Cuando exista un servidor, esta misma API (TEL.track / TEL.error) enviará los eventos a una tabla propia o a un
 * servicio de errores, previa revisión de privacidad.
 */
(function () {
  "use strict";
  var KS = "intimae_stats_v1", KE = "intimae_errors_v1", KV = "intimae_vid", MAX_ERR = 200, KEEP_DAYS = 90;

  function load(k, d) { try { return JSON.parse(localStorage.getItem(k)) || d; } catch (e) { return d; } }
  function save(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); return true; } catch (e) { return false; } }
  function today() { return new Date().toISOString().slice(0, 10); }
  function now() { return Date.now(); }

  var stats = load(KS, { days: {}, perf: {}, terms: {}, v: 1 }), errors = load(KE, { list: [], seq: 0 });
  if (!stats.terms) stats.terms = {};
  var inErr = false, burst = [];

  function prune() {
    var keys = Object.keys(stats.days).sort();
    while (keys.length > KEEP_DAYS) delete stats.days[keys.shift()];
  }
  // track("nombre") suma 1; track("nombre", n) suma n (los importes van en céntimos: «order.cents»)
  function track(name, n) {
    stats = load(KS, stats); if (!stats.terms) stats.terms = {};
    var d = today(), o = stats.days[d] || (stats.days[d] = {});
    o[name] = Math.round(((o[name] || 0) + (n == null ? 1 : n)) * 100) / 100; prune(); save(KS, stats);
  }
  function term(text, found) {
    text = String(text || "").trim().toLowerCase().slice(0, 40); if (text.length < 2) return;
    stats = load(KS, stats); if (!stats.terms) stats.terms = {};
    var t = stats.terms[text] || (stats.terms[text] = { n: 0, zero: 0, last: today() });
    t.n++; if (!found) t.zero++; t.last = today();
    var ks = Object.keys(stats.terms); if (ks.length > 150) { ks.sort(function (a, b) { return stats.terms[a].n - stats.terms[b].n; }); delete stats.terms[ks[0]]; }
    save(KS, stats);
  }
  function perf(page, metric, v) {
    if (!(v >= 0) || v > 600000) return; stats = load(KS, stats);
    var k = page + "|" + metric, p = stats.perf[k] || (stats.perf[k] = { n: 0, sum: 0, max: 0 });
    p.n++; p.sum += v; p.max = Math.max(p.max, v); save(KS, stats);
  }

  function page() {
    var p = location.pathname.replace(/index\.html$/, "").replace(/\/+$/, "") || "/";
    if (p === "/" || p === "") return "tienda";
    if (/\/vendedores\/panel$/.test(p)) return "panel-vendedor";
    if (/\/vendedores$/.test(p)) return "vendedores";
    if (/\/(cuenta|admin|tienda)$/.test(p)) return p.split("/").pop() === "tienda" ? "tienda-publica" : p.split("/").pop();
    return p.split("/").pop().replace(/\.html$/, "") || "otra";
  }
  var PAGE = page();

  /* ---------- errores ---------- */
  function fingerprint(i) { return i.type + "|" + String(i.message).slice(0, 160) + "|" + String(i.source || "").replace(location.origin, "").slice(0, 80); }
  function logError(info) {
    if (inErr) return; inErr = true;
    try {
      var t = now(); burst = burst.filter(function (x) { return t - x < 60000; }); if (burst.length >= 30) return; burst.push(t);
      info.message = String(info.message || "Error sin mensaje").slice(0, 300); info.type = info.type || "js";
      errors = load(KE, errors); var k = fingerprint(info), e = null;
      for (var i = 0; i < errors.list.length; i++) if (errors.list[i].k === k) { e = errors.list[i]; break; }
      if (e) {
        e.count++; e.last = t; e.pages[PAGE] = (e.pages[PAGE] || 0) + 1;
        if (e.status === "resolved") { e.status = "open"; e.regression = true; }
      } else {
        errors.list.push({ id: ++errors.seq, k: k, type: info.type, message: info.message, source: String(info.source || "").replace(location.origin, "").slice(0, 120), line: info.line || 0, col: info.col || 0,
          stack: String(info.stack || "").replace(new RegExp(location.origin, "g"), "").slice(0, 1200), count: 1, first: t, last: t, status: "open", pages: (function () { var o = {}; o[PAGE] = 1; return o; })(),
          ua: navigator.userAgent.slice(0, 140), viewport: window.innerWidth + "x" + window.innerHeight, lang: document.documentElement.lang });
        if (errors.list.length > MAX_ERR) {
          errors.list.sort(function (a, b) { return (a.status === "open" ? 1 : 0) - (b.status === "open" ? 1 : 0) || a.last - b.last; }); errors.list.shift();
        }
      }
      save(KE, errors); track("error." + info.type); track("error.total");
    } finally { inErr = false; }
  }

  window.addEventListener("error", function (ev) {
    if (ev.target && ev.target !== window && ev.target.tagName) { // recurso que no carga (imagen, script, hoja de estilos)
      var src = ev.target.src || ev.target.href || ""; logError({ type: "resource", message: "No se pudo cargar " + ev.target.tagName.toLowerCase() + ": " + src.replace(location.origin, ""), source: src });
    } else logError({ type: "js", message: ev.message, source: ev.filename, line: ev.lineno, col: ev.colno, stack: ev.error && ev.error.stack });
  }, true);
  window.addEventListener("unhandledrejection", function (ev) {
    var r = ev.reason; logError({ type: "promise", message: r && r.message ? r.message : String(r), stack: r && r.stack });
  });
  document.addEventListener("securitypolicyviolation", function (ev) {
    logError({ type: "csp", message: "CSP: " + ev.violatedDirective + " bloqueó " + (ev.blockedURI || "inline"), source: ev.sourceFile, line: ev.lineNumber });
  });
  var ce = console.error;
  console.error = function () {
    try { logError({ type: "console", message: Array.prototype.map.call(arguments, function (a) { return a && a.message ? a.message : typeof a === "object" ? JSON.stringify(a) : String(a); }).join(" ") }); } catch (e) {}
    return ce.apply(console, arguments);
  };

  /* ---------- visitas, sesión, dispositivo y rendimiento ---------- */
  function browser() {
    var u = navigator.userAgent;
    return /Edg\//.test(u) ? "Edge" : /OPR\/|Opera/.test(u) ? "Opera" : /Firefox\//.test(u) ? "Firefox" : /Chrome\//.test(u) ? "Chrome" : /Safari\//.test(u) ? "Safari" : "Otro";
  }
  if (PAGE !== "admin") {
    track("pv"); track("pv:" + PAGE);
    var first = false; try { if (!sessionStorage.getItem("intimae_sess")) { sessionStorage.setItem("intimae_sess", "1"); first = true; } } catch (e) { first = false; }
    if (first) {
      track("session");
      var vid = null; try { vid = localStorage.getItem(KV); if (!vid) { vid = String(Math.random()).slice(2, 12); localStorage.setItem(KV, vid); track("visitor.new"); } else track("visitor.returning"); } catch (e) {}
      var w = window.innerWidth; track("dev." + (w < 760 ? "movil" : w < 1100 ? "tableta" : "escritorio")); track("br." + browser());
      setTimeout(function () { track("lang." + (document.documentElement.lang || "es")); }, 1500);
    }
    var lcp = 0, cls = 0;
    try { new PerformanceObserver(function (l) { var e = l.getEntries(); lcp = e[e.length - 1].startTime; }).observe({ type: "largest-contentful-paint", buffered: true }); } catch (e) {}
    try { new PerformanceObserver(function (l) { l.getEntries().forEach(function (e) { if (!e.hadRecentInput) cls += e.value; }); }).observe({ type: "layout-shift", buffered: true }); } catch (e) {}
    var sent = false;
    function report() {
      if (sent) return; sent = true;
      try { var nav = performance.getEntriesByType("navigation")[0]; if (nav) perf(PAGE, "carga", nav.duration); } catch (e) {}
      if (lcp) perf(PAGE, "lcp", lcp); perf(PAGE, "cls1000", cls * 1000);
    }
    document.addEventListener("visibilitychange", function () { if (document.visibilityState === "hidden") report(); });
    window.addEventListener("pagehide", report);
  }

  window.TEL = {
    track: track, term: term, error: logError, page: PAGE,
    read: function () { return { stats: load(KS, stats), errors: load(KE, errors) }; },
    setStatus: function (id, status) { errors = load(KE, errors); errors.list.forEach(function (e) { if (e.id === id) { e.status = status; e.regression = false; } }); save(KE, errors); },
    remove: function (id) { errors = load(KE, errors); errors.list = errors.list.filter(function (e) { return e.id !== id; }); save(KE, errors); },
    clearErrors: function () { errors = { list: [], seq: errors.seq }; save(KE, errors); },
    clearStats: function () { stats = { days: {}, perf: {}, terms: {}, v: 1 }; save(KS, stats); },
    // Genera un error de prueba para comprobar que la captura funciona
    test: function () { setTimeout(function () { throw new Error("Error de prueba generado desde el panel de administración"); }, 0); }
  };
})();
