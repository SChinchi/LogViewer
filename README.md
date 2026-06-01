# BepInEx Log Viewer

A cross-platform app to view saved BepInEx logs just like [BepInEx.GUI](https://github.com/risk-of-thunder/BepInEx.GUI) does at runtime. Powered by [<img src="https://storage.googleapis.com/cms-storage-bucket/c823e53b3a1a7b0d36a9.png" alt="Flutter" width="50"/>](https://github.com/flutter/flutter)

Available on:
- Windows
- Android
- Web (try it [here](https://schinchi.github.io/logviewer_website/))

## Features

### File support

- Accepts plain text and .zip files.
- Drag-and-drop files onto the executable for quick loading.

### Mod list inspector

- Searchable filter for mods.
- Flags deprecated/old/AI mods by checking their Thunderstore status.
- Custom list for generally problematic mods.
- Long-press selection for adding mods to white-/blacklists.
- Copy all filtered mods to clipboard.
- Generate a profile code (does not include [patchers](https://github.com/SChinchi/LogViewer/issues/4)).

### Console UI

- Searchable console with log-level filters and regex support.
- Search flags to refine results:
  - `exclude:term` or `exclude:(term|another|with spaces)` — exclude events that contain any listed keywords.
  - `repeat:N` — match events repeated at least N times in a row.
  - `range:start..end` — filter by event index. Omitted values use sensible defaults; negative numbers count from the end (e.g., range:-5.. is the last 5 events).
- Long messages are collapsible (configurable).
- Repeated events are bundled to reduce noise, indicated with an orange counter at the bottom right.
- Right-click actions:
  - Copy event text to clipboard; long messages can be copied as a file (configurable).
  - Go to event: resets filters and centers the view on that event for local context.

### Diagnostics

- Outdated Mods — mods not using the latest Thunderstore version (ignore if intentionally downpatched).
- Skipped Mods — mods that fail to load for any reasons (e.g., dependency issues).
- Mods Crashing On Awake — errors originating from BepInEx.Bootstrap.Chainloader:Start() which may lead to further issues.
- Flawed Code Modifications — errors with MMHOOK or Harmony patches indicating broken functionality.
- Stuck Loading x% — errors causing the game to hang during loading.
- Missing Member Exception — errors by outdated mods calling missing code.
- Most Repeated Errors — consecutive error events sorted by frequency (descending).

## How to build

Follow the steps described in the Flutter [documentation](https://docs.flutter.dev/get-started/install) for your current environment.

Run `build_all.ps1` to generate release versions for any supported platforms which can be found in "build/binaries".

For the web you need to create the [sqlite binaries](https://pub.dev/packages/sqflite_common_ffi_web) first by running once:

```
dart run sqflite_common_ffi_web:setup
```