import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../common/constants/app_colors.dart';

/// 带底部导航栏的页面容器
class ShellPage extends StatelessWidget {
  final Widget child;

  const ShellPage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.9),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: BottomNavigationBar(
                currentIndex: _calculateSelectedIndex(context),
                onTap: (index) => _onItemTapped(index, context),
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.key),
                    activeIcon: Icon(Icons.key),
                    label: '车钥匙',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.directions_bike_outlined),
                    activeIcon: Icon(Icons.directions_bike),
                    label: '骑行数据',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.bug_report_outlined),
                    activeIcon: Icon(Icons.bug_report),
                    label: '调试',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/riding')) return 1;
    if (location.startsWith('/debug')) return 2;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/riding');
        break;
      case 2:
        context.go('/debug');
        break;
    }
  }
}
