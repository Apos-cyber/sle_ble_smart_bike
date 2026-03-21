/**
 * NearLink (星闪) 管理模块
 * 负责星闪设备的扫描、连接和管理
 */

import { scan, ssap, constant } from '@kit.NearLinkKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { Logger } from '../utils/Logger'
import { NEARLINK_SCAN_TIMEOUT_MS, NEARLINK_SCAN_MODE_ACTIVE } from '../constants/NearLinkConstants'
import { ConnectionType } from '../constants/BLEConstants'

/**
 * 星闪设备信息
 */
export interface NearLinkDevice {
  /** 设备名称 */
  deviceName: string
  /** 设备地址 */
  address: string
}

/**
 * 星闪扫描回调类型
 */
export type NearLinkScanCallback = (devices: NearLinkDevice[]) => void

/**
 * 星闪连接状态回调类型
 */
export type NearLinkConnectionCallback = (success: boolean, message: string) => void

/**
 * 星闪连接状态枚举
 */
export enum NearLinkConnectionState {
  Disconnected = 0,
  Connecting = 1,
  Connected = 2,
  Disconnecting = 3
}

/**
 * 星闪管理器类
 * 单例模式，通过 getInstance() 获取实例
 */
export class NearLinkManager {
  private static instance: NearLinkManager
  private discoveredDevices: NearLinkDevice[] = []
  private isScanning: boolean = false
  private scanCallback: NearLinkScanCallback | null = null
  private connectionCallback: NearLinkConnectionCallback | null = null
  private ssapClient: ssap.Client | null = null
  private targetDeviceName: string = ''
  private scanTimeoutID: number = -1

  private constructor() {}

  /**
   * 获取 NearLinkManager 单例实例
   * @returns NearLinkManager 实例
   */
  static getInstance(): NearLinkManager {
    if (!NearLinkManager.instance) {
      NearLinkManager.instance = new NearLinkManager()
    }
    return NearLinkManager.instance
  }

  /**
   * 开始星闪扫描
   * @param deviceName 目标设备名称
   * @param callback 扫描结果回调函数
   * @returns true - 成功发起扫描; false - 扫描已进行中或失败
   */
  startScan(deviceName: string, callback: NearLinkScanCallback): boolean {
    if (this.isScanning) {
      Logger.info('NearLinkManager: Already scanning')
      return false
    }

    this.targetDeviceName = deviceName
    this.scanCallback = callback
    this.discoveredDevices = []
    this.isScanning = true

    Logger.info('NearLinkManager: Starting scan for device:', deviceName)

    this.registerDeviceFoundCallback()
    this.performScan()

    return true
  }

  /**
   * 停止星闪扫描
   */
  stopScan(): void {
    Logger.info('NearLinkManager: Stopping scan')

    clearTimeout(this.scanTimeoutID)
    this.scanTimeoutID = -1

    if (!this.isScanning) {
      return
    }

    try {
      scan.off('deviceFound')
      scan.stopScan()
      this.isScanning = false
      Logger.info('NearLinkManager: Scan stopped')
    } catch (error) {
      const err = error as BusinessError
      Logger.error('NearLinkManager: Stop scan failed', err.code.toString(), err.message)
      this.isScanning = false
    }
  }

  /**
   * 注册设备发现回调
   */
  private registerDeviceFoundCallback(): void {
    try {
      scan.on('deviceFound', (data: Array<scan.ScanResults>) => {
        Logger.debug('NearLinkManager: Found devices:', data.length.toString())

        for (let i = 0; i < data.length; i++) {
          const result = data[i]
          const deviceName = result.deviceName || '未知设备'
          const address = result.address

          Logger.debug('NearLinkManager: Device found -', deviceName, address)

          this.addDiscoveredDevice(deviceName, address)
          this.notifyScanCallback()

          if (deviceName === this.targetDeviceName) {
            Logger.info('NearLinkManager: Found target device, connecting...')
            this.stopScan()
            this.connectToDevice(address)
          }
        }
      })
    } catch (error) {
      const err = error as BusinessError
      Logger.error('NearLinkManager: Register device found callback failed', err.code.toString(), err.message)
    }
  }

