/**
 * Copyright (c) 2025 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0
 */

import { hilog } from '@kit.PerformanceAnalysisKit'

/**
 * 统一日志工具类
 */
export class Logger {
  private static readonly DOMAIN: number = 0xFF01
  private static readonly PREFIX: string = 'SmartRiding'
  private static readonly FORMAT: string = '%{public}s'

  /**
   * 打印调试级别日志
   * @param args 日志内容
   */
  static debug(...args: string[]): void {
    hilog.debug(Logger.DOMAIN, Logger.PREFIX, Logger.FORMAT, args)
  }

  /**
   * 打印信息级别日志
   * @param args 日志内容
   */
  static info(...args: string[]): void {
    hilog.info(Logger.DOMAIN, Logger.PREFIX, Logger.FORMAT, args)
  }

  /**
   * 打印警告级别日志
   * @param args 日志内容
   */
  static warn(...args: string[]): void {
    hilog.warn(Logger.DOMAIN, Logger.PREFIX, Logger.FORMAT, args)
  }

  /**
   * 打印错误级别日志
   * @param args 日志内容
   */
  static error(...args: string[]): void {
    hilog.error(Logger.DOMAIN, Logger.PREFIX, Logger.FORMAT, args)
  }
}
