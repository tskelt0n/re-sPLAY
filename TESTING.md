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

## Version 0.8.8 sidebar corner refinement

- Added 18-point concave joins above and below the selected tab where it meets the detail pane, with 12-point outer corners on the left. Decorative curves extend beyond the row without changing its layout or click target.
- Visually inspected the installed Displays selection and saved the updated screenshot. The selected background remains flush and uses the same semantic color as the main pane.
- Compilation, installed strict signature verification, archive integrity, and whitespace checks passed. Navigation behavior and display settings are unchanged.

## Version 0.8.9 seamless window chrome

- Extended the sidebar and detail backgrounds through a transparent titlebar and removed its separator and toolbar backdrop. Native traffic lights, window dragging, and resizing remain provided by AppKit.
- Moved the sidebar toggle into a native titlebar accessory so its horizontal position stays fixed beside the traffic lights. It retains the existing smooth animation and Reduce Motion behavior.
- Inspected the installed dark window in both sidebar states: no contrasting top strip, the toggle remains in place, and monitor previews expand when collapsed. Resized the window vertically and confirmed all controls fit at 1120 × 832 points; shorter windows scroll the content. Saved both preview captures.
- Compilation, shell syntax, installed strict signature verification, ZIP integrity, and whitespace checks passed. Settings, light appearance, fullscreen, and Reduce Motion were not retested in this pass. No monitor settings were changed.

## Version 0.8.10 selected monitor treatment

- Selected shortcut displays have a purple screen-edge glow and a checkmarked Selected badge at the top of the monitor graphic. Unselected displays use neutral borders; active state remains a separate green indicator.
- Clicking a monitor graphic selects the shortcut target. Removed the main-window star controls and replaced the menu-popover preference control with Select/Selected text pills. Accessible labels, selected traits, and shortcut tooltips identify the purpose.
- In the installed app, selected Studio Display (1), visually confirmed that only its glow and badge appeared, then restored ASUS and verified the selected state moved back. All three displays stayed active with brightness unchanged. Checked the collapsed sidebar layout and refreshed both dark preview captures.
- Build, shell syntax, installed strict signature verification, ZIP integrity, and whitespace checks passed. Menu-popover rendering, light appearance, disconnected selection, and hardware switching were not retested in this visual pass.

## Version 0.8.11 monitor selection motion

- Added a 0.28-second smooth animation to the selected screen-edge glow and badge. The badge fades with a subtle 4-point lift and 0.94-to-1 scale; the glow crossfades independently of monitor layout and wallpaper.
- Kept selection decorations mounted so a new selection can retarget an in-flight animation. Animation values depend only on the preferred flag, avoiding repeated motion from status or brightness polling.
- Reduce Motion uses a 0.12-second opacity fade with no translation or scale. The system setting was not changed during this check.
- Built and installed the update; clicked Studio Display (1), Studio Display (2), and ASUS in turn. Verified selection accessibility values and the settled rendering, then left ASUS selected. No brightness or connection controls were operated. Automated captures verify the final state, not perceived motion smoothness or rapid interruption behavior.
- Compilation, shell syntax, strict installed signature verification, ZIP integrity, and whitespace checks passed. Existing 0.8.10 screenshots remain representative of the settled design.

## Version 0.8.12 action button visibility

- Replaced the faint tinted Use only this buttons with a shared 34-point-high action style: primary text, a solid neutral surface, and a visible border in light and dark appearances. The main window and expanded menu-bar controls share the style.
- Hover brightens the surface and adds a purple border and soft shadow over 0.16 seconds. Pressing darkens the surface and adds a small compression; Reduce Motion removes compression. Disabled controls suppress hover/press emphasis, and Increase Contrast strengthens the resting border.
- Inspected the installed dark main window with its sidebar expanded and collapsed; labels and button boundaries are clear and fit within each display's centered controls. Saved updated screenshots. No display switching or brightness actions were triggered.
- Build, shell syntax, strict installed signature verification, ZIP integrity, and whitespace checks passed. Hover/pressed motion, disabled appearance, light mode, accessibility appearance settings, and the menu-bar rendering were not visually exercised; native automation has no pointer-hover operation.

## Build checks

The first downloadable preview adds `Scripts/package-release.sh`, which rebuilds the app, checks its signature and architecture, packages `INSTALL.md`, and generates `SHA256SUMS.txt`. Release verification includes extracting the ZIP into a clean directory, re-verifying the app signature, checking bundle version/minimum OS and system-only runtime libraries, scanning the extracted payload, and validating the checksum. It does not establish a clean-machine Gatekeeper launch: this preview remains ad-hoc signed and unnotarized.

Before preparing the first release, Gitleaks 8.30.1 found no secrets in 21 reachable commits or the tracked snapshot. An additional review covered 127 historical blobs, visible text and metadata from 30 unique historical images, commit identities, and executable strings. The review found a real-name author/committer in historical Git metadata, but no personal email, home-directory paths, device UUIDs in images, or credentials in the release payload. Generated artwork contains provenance metadata from its image provider; it was retained.

Before public release, historical author/committer names were replaced with the project's `t[0]` alias while retaining GitHub noreply addresses. The rewritten history was re-scanned with Gitleaks, the project tree was verified unchanged, and the remote default branch was updated using an explicit force-with-lease. Local future commits use the same alias. This removes the name from reachable project history, but cannot erase existing clones or guarantee removal of old server-side commit objects. The release ZIP's SHA-256 digest was also verified against GitHub's uploaded asset digest.

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
