import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../common/constants/app_colors.dart';
import '../common/constants/app_spacing.dart';
import '../common/constants/app_typography.dart';
import '../common/widgets/widgets.dart';
import '../providers/ble_provider.dart';
import '../common/widgets/device_selection_dialog.dart';
import '../services/ble_service.dart' show CustomButton;

/// 首页 - 车钥匙页面
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {

  @override
  Widget build(BuildContext context) {
    final bleState = ref.watch(bleProvider);

    // 将 BLE 状态转换为 UI 状态
    final connectionStatus = _mapBleState(bleState.connectionState);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('智慧骑行'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 连接状态卡片
              ConnectionCard(
                deviceName: bleState.deviceName ?? '智慧骑行',
                deviceId: bleState.deviceId ?? '',
                status: connectionStatus,
                onConnect: _onConnect,
                onDisconnect: _onDisconnect,
              ),
              const SizedBox(height: AppSpacing.lg),

              // 控制面板标题
              Text(
                '控制面板',
                style: AppTypography.titleLarge,
              ),
              // 未连接时的提示
              if (bleState.connectionState != BleConnectionState.connected) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '请先连接设备以使用控制功能',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),

              // 控制按钮 - 从自定义按钮配置生成（车灯除外，车灯需要弹窗）
              _buildControlCards(bleState.connectionState, bleState.customButtons, (buttonId) {
                if (buttonId == '3') {
                  // 车灯按钮 - 弹出亮度调节
                  _showLightDialog();
                } else {
                  _sendCommand(buttonId);
                }
              }),
              const SizedBox(height: AppSpacing.lg),

              // 错误提示
              if (bleState.errorMessage != null) _buildError(bleState.errorMessage!),
            ],
          ),
        ),
      ),
    );
  }

  ConnectionStatus _mapBleState(BleConnectionState state) {
    switch (state) {
      case BleConnectionState.connected:
        return ConnectionStatus.connected;
      case BleConnectionState.connecting:
        return ConnectionStatus.connecting;
      default:
        return ConnectionStatus.disconnected;
    }
  }

  /// 从自定义按钮构建控制卡片
  Widget _buildControlCards(BleConnectionState connectionState, List<CustomButton> buttons, Function(String) onButtonPressed) {
    final isConnected = connectionState == BleConnectionState.connected;

    // 如果没有配置按钮，显示提示
    if (buttons.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        ),
        child: Text(
          '请在调试页面配置控制按钮',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textHint,
          ),
        ),
      );
    }

    // 过滤掉鸣笛按钮 (id = '4')
    final filteredButtons = buttons.where((b) => b.id != '4').toList();

    // 颜色列表
    final colors = [Colors.green, Colors.red, Colors.orange, Colors.blue, Colors.purple];
    final icons = {
      'lock_open': Icons.lock_open,
      'lock': Icons.lock,
      'highlight': Icons.highlight,
      'volume_up': Icons.volume_up,
      'location_on': Icons.location_on,
    };

    return Column(
      children: [
        // 每行显示2个按钮
        for (var i = 0; i < filteredButtons.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              children: [
                for (var j = i; j < i + 2 && j < filteredButtons.length; j++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: j < i + 1 && j < filteredButtons.length - 1 ? AppSpacing.md : 0),
                      child: _BigActionButton(
                        icon: icons[filteredButtons[j].icon] ?? Icons.power,
                        label: filteredButtons[j].name,
                        color: colors[j % colors.length],
                        isEnabled: isConnected,
                        onPressed: () => onButtonPressed(filteredButtons[j].id),
                      ),
                    ),
                  ),
                if (i + 1 >= filteredButtons.length)
                  const Expanded(child: SizedBox()),
              ],
            ),
          ),
      ],
    );
  }

  /// 显示车灯亮度调节弹窗
  void _showLightDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _LightControlSheet(
        onBrightnessChanged: (value) {
          // value: 0 = 关, 1-255 = 亮度
          final hexValue = value.toRadixString(16).padLeft(2, '0').toUpperCase();
          final command = 'AA 05 $hexValue 00 DD';
          ref.read(bleProvider.notifier).sendCommand(command);
        },
      ),
    );
  }

  Widget _buildError(String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 16),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              error,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: () => ref.read(bleProvider.notifier).clearError(),
            color: AppColors.error,
          ),
        ],
      ),
    );
  }

  void _onConnect() async {
    final success = await showDeviceSelectionDialog(context);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('连接失败'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _onDisconnect() async {
    await ref.read(bleProvider.notifier).disconnect();
  }

  void _sendCommand(String buttonId) async {
    final bleState = ref.read(bleProvider);
    final button = bleState.customButtons.firstWhere(
      (b) => b.id == buttonId,
      orElse: () => throw Exception('未找到按钮'),
    );

    await ref.read(bleProvider.notifier).sendCommand(button.command);
  }

}

/// 大按钮卡片组件
class _BigActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isEnabled;
  final VoidCallback? onPressed;

  const _BigActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.isEnabled,
    this.onPressed,
  });

  @override
  State<_BigActionButton> createState() => _BigActionButtonState();
}

