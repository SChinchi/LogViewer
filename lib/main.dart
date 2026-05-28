import 'package:flutter/material.dart';
import 'package:log_viewer/providers/loading_provider.dart';
import 'package:log_viewer/screens/home_screen.dart';
import 'package:log_viewer/settings.dart';
import 'package:log_viewer/themes/themes.dart';
import 'package:provider/provider.dart';

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  Settings.init();
  runApp(LogViewer(args: args));
}

class LogViewer extends StatelessWidget {
  final List<String> args;

  const LogViewer({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: ChangeNotifierProvider(
        create: (_) => LoadingProvider(),
        builder: (context, _) => HomeScreen(args: args),
      ),
    );
  }
}