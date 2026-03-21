import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';

/// 连接状态类型
enum ConnectionStatus {
  connected,
  connecting,
  disconnected,
}

/// 连接状态指示器
class StatusIndicator extends StatefulWidget {
  final ConnectionStatus status;
  final double size;

  const StatusIndicator({
    super.key,
    required this.status,
    this.size = AppSpacing.statusIndicatorSize,
  });

  @override
  State<StatusIndicator> createState() => _StatusIndicatorState();
}

class _StatusIndicatorState extends State<StatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.status == ConnectionStatus.connected ||
        widget.status == ConnectionStatus.connecting) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(StatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status != oldWidget.status) {
      if (widget.status == ConnectionStatus.connected ||
          widget.status == ConnectionStatus.connecting) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _color {
    switch (widget.status) {
      case ConnectionStatus.connected:
        return AppColors.connected;
      case ConnectionStatus.connecting:
        return AppColors.connecting;
      case ConnectionStatus.disconnected:
        return AppColors.disconnected;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _color.withValues(
              alpha: widget.status == ConnectionStatus.connected
                  ? _animation.value
                  : 1.0,
            ),
            boxShadow: widget.status == ConnectionStatus.connected
                ? [
                    BoxShadow(
                      color: _color.withValues(alpha: 0.5 * _animation.value),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
        );
      },
    );
  }
}
