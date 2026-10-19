# TodoPilot 1.0.2 candidate notes

TodoPilot is the renamed Windows release of Life Manager. It adds the white orbit icon on black, a separate transparent orbit window icon, an interactive color wheel for separate light and dark palettes, validated JSON presets, a Contributors page, and native widget background opacity, a right-click menu, flexible sizing, and layout locking. Fresh installer data uses `%APPDATA%\TodoPilot`; portable extractions use separate location-keyed profiles. The installer retains its prior AppId and install directory for a registered TodoPilot upgrade. Older Life Manager data requires an explicit import on a fresh installation.

The package includes the Flutter runtime and native widget. The installer is unsigned. Windows 10, installed upgrades and uninstall, widget alpha against different wallpapers, Win+D, multiple monitors and DPI, privacy integration, and complete native GUI interactions still require manual acceptance. Public release also awaits creator approval of the proposed MIT license and GitHub destination.

Version 1.0.2 uses the transparent, black-outlined orbit inside the Flutter sidebar, matching the title-bar treatment while preserving the black-tile executable and installer icon. Packaging now rejects leftover legacy executables. Public-name clearance is also pending because other task products use TodoPilot or ToDoPilot.
