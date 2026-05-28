import 'package:flutter/material.dart';
import 'package:log_viewer/providers/loading_provider.dart';
import 'package:log_viewer/screens/home_screen.dart';
import 'package:log_viewer/settings.dart';
import 'package:log_viewer/themes/themes.dart';
import 'package:provider/provider.dart';

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  Settings.init();
  runApp(MyApp(args: args));
}

class MyApp extends StatelessWidget {
  static late List<String> args;

  MyApp({super.key, args}) {
    MyApp.args = args;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: ChangeNotifierProvider(
        create: (_) => LoadingProvider(),
        builder: (context, _) => const HomeScreen(),
      ),
    );
  }
}