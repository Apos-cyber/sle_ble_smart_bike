import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

/// BLE 设备信息
class BleDevice {
  final String id;
  final String name;
  final int rssi;
  final BluetoothDevice device;

  BleDevice({
    required this.id,
    required this.name,
    required this.rssi,
    required this.device,
  });
}

/// 自定义按钮配置
class CustomButton {
  final String id;
  final String name;
  final String command;
  final String icon;

  const CustomButton({
    required this.id,
    required this.name,
    required this.command,
    required this.icon,
  });

  CustomButton copyWith({String? name, String? command, String? icon}) {
    return CustomButton(
      id: id,
      name: name ?? this.name,
      command: command ?? this.command,
      icon: icon ?? this.icon,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'command': command,
        'icon': icon,
      };

  factory CustomButton.fromJson(Map<String, dynamic> json) => CustomButton(
        id: json['id'],
        name: json['name'],
        command: json['command'],
        icon: json['icon'],
      );

  // 默认按钮
  static List<CustomButton> get defaultButtons => const [
        CustomButton(id: '1', name: '解锁', command: 'AA 01 01 00 DD', icon: 'lock_open'),
        CustomButton(id: '2', name: '上锁', command: 'AA 01 02 00 DD', icon: 'lock'),
        CustomButton(id: '3', name: '车灯', command: 'AA 02 01 00 DD', icon: 'highlight'),
        CustomButton(id: '4', name: '鸣笛', command: 'AA 03 01 00 DD', icon: 'volume_up'),
        CustomButton(id: '5', name: '寻车', command: 'AA 04 01 00 DD', icon: 'location_on'),
      ];
}

/// BLE 配置
class BleConfig {
  final String serviceUuid;
  final String characteristicUuid;
  final String? lastDeviceId;
  final String? lastDeviceName;
  final List<CustomButton> customButtons;

  BleConfig({
    this.serviceUuid = 'abcd',
    this.characteristicUuid = 'efef',
    this.lastDeviceId,
    this.lastDeviceName,
    this.customButtons = const [],
  });

  BleConfig copyWith({
    String? serviceUuid,
    String? characteristicUuid,
    String? lastDeviceId,
    String? lastDeviceName,
    List<CustomButton>? customButtons,
  }) {
    return BleConfig(
      serviceUuid: serviceUuid ?? this.serviceUuid,
      characteristicUuid: characteristicUuid ?? this.characteristicUuid,
      lastDeviceId: lastDeviceId ?? this.lastDeviceId,
      lastDeviceName: lastDeviceName ?? this.lastDeviceName,
      customButtons: customButtons ?? this.customButtons,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'serviceUuid': serviceUuid,
      'characteristicUuid': characteristicUuid,
      'lastDeviceId': lastDeviceId,
      'lastDeviceName': lastDeviceName,
      'customButtons': customButtons.map((b) => b.toJson()).toList(),
    };
  }

  factory BleConfig.fromJson(Map<String, dynamic> json) {
    final buttons = (json['customButtons'] as List<dynamic>?)
            ?.map((b) => CustomButton.fromJson(b))
            .toList() ??
        [];

    return BleConfig(
      serviceUuid: json['serviceUuid'] ?? 'abcd',
      characteristicUuid: json['characteristicUuid'] ?? 'efef',
      lastDeviceId: json['lastDeviceId'],
      lastDeviceName: json['lastDeviceName'],
      customButtons: buttons.isEmpty ? CustomButton.defaultButtons : buttons,
    );
  }
}

/// BLE 服务异常
class BleException implements Exception {
  final String message;
  final int? code;

  BleException(this.message, {this.code});

  @override
  String toString() => 'BleException: $message (code: $code)';
}

/// BLE 服务
class BleService {
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writeCharacteristic;
  bool _writeWithoutResponse = false; // 标记特征是否支持 writeWithoutResponse
  String? _currentServiceUuid;
  String? _currentCharacteristicUuid;
  BluetoothCharacteristic? _notifyCharacteristic;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _stateSubscription;
  StreamController<List<BleDevice>>? _scanController;
  Completer<BluetoothDevice>? _connectionCompleter;

  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isConnected => _connectedDevice != null;

  /// 获取当前连接的 Service UUID
  String? get currentServiceUuid => _currentServiceUuid;

  /// 获取当前连接的 Characteristic UUID
  String? get currentCharacteristicUuid => _currentCharacteristicUuid;

  /// 检查并请求蓝牙权限
  Future<bool> checkAndRequestPermissions() async {
    // 检查蓝牙适配器状态
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      return false;
    }

