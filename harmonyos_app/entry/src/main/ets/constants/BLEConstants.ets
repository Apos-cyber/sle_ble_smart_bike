/**
 * BLE 模块常量集中管理
 */

import { Permissions } from '@kit.AbilityKit'

/**
 * 权限列表
 */
export const PERMISSION_LIST: Array<Permissions> = [
  'ohos.permission.ACCESS_BLUETOOTH',
  'ohos.permission.LOCATION'
]

/**
 * 扫描超时时间 (毫秒)
 */
export const SCAN_TIMEOUT_MS: number = 10000

/**
 * 扫描间隔 (毫秒)
 */
export const SCAN_INTERVAL_MS: number = 500

/**
 * 等待蓝牙开启时间 (毫秒)
 */
export const BLUETOOTH_ENABLE_WAIT_MS: number = 2000

/**
 * 扫描结果通知间隔 (毫秒)
 */
export const SCAN_RESULT_NOTIFY_INTERVAL_MS: number = 100

/**
 * 连接超时时间 (毫秒)
 */
export const CONNECTION_TIMEOUT_MS: number = 10000

/**
 * 结果弹窗自动关闭时间 (毫秒)
 */
export const RESULT_DIALOG_AUTO_CLOSE_MS: number = 2000

/**
 * 设备名称正则验证
 */
export const DEVICE_NAME_PATTER_REGEX: string = '^[a-zA-Z0-9_\\-\\s]+$'

/**
 * 未知设备默认名称
 */
export const UNKNOWN_DEVICE_NAME: string = '未知设备'

/**
 * 目标设备名称关键词
 */
export const TARGET_DEVICE_KEYWORDS: string[] = ['sle', 'bike']

/**
 * 连接状态枚举
 */
export enum ConnectionState {
  Connecting = 1,
  Connected = 2,
  Disconnecting = 3,
  Disconnected = 4
}

/**
 * 连接类型枚举 - 用于区分蓝牙和星闪连接
 */
export enum ConnectionType {
  None = 0,
  BLE = 1,
  NearLink = 2
}

/**
 * BLE广播数据类型枚举
 */
export enum BLEAdvertiseType {
  Flags = 0x01,
  ServiceUuid16BitMore = 0x02,
  ServiceUuid16BitComplete = 0x03,
  ServiceUuid32BitMore = 0x04,
  ServiceUuid32BitComplete = 0x05,
  ServiceUuid128BitMore = 0x06,
  ServiceUuid128BitComplete = 0x07,
  LocalNameShort = 0x08,
  LocalNameComplete = 0x09,
  ManufacturerSpecificData = 0xFF
}
