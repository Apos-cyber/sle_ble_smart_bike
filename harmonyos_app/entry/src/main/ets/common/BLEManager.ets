/**
 * BLE 管理模块
 * 负责蓝牙低功耗设备的扫描、连接和管理
 */

import { access, ble, constant } from '@kit.ConnectivityKit'
import { abilityAccessCtrl, bundleManager, common, Permissions } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { Logger } from '../utils/Logger'
import { TextDecoderUtil } from '../utils/TextDecoderUtil'
import { formatHex } from '../utils/HexUtil'
import {
  PERMISSION_LIST,
  SCAN_TIMEOUT_MS,
  SCAN_INTERVAL_MS,
  BLUETOOTH_ENABLE_WAIT_MS,
  UNKNOWN_DEVICE_NAME,
  TARGET_DEVICE_KEYWORDS,
  ConnectionState,
  ConnectionType,
  BLEAdvertiseType
} from '../constants/BLEConstants'

/**
 * BLE 设备信息接口
 */
export interface BLEDevice {
  /** 设备ID (MAC地址) */
  deviceId: string
  /** 设备名称 */
  deviceName: string
  /** 信号强度 */
  rssi: number
}

/**
 * BLE 扫描回调类型
 */
export type BLEScanCallback = (devices: BLEDevice[]) => void

/**
 * BLE 连接状态回调类型
 * @param connected true - 已连接; false - 已断开
 * @param deviceId 设备ID
 */
export type BLEConnectionCallback = (connected: boolean, deviceId: string) => void

/**
 * BLE 管理器类
 * 单例模式，通过 getInstance() 获取实例
 */
export class BLEManager {
  private static instance: BLEManager
  private context: common.UIAbilityContext | null = null
  private discoveredDevices: BLEDevice[] = []
  private isScanning: boolean = false
  private scanCallback: BLEScanCallback | null = null
  private gattClientDevice: ble.GattClientDevice | null = null
  private permissions: Array<Permissions> = PERMISSION_LIST
  private scanTimeoutID: number = -1
  private connectionCallback: BLEConnectionCallback | null = null
  private currentDeviceId: string = ''

  private constructor() {}

  /**
   * 获取 BLEManager 单例实例
   * @returns BLEManager 实例
   */
  static getInstance(): BLEManager {
    if (!BLEManager.instance) {
      BLEManager.instance = new BLEManager()
    }
    return BLEManager.instance
  }

  /**
   * 设置 UIAbilityContext
   * @param context UIAbilityContext 实例
   */
  setContext(context: common.UIAbilityContext): void {
    this.context = context
  }

  /**
   * 请求蓝牙权限
   * @returns true - 权限已授予; false - 权限未授予
   */
  async requestPermissions(): Promise<boolean> {
    if (!this.context) {
      Logger.error('BLEManager: Context is null')
      return false
    }

    try {
      const grantStatus = await this.checkPermissions()
      if (grantStatus) {
        Logger.info('BLEManager: Permissions already granted')
        return true
      }

      const atManager = abilityAccessCtrl.createAtManager()
      const result = await atManager.requestPermissionsFromUser(this.context, this.permissions)
      const authResults = result.authResults

      if (authResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        Logger.info('BLEManager: Permission granted')
        return true
      } else {
        Logger.error('BLEManager: Permission denied')
        return false
      }
    } catch (error) {
      const err = error as BusinessError
      Logger.error('BLEManager: Request permissions failed', err.code.toString(), err.message)
      return false
    }
  }

  /**
   * 检查权限是否已授予
   * @returns true - 已授予; false - 未授予
   */
  private async checkPermissions(): Promise<boolean> {
    try {
      const bundleInfo = await bundleManager.getBundleInfoForSelf(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
      )
      const tokenId = bundleInfo.appInfo.accessTokenId
      const atManager = abilityAccessCtrl.createAtManager()
      const result = await atManager.checkAccessToken(tokenId, 'ohos.permission.ACCESS_BLUETOOTH')
      return result === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED
    } catch (error) {
      const err = error as BusinessError
      Logger.error('BLEManager: Check permissions failed', err.code.toString(), err.message)
      return false
    }
  }