    // Android 12+ 需要 BLUETOOTH_SCAN 和 BLUETOOTH_CONNECT 权限
    // Android 11 及以下需要 BLUETOOTH, BLUETOOTH_ADMIN, ACCESS_FINE_LOCATION
    final bluetoothScan = await Permission.bluetoothScan.request();
    final bluetoothConnect = await Permission.bluetoothConnect.request();
    final location = await Permission.locationWhenInUse.request();

    // 检查权限状态
    if (bluetoothScan.isDenied || bluetoothConnect.isDenied || location.isDenied) {
      // 如果仍然被拒绝，至少尝试定位权限
      if (location.isPermanentlyDenied) {
        // 可以引导用户去设置页面
        await openAppSettings();
      }
      return false;
    }

    return true;
  }

  /// 扫描设备
  Stream<List<BleDevice>> scanDevices({Duration timeout = const Duration(seconds: 10)}) {
    _scanController?.close();
    _scanController = StreamController<List<BleDevice>>();

    final foundDevices = <String, BleDevice>{};

    _scanSubscription = FlutterBluePlus.scanResults.listen(
      (results) {
        for (var result in results) {
          final device = BleDevice(
            id: result.device.remoteId.str,
            name: result.device.platformName.isNotEmpty
                ? result.device.platformName
                : '未知设备',
            rssi: result.rssi,
            device: result.device,
          );
          foundDevices[device.id] = device;
        }
        _scanController?.add(foundDevices.values.toList()
          ..sort((a, b) => b.rssi.compareTo(a.rssi)));
      },
      onError: (e) {
        _scanController?.addError(e);
      },
    );

    FlutterBluePlus.startScan(timeout: timeout).catchError((e) {
      _scanController?.addError(e);
    });

    return _scanController!.stream;
  }

  /// 停止扫描
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  /// 连接设备 - 最佳实践
  Future<BluetoothDevice> connect(BleDevice device, BleConfig config) async {
    // 停止扫描
    await stopScan();

    // 断开已有连接
    if (_connectedDevice != null) {
      await disconnect();
    }

    try {
      // 方法1: 先连接，然后等待连接状态
      print('开始连接设备...');
      await device.device.connect(timeout: const Duration(seconds: 15));
      print('connect() 调用完成');

      // 等待连接状态变为 connected
      print('等待连接状态...');
      await device.device.connectionState
          .firstWhere((state) => state == BluetoothConnectionState.connected);
      print('已连接到设备');

      // 记录连接
      _connectedDevice = device.device;

      // 监听断开状态（用于后续处理断开）
      _connectionSubscription = device.device.connectionState.listen((state) {
        print('BLE 状态变化: $state');
        if (state == BluetoothConnectionState.disconnected) {
          _connectedDevice = null;
          _writeCharacteristic = null;
          _notifyCharacteristic = null;
        }
      });

      // 发现服务
      await _discoverServices(device.device, config);

      print('连接成功!');
      return device.device;
    } catch (e) {
      print('连接失败: $e');
      rethrow;
    }
  }

  /// 发现服务和特征
  Future<void> _discoverServices(BluetoothDevice device, BleConfig config) async {
    final services = await device.discoverServices();

    print('========== BLE 服务发现 ==========');
    print('期望 Service UUID: ${config.serviceUuid}');
    print('期望 Characteristic UUID: ${config.characteristicUuid}');
    print('');

    for (var service in services) {
      print('Service: ${service.uuid.str}');
      for (var char in service.characteristics) {
        print('  Characteristic: ${char.uuid.str}');
        print('    properties: write=${char.properties.write}, writeWithoutResponse=${char.properties.writeWithoutResponse}, notify=${char.properties.notify}');
      }
    }
    print('');

    // 转换为短格式进行匹配 (如 0000abcd-... -> abcd)
    String toShortUuid(String uuid) {
      final upper = uuid.toUpperCase().replaceAll('-', '');
      if (upper.startsWith('0000') && upper.length == 36) {
        return upper.substring(4, 8);
      }
      return uuid;
    }

    for (var service in services) {
      final serviceShort = toShortUuid(service.uuid.str);
      final configServiceShort = toShortUuid(config.serviceUuid);

      print('匹配: $serviceShort vs $configServiceShort');

      if (serviceShort == configServiceShort || service.uuid.str.toUpperCase() == config.serviceUuid.toUpperCase()) {
        for (var char in service.characteristics) {
          final charShort = toShortUuid(char.uuid.str);
          final configCharShort = toShortUuid(config.characteristicUuid);

          if (charShort == configCharShort || char.uuid.str.toUpperCase() == config.characteristicUuid.toUpperCase()) {
            // 检查属性 - 同时支持 write 和 writeWithoutResponse
            if (char.properties.write || char.properties.writeWithoutResponse) {
              _writeCharacteristic = char;
              _writeWithoutResponse = char.properties.writeWithoutResponse;
              // 转换为短 UUID 格式 (如 0xABCD)
              _currentServiceUuid = '0x${service.uuid.str.toUpperCase().replaceAll('-', '').substring(0, 4)}';
              _currentCharacteristicUuid = '0x${char.uuid.str.toUpperCase().replaceAll('-', '').substring(0, 4)}';
              print('✓ 找到可写特征: ${char.uuid.str} (write=${char.properties.write}, writeWithoutResponse=${char.properties.writeWithoutResponse})');
              print('✓ 短 UUID: Service=$_currentServiceUuid, Characteristic=$_currentCharacteristicUuid');
            }
            if (char.properties.notify) {
              _notifyCharacteristic = char;
              await char.setNotifyValue(true);
              print('✓ 找到通知特征: ${char.uuid.str}');
            }
          }
        }
      }
    }

    if (_writeCharacteristic == null) {
      print('✗ 未找到可写的特征!');
      throw BleException('未找到可写的特征', code: -2);
    }

    print('========== BLE 服务发现完成 ==========');
  }

