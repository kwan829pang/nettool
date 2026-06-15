import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NetToolApp());
}

class NetToolApp extends StatelessWidget {
  const NetToolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NetTool',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const HomeScreen(),
    );
  }
}
