/* Intimae · área de vendedores (separada de la tienda) */
(function () {
  "use strict";

  // Configuración: se completará cuando haya titularidad y correos reales.
  var CONFIG = { sellerEmail: "vendedores@example.com" };
  // Comisión sobre el precio de venta (sin envío). PROPUESTA, pendiente de confirmar (ver docs/ESTUDIO-LEGAL-Y-MERCADO.md).
  var COMMISSION_PCT = 20;

  var t = I18N.t, money = I18N.money;
  var $ = function (s) { return document.querySelector(s); };
  function el(tag, text) { var n = document.createElement(tag); if (text != null) n.textContent = text; return n; }
  function cname(code) { return I18N.country(code); }

  var sel = $("#s-country"), comm = $("#s-comm");
  var country = (function () {
    var r = ((navigator.language || "es-ES").split("-")[1] || "").toUpperCase();
    return TAX.get(r) ? r : "ES";
  })();

  I18N.mountSelect($("#lang"));

  /* ---------- Países e idioma de comunicación ---------- */
  function fillCountries() {
    var list = TAX.countries.slice().sort(function (a, b) { return cname(a.code).localeCompare(cname(b.code), I18N.current()); });
    sel.textContent = "";
    [["dest.eu", true], ["dest.non", false]].forEach(function (g) {
      var og = document.createElement("optgroup"); og.label = t(g[0]);
      list.filter(function (c) { return c.eu === g[1]; }).forEach(function (c) { var o = el("option", cname(c.code)); o.value = c.code; og.appendChild(o); });
      sel.appendChild(og);
    });
    sel.value = country;
  }
  function fillComm() {
    comm.textContent = "";
    I18N.supported.forEach(function (c) { var o = el("option", I18N.native[c]); o.value = c; comm.appendChild(o); });
    comm.value = I18N.current();
  }
  // El país de residencia sugiere el idioma de la página y el de comunicación (editable)
  sel.addEventListener("change", function () {
    country = sel.value;
    I18N.suggestForCountry(country);
  });
  comm.addEventListener("change", function () { I18N.set(comm.value, true); });

  /* ---------- Calculadora de comisión ---------- */
  var price = $("#calc-price");
  function renderCalc() {
    var p = Math.max(0, parseFloat(price.value) || 0);
    var fee = Math.round(p * COMMISSION_PCT) / 100;
    $("#calc-sale").textContent = money(p);
    $("#calc-fee-label").textContent = t("sv.calc.fee", { pct: I18N.number(COMMISSION_PCT) });
    $("#calc-fee").textContent = "− " + money(fee);
    $("#calc-net").textContent = money(p - fee);
  }
  price.addEventListener("input", renderCalc);

  /* ---------- Formulario ---------- */
  var kindHint = $("#kind-hint"), proFields = $("#pro-fields");
  function renderHint() {
    var kind = document.querySelector("input[name=kind]:checked").value;
    kindHint.textContent = t("sv.hint." + kind);
    proFields.hidden = kind !== "profesional";
  }
  document.querySelectorAll("input[name=kind]").forEach(function (r) { r.addEventListener("change", renderHint); });

  var msg = $("#seller-msg");
  function setMsg(text, err) { msg.textContent = text; msg.className = "msg" + (err ? " err" : ""); }

  $("#seller-form").addEventListener("submit", function (e) {
    e.preventDefault();
    var form = e.target, d = new FormData(form);
    if (+d.get("age") < 18) return setMsg(t("sv.msg.age"), true);
    if (!form.checkValidity()) return setMsg(t("sv.msg.invalid"), true);
    var pro = d.get("kind") === "profesional";
    var vat = String(d.get("vatid") || "").replace(/\s+/g, "").toUpperCase();
    if (pro && vat && !/^[A-Z]{2}[0-9A-Z]{8,12}$/.test(vat)) return setMsg(t("sv.msg.vat"), true);
    var c = TAX.get(d.get("country"));
    // El correo va en español: es el idioma de trabajo del equipo; se indica el idioma de la persona.
    var body = "Alias: " + d.get("alias") + "\nCorreo: " + d.get("email") + "\nPaís: " + d.get("country") +
      "\nIdioma de comunicación: " + d.get("comm") + "\nEdad: " + d.get("age") +
      "\nVende como: " + d.get("kind") + (pro ? "\nNúmero de IVA: " + (vat || "-") + "\nRégimen: " + (d.get("regime") || "sin indicar") : "") +
      "\n\n" + (d.get("about") || "");
    window.location.href = "mailto:" + CONFIG.sellerEmail + "?subject=" + encodeURIComponent("Solicitud de vendedor: " + d.get("alias")) + "&body=" + encodeURIComponent(body);
    setMsg(c && !c.eu ? t("sv.msg.outside", { country: cname(c.code) }) : t("sv.msg.sent"));
  });

  /* ---------- Aparición suave ---------- */
  var revealEls = document.querySelectorAll(".reveal");
  if ("IntersectionObserver" in window) {
    var io = new IntersectionObserver(function (es) {
      es.forEach(function (en) { if (en.isIntersecting) { en.target.classList.add("in"); io.unobserve(en.target); } });
    }, { rootMargin: "0px 0px -8% 0px", threshold: 0.08 });
    revealEls.forEach(function (n) { io.observe(n); });
  } else { revealEls.forEach(function (n) { n.classList.add("in"); }); }

  /* ---------- Arranque ---------- */
  function renderAll() { fillCountries(); fillComm(); renderCalc(); renderHint(); }
  I18N.onChange(renderAll);
  // Si la persona no ha elegido idioma, el del navegador manda; el país de residencia lo ajusta al elegirlo.
  I18N.start();
})();
