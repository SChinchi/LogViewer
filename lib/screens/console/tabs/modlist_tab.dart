import 'package:flutter/material.dart';

import 'package:log_viewer/log_parser.dart';

class ModListPage extends StatelessWidget {
  final TabController tabController;

  const ModListPage({super.key, required this.tabController});

  @override
  Widget build(BuildContext context) {
    return const FutureBuilderExampleApp();
  }
}

class FutureBuilderExampleApp extends StatelessWidget {
  const FutureBuilderExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
      return const FutureBuilderExample();
  }
}

class FutureBuilderExample extends StatefulWidget {
  const FutureBuilderExample({super.key});

  @override
  State<FutureBuilderExample> createState() => _HomePageState();
}

class _HomePageState extends State<FutureBuilderExample> {

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: Logger.modStatusNetRequest,
        builder: (context, snapshot) {
          var modList = Container(
              color: Colors.black,
              child: ListView.builder(
                itemCount: Logger.mods.length,
                itemBuilder: (context, index) {
                  var mod = Logger.mods[index];
                  return SelectableText(
                    mod.guid,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                        color: mod.isDeprecated ? Colors.red : (!mod.isLatest ? Colors.yellow : Colors.white)),
                  );
                },
              ));
          if (snapshot.connectionState == ConnectionState.done) {
            return modList;
          }
          return Stack(children: [modList, const Center(child: CircularProgressIndicator())]);
        }
    );
  }
}