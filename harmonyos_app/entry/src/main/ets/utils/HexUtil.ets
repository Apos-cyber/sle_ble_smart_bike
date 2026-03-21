/**
 * 十六进制格式工具类
 */

/**
 * 将 ArrayBuffer 转换为十六进制字符串
 * @param data ArrayBuffer 数据
 * @returns 十六进制字符串，格式如 "00 1A 2B..."
 */
function formatHex(data: ArrayBuffer): string {
  if (!data || data.byteLength === 0) {
    return ''
  }
  const bytes = new Uint8Array(data)
  return Array.from(bytes).map(b => b.toString(16).padStart(2, '0')).join(' ')
}

/**
 * 将字节数组转换为十六进制字符串
 * @param bytes 字节数组
 * @returns 十六进制字符串
 */
function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes).map(b => b.toString(16).padStart(2, '0')).join(' ')
}

export { formatHex, bytesToHex }
