import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../pages/home_page.dart';
import '../pages/riding_page.dart';
import '../pages/debug_page.dart';
import '../pages/shell_page.dart';

/// 应用路由配置
class AppRouter {
  AppRouter._();

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    routes: [
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => ShellPage(child: child),
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomePage(),
            ),
          ),
          GoRoute(
            path: '/riding',
            name: 'riding',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: RidingPage(),
            ),
          ),
          GoRoute(
            path: '/debug',
            name: 'debug',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DebugPage(),
            ),
          ),
        ],
      ),
    ],
  );
}
