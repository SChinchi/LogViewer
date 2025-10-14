# BepInEx Log Viewer

A cross-platform app to view saved BepInEx logs just like [BepInEx.GUI](https://github.com/risk-of-thunder/BepInEx.GUI) does at runtime. Powered by [<img src="https://storage.googleapis.com/cms-storage-bucket/c823e53b3a1a7b0d36a9.png" alt="Flutter" width="50"/>](https://github.com/flutter/flutter)

Available on:
- Windows
- Android
- Web

## Features

- Supports plain text and .zip files.
- Drag-n-drop files on the executable for easy loading.
- Mod list inspector with search filtering.
  - Deprecated/old mods are flagged appropriately by checking their status on Thunderstore.
    - Whitelist for any mods that fall under these conditions but are still functional.
  - Custom list for generally problematic mods.
  - Long press for custom selection. It is recommended to use this way to add mods to any white-/blacklists.
  - Copy all filtered mods to clipboard.
  - Create a profile code from the mods in the log.
- A console UI with search and log level filters.
  - Long messages are collapsible. Configurable. 
  - Repeated events are bundled together for compression and to highlight potential error spam. Indicated with an orange number at the bottom right.
  - The search supports regex. The following flags can further limit a search:
    - `exclude:term` or `exclude:(term|another|and with spaces)` filters events that contain any of the specified keywords. 
    - `repeat:N` filters for events that are repeated at least N times in a row.
    - `range:start..end` filters for event indices. If either value is omitted, a default is used. Negative numbers count from the end of the list, e.g., `range:-5..` is the last 5 events.
  - Right click to copy selected event to clipboard. Long messages can be copied as a file instead. Configurable. 
- A diagnostics tab that collects various issues that may highlight why a profile leads to errors.
  - **Outdated Mods**: for mods not using the latest version on Thunderstore. Ignore if intentionally downpatching.
  - **Missing Dependencies & Incompatibilities**: for mods failing to load due to dependency issues.
  - **Mods Crashing On Awake**: errors with `BepInEx.Bootstrap.Chainloader:Start()`. Incomplete mod loading may lead to issues for other mods.
  - **Flawed Code Modifications**: errors about MMHOOK and Harmony patches. Signals broken mods or corrupted code state.
  - **Stuck Loading x%**: for errors that cause the game to hang on the loading screen. 
  - **Missing Member Exception**: for outdated mods that attempt to call missing code.
  - **Most Repeated Errors**: events logged multiple times consecutively (most likely errors) sorted in descending order.

## How to build

Follow the steps described in the Flutter [documentation](https://docs.flutter.dev/get-started/install) for your current environment.

Run `build_all.ps1` to generate release versions for any supported platforms which can be found in "build/binaries".