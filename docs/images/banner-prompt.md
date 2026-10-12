# README banner and previews

Updated October 12, 2026 with the built-in image-generation tool, using the existing branded banner and the real version 0.8.12 app screenshot as compositing references.

`readme-banner.png` is a generated promotional composition showing the current sidebar and seamless titlebar, three active displays, the selected ASUS monitor's purple glow and Selected badge, and higher-contrast Use only this buttons. Brightness values follow the captured state: Studio Display (1) 0%, ASUS 25%, Studio Display (2) 0%. Monitor settings were not changed to stage the banner. Rendering may differ slightly from native controls; the README also links the unedited captures.

## Source assets

- `app-dark.png`: unedited 0.8.12 main window; authoritative app reference for this banner.
- `sidebar-collapsed.png`: unedited 0.8.12 main window with sidebar collapsed.
- `app-light.png`: earlier 0.8.0 light appearance capture.
- `quick-controls.png`: earlier 0.8.0 light menu-bar popover capture.
- `../brand/re-splay-symbol.png`: authoritative purple return-frame symbol, retained from the existing banner.

Monitor preview wallpaper is illustrative artwork, not a live screen capture. See [wallpaper provenance](../../Assets/README.md) and [brand assets](../brand/README.md).

## Generation prompt

Image 1 was the previous README banner (available in Git history); image 2 was `app-dark.png`.

```text
Use case: compositing.
Asset: updated GitHub README promotional banner for re-sPLAY, landscape 16:9.
Image 1 is the existing banner to edit. Image 2 is the authoritative current version 0.8.12 app screenshot to insert.
Replace only the entire outdated app window on the right in image 1 with the complete app window from image 2. Preserve image 1's charcoal and violet glow backdrop, purple return-frame logo, left-column typography and exact wording: "re-sPLAY", "Your displays.", "Your choice.", "Native display control for macOS". Maintain generous margins, flat front-facing app window, soft shadow, crisp legible UI. Fit the new window at its correct aspect ratio, with no cropping of its outer corners or footer.
The app UI must faithfully match image 2: seamless transparent titlebar, larger sidebar brand at top, dark connected selected Displays tab, Settings beneath, status at sidebar bottom. Three monitors, all active, named Studio Display (1), ASUS PG32UCDM, Studio Display (2). Only the center ASUS monitor has a subtle purple screen-edge glow, a purple outline and a checkmarked "Selected" pill centered on its top edge. The two Studio monitors have neutral grey outlines and no badge or glow. All three brightness sliders clearly visible, Studio values 0%, ASUS 25%. Both Studio auto brightness switches off. Three legible grey rounded "Use only this" buttons with light semibold text and visible borders, centered under their respective monitor controls. No star icons. Four equal-width setup tabs with All displays selected. Preserve all other screenshot labels, controls, wallpaper, layout and spacing.
Do not redesign the UI, invent controls, add promotional labels or version numbers, change the logo, or alter the left text. This is a product screenshot replacement, not a new UI concept. Opaque background, high-resolution crisp finish.
```

## Final correction prompt

Image 1 was the first generated revision; image 2 remained `app-dark.png`. The final revision was inspected for branding, sidebar shape, selected badge/glow, all three brightness controls, readable buttons, and text accuracy.

```text
Use case: compositing. Make one precise correction to image 1 (the generated re-sPLAY banner), using image 2 (the actual current app screenshot) as the authoritative sidebar reference.
Correct only the app sidebar selection: the "Displays" row must NOT have a light grey floating rounded rectangle. It must have the same dark charcoal background as the adjacent main content, joining it flush on the right edge like a folder tab, with the large smooth concave curves above and below the join visible in image 2. The sidebar brand section above and Settings area below remain slightly lighter grey. Remove the artificial rectangular block edge beneath the sidebar brand. Preserve the exact connected silhouette of image 2.
Keep ALL other pixels/composition/text as close as possible to image 1: the left logo, all marketing text, charcoal-violet background, app-window placement, three active monitors, ASUS-only purple glow and Selected badge, brightness 0% / 25% / 0%, grey "Use only this" buttons, all labels, footer, controls and margins. No new elements, no text changes, no UI redesign, no version labels. Landscape 16:9 opaque banner.
```
