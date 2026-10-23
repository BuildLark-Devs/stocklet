# Google Play feature graphic

The feature graphic (1024×500) is **mandatory** on the listing and cannot come
from a screenshot: it is a design. It is generated from `feature-graphic.html`
with headless Chrome, so the size is exact and redoing it is one command.

## Regenerate

```
"C:\Program Files\Google\Chrome\Application\chrome.exe" --headless --disable-gpu --hide-scrollbars --force-device-scale-factor=1 --screenshot="..\..\screenshots\feature-graphic.png" --window-size=1024,500 "file:///C:/Users/PC/Documents/reposteria_app/reposteria_app/tool/graphic/feature-graphic.html"
```

The PNG lands in `screenshots/`, which is outside git because it is regenerated.

## What constrains the design

- **Play crops it** on several surfaces, so nothing important goes near the
  edges: all content stays inside an 80 px margin. The background circles do
  cross it, deliberately.
- **It allows no transparency**: the background is opaque edge to edge.
- The colours come from `lib/tema.dart`: green `#0E9F6E` over `#0A7D55`.
- `stocklet_icon.png` is a copy of `assets/icon/stocklet_icon.png`. If the app
  icon changes, it has to be copied again.

## The figures on the card

They are the demo business figures (`tool/demo/seed.js`) for the **Torta de
chocolate**: cost 59,515, charged 76,000, suggested 99,192.

**If you change the seeder's prices, these figures have to be updated**, or the
graphic will contradict the product comparator screenshot. It is the only
dependency between the two, and nothing detects it automatically.
