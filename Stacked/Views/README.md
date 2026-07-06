# Views

Stacked’s SwiftUI views are grouped by platform so multiplatform files compile cleanly in one target.

## Folders

| Folder | Purpose |
|--------|---------|
| **`Shared/`** | UI and logic used on both iPhone/iPad and Mac. No `#if os(...)` required unless a small platform branch is unavoidable (e.g. settings copy). |
| **`iOS/`** | iPhone and iPad only. Each file is wrapped in `#if os(iOS) … #endif` and defines the iOS variant of a type (e.g. `RootView`, `HomeView`, `AddBookSheet`). |
| **`macOS/`** | Mac only. Same pattern with `#if os(macOS)`. |

Only one platform folder defines each shell type; the other is compiled out.

## Notable shared modules

- **`Shared/AddBook/`** — `SearchSource`, `AddPreselection`, `SearchResultRow`, and `AddBookActions` (search, ISBN, and add-to-library logic). Platform `AddBookSheet` files are thin UI shells around `AddBookActions`.
- **`Shared/Settings/`** — `SettingsContent` holds all sections, state, CRUD, and sheets/alerts. Platform `SettingsView` files only choose `Form` vs `List` and set the navigation title.
- **`Shared/Home/HomeScreen.swift`** — Collection summary and location/format tiles. iOS `HomeView` adds the iCloud sign-in banner; macOS `HomeView` does not.
- **`Shared/Platform/`** — Cross-platform helpers (`Formatters`, `Image+PlatformData`). Platform-specific presentation (`addBookSheet`, `ExportShareSheet`) lives under `iOS/` and `macOS/`.

## Adding a new screen

1. Put shared layout and business logic in **`Shared/`**.
2. Add platform-specific wrappers in **`iOS/`** and/or **`macOS/`**, each fully wrapped in the matching `#if os(...)` guard.
3. Avoid duplicating type names across platforms without guards — the build includes all `.swift` files in the target.
4. Platform folders use **Xcode platform filters** in `project.pbxproj` (`platformFiltersByRelativePath`) so iOS and macOS files can share basenames (e.g. `RootView.swift`) without duplicate compile outputs.
