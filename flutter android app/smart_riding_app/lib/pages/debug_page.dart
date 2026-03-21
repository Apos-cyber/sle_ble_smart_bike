import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../common/constants/app_colors.dart';
import '../common/constants/app_spacing.dart';
import '../common/constants/app_typography.dart';
import '../common/widgets/primary_button.dart';
import '../providers/ble_provider.dart';
import '../services/ble_service.dart' show CustomButton;

/// 调试页面
class DebugPage extends ConsumerStatefulWidget {
  const DebugPage({super.key});

  @override
  ConsumerState<DebugPage> createState() => _DebugPageState();
}

class _DebugPageState extends ConsumerState<DebugPage> {
  final _commandController = TextEditingController();

  String _lastResponse = '';
  bool _isSending = false;

  // 默认控制按钮列表
  List<Map<String, dynamic>> _customButtons = [
    {'id': '1', 'icon': 'lock_open', 'name': '解锁', 'command': 'AA 01 01 00 DD'},
    {'id': '2', 'icon': 'lock', 'name': '上锁', 'command': 'AA 01 02 00 DD'},
    {'id': '3', 'icon': 'highlight', 'name': '车灯', 'command': 'AA 02 01 00 DD'},
    {'id': '5', 'icon': 'location_on', 'name': '寻车', 'command': 'AA 04 01 00 DD'},
  ];

