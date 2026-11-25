/*
 * Idiomas de Intimae.
 *  - El español es el idioma de origen: vive en el propio HTML (atributos data-i18n) y en i18n/es.js.
 *  - Los demás idiomas se cargan bajo demanda desde i18n/<código>.js.
 *  - Orden de elección: idioma elegido por la persona > idioma del navegador > país > inglés.
 *  - Al cambiar de país (entrega o residencia) se sugiere su idioma, salvo que la persona ya haya elegido uno
 *    o que ese país no tenga traducción propia (entonces se mantiene el idioma actual).
 */
(function () {
  "use strict";

  var SUPPORTED = ["es", "en", "fr", "de", "it", "pt", "nl"];
  var NATIVE = { es: "Español", en: "English", fr: "Français", de: "Deutsch", it: "Italiano", pt: "Português", nl: "Nederlands" };
  var LOCALE = { es: "es-ES", en: "en-GB", fr: "fr-FR", de: "de-DE", it: "it-IT", pt: "pt-PT", nl: "nl-NL" };
  // Idioma sugerido por país. Los países sin traducción propia usan inglés hasta que se añada la suya.
  var BY_COUNTRY = { ES: "es", IC: "es", FR: "fr", LU: "fr", DE: "de", AT: "de", CH: "de", NL: "nl", BE: "nl", IT: "it", PT: "pt", GB: "en", IE: "en", MT: "en" };
  var K_LANG = "intimae_lang", K_MANUAL = "intimae_lang_manual";

  var lang = "es", dicts = {}, listeners = [], selects = [], loading = {};
  var script = document.currentScript;
  var BASE = (script && script.src ? script.src : "").replace(/js\/i18n\.js(\?.*)?$/, "i18n/");

  var store = {
    get: function (k) { try { return localStorage.getItem(k); } catch (e) { return null; } },
    set: function (k, v) { try { localStorage.setItem(k, v); } catch (e) {} }
  };

  function valid(c) { return SUPPORTED.indexOf(c) !== -1; }

  function initial() {
    var saved = store.get(K_LANG);
    if (valid(saved) && store.get(K_MANUAL) === "1") return saved;
    var list = navigator.languages && navigator.languages.length ? navigator.languages : [navigator.language || "en"];
    for (var i = 0; i < list.length; i++) {
      var c = String(list[i]).slice(0, 2).toLowerCase();
      if (valid(c)) return c;
    }
    return "en";
  }

  function register(code, obj) { dicts[code] = obj; }

  function load(code) {
    if (dicts[code] || code === "es" && dicts.es) return Promise.resolve();
    if (loading[code]) return loading[code];
    loading[code] = new Promise(function (resolve) {
      var s = document.createElement("script");
      s.src = BASE + code + ".js";
      s.onload = resolve;
      s.onerror = resolve; // sin diccionario: se queda en español
      document.head.appendChild(s);
    });
    return loading[code];
  }

  function t(key, vars) {
    var s = (dicts[lang] && dicts[lang][key]);
    if (s == null) s = dicts.es && dicts.es[key];
    if (s == null) return key;
    if (vars) s = s.replace(/\{(\w+)\}/g, function (m, k) { return vars[k] != null ? vars[k] : m; });
    return s;
  }

  function apply() {
    var d = dicts[lang] || {};
    document.querySelectorAll("[data-i18n]").forEach(function (el) {
      if (el.dataset.es == null) el.dataset.es = el.innerHTML;
      var v = lang === "es" ? el.dataset.es : (d[el.getAttribute("data-i18n")] != null ? d[el.getAttribute("data-i18n")] : el.dataset.es);
      if (el.innerHTML !== v) el.innerHTML = v;
    });
    document.querySelectorAll("[data-i18n-attr]").forEach(function (el) {
      el.getAttribute("data-i18n-attr").split(";").forEach(function (pair) {
        var p = pair.split(":"); if (p.length < 2) return;
        var attr = p[0].trim(), key = p[1].trim(), store0 = "data-es-" + attr;
        if (!el.hasAttribute(store0)) el.setAttribute(store0, el.getAttribute(attr) || "");
        var v = lang === "es" ? el.getAttribute(store0) : (d[key] != null ? d[key] : el.getAttribute(store0));
        el.setAttribute(attr, v);
      });
    });
    document.documentElement.lang = lang;
    selects.forEach(function (s) { s.value = lang; });
  }

  function done() {
    document.documentElement.classList.remove("i18n-pending");
    apply();
    listeners.forEach(function (fn) { try { fn(lang); } catch (e) {} });
  }

  function set(code, manual) {
    if (!valid(code)) code = "en";
    return load(code).then(function () {
      lang = code;
      store.set(K_LANG, code);
      if (manual) store.set(K_MANUAL, "1");
      done();
    });
  }

  // Sugiere el idioma de un país si la persona no ha elegido uno a mano. Si el país no tiene
  // traducción propia, se mantiene el idioma actual en lugar de forzar el inglés.
  function suggestForCountry(country) {
    if (store.get(K_MANUAL) === "1") return Promise.resolve();
    var c = BY_COUNTRY[country];
    if (!c || c === lang) return Promise.resolve();
    return set(c, false);
  }

  function mountSelect(sel) {
    if (!sel) return;
    SUPPORTED.forEach(function (c) {
      var o = document.createElement("option"); o.value = c; o.textContent = NATIVE[c]; sel.appendChild(o);
    });
    sel.value = lang;
    sel.addEventListener("change", function () { set(sel.value, true); });
    selects.push(sel);
  }

  function money(n) {
    try { return new Intl.NumberFormat(LOCALE[lang], { style: "currency", currency: "EUR" }).format(n); }
    catch (e) { return n.toFixed(2).replace(".", ",") + " €"; }
  }
  function number(n) {
    try { return new Intl.NumberFormat(LOCALE[lang], { maximumFractionDigits: 1 }).format(n); }
    catch (e) { return String(n); }
  }
  function country(code) {
    try { return new Intl.DisplayNames([LOCALE[lang]], { type: "region" }).of(code) || code; }
    catch (e) { return code; }
  }

  window.I18N = {
    supported: SUPPORTED,
    native: NATIVE,
    register: register,
    t: t,
    set: set,
    apply: apply,
    mountSelect: mountSelect,
    suggestForCountry: suggestForCountry,
    money: money,
    number: number,
    country: country,
    current: function () { return lang; },
    onChange: function (fn) { listeners.push(fn); },
    // Arranque: devuelve una promesa que se cumple cuando el idioma inicial está aplicado.
    start: function () { return set(initial(), false); }
  };
})();
