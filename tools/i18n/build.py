#!/usr/bin/env python3
"""Genera i18n/<idioma>.js a partir de tools/i18n/src/<idioma>.py y valida que estén completos.

Uso:   python3 tools/i18n/build.py
Añadir un idioma: copiar src/en.py a src/<código>.py, traducir los valores y añadir el código a
SUPPORTED en js/i18n.js (y su nombre nativo en NATIVE, y su configuración regional en LOCALE).

El español es el origen: los textos estáticos están en los HTML (data-i18n / data-i18n-attr) y los
dinámicos en i18n/es.js. Este script extrae todas las claves y exige que cada idioma las tenga todas,
con los mismos marcadores {x}, las mismas etiquetas HTML y los mismos enlaces.
Requiere: pip install beautifulsoup4
"""
import json, re, sys, pathlib, importlib.util
from bs4 import BeautifulSoup

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / "tools" / "i18n" / "src"
PAGES = ["index.html", "vendedores/index.html"]

def spanish_keys():
    keys = {}
    for f in PAGES:
        soup = BeautifulSoup((ROOT / f).read_text(encoding="utf-8"), "html.parser")
        for el in soup.select("[data-i18n]"):
            keys[el["data-i18n"]] = el.decode_contents().strip()
        for el in soup.select("[data-i18n-attr]"):
            for pair in el["data-i18n-attr"].split(";"):
                attr, key = pair.split(":")
                keys.setdefault(key.strip(), el.get(attr.strip(), ""))
    es = (ROOT / "i18n" / "es.js").read_text(encoding="utf-8")
    keys.update(dict(re.findall(r'"([\w.]+)":\s*"((?:[^"\\]|\\.)*)"', es)))
    prod = (ROOT / "js" / "products.js").read_text(encoding="utf-8")
    for m in re.finditer(r'\{ id: (\d+), ref: "\d+", type: "\w+",\s*title: "([^"]+)".*?material:\s*"([^"]+)",\s*colour:\s*"([^"]+)",\s*desc:\s*"([^"]+)"', prod):
        i, t, mat, col, desc = m.groups()
        keys.update({f"p.{i}.title": t, f"p.{i}.desc": desc, f"p.{i}.material": mat, f"p.{i}.colour": col})
    return keys

ph = lambda s: sorted(re.findall(r"\{\w+\}", s))
tags = lambda s: sorted(re.findall(r"<(/?\w+)", s.replace("<br/>", "<br>")))
hrefs = lambda s: sorted(re.findall(r'href="([^"]+)"', s.replace("&amp;", "&")))

def main():
    ES = spanish_keys()
    problems = 0
    for f in sorted(SRC.glob("*.py")):
        lang = f.stem
        spec = importlib.util.spec_from_file_location(lang, f); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
        T = m.T
        miss = [k for k in ES if k not in T]; extra = [k for k in T if k not in ES]
        bad = []
        for k, v in T.items():
            if k in ES and (ph(v) != ph(ES[k]) or tags(v) != tags(ES[k]) or hrefs(v) != hrefs(ES[k]) or not v.strip()):
                bad.append(k)
        print(f"{lang}: {len(T)} claves | faltan {miss} | sobran {extra} | incoherentes {bad}")
        problems += len(miss) + len(extra) + len(bad)
        out = ROOT / "i18n" / f"{lang}.js"
        out.write_text('/* Generado por tools/i18n/build.py. No editar a mano. */\nI18N.register("%s", %s);\n' % (lang, json.dumps(T, ensure_ascii=False, indent=0)), encoding="utf-8")
    print("PROBLEMAS:", problems)
    sys.exit(1 if problems else 0)

if __name__ == "__main__":
    main()
