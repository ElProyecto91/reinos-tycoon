# Intimae

Web estática de un marketplace para adultos de lencería usada, con carácter erótico.
Sin dependencias ni build: abre `index.html` o sirve la carpeta con cualquier hosting estático.

## Qué incluye

- Verificación de edad (18+) al entrar.
- Catálogo con filtros (prenda, talla, días de uso) y orden.
- Carrito y formulario de pedido (genera un email; pago manual).
- Alta de vendedores (mayores de 18, con verificación de identidad).
- Páginas de términos, privacidad y normas (`legal.html`, plantilla orientativa).

## Antes de publicar

1. Cambia los emails en `js/app.js` (`CONFIG`).
2. Sustituye los productos de demostración en `js/products.js`.
3. Revisa `legal.html` con un abogado de tu país.
4. Comprueba que tu hosting y tu medio de cobro admiten contenido para adultos
   (Stripe y PayPal suelen restringirlo; por eso el pago es manual).

## Probar en local

```bash
python3 -m http.server 8000
```
