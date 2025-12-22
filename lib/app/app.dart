import 'package:flutter/material.dart';
import 'package:bestie/app/router.dart';
import 'package:bestie/core/theme/app_theme.dart';

class BestieApp extends StatelessWidget {
  const BestieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bestie',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: AppRouter.splash,
      routes: AppRouter.routes,
    );
  }
}
