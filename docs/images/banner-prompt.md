# README banner and previews

Updated October 12, 2026 using the built-in image-generation tool, with the real version 0.8.4 screenshot and the repository's purple return-frame logo as compositing references.

`readme-banner.png` is a generated promotional composition. It depicts all three displays active, their brightness controls at the captured 0% values, and the current sidebar, centered controls, and fixed-width display tabs. Monitor settings were not changed to stage the banner. Rendering may differ slightly from native controls; the README also links the unedited captures.

## Source assets

- `app-dark.png`: unedited 0.8.8 main window with rounded inside corners at the sidebar selection (updated after banner generation).
- `sidebar-collapsed.png`: unedited 0.8.4 main window with sidebar collapsed.
- `app-light.png`: earlier 0.8.0 light appearance capture.
- `quick-controls.png`: earlier 0.8.0 light menu-bar popover capture.
- `../brand/re-splay-symbol.png`: authoritative purple return-frame symbol.

Monitor preview wallpaper is illustrative artwork, not a live screen capture. See [wallpaper provenance](../../Assets/README.md) and [brand assets](../brand/README.md).

## Final generation prompt

```text
Use case: compositing / ads-marketing.
Create a polished 2048x1152 landscape GitHub README promotional banner for re-sPLAY, using the two supplied images.
Image 1 is the EXACT current macOS app window and must be preserved as a faithful, readable product screenshot. Image 2 is the authoritative purple return-frame monitor logo to place next to the product name. Preserve that logo shape exactly.
Composition: a quiet charcoal backdrop with a subtle violet glow; restrained left column approximately 27% of the canvas, and the complete, flat, front-facing app window prominently occupying the right 70%, with enough margin to show all rounded corners and a soft shadow. No perspective tilt.
Left column: the purple logo and white product name "re-sPLAY", followed by the exact two-line headline "Your displays.\nYour choice." and smaller muted text "Native display control for macOS".
App screenshot invariants: sidebar open, Displays selected, Settings beneath it, purple brand at sidebar bottom, no title text in top-left toolbar, fixed sidebar toggle beside traffic lights, all three displays active, three equally sized monitor previews showing purple mountain-and-lake wallpaper, centered names Studio Display (1), ASUS PG32UCDM, Studio Display (2), narrowed centered controls below each display. All three brightness sliders visible, all read 0%, Studio auto-brightness toggles off, no auto-brightness control for ASUS. Keep preferred star on ASUS. Four equal-width setup tabs. Preserve all existing labels and controls. Do not invent controls, change values, or alter UI layout. Treat the app screenshot as an inserted image rather than redesigning it.
Visual style: premium native Mac utility, crisp clear typography, restrained violet accent #5C2EFF, generous outer breathing room, product-first.
Avoid extra text, feature lists, decorative devices, badges, watermark, version numbers, and any changes to the monitor graphics or app UI. Opaque background.
```
