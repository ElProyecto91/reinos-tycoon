/*
 * Intimae · medición de visitas con Vercel Web Analytics (sin cookies).
 * Solo se carga en el dominio de producción (*.vercel.app o el dominio propio cuando exista), nunca en
 * pruebas ni en localhost; respeta «No rastrear» (DNT), Global Privacy Control y la opción de desactivarlo
 * en la página de cookies. No se carga en la cuenta, el panel del vendedor ni la administración.
 * Requiere activar Web Analytics en el proyecto de Vercel (ver docs/ANALITICA-VERCEL.md); mientras no esté
 * activado, el script devuelve 404 y no se mide nada.
 */
(function () {
  "use strict";
  // Dominios donde se mide. Añadir aquí el dominio propio cuando se compre.
  var HOSTS = [/\.vercel\.app$/];

  function shouldLoad(host, dnt, gpc, optOut) {
    if (optOut || dnt === "1" || dnt === "yes" || gpc === true) return false;
    return HOSTS.some(function (r) { return r.test(host); });
  }
  window.INTIMAE_ANALYTICS = { shouldLoad: shouldLoad, optOutKey: "intimae_no_analytics" };

  var optOut = false;
  try { optOut = localStorage.getItem("intimae_no_analytics") === "1"; } catch (e) {}
  if (!shouldLoad(location.hostname, navigator.doNotTrack || window.doNotTrack, navigator.globalPrivacyControl === true, optOut)) return;

  window.va = window.va || function () { (window.vaq = window.vaq || []).push(arguments); };
  var s = document.createElement("script");
  s.defer = true; s.src = "/_vercel/insights/script.js";
  document.head.appendChild(s);
})();
