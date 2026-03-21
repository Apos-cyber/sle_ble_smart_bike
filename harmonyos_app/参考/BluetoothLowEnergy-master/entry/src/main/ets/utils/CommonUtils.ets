/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
 * Licensed under the Apache License,Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { Logger } from './Logger';
import { abilityAccessCtrl, bundleManager, common, Permissions } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';

/**
 * Common utility helpers shared across the project.
 */
export default class CommonUtils {
  /**
   * Convert a number array into an ArrayBuffer.
   * @param byteArr Array of byte values (0-255).
   * @returns ArrayBufferLike representing the same bytes.
   */
  public static byteArray2ArrayBuffer(byteArr: Array<number>): ArrayBufferLike {
    return new Uint8Array(byteArr).buffer;
  }

  /**
   * Convert an ArrayBuffer into a number array.
   * @param arrayBuffer Input ArrayBuffer.
   * @returns Array<number> of byte values.
   */
  public static arrayBuffer2ByteArray(arrayBuffer: ArrayBuffer): Array<number> {
    return [...new Uint8Array(arrayBuffer)];
  }

  /**
   * Format a Date into a string using a simple token replacement template.
   * Supported tokens: yyyy, MM, dd, HH, mm, ss.
   * @param date Date instance to format.
   * @param format Format pattern, default 'yyyy-MM-dd HH:mm:ss'.
   * @returns Formatted date string.
   */
  public static dateFormat(date: Date, format: string = 'yyyy-MM-dd HH:mm:ss'): string {
    const MAX_LENGTH: number = 2;
    let year = date.getFullYear().toString();
    let month = (date.getMonth() + 1).toString().padStart(MAX_LENGTH, '0');
    let day = (date.getDate()).toString().padStart(MAX_LENGTH, '0'); // Correct day format without +1
    let hour = (date.getHours()).toString().padStart(MAX_LENGTH, '0'); // Correct hour/min/sec without extra +1
    let minute = (date.getMinutes()).toString().padStart(MAX_LENGTH, '0');
    let second = (date.getSeconds()).toString().padStart(MAX_LENGTH, '0');
    let result = format.replace('yyyy', year);
    result = result.replace('MM', month);
    result = result.replace('dd', day);
    result = result.replace('HH', hour);
    result = result.replace('mm', minute);
    result = result.replace('ss', second);
    return result
  }

  /**
   * Get a random integer between min and max (both inclusive).
   * @param min Minimum integer value.
   * @param max Maximum integer value.
   * @returns Random integer within [min, max].
   */
  public static getRandomInt(min: number, max: number): number {
    return Math.floor(Math.random() * (max - min + 1) + min);
  }

  /**
   * Show a simple toast message by using UIContext prompt API.
   * @param ctx Optional UIContext to obtain PromptAction from.
   * @param curMsg ResourceStr message to display.
   */
  public static showToast(ctx: UIContext | undefined, curMsg: ResourceStr) {
    try {
      ctx?.getPromptAction().showToast({
        message: curMsg,
        duration: 2000
      });
    } catch (error) {
      Logger.warn(`Failed to open toast dialog, error info: ${JSON.stringify(error)}`);
    }
  }

  /**
   * Checks if all specified permissions are granted.
   *
   * Verifies each permission in the provided list against the current access token.
   * If any permission is not granted, initiates a user permission request flow;
   * otherwise, logs successful authorization.
   *
   * @param permissions - Array of permissions to check
   * @param context - UI context for displaying permission requests
   */
  public static async checkPermissions(permissions: Array<Permissions>, context: UIContext): Promise<void> {
    const tokenId = await CommonUtils.getAccessTokenId();
    const allGranted = await Promise.all(
      permissions.map(async (permission) =>
      await CommonUtils.checkPermissionGrant(tokenId, permission) === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED
      )
    );
    if (!allGranted.every(Boolean)) {
      CommonUtils.reqPermissionsFromUser(permissions, context);
    } else {
      Logger.info(`All permissions authorized successfully.`);
    }
  }

