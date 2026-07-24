# LaunchNow Roadmap

Use this checklist to track future features. When the 2.0.0 roadmap is complete, LaunchNow should be ready for a 2.0.0 release.

## Roadmap to 2.0.0

- [x] 1. Update UX Improvements
  - Show the latest automatic update check status more clearly.
  - Show readable error details or logs when update checks, downloads, or installs fail.
  - Add an auto update button so users can trigger the automatic update flow directly.

- [x] 2. Cloud Sync Auto Backup
  - Automatically back up profiles when users save a profile or change the layout.
  - Detect when the cloud folder has newer data than local profiles.
  - Add conflict handling before overwriting local or cloud profile data.

- [x] 3. Profile Version History
  - Keep recent profile snapshots, such as the latest 5-10 versions.
  - Let users restore a previous profile snapshot.
  - Make it easy to recover after accidental layout changes.

- [x] 4. App Usage / Smart Suggestions
  - Track app launches so LaunchNow can sort by real usage.
  - Suggest folders or categories from usage patterns.
  - Add a toggle so users can disable smart suggestions or automatic layout changes.

- [x] 5. Search Command Palette
  - Add a shortcut-driven command palette for app search and actions.
  - Support actions such as Open, Show in Finder, Rename, and Change Icon.
  - Keep the flow focused on LaunchNow while feeling fast like Spotlight or Raycast.

- [x] 6. Folder Customization More
  - Add folder color customization.
  - Add folder background customization.
  - Support sorting apps inside folders.
  - Add folder layout locking.

- [x] 7. Layout Lock / Edit Mode
  - Add a layout lock to prevent accidental dragging.
  - Require Edit Mode before users can reorder apps or create folders.
  - Show drag grid guidance that explains folder creation zones and swap zones while dragging.

- [x] 8. Onboarding / First Run Setup
  - Guide first-time users through language, shortcut, app scan, and fullscreen mode choices.
  - Reduce setup confusion for new users.

- [x] 9. Diagnostics / Support Panel
  - Add an Export Debug Info button.
  - Show app version, update status, data path, last sync status, and relevant logs.
  - Make bug reports easier to inspect and reproduce.

- [x] 10. Performance / Large App Library Polish
  - Optimize app scanning and cache refresh behavior.
  - Add lazy icon loading where it helps.
  - Reduce memory usage for large app libraries.

## Suggested 2.0.0 Order

- [x] Update UX Improvements
- [x] Cloud Sync Auto Backup
- [x] Profile Version History
- [x] Layout Lock / Edit Mode
- [x] Search Command Palette
- [x] Diagnostics / Support Panel
- [x] Performance / Large App Library Polish
- [x] Folder Customization More
- [x] App Usage / Smart Suggestions
- [x] Onboarding / First Run Setup

## Completed 1.x Roadmap

- [x] Rename App Display Name
  - Let users set a custom display name per app without renaming the real `.app` bundle.

- [x] Custom Folder Icon
  - Let users choose a custom icon for folders, matching the custom app icon flow.

- [x] Right-click Context Menu
  - Add contextual actions for apps and folders: Open, Show in Finder, Change Icon, Reset Icon, Rename, Remove.

- [x] Keyboard Shortcut / Hotkey Setting
  - Let users configure a global shortcut to show or hide LaunchNow.

- [x] Theme / Appearance Presets
  - Add presets such as Glass, Dark, Light, Compact, and Classic Launchpad.

- [x] Backup / Restore Profiles
  - Support multiple saved layouts, such as Work, Personal, Gaming, or exported/imported profiles.

- [x] Cloud Folder Sync
  - Let users choose an iCloud Drive, Google Drive, Dropbox, OneDrive, or other synced folder for online profile backups.

- [x] Auto Check Update
  - Automatically check for new releases in the background and notify users when an update is available.

- [x] Search Actions
  - Let users choose whether search covers LaunchNow apps or all apps on the Mac, while exposing contextual actions in search results.

- [x] Auto-organize Apps
  - Group apps automatically by category, such as Developer, Design, Games, Utilities, and Productivity.

- [x] Change Background
  - Let users customize the LaunchNow background with colors, images, opacity, blur, and appearance presets.