  @override
  void initState() {
    super.initState();
    // 从 provider 加载自定义按钮
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bleState = ref.read(bleProvider);
      if (bleState.customButtons.isNotEmpty) {
        setState(() {
          _customButtons = bleState.customButtons
              .map((b) => {
                    'id': b.id,
                    'name': b.name,
                    'command': b.command,
                    'icon': b.icon,
                  })
              .toList();
        });
      }
    });
  }

  @override
  void dispose() {
    _commandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bleState = ref.watch(bleProvider);
    final isConnected = bleState.connectionState == BleConnectionState.connected;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('BLE调试'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveConfig,
            tooltip: '保存',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 连接状态提示
              _buildConnectionStatus(bleState),
              const SizedBox(height: AppSpacing.lg),

              // 控制按钮管理
              _buildButtonManagementSection(),
              const SizedBox(height: AppSpacing.lg),

              // 指令发送测试
              _buildCommandTestSection(isConnected),

              // 底部安全边距
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionStatus(BleState bleState) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (bleState.connectionState) {
      case BleConnectionState.connected:
        statusColor = Colors.green;
        statusText = '已连接: ${bleState.deviceName ?? "未知设备"}';
        statusIcon = Icons.bluetooth_connected;
        break;
      case BleConnectionState.connecting:
        statusColor = Colors.orange;
        statusText = '连接中...';
        statusIcon = Icons.bluetooth_searching;
        break;
      case BleConnectionState.error:
        statusColor = Colors.red;
        statusText = '连接失败: ${bleState.errorMessage ?? "未知错误"}';
        statusIcon = Icons.error;
        break;
      case BleConnectionState.disconnected:
        statusColor = Colors.grey;
        statusText = '未连接';
        statusIcon = Icons.bluetooth_disabled;
        break;
      case BleConnectionState.scanning:
        statusColor = Colors.blue;
        statusText = '扫描中...';
        statusIcon = Icons.bluetooth_searching;
        break;
    }

    // 如果已连接，显示 UUID
    String? uuidInfo;
    if (bleState.connectionState == BleConnectionState.connected &&
        bleState.serviceUuid != null &&
        bleState.characteristicUuid != null) {
      uuidInfo = 'Service: ${bleState.serviceUuid}\nCharacteristic: ${bleState.characteristicUuid}';
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  statusText,
                  style: AppTypography.bodyMedium.copyWith(color: statusColor),
                ),
              ),
            ],
          ),
          if (uuidInfo != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              uuidInfo,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildButtonManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '控制按钮管理',
              style: AppTypography.titleLarge,
            ),
            TextButton.icon(
              onPressed: _addButton,
              icon: const Icon(Icons.add),
              label: const Text('添加按钮'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: ReorderableListView.builder(
            shrinkWrap: true,
            itemCount: _customButtons.length,
            onReorder: _reorderButtons,
            itemBuilder: (context, index) {
              final button = _customButtons[index];
              return Container(
                key: ValueKey('$index-${button['name']}'),
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      _getIconFromString(button['icon'] ?? 'power'),
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            button['name'] as String,
                            style: AppTypography.titleMedium,
                          ),
                          Text(
                            button['command'] as String,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textHint,
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: () => _editButton(index),
                      color: AppColors.textSecondary,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 18),
                      onPressed: () => _deleteButton(index),
                      color: AppColors.error,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                    const Icon(
                      Icons.drag_handle,
                      color: AppColors.textHint,
                      size: 18,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCommandTestSection(bool isConnected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '指令发送测试',
          style: AppTypography.titleLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '指令',
                style: AppTypography.labelLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _commandController,
                decoration: const InputDecoration(
                  hintText: '输入指令，如: AA 01 01 00 DD 或 Hello',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                text: '发送指令',
                isLoading: _isSending,
                onPressed: isConnected ? _sendTestCommand : null,
              ),
              if (!isConnected) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '请先连接设备',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ],
              if (_lastResponse.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  '响应:',
                  style: AppTypography.labelLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  ),
                  child: Text(
                    _lastResponse,
                    style: AppTypography.bodyMedium.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _saveConfig() async {
    // 转换 Map 为 CustomButton
    final buttons = _customButtons.map((m) => CustomButton(
          id: m['id'] ?? DateTime.now().toString(),
          name: m['name'] ?? '',
          command: m['command'] ?? '',
          icon: m['icon'] ?? 'power',
        )).toList();

    await ref.read(bleProvider.notifier).updateCustomButtons(buttons);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('配置已保存'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _addButton() {
    _showButtonEditDialog(null, -1);
  }

  void _editButton(int index) {
    _showButtonEditDialog(_customButtons[index], index);
  }

  /// 将字符串转换为 IconData
  IconData _getIconFromString(String iconName) {
    final icons = {
      'lock_open': Icons.lock_open,
      'lock': Icons.lock,
      'highlight': Icons.highlight,
      'volume_up': Icons.volume_up,
      'location_on': Icons.location_on,
      'power': Icons.power,
      'settings_remote': Icons.settings_remote,
    };
    return icons[iconName] ?? Icons.power;
  }

  void _deleteButton(int index) {
    setState(() {
      _customButtons.removeAt(index);
    });
  }

  void _reorderButtons(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _customButtons.removeAt(oldIndex);
      _customButtons.insert(newIndex, item);
    });
  }

  void _showButtonEditDialog(Map<String, dynamic>? button, int index) {
    final nameController = TextEditingController(text: button?['name'] ?? '');
    final commandController = TextEditingController(text: button?['command'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(button == null ? '添加按钮' : '编辑按钮'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '按钮名称',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: commandController,
              decoration: const InputDecoration(
                labelText: '指令',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newButton = {
                'icon': 'settings_remote',
                'name': nameController.text,
                'command': commandController.text,
              };
              setState(() {
                if (button == null) {
                  _customButtons.add(newButton);
                } else {
                  _customButtons[index] = newButton;
                }
              });
              Navigator.pop(context);
              // 自动保存到 provider
              _saveConfig();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _sendTestCommand() async {
    if (_commandController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入指令')),
      );
      return;
    }

    setState(() {
      _isSending = true;
      _lastResponse = '';
    });

    final response = await ref.read(bleProvider.notifier).sendCommand(_commandController.text);

    setState(() {
      _isSending = false;
      _lastResponse = response ?? '发送失败';
    });
  }
}