  /**
   * 检查蓝牙是否已启用
   * @returns true - 已启用; false - 未启用
   */
  isBluetoothEnabled(): boolean {
    let state: access.BluetoothState = access.BluetoothState.STATE_OFF
    try {
      state = access.getState()
    } catch (error) {
      const err = error as BusinessError
      Logger.error('BLEManager: getState failed', err.code.toString(), err.message)
    }
    return state === access.BluetoothState.STATE_ON || state === access.BluetoothState.STATE_TURNING_ON
  }

  /**
   * 启用蓝牙
   * @returns true - 成功; false - 失败
   */
  enableBluetooth(): boolean {
    try {
      access.enableBluetooth()
      return true
    } catch (error) {
      const err = error as BusinessError
      Logger.error('BLEManager: enableBluetooth failed', err.code.toString(), err.message)
      return false
    }
  }

  /**
   * 禁用蓝牙
   * @returns true - 成功; false - 失败
   */
  disableBluetooth(): boolean {
    try {
      access.disableBluetooth()
      return true
    } catch (error) {
      const err = error as BusinessError
      Logger.error('BLEManager: disableBluetooth failed', err.code.toString(), err.message)
      return false
    }
  }

  /**
   * 开始 BLE 扫描
   * @param callback 扫描结果回调函数
   * @returns true - 成功发起扫描; false - 扫描已进行中或失败
   */
  startScan(callback: BLEScanCallback): boolean {
    if (this.isScanning) {
      Logger.info('BLEManager: Already scanning')
      return false
    }

    this.scanCallback = callback
    this.discoveredDevices = []
    this.isScanning = true

    const btEnabled = this.isBluetoothEnabled()
    Logger.info('BLEManager: Bluetooth enabled:', btEnabled.toString())

    if (!btEnabled) {
      Logger.info('BLEManager: Bluetooth not enabled, enabling...')
      this.enableBluetooth()
      setTimeout(() => {
        const nowEnabled = this.isBluetoothEnabled()
        Logger.info('BLEManager: Bluetooth state after wait:', nowEnabled.toString())
        this.performScan()
      }, BLUETOOTH_ENABLE_WAIT_MS)
    } else {
      this.performScan()
    }

    return true
  }

  /**
   * 执行 BLE 扫描
   */
  private performScan(): void {
    Logger.info('BLEManager: Performing scan...')

    this.setupDeviceFindListener()

    const scanOptions: ble.ScanOptions = {
      interval: SCAN_INTERVAL_MS,
      dutyMode: ble.ScanDuty.SCAN_MODE_BALANCED,
      matchMode: ble.MatchMode.MATCH_MODE_AGGRESSIVE
    }

    const scanFilter: ble.ScanFilter = {}

    Logger.info('BLEManager: Starting scan with filter')
    ble.startBLEScan([scanFilter], scanOptions)
    Logger.info('BLEManager: Started BLE scan')
    this.startScanTimeoutCountdown()
  }

  /**
   * 设置设备发现监听器
   */
  private setupDeviceFindListener(): void {
    try {
      ble.on('BLEDeviceFind', (results: Array<ble.ScanResult>) => {
        Logger.debug('BLEManager: Found devices:', results.length.toString())
        results.forEach((result: ble.ScanResult) => {
          this.processScanResult(result)
        })
      })
    } catch (error) {
      const err = error as BusinessError
      Logger.error('BLEManager: Setup device find listener failed', err.code.toString(), err.message)
      this.isScanning = false
    }
  }

