import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'common/theme/app_theme.dart';
import 'router/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: SmartRidingApp(),
    ),
  );
}

class SmartRidingApp extends StatelessWidget {
  const SmartRidingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '智慧骑行',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: AppRouter.router,
    );
  }
}
