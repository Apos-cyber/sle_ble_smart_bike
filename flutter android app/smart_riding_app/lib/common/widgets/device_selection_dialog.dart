import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/ble_service.dart';
import '../../providers/ble_provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_typography.dart';

/// 设备选择对话框
class DeviceSelectionDialog extends ConsumerStatefulWidget {
  const DeviceSelectionDialog({super.key});

  @override
  ConsumerState<DeviceSelectionDialog> createState() => _DeviceSelectionDialogState();
}

class _DeviceSelectionDialogState extends ConsumerState<DeviceSelectionDialog> {
  @override
  void initState() {
    super.initState();
    // 开始扫描
    Future.microtask(() {
      ref.read(bleProvider.notifier).startScan();
    });
  }

  @override
  void dispose() {
    // 对话框关闭时停止扫描
    Future.microtask(() {
      if (mounted) {
        ref.read(bleProvider.notifier).stopScan();
      }
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bleState = ref.watch(bleProvider);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
      ),
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxHeight: 500),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '选择设备',
                  style: AppTypography.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // 扫描状态
            _buildScanStatus(bleState),
            const SizedBox(height: AppSpacing.md),

            // 设备列表
            Flexible(
              child: _buildDeviceList(bleState),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanStatus(BleState bleState) {
    if (bleState.connectionState == BleConnectionState.scanning) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              '正在扫描设备...',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      );
    }

    if (bleState.foundDevices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.bluetooth_searching,
              color: AppColors.textHint,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                '未发现设备，请确保车辆蓝牙已开启',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textHint,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle,
            color: Colors.green,
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            '发现 ${bleState.foundDevices.length} 个设备',
            style: AppTypography.bodyMedium.copyWith(
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList(BleState bleState) {
    if (bleState.foundDevices.isEmpty && bleState.connectionState != BleConnectionState.scanning) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.bluetooth_disabled,
              size: 48,
              color: AppColors.textHint,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '未发现设备',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton.icon(
              onPressed: () {
                ref.read(bleProvider.notifier).startScan();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('重新扫描'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: bleState.foundDevices.length,
      itemBuilder: (context, index) {
        final device = bleState.foundDevices[index];
        return _buildDeviceItem(device, bleState.connectionState == BleConnectionState.connecting);
      },
    );
  }

  Widget _buildDeviceItem(BleDevice device, bool isConnecting) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        onTap: isConnecting
            ? null
            : () async {
                final success = await ref.read(bleProvider.notifier).connect(device);
                if (mounted) {
                  Navigator.of(context).pop(success);
                }
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 4,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name.isNotEmpty ? device.name : '未知设备',
                      style: AppTypography.titleMedium,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      device.id,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textHint,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (isConnecting)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                )
              else
                _buildSignalIcon(device.rssi),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignalIcon(int rssi) {
    IconData icon;
    Color color;

    if (rssi > -50) {
      icon = Icons.signal_wifi_4_bar;
      color = Colors.green;
    } else if (rssi > -70) {
      icon = Icons.network_wifi_3_bar;
      color = Colors.lightGreen;
    } else if (rssi > -80) {
      icon = Icons.network_wifi_2_bar;
      color = Colors.orange;
    } else {
      icon = Icons.network_wifi_1_bar;
      color = Colors.red;
    }

    return Icon(icon, color: color, size: 16);
  }
}

/// 显示设备选择对话框
Future<bool> showDeviceSelectionDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const DeviceSelectionDialog(),
  );
  return result ?? false;
}
