/**
 * NearLink (星闪) 模块常量集中管理
 */

/**
 * 星闪扫描超时时间 (毫秒)
 */
export const NEARLINK_SCAN_TIMEOUT_MS: number = 10000

/**
 * 星闪扫描模式 - 主动扫描
 */
export const NEARLINK_SCAN_MODE_ACTIVE: number = 2

/**
 * 等待星闪模块开启时间 (毫秒)
 */
export const NEARLINK_ENABLE_WAIT_MS: number = 2000

/**
 * 星闪连接超时时间 (毫秒)
 */
export const NEARLINK_CONNECTION_TIMEOUT_MS: number = 10000

/**
 * 星闪连接状态枚举
 */
export enum NearLinkConnectionState {
  Disconnected = 0,
  Connecting = 1,
  Connected = 2,
  Disconnecting = 3
}
