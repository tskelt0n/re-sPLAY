# Verification

## Tested environment

Functional checks were performed during development on October 12, 2026, with macOS 27.0.1, an M4 Max MacBook Pro, two Apple Studio Displays, an ASUS PG32UCDM, and CalDigit TS4 docks. These are hardware-specific observations, not a compatibility guarantee.

## Verified behavior through version 0.7.2

- Exclusive mode worked for the ASUS and each Studio Display. Switching between inactive displays connected the target first, then disabled the others. Restore All returned all three to the original arrangement.
- Attempting to disconnect all active displays was rejected before applying a display configuration.
- Both global shortcuts registered. Physical keyboard testing confirmed exclusive mode and restoration. Synthetic key events did not reliably reach Carbon hotkeys and were not accepted as end-to-end verification.
- Launch-at-login registration reported enabled through SMAppService and the native interface. A logout/login cycle was not performed.
- Studio Display brightness and auto-brightness controls were tested independently using the actual app and fresh-process readbacks. With auto brightness Off, manually selected levels held during a 20-second check.
- The native interface was inspected in light and dark appearances. Display names and controls aligned, info popovers wrapped, and slider tick marks were removed. Minimum-window-size rendering was not independently confirmed.
- Version 0.7.2 corrected ASUS HDR brightness routing: native capability is queried instead of selecting the backend by monitor manufacturer. Setting the app slider to 15% moved the native System Settings slider. Changing System Settings to 25% appeared in the app after refresh. The user then confirmed that the app visibly changed brightness with HDR enabled.
- A brightness request above 100% was rejected before writing. Native writes require readback within one percentage point of the requested value. Writes are serialized and debounced; request revisions reject stale results.
- App builds and ad-hoc signatures passed verification before packaging and on the installed copy.

Earlier DDC tests confirmed changes to the ASUS luminance register, but those readbacks did **not** establish visible brightness changes in HDR. Native macOS brightness is the verified path for that configuration. No physical luminance or power measurements were made.

## Build checks

```sh
bash -n build.sh
./build.sh
codesign --verify --deep --strict build/re-sPLAY.app
git diff --check
```

Some file providers attach metadata to app bundles after signing. The build signs and verifies in a temporary directory and creates the ZIP before copying to `build/`. If metadata affects the copied bundle, extract the ZIP to a regular local directory and verify that copy.

## Repository import checks

The 0.7.2 source was imported into this repository on October 12, 2026. Swift source matches the working app apart from removal of trailing whitespace. The build now keeps its app and ZIP under `build/` and bundles the repository's MIT license alongside the third-party notices.

Shell syntax, compilation from this directory, strict signature verification, ZIP integrity, bundle version, packaged license/notices, and Git ignore rules were checked. No display settings were changed or hardware regression tests repeated for this import.

## Manual regression checks

Save the current display arrangement, brightness levels, and auto-brightness preferences before tests that change them; restore those settings afterward.

1. Open the app and verify all connected displays, brightness values, shortcut target, and login state.
2. Use each display exclusively, then switch directly to another inactive display. Confirm the target remains usable and Restore All returns the workspace.
3. Test both shortcuts from a physical keyboard while another app is active. Confirm the last active display cannot be disconnected.
4. Change each display’s brightness independently. Check the visible result and fresh readback, rather than relying only on an acknowledged DDC write.
5. With ASUS HDR enabled, compare the app and System Settings brightness sliders in both directions. Confirm HDR stays enabled and the picture visibly changes.
6. Toggle each supported auto-brightness control and verify the other display’s preference remains unchanged. With it Off, confirm manual brightness holds.
7. Check controls while a display is disconnected and after restoring it. Inspect light/dark appearances and window resizing for clipping or inaccessible controls.

## Limits

Not established: overnight sleep/wake reliability, persistence through every logout or restart, arbitrary hot-plug during device I/O, all WindowServer failures, Intel support, other monitor/dock combinations, or future macOS API behavior. The 0.7.2 fix was tested with HDR kept enabled; toggling HDR off/on and unsupported native-control failure paths were not exercised. There is no automated hardware test suite or CI workflow yet.
