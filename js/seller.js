/* Intimae · área de vendedores (separada de la tienda) */
(function () {
  "use strict";

  // Comisión sobre el precio de venta (sin envío): se lee de los ajustes (administración). PROPUESTA, pendiente de confirmar.
  function commissionPct() { return INT.settings().commission; }

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
    var fee = Math.round(p * commissionPct()) / 100;
    $("#calc-sale").textContent = money(p);
    $("#calc-fee-label").textContent = t("sv.calc.fee", { pct: I18N.number(commissionPct()) });
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
    var ic = d.get("country") === "IC";
    if (pro && vat && !(ic ? /^(ES)?[A-Z0-9]{9}$/ : /^[A-Z]{2}[0-9A-Z]{8,12}$/).test(vat)) return setMsg(t("sv.msg.vat"), true);
    if (String(d.get("pass")).length < 8) return setMsg(t("sv.msg.pass"), true);
    var c = TAX.get(d.get("country"));
    INT.seller.apply({ alias: d.get("alias"), email: d.get("email"), pass: d.get("pass"), country: d.get("country"), comm: d.get("comm"), age: d.get("age"),
      kind: d.get("kind"), vatId: vat, regime: d.get("regime"), about: d.get("about") })
      .then(function () {
        form.reset(); renderHint();
        setMsg(t("sv.msg.created") + (c && !c.eu ? " " + t("sv.msg.outside", { country: cname(c.code) }) : ""));
        var a = document.createElement("a"); a.className = "link"; a.href = "panel/"; a.textContent = t("sv.hdr.panel"); msg.appendChild(document.createTextNode(" ")); msg.appendChild(a);
      })
      .catch(function (err) { setMsg(err.code === "exists" ? t("sv.msg.exists") : err.code === "minor" ? t("sv.msg.age") : err.code === "pass" ? t("sv.msg.pass") : t("sv.msg.invalid"), true); });
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
