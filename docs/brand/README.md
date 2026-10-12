# re-sPLAY identity

The preferred return-frame monitor design replaces the earlier three-monitor concept. A rounded monitor frame becomes a return arrow along its top edge, linking display control and restoration in a single symbol.

The authoritative, resolution-independent drawing is [`Sources/BrandArtwork.swift`](../../Sources/BrandArtwork.swift), adapted from the user-supplied logo reference. The same drawing supplies the purple app branding, monochrome menu-bar template image, and white-on-purple app icon.

- `re-splay-symbol.png`: transparent purple symbol, exported at 1024 × 1024.
- `re-splay-app-icon.png`: app-icon artwork, exported at 1024 × 1024.
- Accent: sRGB approximately `#5C2EFF`.

Preserve the open frame, left-facing return arrow, separate foot, rounded joins, and clear space. At menu-bar size, use the monochrome template symbol so macOS can adapt its color to appearance and selection.

## Export

```sh
mkdir -p work
xcrun swiftc Sources/BrandArtwork.swift Scripts/GenerateIcon.swift -o work/export-brand -framework AppKit
work/export-brand work/Brand.iconset docs/brand
```

The normal build generates the complete iconset and packages it as AppIcon.icns. No downloaded font, image model, or third-party library is required to reproduce the logo or app icon.
