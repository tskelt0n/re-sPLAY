# Privacy

re-sPLAY operates locally. The current source includes no analytics, advertising SDK, crash-report upload, account system, or application network requests. Monitor previews use bundled artwork; they do not capture the desktop.

## Local settings

The app stores its settings in macOS UserDefaults under the bundle identifier `local.DisplaySwitch`. These include display identifiers and names, the last known display layout, displays disabled by the app, shortcut target, window state, and recovery information. macOS manages login-item registration and display brightness preferences separately.

These settings are created on each user's Mac. The release package contains only the compiled app, bundled artwork, license notices, and installation guide. It does not include the developer's preferences or diagnostics.

## Sharing diagnostics

Command-line diagnostics can contain display UUIDs, monitor names, layout coordinates, and local status. Review and redact them before posting an issue or sharing a screenshot. The app does not upload these reports automatically.

## Distribution

The first preview is ad-hoc signed and is not notarized. GitHub processes downloads and repository activity under its own privacy policy; macOS may perform its normal security checks. Public GitHub account names and contribution metadata are separate from the app's local settings.

## Release privacy review

The first-release review checked tracked files, reachable Git history, image text/metadata, and the packaged app for secrets and personal paths. Automated scanning cannot prove that no sensitive information exists; future contributions and release assets should be reviewed again before publication.