  /**
   * 处理单个扫描结果
   * @param result 扫描结果
   */
  private processScanResult(result: ble.ScanResult): void {
    const deviceId = result.deviceId
    const rssiValue = result.rssi

    if (result.data) {
      Logger.debug('BLEManager: Adv raw:', formatHex(result.data))
    }

    let rawDeviceName = result.deviceName
    let cleanDeviceName = rawDeviceName ? rawDeviceName.replace(/\0/g, '').trim() : ''

    if (cleanDeviceName.length === 0 && result.data) {
      const parsedName = parseDeviceNameFromAdvData(result.data)
      if (parsedName) {
        rawDeviceName = parsedName
        cleanDeviceName = parsedName
      }
    }

    const deviceName = (cleanDeviceName && cleanDeviceName.length > 0) ? cleanDeviceName : UNKNOWN_DEVICE_NAME

    if (this.isTargetDevice(deviceName)) {
      Logger.info('BLEManager: Found target device:', deviceName, deviceId)
    }

    this.updateDiscoveredDevice(deviceId, deviceName, rssiValue)
    this.notifyScanCallback()
  }

  /**
   * 检查是否为目标设备
   * @param deviceName 设备名称
   * @returns true - 是目标设备; false - 不是
   */
  private isTargetDevice(deviceName: string): boolean {
    const lowerName = deviceName.toLowerCase()
    return TARGET_DEVICE_KEYWORDS.some(keyword => lowerName.includes(keyword))
  }

  /**
   * 更新已发现设备列表
   * @param deviceId 设备ID
   * @param deviceName 设备名称
   * @param rssi 信号强度
   */
  private updateDiscoveredDevice(deviceId: string, deviceName: string, rssi: number): void {
    const existingIndex = this.discoveredDevices.findIndex((d: BLEDevice) => d.deviceId === deviceId)
    if (existingIndex >= 0) {
      this.discoveredDevices[existingIndex].rssi = rssi
    } else {
      this.discoveredDevices.push({
        deviceId: deviceId,
        deviceName: deviceName,
        rssi: rssi
      })
    }
  }

  /**
   * 通知扫描回调
   */
  private notifyScanCallback(): void {
    if (this.scanCallback) {
      this.scanCallback([...this.discoveredDevices])
    }
  }

  /**
   * 启动扫描超时计时器
   */
  private startScanTimeoutCountdown(): void {
    clearTimeout(this.scanTimeoutID)
    this.scanTimeoutID = setTimeout(() => {
      Logger.info('BLEManager: Scan timeout, stopping scan...')
      this.stopScan()
    }, SCAN_TIMEOUT_MS)
  }

  /**
   * 停止 BLE 扫描
   */
  stopScan(): void {
    clearTimeout(this.scanTimeoutID)
    this.scanTimeoutID = -1

    if (!this.isScanning) {
      return
    }

    try {
      ble.off('BLEDeviceFind')
      ble.stopBLEScan()
      this.isScanning = false
      Logger.info('BLEManager: Stopped scanning')
    } catch (error) {
      const err = error as BusinessError
      Logger.error('BLEManager: Stop scan failed', err.code.toString(), err.message)
    }
  }

  /**
   * 连接 BLE 设备
   * @param deviceId 设备ID
   * @returns true - 成功发起连接; false - 发起连接失败
   */
  async connect(deviceId: string): Promise<boolean> {
    return new Promise((resolve) => {
      try {
        this.currentDeviceId = deviceId
        this.gattClientDevice = ble.createGattClientDevice(deviceId)

        this.gattClientDevice.on('BLEConnectionStateChange', (data: ble.BLEConnectionChangeState) => {
          Logger.info('BLEManager: Connection state changed:', data.state.toString())
          if (data.state === constant.ProfileConnectionState.STATE_CONNECTED) {
            Logger.info('BLEManager: Connected to device:', deviceId)
            if (this.connectionCallback) {
              this.connectionCallback(true, deviceId)
            }
          } else if (data.state === constant.ProfileConnectionState.STATE_DISCONNECTED) {
            Logger.info('BLEManager: Disconnected from device:', deviceId)
            this.gattClientDevice = null
            if (this.connectionCallback) {
              this.connectionCallback(false, deviceId)
            }
          }
        })

        this.gattClientDevice.connect()
        Logger.info('BLEManager: Connecting to device:', deviceId)
        resolve(true)
      } catch (error) {
        this.gattClientDevice = null
        this.currentDeviceId = ''
        const err = error as BusinessError
        Logger.error('BLEManager: Connect failed', err.code.toString(), err.message)
        resolve(false)
      }
    })
  }

