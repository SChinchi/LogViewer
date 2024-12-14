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
    getData();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: getData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
                color: Colors.black,
                alignment: Alignment.center,
                child: const CircularProgressIndicator()
            );
          }
          return Container(
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
        }
    );
  }

  Future<void> getData() async {
    if (Logger.mods.every((m) => m.loaded)) {
      return;
    }
    /*
    for (var mod in Logger.mods) {
      print(mod.guid);
      if (!mod.loaded) {
        var data = mod.guid.split('-');
        var response = await http
            .get(Uri.parse(
            'https://thunderstore.io/api/experimental/package/${data[0]}/${data[1]}/'));
        if (response.statusCode == 200) {
          var modData = jsonDecode(response.body) as Map<String, dynamic>;
          mod.isDeprecated = modData['is_deprecated'];
          mod.isLatest = data[2] == modData['latest']['version_number'];
        }
        else {
          print('We got to an issue: (${data[0]}, ${data[1]}) ${response.statusCode}');
        }
        mod.loaded = true;
      }
    }
     */
    setState(() {});
  }
}