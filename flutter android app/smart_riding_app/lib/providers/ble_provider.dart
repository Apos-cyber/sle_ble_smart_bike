import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ble_service.dart';

/// BLE 连接状态
enum BleConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  error,
}

/// BLE 状态
class BleState {
  final BleConnectionState connectionState;
  final String? deviceName;
  final String? deviceId;
  final String? serviceUuid;
  final String? characteristicUuid;
  final List<BleDevice> foundDevices;
  final String? errorMessage;
  final String? lastResponse;
  final List<CustomButton> customButtons;

  const BleState({
    this.connectionState = BleConnectionState.disconnected,
    this.deviceName,
    this.deviceId,
    this.serviceUuid,
    this.characteristicUuid,
    this.foundDevices = const [],
    this.errorMessage,
    this.lastResponse,
    this.customButtons = const [],
  });

  BleState copyWith({
    BleConnectionState? connectionState,
    String? deviceName,
    String? deviceId,
    String? serviceUuid,
    String? characteristicUuid,
    List<BleDevice>? foundDevices,
    String? errorMessage,
    String? lastResponse,
    List<CustomButton>? customButtons,
  }) {
    return BleState(
      connectionState: connectionState ?? this.connectionState,
      deviceName: deviceName ?? this.deviceName,
      deviceId: deviceId ?? this.deviceId,
      serviceUuid: serviceUuid ?? this.serviceUuid,
      characteristicUuid: characteristicUuid ?? this.characteristicUuid,
      foundDevices: foundDevices ?? this.foundDevices,
      errorMessage: errorMessage,
      lastResponse: lastResponse,
      customButtons: customButtons ?? this.customButtons,
    );
  }
}

/// BLE Provider
class BleNotifier extends StateNotifier<BleState> {
  final BleService _bleService;
  final BleConfigStorage _configStorage;
  BleConfig _config;
  StreamSubscription? _scanSubscription;

  BleNotifier(this._bleService, this._configStorage)
      : _config = BleConfig(),
        super(const BleState()) {
    _init();
  }

  BleConfig get config => _config;

  Future<void> _init() async {
    _config = await _configStorage.load();
    // 加载自定义按钮到状态
    state = state.copyWith(customButtons: _config.customButtons);
  }

  /// 更新自定义按钮
  Future<void> updateCustomButtons(List<CustomButton> buttons) async {
    _config = _config.copyWith(customButtons: buttons);
    await _configStorage.save(_config);
    state = state.copyWith(customButtons: buttons);
  }

  /// 开始扫描设备
  Future<void> startScan() async {
    if (state.connectionState == BleConnectionState.scanning) return;

    // 检查蓝牙是否开启
    final hasPermission = await _bleService.checkAndRequestPermissions();
    if (!hasPermission) {
      state = state.copyWith(
        connectionState: BleConnectionState.error,
        errorMessage: '请确保蓝牙已开启，并授予相关权限',
      );
      return;
    }

    state = state.copyWith(
      connectionState: BleConnectionState.scanning,
      foundDevices: [],
      errorMessage: null,
    );

    _scanSubscription?.cancel();
    _scanSubscription = _bleService.scanDevices().listen(
      (devices) {
        if (mounted) {
          state = state.copyWith(foundDevices: devices);
        }
      },
      onError: (e) {
        if (mounted) {
          state = state.copyWith(
            connectionState: BleConnectionState.error,
            errorMessage: e.toString(),
          );
        }
      },
    );
  }

  /// 停止扫描
  Future<void> stopScan() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await _bleService.stopScan();

    if (state.connectionState == BleConnectionState.scanning) {
      state = state.copyWith(connectionState: BleConnectionState.disconnected);
    }
  }

  /// 连接设备
  Future<bool> connect(BleDevice device) async {
    state = state.copyWith(
      connectionState: BleConnectionState.connecting,
      deviceName: device.name,
      deviceId: device.id,
      errorMessage: null,
    );

    // 停止扫描
    await stopScan();

    try {
      print('[Provider] 开始连接设备: ${device.name}');
      await _bleService.connect(device, _config);
      print('[Provider] 连接成功!');

      // 保存最后连接的设备
      _config = _config.copyWith(
        lastDeviceId: device.id,
        lastDeviceName: device.name,
      );
      await _configStorage.save(_config);

      // 获取 UUID
      final serviceUuid = _bleService.currentServiceUuid;
      final characteristicUuid = _bleService.currentCharacteristicUuid;
      print('[Provider] Service UUID: $serviceUuid, Characteristic UUID: $characteristicUuid');

      state = state.copyWith(
        connectionState: BleConnectionState.connected,
        serviceUuid: serviceUuid,
        characteristicUuid: characteristicUuid,
      );
      print('[Provider] 状态已更新为 connected');
      return true;
    } catch (e, stack) {
      print('[Provider] 连接失败: $e');
      print('[Provider] 堆栈: $stack');
      state = state.copyWith(
        connectionState: BleConnectionState.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    await _bleService.disconnect();
    state = state.copyWith(
      connectionState: BleConnectionState.disconnected,
      deviceName: null,
      deviceId: null,
      lastResponse: null,
    );
  }

  /// 发送指令
  Future<String?> sendCommand(String hexCommand) async {
    if (state.connectionState != BleConnectionState.connected) {
      return null;
    }

    try {
      final response = await _bleService.sendCommand(hexCommand);
      final responseHex = response.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      state = state.copyWith(lastResponse: responseHex);
      return responseHex;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return null;
    }
  }

  /// 更新配置
  Future<void> updateConfig(BleConfig newConfig) async {
    _config = newConfig;
    await _configStorage.save(_config);
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _bleService.dispose();
    super.dispose();
  }
}

/// BLE 服务 Provider
final bleServiceProvider = Provider<BleService>((ref) {
  final service = BleService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// BLE 配置存储 Provider
final bleConfigStorageProvider = Provider<BleConfigStorage>((ref) {
  return BleConfigStorage();
});

/// BLE 状态 Provider
final bleProvider = StateNotifierProvider<BleNotifier, BleState>((ref) {
  final bleService = ref.watch(bleServiceProvider);
  final configStorage = ref.watch(bleConfigStorageProvider);
  return BleNotifier(bleService, configStorage);
});
