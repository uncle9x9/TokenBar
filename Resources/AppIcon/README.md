# TokenBar application icon

`TokenBar.png` is the selected Quota Orbit design, refined with the built-in ImageGen edit tool. Its transparent corners and navy tile work against light and dark macOS backgrounds. `TokenBar.icns` contains all standard 16–1024 pixel representations and is copied into the application by `Scripts/package_app.sh`.

The application icon is a static brand asset. The menu bar renderer independently displays live reset time and quota usage.

## Generation prompt

Preserve the selected icon's midnight navy rounded square and icy cyan nearly complete circular countdown ring with a small upper-right gap, plus its centered horizontal quota capsule filled about two thirds from the left. Extract and refine only that app icon as one centered square deliverable with transparent background outside rounded corners. Balanced padding, tasteful navy gradient, crisp rounded ring and capsule. Remove all text, both bottom light/dark sample panels, white heavy extrusion and large shadow. Subtle edge lighting only; no typography, labels, extra objects or presentation board.

## Rebuild ICNS on macOS

Run from the repository root:

```bash
mkdir -p .build/TokenBar.iconset
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" Resources/AppIcon/TokenBar.png \
    --out ".build/TokenBar.iconset/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" Resources/AppIcon/TokenBar.png \
    --out ".build/TokenBar.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns .build/TokenBar.iconset -o Resources/AppIcon/TokenBar.icns
```
