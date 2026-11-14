import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:log_viewer/constants.dart';
import 'package:log_viewer/providers/mod_manager.dart';
import 'package:log_viewer/settings.dart';
import 'package:log_viewer/themes/themes.dart';
import 'package:log_viewer/utils.dart';
import 'package:log_viewer/widgets/advanced_scrollable.dart';
import 'package:provider/provider.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class ModListPage extends StatefulWidget {
  final TabController tabController;
  final FocusNode focusNode;

  const ModListPage({super.key, required this.tabController, required this.focusNode});

  @override
  State<ModListPage> createState() => _ModListPageState();
}

class _ModListPageState extends State<ModListPage> with AutomaticKeepAliveClientMixin {
  // Either "Manifest" line (with "Loading" line if it exists), else just "Loading" line.
  // [\d:.]+ is to account for the timestamp in front of the second line with AsyncLoggers.
  static final _modPattern = RegExp('\\[Info\\s*:\\s*BepInEx\\] TS Manifest: (.*)'
      '(?:\\r?\\n(?:\\[[\\d:.]+\\] )?\\[Info\\s*:\\s*BepInEx\\] Loading \\[(.*)\\])?'
      '|\\[Info\\s*:\\s*BepInEx\\] Loading \\[(.*)\\]',
      multiLine: true
  );

