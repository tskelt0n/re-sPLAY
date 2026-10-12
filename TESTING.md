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

## Version 0.8.0 redesign checks

- Compiled the native sidebar window, tabbed menu-bar popover, and shared return-frame branding. Verified strict ad-hoc signatures on the packaged and installed app.
- Inspected the main window in light and dark appearance with all three displays active, their brightness controls visible, and both Studio auto-brightness toggles Off. Saved actual app captures for the README.
- Opened Quick Controls with Command–Shift–D and inspected the compact three-display view. The user physically confirmed that the Displays and Settings tabs, expanded display rows, and brightness controls work.
- Automated inspection of some Settings/expanded views crashed Codex's `SkyComputerUseService`; no corresponding re-sPLAY crash was observed. The user's physical check supplements automation for those views.
- Checked the last-display guard and launch-at-login status. The installed copy follows the system appearance and retains the existing bundle identifier, preferences, and login registration.
- The display-switching engine and native HDR/DDC brightness implementation are unchanged. Workspace recall is intentionally deferred. A full hardware regression cycle and minimum-window-size rendering check were not repeated for this UI change.

## Version 0.8.1 window and popover fixes

- Verified the title is visually hidden while retaining the window's accessibility name.
- Clicked the sidebar toggle in both directions and compared rendered screenshots: the single button remains beside the traffic-light controls on the left. Enforced the sidebar's minimum width to keep its brand label readable.
- The popover now resolves its hosted content size before positioning instead of starting with a stale fixed height. Opening it no longer calls application-wide activation, and reopening is ignored while the popover is shown. Its gear button selects the internal Settings tab.
- Build and installed strict signature verification passed. The user physically confirmed that the panel sits directly beneath the menu-bar icon and opens without reopening the closed main window.

## Version 0.8.2 responsive layout

- Replaced the adaptive column template with an explicit count capped at the number of displays, eliminating the empty fourth slot at the sidebar-collapse breakpoint.
- Preview height now follows column width and device aspect ratio; column spacing also grows with the available width. Single-display panels are capped at a readable width.
- Inspected installed app screenshots with the sidebar open and closed at the same 1120-point window width: all three displays fill the row, and monitor preview width grows from approximately 264 to 322 points after collapsing the sidebar. Controls remain visible and aligned, and the sidebar button stays fixed.
- Compilation, installed signature verification, archive integrity, and whitespace checks passed. Hardware settings were unchanged. Minimum-width rendering was not verified: the automated resize gesture did not resize the window.

## Version 0.8.3 control spacing and stable tabs

- Centered each monitor's name and controls in a group capped at 260 points, with horizontal insets. Monitor illustration geometry and responsive preview sizing are unchanged.
- Gave the display-setup segmented control an explicit width based on its segment count, removing reliance on fluctuating intrinsic widths during view refreshes.
- Inspected both sidebar states in the installed app and compared the collapsed layout again after multiple refresh cycles. The sampled captures appeared stable, but the user subsequently reproduced internal segment resizing in 0.8.3. The outer frame alone was insufficient. Monitor previews retained their previous sizes while the controls were visibly separated.
- Build, installed strict signature verification, archive integrity, and whitespace checks passed. No display brightness or connection settings were changed.

## Version 0.8.4 native segment sizing

- Replaced the SwiftUI display-setup Picker with an AppKit segmented control that assigns 96 points to each segment and uses fixed distribution. The surrounding frame includes its border inset.
- Reconfigure labels and widths only when available options change; normal model refreshes update selection and enabled state without rebuilding segments.
- Compared installed app captures across a 25-second interval: segment boundaries and the control's origin remained unchanged. Inspected both sidebar states and the menu-bar control. Clicking All displays confirmed the native action invokes restoration and disables segments during the transition.
- Retained the capsule appearance and purple selection. Control spacing and monitor artwork are unchanged. Compilation and installed signature verification passed.

## Version 0.8.5 sidebar readability

- Enlarged sidebar navigation to 17-point labels and 21-point icons, with taller rows and a 220-point minimum sidebar width.
- Moved the brand to a prominent top header, using a 36-point symbol and 21-point product name. Added current display status at the bottom.
- Inspected the installed window: labels fit, all three monitor columns remain visible, and sidebar collapse/reopen works. Captured the updated dark window for the README. Settings content was not retested; navigation selection wiring is unchanged.
- Compilation, installed strict signature verification, archive integrity, and whitespace checks passed. Display settings were unchanged.

## Version 0.8.6 navigation motion

- Sidebar visibility changes now run in a 0.32-second smooth animation transaction. Page changes use a 0.24-second crossfade with an 8-point insertion offset inside a clipped, stable detail container.
- Animations are scoped to sidebar visibility and selected page, not periodic brightness or status updates. Reduce Motion disables the sidebar spring and page translation, retaining a 0.12-second opacity fade.
- Installed app launched and sidebar collapse/reopen reached the correct states. The user physically confirmed that both sidebar and page transitions feel smooth; automated captures only verify settled states. Reduce Motion was not toggled on the user's system during testing.
- Compilation, installed strict signature verification, archive integrity, and whitespace checks passed.

## Version 0.8.7 connected sidebar selection

- Replaced the system list highlight with navigation buttons whose selected background uses the same semantic window-background color as the detail pane. The selected shape has rounded left corners and extends to the sidebar's right edge.
- Preserved selection accessibility traits, native button keyboard activation, up/down navigation handling, and the existing page transitions.
- Visually confirmed the selected Displays tab joins the main pane and saved an updated capture. Settings inspection again encountered the known Codex native inspection-service failure; its rendered selection and keyboard navigation were not independently verified in this pass.
- Compilation, installed strict signature verification, archive integrity, and whitespace checks passed. No display settings were changed.

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
7. Open the menu-bar popover, switch between Displays and Settings, and expand each display row. Check brightness, auto brightness where supported, shortcut selection, and the last-display guard in both surfaces.
8. Check controls while a display is disconnected and after restoring it. Inspect light/dark appearances and window resizing for clipping or inaccessible controls.

## Limits

Not established: overnight sleep/wake reliability, persistence through every logout or restart, arbitrary hot-plug during device I/O, all WindowServer failures, Intel support, other monitor/dock combinations, or future macOS API behavior. The 0.7.2 fix was tested with HDR kept enabled; toggling HDR off/on and unsupported native-control failure paths were not exercised. There is no automated hardware test suite or CI workflow yet.
