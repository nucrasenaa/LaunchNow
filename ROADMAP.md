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

## Roadmap After 2.0.1

- [x] 1. Drag & Drop Reliability 2
  - Make drop targets clearer while dragging.
  - Reduce folder creation and app swap misses.
  - Add a debug mode for inspecting drop zones.

- [ ] 2. Updater Hardening
  - Show clearer download and install progress.
  - Verify downloaded update artifacts with hashes.
  - Add a manual download fallback when automatic install fails.

- [ ] 3. First Run / Onboarding Polish
  - Let new users choose language, shortcut, app scan, search scope, and fullscreen mode in one focused flow.
  - Make the first launch easier to understand before users reach Settings.

- [ ] 4. Settings Search
  - Search settings by keywords such as update, grid, shortcut, and backup.
  - Jump directly to the matching settings section.

- [ ] 5. Advanced Grid Presets
  - Add presets such as Compact, Balanced, Large Icons, and Dense Work Mode.
  - Show a preview before applying a preset.

- [ ] 6. Folder UX Improvements
  - Make folder color, image, and name customization easier to access.
  - Improve folder sorting and folder locking flows.
  - Preview folder style changes before applying them.

- [ ] 7. Backup Safety
  - Preview restore changes before overwriting current data.
  - Compare local profiles with cloud backups.
  - Create an automatic backup before import or restore.

- [ ] 8. Diagnostics Upgrade
  - Add Copy Debug Summary.
  - Export recent logs alongside debug info.
  - Check permissions, paths, and update status in a readable support view.

- [ ] 9. Performance Monitor
  - Show app scan time, cached icon count, and cache health.
  - Add cache clear and rebuild controls.
  - Surface useful performance details for large app libraries.

- [ ] 10. Command Palette Actions 2
  - Add more `Command + K` actions such as Rename, Change Icon, Add to Folder, Open Settings Section, and Backup Now.
  - Keep command palette actions fast and keyboard-friendly.

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