  /**
   * 添加已发现设备
   * @param deviceName 设备名称
   * @param address 设备地址
   */
  private addDiscoveredDevice(deviceName: string, address: string): void {
    const existingIndex = this.discoveredDevices.findIndex((d: NearLinkDevice) => d.address === address)
    if (existingIndex < 0) {
      this.discoveredDevices.push({
        deviceName: deviceName,
        address: address
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
   * 执行星闪扫描
   */
  private performScan(): void {
    try {
      const scanFilter: scan.ScanFilters = {
        deviceName: this.targetDeviceName
      }

      const scanOptions: scan.ScanOptions = {
        scanMode: NEARLINK_SCAN_MODE_ACTIVE
      }

      scan.startScan([scanFilter], scanOptions)
        .then(() => {
          Logger.info('NearLinkManager: Start scan success')
          this.startScanTimeoutCountdown()
        })
        .catch((err: BusinessError) => {
          Logger.error('NearLinkManager: Start scan failed', err.code.toString(), err.message)
          this.isScanning = false
        })
    } catch (error) {
      const err = error as BusinessError
      Logger.error('NearLinkManager: Perform scan failed', err.code.toString(), err.message)
      this.isScanning = false
    }
  }

  /**
   * 启动扫描超时计时器
   */
  private startScanTimeoutCountdown(): void {
    clearTimeout(this.scanTimeoutID)
    this.scanTimeoutID = setTimeout(() => {
      Logger.info('NearLinkManager: Scan timeout, stopping...')
      this.stopScan()
    }, NEARLINK_SCAN_TIMEOUT_MS)
  }

  /**
   * 连接到星闪设备
   * @param address 设备地址
   */
  private connectToDevice(address: string): void {
    Logger.info('NearLinkManager: Connecting to device:', address)

    try {
      this.ssapClient = ssap.createClient(address)

      this.ssapClient.on('connectionStateChange', (data: ssap.ConnectionChangeState) => {
        Logger.info('NearLinkManager: Connection state changed:', data.state.toString())
        if (data.state === constant.ConnectionState.STATE_CONNECTED) {
          Logger.info('NearLinkManager: Connected to device:', address)
        } else if (data.state === constant.ConnectionState.STATE_DISCONNECTED) {
          Logger.info('NearLinkManager: Disconnected from device:', address)
        }
      })

      this.ssapClient.connect()
        .then(() => {
          Logger.info('NearLinkManager: Connect request sent')
          if (this.connectionCallback) {
            this.connectionCallback(true, '星闪连接成功')
          }
        })
        .catch((err: BusinessError) => {
          this.ssapClient = null
          Logger.error('NearLinkManager: Connect failed', err.code.toString(), err.message)
          if (this.connectionCallback) {
            this.connectionCallback(false, `连接失败: ${err.message}`)
          }
        })
    } catch (error) {
      this.ssapClient = null
      const err = error as BusinessError
      Logger.error('NearLinkManager: Create client failed', err.code.toString(), err.message)
      if (this.connectionCallback) {
        this.connectionCallback(false, `创建连接失败: ${err.message}`)
      }
    }
  }

  /**
   * 设置连接状态回调
   * @param callback 连接状态回调函数
   */
  setConnectionCallback(callback: NearLinkConnectionCallback): void {
    this.connectionCallback = callback
  }

  /**
   * 断开星闪连接
   */
  disconnect(): void {
    if (this.ssapClient) {
      try {
        this.ssapClient.off('connectionStateChange')
        this.ssapClient.disconnect()
          .then(() => {
            Logger.info('NearLinkManager: Disconnected')
          })
          .catch((err: BusinessError) => {
            Logger.error('NearLinkManager: Disconnect failed', err.code.toString(), err.message)
          })
        this.ssapClient.close()
        this.ssapClient = null
      } catch (error) {
        const err = error as BusinessError
        Logger.error('NearLinkManager: Disconnect error', err.code.toString(), err.message)
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
   * 获取当前连接状态
   * @returns NearLinkConnectionState
   */
  getConnectionState(): NearLinkConnectionState {
    if (this.ssapClient) {
      return NearLinkConnectionState.Connected
    }
    return NearLinkConnectionState.Disconnected
  }

  /**
   * 获取连接类型
   * @returns ConnectionType.NearLink
   */
  getConnectionType(): ConnectionType {
    return ConnectionType.NearLink
  }
}
