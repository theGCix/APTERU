import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ERUApp());
}

class ERUApp extends StatelessWidget {
  const ERUApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ERU Inventario',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const HomeScreen(),
    );
  }
}
