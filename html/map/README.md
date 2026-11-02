# Map image

Put a top-down GTA V map image here (for example `gta5.webp`) and point
`Config.Map.Image` at it (`'map/gta5.webp'`). `.webp`, `.jpg` and `.png` files
in this folder are streamed to clients automatically.

`Config.Map.Bounds` are the world coordinates of the image's edges. The defaults
fit the common square "GTA V atlas / satellite / road" renders that cover
x -5661.6 to 6693.6 and y -4058.5 to 8429.3. If members appear offset, adjust
the bounds: stand somewhere recognisable, open Hearth and nudge the numbers.

Keep the image at 4096px or smaller; the phone loads the whole file at once.
Without an image the app shows a plain grid and everything else still works.

Rockstar's map art isn't bundled because of licensing. Use an image you have the
rights to use.