  /// 断开连接
  Future<void> disconnect() async {
    await _connectionSubscription?.cancel();
    await _stateSubscription?.cancel();
    _connectionSubscription = null;
    _stateSubscription = null;

    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
      _writeCharacteristic = null;
      _writeWithoutResponse = false;
      _currentServiceUuid = null;
      _currentCharacteristicUuid = null;
      _notifyCharacteristic = null;
    }
  }

  /// 发送指令 - 支持 HEX 或字符串格式
  Future<List<int>> sendCommand(String command) async {
    if (_writeCharacteristic == null) {
      throw BleException('未连接设备', code: -3);
    }

    // 解析命令
    List<int> bytes;

    // 判断是否为 HEX 格式
    // 1. 如果以 "hex:" 开头，按 HEX 解析
    // 2. 如果全是有效 HEX 字符 (0-9, A-F)，按 HEX 解析
    // 3. 否则按字符串解析
    bool isHex = false;
    String hexContent = command;

    if (command.toLowerCase().startsWith('hex:')) {
      isHex = true;
      hexContent = command.substring(4);
    } else {
      // 检查是否全是有效的 HEX 字符（不含空格）
      final cleanHex = command.replaceAll(RegExp(r'[\s,]'), '');
      if (cleanHex.isNotEmpty && RegExp(r'^[0-9A-Fa-f]+$').hasMatch(cleanHex)) {
        isHex = true;
        hexContent = cleanHex;
      }
    }

    if (isHex) {
      // HEX 格式: "AA 01 01 00 DD" 或 "hex:AA010100DD"
      bytes = _parseHexCommand(hexContent);
    } else {
      // 字符串格式: 直接转为 ASCII 字节
      bytes = command.codeUnits;
    }

    print('发送命令: $command -> $bytes, withoutResponse: $_writeWithoutResponse');

    // 写入数据 - 根据特征属性选择
    await _writeCharacteristic!.write(bytes, withoutResponse: _writeWithoutResponse);

    // 如果有通知特征，监听响应
    if (_notifyCharacteristic != null) {
      final completer = Completer<List<int>>();

      final subscription = _notifyCharacteristic!.lastValueStream.listen(
        (value) {
          if (!completer.isCompleted) {
            completer.complete(value.toList());
          }
        },
        onError: (e) {
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        },
      );

      // 设置超时
      final result = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => <int>[],
      );

      await subscription.cancel();
      return result;
    }

    return [];
  }

  /// 解析 HEX 命令字符串
  List<int> _parseHexCommand(String hex) {
    // 移除空格和特殊字符
    hex = hex.replaceAll(RegExp(r'[\s,]'), '').toUpperCase();

    if (hex.isEmpty) {
      return [];
    }

    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      if (i + 2 <= hex.length) {
        bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
      }
    }
    return bytes;
  }

  /// 监听连接状态变化
  Stream<BluetoothConnectionState> get connectionStateStream {
    if (_connectedDevice == null) {
      return Stream.value(BluetoothConnectionState.disconnected);
    }
    return _connectedDevice!.connectionState;
  }

  /// 释放资源
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _stateSubscription?.cancel();
    _scanController?.close();
    disconnect();
  }
}

/// BLE 配置存储服务
class BleConfigStorage {
  static const String _key = 'ble_config';

  Future<BleConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json != null) {
      try {
        return BleConfig.fromJson(jsonDecode(json));
      } catch (e) {
        return BleConfig();
      }
    }
    return BleConfig();
  }

  Future<void> save(BleConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(config.toJson()));
  }
}
