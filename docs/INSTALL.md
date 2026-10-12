# Install re-sPLAY

Requires an Apple silicon Mac (M-series) running macOS 27 or later. Intel Macs and earlier macOS versions are not supported. Xcode, Command Line Tools, Homebrew, and a compiler are **not required** to use the packaged app.

1. Download `re-sPLAY-v0.8.12-macos27-arm64.zip` from the GitHub release's **Assets** section. The automatically generated Source code archives are for developers.
2. Double-click the ZIP in Finder.
3. Quit any running copy of re-sPLAY, then drag `re-sPLAY.app` into Applications. Replace the previous app if upgrading.
4. Open re-sPLAY. Its display icon appears in the menu bar; choose **Open re-sPLAY** to open its main window.

## First-open approval

This first preview is ad-hoc signed, not Developer ID signed or Apple-notarized. macOS may block the first launch because it cannot verify the developer. If you trust this download, first try opening the app, then use **System Settings → Privacy & Security → Open Anyway** and confirm. See [Apple's instructions](https://support.apple.com/en-us/102445). Managed Macs may prohibit this exception.

No system-wide Gatekeeper changes or Terminal quarantine-removal commands are needed. If macOS reports malware or a damaged app, stop and check the download rather than bypassing that warning.

## Verify the download (optional)

Download `SHA256SUMS.txt` into the same folder as the ZIP. In Terminal, change to that folder and run:

```sh
shasum -a 256 -c SHA256SUMS.txt
```

The result should say `OK`. The checksum detects a changed or incomplete download; it does not replace Developer ID signing or notarization.

## Getting started

- Use **Use only this** to activate one monitor exclusively, or **Restore all** to reconnect displays disabled by this app.
- Click a monitor graphic to select the target for **Control–Option–Command–1**; press that shortcut again to restore. **Control–Option–Command–0** restores all.
- Brightness and auto-brightness controls depend on the monitor and connection. Native HDR brightness is supported where macOS exposes it.
- Enable **Launch at login** in Settings after moving the app to its permanent location.

This preview uses private macOS display APIs and has been tested on a limited hardware set. Review the repository's TESTING.md for limitations. Quitting normally restores displays the app disabled. If a display fails to reconnect, reconnect its cable or restart the Mac.

Project and downloads: https://github.com/tskelt0n/re-sPLAY