  /**
   * Retrieves the UI context from application storage
   *
   * This method fetches the UIContext instance stored under the key 'uiContext'
   * in the application's storage. If no context is found, it returns undefined.
   *
   * @returns {UIContext | undefined} The UI context instance if available, otherwise undefined
   * @private This is a private method intended for internal class use only
   */
  public static getUIContext(): UIContext | undefined {
    return AppStorage.get('uiContext') as UIContext | undefined;
  }

  /**
   * Retrieves the host context from the UI context
   * @returns {common.UIAbilityContext | undefined} The host context instance if available, otherwise undefined
   */
  public static getHostContext(): common.UIAbilityContext | undefined {
    return CommonUtils.getUIContext()?.getHostContext() as common.UIAbilityContext | undefined;
  }

  /**
   * Retrieves the main window instance from the host context
   *
   * @returns {window.Window | undefined} The main window instance if successfully retrieved, otherwise undefined
   */
  public static getMainWindow(): window.Window | undefined {
    const hostContext = CommonUtils.getHostContext();
    if (!hostContext) {
      Logger.warn('Host context unavailable.');
      return undefined;
    }
    try {
      return hostContext.windowStage.getMainWindowSync();
    } catch (error) {
      Logger.warn(`Failed to obtain the main window of this window stage, error info: ${JSON.stringify(error)}`)
      return undefined;
    }
  }

  /**
   * Requests specified permissions from the user via system dialog
   *
   * @param permissions - Array of permissions to request
   * @param context - UIContext for getting ability context and displaying UI
   *
   * @remarks
  * This method checks permission authorization status and triggers system dialog if needed.
   * User must grant all requested permissions for Bluetooth communication to work properly.
   */
  private static reqPermissionsFromUser(permissions: Array<Permissions>, context: UIContext) {
    const ctx: common.UIAbilityContext = context.getHostContext() as common.UIAbilityContext;
    const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    // requestPermissionsFromUser checks permission authorization status to determine whether to show dialog
    atManager.requestPermissionsFromUser(ctx, permissions).then((data) => {
      const grantStatus: Array<number> = data.authResults;
      const grantStatusCount: number = grantStatus.reduce((prev, curr) => prev + curr, 0);
      if (grantStatusCount === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        Logger.info(`All permissions authorized successfully.`)
      } else {
        // Second request authorization
        atManager.requestPermissionOnSetting(ctx, permissions).then((data: Array<abilityAccessCtrl.GrantStatus>) => {
          Logger.info(`requestPermissionOnSetting success, result:${JSON.stringify(data)}`);
        }).catch((err: BusinessError) => {
          Logger.error(`requestPermissionOnSetting failed, error info:${JSON.stringify(err)}`);
        })
      }
    }).catch((e: Error) => {
      Logger.error(`Failed to request permissions from user, error info: ${JSON.stringify(e)}`);
    })
  }

  private static async getAccessTokenId(): Promise<number> {
    // Get the accessTokenId of the application
    let tokenId: number = 0;
    try {
      const bundleInfo: bundleManager.BundleInfo =
        await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      const appInfo: bundleManager.ApplicationInfo = bundleInfo.appInfo;
      tokenId = appInfo.accessTokenId;
    } catch (error) {
      Logger.error(`Failed to get bundle info for self, error info: ${error}`);
    }
    return tokenId;
  }

  private static async checkPermissionGrant(token: number,
    permission: Permissions): Promise<abilityAccessCtrl.GrantStatus> {
    const atManager = abilityAccessCtrl.createAtManager();
    try {
      return await atManager.checkAccessToken(token, permission);
    } catch (err) {
      Logger.error(`Failed to check access token, error info: ${JSON.stringify(err)}`);
      return abilityAccessCtrl.GrantStatus.PERMISSION_DENIED;
    }
  }
}