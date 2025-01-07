import 'package:flutter/material.dart';

import '../../constants.dart';
import '../settings_screen.dart';
import 'tabs/summary_tab.dart';
import 'tabs/modlist_tab.dart';
import 'tabs/console_tab.dart';
import 'tabs/diagnostics_tabs.dart';

class ConsoleScreen extends StatefulWidget {
  const ConsoleScreen({super.key});

  @override
  State<ConsoleScreen> createState() => _ConsoleScreenState();
}

class _ConsoleScreenState extends State<ConsoleScreen> with SingleTickerProviderStateMixin {
  late TabController tabController;

  @override
  void initState() {
    tabController = TabController(length: 4, vsync: this);
    tabController.addListener(() {
      setState(() {});
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            toolbarHeight: 30,
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              PopupMenuButton<String>(
                onSelected: ((value) => {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()))
                }),
                itemBuilder: (BuildContext context) {
                  return Constants.menuOptions.map((String choice) {
                    return PopupMenuItem<String>(value: choice, child: Text(choice));
                  }).toList();
                },
              )
            ],
            bottom: TabBar(
                controller: tabController,
                labelColor: Colors.white,
                indicator: const UnderlineTabIndicator(borderSide: BorderSide(color: Colors.white, width: 2.0)),
                tabs: const [
                  Tab(text: Constants.titleTab_1),
                  Tab(text: Constants.titleTab_2),
                  Tab(text: Constants.titleTab_3),
                  Tab(text: Constants.titleTab_4),
                ]
            )
        ),
        body: TabBarView(controller: tabController, children: [
          SummaryPage(tabController: tabController),
          ModListPage(tabController: tabController),
          ConsolePage(tabController: tabController),
          DiagnosticsPage(tabController: tabController),
        ])
    );
  }
}