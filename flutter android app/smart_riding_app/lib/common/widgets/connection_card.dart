import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_typography.dart';
import 'status_indicator.dart';

/// 连接状态卡片
class ConnectionCard extends StatelessWidget {
  final String deviceName;
  final String deviceId;
  final ConnectionStatus status;
  final VoidCallback? onConnect;
  final VoidCallback? onDisconnect;

  const ConnectionCard({
    super.key,
    this.deviceName = '未连接设备',
    this.deviceId = '',
    this.status = ConnectionStatus.disconnected,
    this.onConnect,
    this.onDisconnect,
  });

  String get _statusText {
    switch (status) {
      case ConnectionStatus.connected:
        return '已连接';
      case ConnectionStatus.connecting:
        return '连接中...';
      case ConnectionStatus.disconnected:
        return '未连接';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 200, maxHeight: 240),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXLarge),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 设备图标
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.electric_bike,
                size: 30,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // 设备名称
            Text(
              deviceName,
              style: AppTypography.titleLarge.copyWith(
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),

            // 状态指示
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                StatusIndicator(status: status),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  _statusText,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // 连接按钮
            _buildActionButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    switch (status) {
      case ConnectionStatus.connected:
        return SizedBox(
          width: 120,
          child: ElevatedButton.icon(
            onPressed: onDisconnect,
            icon: const Icon(Icons.bluetooth_disabled, size: 16),
            label: const Text('断开连接', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
          ),
        );
      case ConnectionStatus.connecting:
        return SizedBox(
          width: 120,
          child: ElevatedButton.icon(
            onPressed: null,
            icon: const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            label: const Text('连接中', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
          ),
        );
      case ConnectionStatus.disconnected:
        return SizedBox(
          width: 120,
          child: ElevatedButton.icon(
            onPressed: onConnect,
            icon: const Icon(Icons.bluetooth_searching, size: 16),
            label: const Text('连接车辆', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
          ),
        );
    }
  }
}
