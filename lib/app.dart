import 'package:flutter/material.dart';

import 'screens/auth_gate_screen.dart';
import 'theme/app_theme.dart';

class LoyaloApp extends StatelessWidget {
  const LoyaloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Loyalo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AuthGateScreen(),
    );
  }
}
