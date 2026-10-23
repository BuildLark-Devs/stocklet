// Makes the PWA maskable icons opaque.
//
// An icon with purpose:"maskable" is cropped by the system to whatever shape
// it likes (circle, squircle, teardrop). That is why it cannot carry
// transparency: wherever there is any, a hole shows through. But
// flutter_launcher_icons generates the maskable icons from the same image as
// the normal ones, and the Stocklet logo has rounded — therefore transparent
// — corners.
//
// This extends the edge colour outwards into the corners, rather than filling
// with a flat green, which would leave a visible seam against the gradient.
//
// IT HAS TO BE RUN AGAIN every time `dart run flutter_launcher_icons` runs,
// because the generator rewrites these two files and takes the fix with it:
//
//   dart run flutter_launcher_icons && node tool/icons/seal-maskable.js

const fs = require('fs');
const path = require('path');
const {PNG} = require('pngjs');

const RAIZ = path.join(__dirname, '..', '..');
const ARCHIVOS = [
  'web/icons/Icon-maskable-192.png',
  'web/icons/Icon-maskable-512.png',
];

function sellar(rutaRelativa) {
  const ruta = path.join(RAIZ, rutaRelativa);
  const p = PNG.sync.read(fs.readFileSync(ruta));
  const W = p.width, H = p.height, cx = W / 2, cy = H / 2;
  let rellenados = 0;

  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const i = (W * y + x) << 2;
      if (p.data[i + 3] >= 250) continue;
      // Walk towards the centre until an opaque pixel turns up, and copy its
      // colour.
      const dx = cx - x, dy = cy - y;
      const pasos = Math.ceil(Math.hypot(dx, dy));
      for (let s = 1; s <= pasos; s++) {
        const sx = Math.round(x + dx * s / pasos);
        const sy = Math.round(y + dy * s / pasos);
        const j = (W * sy + sx) << 2;
        if (p.data[j + 3] >= 250) {
          p.data[i] = p.data[j];
          p.data[i + 1] = p.data[j + 1];
          p.data[i + 2] = p.data[j + 2];
          p.data[i + 3] = 255;
          rellenados++;
          break;
        }
      }
    }
  }

  fs.writeFileSync(ruta, PNG.sync.write(p));

  let sinOpacar = 0;
  for (let i = 3; i < p.data.length; i += 4) if (p.data[i] < 250) sinOpacar++;
  if (sinOpacar > 0) {
    throw new Error(rutaRelativa + ': ' + sinOpacar +
        ' pixels are still transparent');
  }
  console.log('  ' + rutaRelativa + ': ' + rellenados +
      ' corner pixels filled, 0 transparent');
}

ARCHIVOS.forEach(sellar);
console.log('Maskable icons sealed.');