class _BigActionButtonState extends State<_BigActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.isEnabled ? widget.color : AppColors.textHint;

    return GestureDetector(
      onTapDown: widget.isEnabled ? (_) => _controller.forward() : null,
      onTapUp: widget.isEnabled ? (_) => _controller.reverse() : null,
      onTapCancel: widget.isEnabled ? () => _controller.reverse() : null,
      onTap: widget.isEnabled ? widget.onPressed : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            gradient: widget.isEnabled
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.color,
                      widget.color.withValues(alpha: 0.8),
                    ],
                  )
                : null,
            color: widget.isEnabled ? null : AppColors.background,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
            border: Border.all(
              color: widget.isEnabled ? Colors.transparent : AppColors.textHint.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: widget.isEnabled
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                size: 36,
                color: widget.isEnabled
                    ? Colors.white
                    : AppColors.textHint.withValues(alpha: 0.5),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                widget.label,
                style: AppTypography.titleMedium.copyWith(
                  color: widget.isEnabled
                      ? Colors.white
                      : AppColors.textHint.withValues(alpha: 0.5),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 车灯开关按钮
class _LightSwitchButton extends StatelessWidget {
  final bool isEnabled;
  final bool isOn;
  final VoidCallback? onPressed;

  const _LightSwitchButton({
    required this.isEnabled,
    required this.isOn,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEnabled ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 60,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isOn
              ? AppColors.primary
              : AppColors.textHint.withValues(alpha: 0.3),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(2),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              isOn ? Icons.check : Icons.close,
              size: 16,
              color: isOn ? AppColors.primary : AppColors.textHint,
            ),
          ),
        ),
      ),
    );
  }
}

/// 车灯亮度控制弹窗
class _LightControlSheet extends StatefulWidget {
  final Function(int) onBrightnessChanged;

  const _LightControlSheet({required this.onBrightnessChanged});

  @override
  State<_LightControlSheet> createState() => _LightControlSheetState();
}

class _LightControlSheetState extends State<_LightControlSheet> {
  double _brightness = 0; // 0 = 关, >0 = 亮

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('车灯亮度', style: AppTypography.titleLarge),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // 开关按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('开关', style: AppTypography.bodyMedium),
              Switch(
                value: _brightness > 0,
                onChanged: (value) {
                  setState(() {
                    _brightness = value ? 128 : 0;
                  });
                  widget.onBrightnessChanged(_brightness.toInt());
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // 亮度滑块
          Text('亮度: ${_brightness.toInt()}', style: AppTypography.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          Slider(
            value: _brightness.clamp(1, 255),
            min: 1,
            max: 255,
            divisions: 254,
            onChanged: (value) {
              setState(() {
                _brightness = value;
              });
            },
            onChangeEnd: (value) {
              widget.onBrightnessChanged(value.toInt());
            },
          ),

          // 快捷按钮
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _QuickButton(label: '关', value: 0, onTap: () {
                setState(() => _brightness = 0);
                widget.onBrightnessChanged(0);
              }),
              _QuickButton(label: '25%', value: 64, onTap: () {
                setState(() => _brightness = 64);
                widget.onBrightnessChanged(64);
              }),
              _QuickButton(label: '50%', value: 128, onTap: () {
                setState(() => _brightness = 128);
                widget.onBrightnessChanged(128);
              }),
              _QuickButton(label: '75%', value: 191, onTap: () {
                setState(() => _brightness = 191);
                widget.onBrightnessChanged(191);
              }),
              _QuickButton(label: '100%', value: 255, onTap: () {
                setState(() => _brightness = 255);
                widget.onBrightnessChanged(255);
              }),
            ],
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + AppSpacing.md),
        ],
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback onTap;

  const _QuickButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primary),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(color: AppColors.primary)),
      ),
    );
  }
}