  /**
   * 断开 BLE 连接
   */
  disconnect(): void {
    if (this.gattClientDevice) {
      try {
        this.gattClientDevice.off('BLEConnectionStateChange')
        this.gattClientDevice.disconnect()
        Logger.info('BLEManager: Disconnected')
      } catch (error) {
        const err = error as BusinessError
        Logger.error('BLEManager: Disconnect failed', err.code.toString(), err.message)
      }
    }
  }

  /**
   * 关闭 GATT 连接并释放资源
   */
  close(): void {
    if (this.gattClientDevice) {
      try {
        this.gattClientDevice.close()
        this.gattClientDevice = null
        Logger.info('BLEManager: Device closed')
      } catch (error) {
        const err = error as BusinessError
        Logger.error('BLEManager: Close failed', err.code.toString(), err.message)
      }
    }
  }

  /**
   * 获取当前扫描状态
   * @returns true - 正在扫描; false - 未在扫描
   */
  isCurrentlyScanning(): boolean {
    return this.isScanning
  }

  /**
   * 设置连接状态回调
   * @param callback 连接状态变化回调
   */
  setConnectionCallback(callback: BLEConnectionCallback): void {
    this.connectionCallback = callback
  }

  /**
   * 获取当前连接状态
   * @returns ConnectionState
   */
  getConnectionState(): ConnectionState {
    if (this.gattClientDevice) {
      return ConnectionState.Connected
    }
    return ConnectionState.Disconnected
  }

  /**
   * 获取连接类型
   * @returns ConnectionType.BLE
   */
  getConnectionType(): ConnectionType {
    return ConnectionType.BLE
  }
}

/**
 * 解析广播数据中的设备名称
 * @param data 广播数据 ArrayBuffer
 * @returns 设备名称或 null
 */
function parseDeviceNameFromAdvData(data: ArrayBuffer): string | null {
  if (!data || data.byteLength === 0) {
    return null
  }

  const dataBytes = new Uint8Array(data)
  let i = 0

  // 1. 标准遍历 AD Structure
  while (i < dataBytes.length) {
    const adStructLength = dataBytes[i]

    if (adStructLength === 0 || i + 1 + adStructLength > dataBytes.length) {
      break
    }

    const adType = dataBytes[i + 1]

    if (adType === BLEAdvertiseType.LocalNameComplete || adType === BLEAdvertiseType.LocalNameShort) {
      const nameBytes = dataBytes.slice(i + 2, i + 1 + adStructLength)
      try {
        const name = TextDecoderUtil.decodeToString(nameBytes).replace(/\0/g, '').trim()
        if (name.length > 0) {
          return name
        }
      } catch (e) {
        Logger.debug('BLEManager: Standard parse error:', e)
      }
    }

    i += adStructLength + 1
  }

  // 2. 容错/暴力搜索
  Logger.debug('BLEManager: Standard parse failed, attempting brute-force fallback')
  for (let k = 1; k < dataBytes.length - 1; k++) {
    const type = dataBytes[k]
    if (type === BLEAdvertiseType.LocalNameComplete || type === BLEAdvertiseType.LocalNameShort) {
      const len = dataBytes[k - 1]
      if (len > 1 && k + len <= dataBytes.length) {
        const nameBytes = dataBytes.slice(k + 1, k + len)
        try {
          const name = TextDecoderUtil.decodeToString(nameBytes).replace(/\0/g, '').trim()
          const regex = new RegExp('^[a-zA-Z0-9_\\-\\s]+$')
          if (name.length > 0 && regex.test(name)) {
            return name
          }
        } catch (e) {
          // 忽略尝试失败
        }
      }
    }
  }

  return null
}
