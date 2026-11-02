# Map image

`map.jpg` is the server's postal map. `Config.Map` in `config.lua` holds its calibration:

- **Bounds** are the world coordinates of the image's edges. They were fitted by matching the
  OCRP postal labels printed on the image to the published OCRP postal coordinates.
  760 of the 865 postals matched, with a median error of 1.5 px (about 12 m).
- **Insets** move areas the image draws away from their real position. Cayo Perico is drawn
  about 2.7 km west of where it really is. The offset is anchored on the Cayo airstrip hangar
  (4494, -4523) and is accurate to roughly ±50 m.

A higher-resolution export of the same map can replace `map.jpg` without touching the
numbers. A different map image needs new bounds.

The app picks its zoom range from the image resolution, so a sharper image allows closer
zoom. Keep the image at 4096 px or smaller; the phone loads it in one go.
