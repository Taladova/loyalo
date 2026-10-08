import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class LegalScreen extends StatelessWidget {
  final String title;
  final String content;

  const LegalScreen({super.key, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(
          content.trim(),
          style: TextStyle(
            fontSize: 13.5,
            color: AppTheme.textOf(context),
            height: 1.6,
          ),
        ),
      ),
    );
  }
}
