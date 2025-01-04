# Log Viewer

A cross-platform app to view saved BepInEx logs just like [BepInEx.GUI](https://github.com/risk-of-thunder/BepInEx.GUI) does at runtime. Powered by [<img src="https://storage.googleapis.com/cms-storage-bucket/c823e53b3a1a7b0d36a9.png" alt="Flutter" width="50"/>](https://github.com/flutter/flutter)

## Features

- Drag-n-drop files on the executable for easy loading.
- Deprecated mods are flagged appropriately by checking their status on Thunderstore.
- A console UI with search and log level filters.
  - Repeated events are bundled together for compression and to highlight potential error spam.
  - The search supports regex and starting the text with `repeat:N` also filters for events that are repeated at least N times in a row.
- A diagnostics tab that collects various issues that may highlight why a profile leads to errors.
  - Missing Member Exception: for outdated mods that attempt to call missing code.
  - Most Repeated Errors: events logged multiple times consecutively (most likely errors) sorted in descending order.

### Planned before 1.0

- Main screen
  - Add loading progress bar for big files. Optimisation might also be possible when parsing the log.
  - Properly show an error message when an invalid file is selected.
- Summary
  - Currently very much WIP. Maybe trim the information shown, maybe combine it with Diagnostics, maybe get rid of it.
- Mod list
  - Add search filtering.
  - Flag mods as old (latest update older than a certain date).
  - Flag mods as problematic with a custom list.
  - Add whitelist for functional mods that should not be flagged.
  - Add floating button to copy to clipboard deprecated/old/etc mods.
- Console
  - Show additional lines around an event for context?
- Diagnostics
  - List any mods not loading due to missing dependencies.
  - Capture mods that corrupt code with bad IL.
  - List any mods that crash on their Awake (includes `BepInEx.Bootstrap.Chainloader:Start()` in the stack trace).

## How to build

Follow the steps described in the Flutter [documentation](https://docs.flutter.dev/get-started/install) for your current environment.

Do note the app is currently only tested on Windows and Android.