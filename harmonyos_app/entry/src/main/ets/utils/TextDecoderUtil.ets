/**
 * TextDecoder 单例工具类
 * 避免重复实例化 TextDecoder
 */

import util from '@ohos.util'

class TextDecoderUtil {
  private static instance: util.TextDecoder | null = null

  /**
   * 获取 TextDecoder 单例实例
   * @returns TextDecoder 实例
   */
  static getInstance(): util.TextDecoder {
    if (!TextDecoderUtil.instance) {
      TextDecoderUtil.instance = new util.TextDecoder('utf-8', { ignoreBOM: true })
    }
    return TextDecoderUtil.instance
  }

  /**
   * 解码字节数组为字符串
   * @param bytes 字节数组
   * @returns 解码后的字符串
   */
  static decodeToString(bytes: Uint8Array): string {
    return TextDecoderUtil.getInstance().decodeToString(bytes)
  }
}

export { TextDecoderUtil }
