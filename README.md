# Log Viewer

A cross-platform app to view saved BepInEx logs just like [BepInEx.GUI](https://github.com/risk-of-thunder/BepInEx.GUI) does at runtime. Powered by [<img src="https://storage.googleapis.com/cms-storage-bucket/c823e53b3a1a7b0d36a9.png" alt="Flutter" width="50"/>](https://github.com/flutter/flutter)

## Features

- Drag-n-drop files on the executable for easy loading.
- Mod list inspector with search filtering.
  - Deprecated/old mods are flagged appropriately by checking their status on Thunderstore.
    - Whitelist for any mods that fall under these conditions but are still functional.
  - Custom list for generally problematic mods.
  - Copy to clipboard.
- A console UI with search and log level filters.
  - Repeated events are bundled together for compression and to highlight potential error spam. Indicated with an orange number at the bottom right.
  - The search supports regex. The following flags can further limit a search:
    - `repeat:N` filters for events that are repeated at least N times in a row.
    - `range:start..end` filters for event indices. If either value is omitted, a default is used. Negative numbers count from the end of the list, e.g., `range:-5..` is the last 5 events.
- A diagnostics tab that collects various issues that may highlight why a profile leads to errors.
  - Mods Crashing On Awake: errors with `BepInEx.Bootstrap.Chainloader:Start()`. Incomplete mod loading may lead to issues for other mods.
  - Stuck Loading x%: for errors that cause the game to hang on the loading screen. 
  - Missing Member Exception: for outdated mods that attempt to call missing code.
  - Most Repeated Errors: events logged multiple times consecutively (most likely errors) sorted in descending order.

### Planned before 1.0

- Main screen
  - Add loading progress bar for big files. Optimisation might also be possible when parsing the log.
- Summary
  - Currently very much WIP. Maybe trim the information shown, maybe combine it with Diagnostics, maybe get rid of it.
- Diagnostics
  - List any mods not loading due to missing dependencies.
  - Capture mods that corrupt code with bad IL.

## How to build

Follow the steps described in the Flutter [documentation](https://docs.flutter.dev/get-started/install) for your current environment.

Do note the app is currently only tested on Windows and Android.