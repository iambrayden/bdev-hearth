# Map image

`map.jpg` is the server's postal map. `Config.Map` in `config.lua` holds its calibration:

- **Bounds** are the world coordinates of the image's edges. They were fitted by matching the
  OCRP postal labels printed on the image to the published OCRP postal coordinates.
  760 of the 865 postals matched, with a median error of 1.5 px (about 12 m).
- **Insets** move areas the image draws away from their real position. Cayo Perico is drawn
  about 2.7 km west of where it really is. The offset is anchored on the Cayo airstrip hangar
  (4494, -4523) and is accurate to roughly ±50 m.

## Sharpness

The bundled `map.jpg` is only 1608 px wide, about 8 m per pixel, so it can't show street-level
detail. The app caps zoom at about 1.7× the image's resolution to keep it from turning to mush.

For a sharp map, export the same map at high resolution (8000 px wide or more) and cut it into
tiles. Only the tiles on screen are loaded, so even a huge map stays light on the phone:

```bash
pip install pillow
python tools/make_tiles.py path/to/big-map.png
```

Then paste the `Tiles = { ... }` line it prints into `Config.Map`. The bounds and the Cayo
inset stay the same as long as it's the same map render.
