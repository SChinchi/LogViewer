import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:log_viewer/constants.dart';
import 'package:log_viewer/providers/mod_manager.dart';
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
}