  late final ModManager _modManager;
  final _textFocusNode = FocusNode(debugLabel: 'modlist-search');
  final _dropdownFocusNode = FocusNode(debugLabel: 'modlist-dropdown');
  late final TextEditingController _textController;
  final _scrollController = ScrollController(debugLabel: 'modlist');

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _modManager = context.read<ModManager>();
    _textController = TextEditingController(text: '');
  }

  @override
  void dispose() {
    _textFocusNode.dispose();
    _dropdownFocusNode.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final mods = context.select((ModManager manager) => manager.filteredMods.toList());
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 3, 5, 3),
      child: Column(
        children: [
          Container(
            alignment: Alignment.topLeft,
            height: 70,
            width: 400,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
                  height: 70,
                  width: 200,
                  child: TextField(
                    focusNode: _textFocusNode,
                    controller: _textController,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      labelText: Constants.searchText,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (text) {
                      _modManager.searchString = text;
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 10, 0, 0),
                  height: 70,
                  width: 200,
                  child: DropdownMenu(
                    initialSelection: _modManager.category,
                    inputDecorationTheme: InputDecorationTheme(
                      isDense: true,
                      constraints: BoxConstraints.tight(const Size.fromHeight(50)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    onSelected: (ModCategory? value) {
                      _modManager.category = value!;
                    },
                    dropdownMenuEntries: UnmodifiableListView(
                      ModCategory.values.map((ModCategory cat) =>
                          DropdownMenuEntry(value: cat, label: cat.name)),
                    ),
                    focusNode: _dropdownFocusNode,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                AdvancedScrollable(
                  controller: _scrollController,
                  mainFocusNode: widget.focusNode,
                  otherFocusNodes: [_textFocusNode, _dropdownFocusNode],
                  child: SuperListView.builder(
                    controller: _scrollController,
                    itemCount: mods.length,
                    itemBuilder: (context, index) {
                      return Selector<ModManager, (String, int, bool)>(
                        selector: (context, modManager) => (mods[index].name, mods[index].labels, mods[index].isSelected),
                        builder: (context, value, _) {
                          final mod = mods[index];
                          return GestureDetector(
                            child: Text(
                              mod.name,
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                color: mod.isDeprecated ? Colors.red
                                    : mod.isOld ? Colors.grey
                                    : mod.isProblematic ? Colors.yellow
                                    : mod.isAi ? Colors.blue
                                    : AppTheme.primaryColor,
                                backgroundColor: mod.isSelected ? AppTheme.selectedColor
                                    : AppTheme.secondaryColor,
                              ),
                            ),
                            onLongPress: () {
                              if (!_modManager.isInSelectionMode) {
                                _modManager.toggleSelected(mod);
                              }
                            },
                            onTap: () {
                              if (_modManager.isInSelectionMode) {
                                _modManager.toggleSelected(mod);
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: FloatingActionButton(
                          heroTag: 'mod_diff',
                          child: const Icon(Icons.compare_arrows_rounded),
                          onPressed: () async {
                            final file = await FilePicker.pickFile();
                            if (file != null) {
                              var text = _loadText(await file.readAsBytes());
                              // We only scan the first 100 MB. A very long file may lead to more matches than
                              // the int max value, which can lead to an error. This size limit is more than
                              // generous for ensuring we are past any mod loading phase in the log file.
                              final sizeLimit = 100 * 1024 * 1024;
                              if (text.length > sizeLimit) {
                                text = text.substring(0, sizeLimit);
                              }
                              final modNames = _parseModNamesFromLogText(text);
                              final originalModNames = _modManager.mods.map((mod) => mod.name).toSet();
                              var found1 = originalModNames.difference(modNames);
                              var found2 = modNames.difference(originalModNames);
                              if (context.mounted) {
                                if (modNames.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text(Constants.modDiffNoMods)));
                                } else if (found1.isEmpty && found2.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text(Constants.modDiffOK)));
                                } else {
                                  final stringBuffer = StringBuffer();
                                  if (found1.isNotEmpty) {
                                    stringBuffer.writeln('ONLY IN PRIMARY FILE');
                                    stringBuffer.writeln('--------------------');
                                    stringBuffer.write(found1.join('\n'));
                                  }
                                  if (found2.isNotEmpty) {
                                    if (found1.isNotEmpty) {
                                      stringBuffer.writeln('\n');
                                    }
                                    stringBuffer.writeln('ONLY IN SECONDARY FILE');
                                    stringBuffer.writeln('----------------------');
                                    stringBuffer.write(found2.join('\n'));
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text(Constants.modDiffIssuesFound)));
                                  await Clipboard.setData(ClipboardData(text: stringBuffer.toString()));
                                }
                              }
                              if (Environment.isMobile) {
                                FilePicker.clearTemporaryFiles();
                              }
                            }
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: FloatingActionButton(
                          heroTag: 'profile',
                          child: const Icon(Icons.account_circle_rounded),
                          onPressed: () async {
                            // TODO: Fix for Web
                            if (Environment.isWeb) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text(Constants.profileCodeError)));
                              }
                              return;
                            }
                            if (_modManager.mods.isEmpty) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text(Constants.emptyModList)));
                              }
                              return;
                            }
                            final stringBuffer = StringBuffer('profileName: ${Constants.modProfileName}\n');
                            stringBuffer.writeln('mods:');
                            for (var mod in _modManager.mods) {
                              if (mod.hasManifest) {
                                final version = mod.version;
                                stringBuffer.writeln('  - name: ${mod.fullName}');
                                stringBuffer.writeln('    version:');
                                stringBuffer.writeln('      major: ${version.major}');
                                stringBuffer.writeln('      minor: ${version.minor}');
                                stringBuffer.writeln('      patch: ${version.patch}');
                                stringBuffer.writeln('    enabled: true');
                              }
                            }
                            final fileHandle = RamFileHandle.asWritableRamBuffer();
                            final fileStream = OutputFileStream.toRamFile(fileHandle);
                            final zipFile = ZipFileEncoder()
                              ..createWithStream(fileStream)
                              ..addArchiveFile(ArchiveFile.string('export.r2x', stringBuffer.toString()));
                            await zipFile.close();
                            await fileHandle.close();
                            await fileStream.close();

                            final data = '#r2modman\n${base64Encode(fileStream.getBytes())}';
                            try {
                              final post = await http.post(
                                Uri.parse('https://thunderstore.io/api/experimental/legacyprofile/create/'),
                                headers: {
                                  'Content-Type': 'application/octet-stream',
                                },
                                body: data,
                              );
                              final message = post.statusCode == 200
                                  ? json.decode(post.body)['key']
                                  : 'Error: ${post.statusCode}';
                              await Clipboard.setData(ClipboardData(text: message));
                            } on SocketException {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text(Constants.noConnectionError)));
                              }
                            }
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: FloatingActionButton(
                          heroTag: 'copy',
                          child: const Icon(Icons.copy),
                          onPressed: () async {
                            final text = _modManager.filteredMods.map((m) => m.name).join('\n');
                            await Clipboard.setData(ClipboardData(text: text));
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _loadText(List<int> bytes) {
    // TODO: Should probably refactor this with LoadingProvider.loadFromBytes that does a very similar thing.
    var finalBytes = bytes;
    if (bytes.length >= Constants.zipHeader.length && listEquals(bytes.getRange(0, 4).toList(), Constants.zipHeader)) {
      final zip = ZipDecoder().decodeBytes(bytes);
      if (zip.isNotEmpty) {
        finalBytes = zip.first.content;
      }
    }
    try {
      return utf8.decode(finalBytes);
    } on FormatException {
      return '';
    }
  }

  static Set<String> _parseModNamesFromLogText(String text) {
    final matches = _modPattern.allMatches(text);
    final modData = <(String, String)>[];
    final manifestCounter = <String, int>{};
    for (final match in matches) {
      final manifestName = match.group(1) ?? Constants.noManifestModName;
      final bepInExName = match.group(2) ?? match.group(3) ?? '';
      modData.add((manifestName, bepInExName));
      if (!manifestCounter.containsKey(manifestName)) {
        manifestCounter[manifestName] = 1;
      } else {
        manifestCounter[manifestName] = manifestCounter[manifestName]! + 1;
      }
    }
    final modNames = <String>{};
    for (final mod in modData) {
      // Replicating the naming pattern that Mod.name also uses.
      if (Settings.useModManifest.value) {
        if (mod.$1 != Constants.noManifestModName && manifestCounter[mod.$1]! == 1) {
          modNames.add(mod.$1);
        } else {
          modNames.add('${mod.$1} [${mod.$2}]');
        }
      } else {
        modNames.add(mod.$2);
      }
    }
    return modNames;
  }
}