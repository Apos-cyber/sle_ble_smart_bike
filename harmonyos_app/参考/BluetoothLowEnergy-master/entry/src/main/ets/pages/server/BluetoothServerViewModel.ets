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

import CommonUtils from '../../utils/CommonUtils';
import BluetoothServerModel, {
  BluetoothServerModelListener,
  StartAdvertiserResult
} from './model/BluetoothServerModel';
import { util } from '@kit.ArkTS';
import { Logger } from '../../utils/Logger';
import { MAX_BLUETOOTH_NAME_LENGTH, MAX_HEART_RATE, MIN_HEART_RATE } from '../../contants/CommonConstants';

/**
 * ViewModel layer: Coordinates views and models, maintains UI state
 */
@ObservedV2
class BluetoothServerViewModel {
  // Bluetooth server viewModel singleton
  private static instance: BluetoothServerViewModel;
  // Connected device id from LocalStorage; watcher logs change.
  @Trace deviceId: string = '';
  // Flag indicating Bluetooth switch state; watcher toggles advertising.
  @Trace bluetoothEnable: boolean = false;
  // Whether advertising is currently active.
  @Trace startAdvertiserState: boolean = false;
  // Local Bluetooth name cached for display.
  @Trace localName: string = '';
  // Current heart rate being broadcast (demo value).
  @Trace heartRate: number = -1;
  // Interval id for periodic heart rate notifications.
  mIntervalId: number = -1;
  private model: BluetoothServerModel;
  // Avoid triggering the Bluetooth disabled prompt on initial page.
  private bluetoothStateInitialized: boolean = false;

  private constructor() {
    this.model = new BluetoothServerModel();
    this.model.setListener(this.createListener());
  }

  public static getInstance(): BluetoothServerViewModel {
    if (!BluetoothServerViewModel.instance) {
      BluetoothServerViewModel.instance = new BluetoothServerViewModel();
    }
    return BluetoothServerViewModel.instance;
  }

  /**
   * Stop BLE broadcasting
   */
  stopAdvertiser(): void {
    if (this.startAdvertiserState) {
      this.model.stopAdvertiser();
      this.toggleHeartRate(false);
      this.startAdvertiserState = false;
      CommonUtils.showToast(CommonUtils.getUIContext(), $r('app.string.ble_heart_rate_broadcast_is_disabled'));
    }
    this.heartRate = -1;
    this.bluetoothStateInitialized = false;
  }

  /**
   * Toggle BLE advertising state.
   * Starts advertising if currently stopped; otherwise stops it.
   */
  toggleAdvertiser(): void {
    if (this.startAdvertiserState) {
      this.model.stopAdvertiser();
      this.toggleHeartRate(false);
      this.startAdvertiserState = false;
      CommonUtils.showToast(CommonUtils.getUIContext(), $r('app.string.ble_heart_rate_broadcast_is_disabled'));
    } else {
      let BLEName: string = this.getLocalName();
      // Basic length guard to keep ADV data within 31 bytes when combined with other fields.
      if (this.stringToBytes(BLEName) > MAX_BLUETOOTH_NAME_LENGTH) {
        CommonUtils.showToast(CommonUtils.getUIContext(), $r('app.string.change_bluetooth_name'));
        return;
      }
      let ret = this.startAdvertiser();
      if (ret) {
        this.localName = BLEName;
        this.toggleHeartRate(true);
        this.startAdvertiserState = true;
        CommonUtils.showToast(CommonUtils.getUIContext(),
          $r('app.string.the_ble_heart_rate_broadcast_has_been_enabled'));
      } else {
        Logger.warn(`Failed to start BLE advertising and initialize the Heart Rate Service.`)
      }
    }
  }

  /**
   * Get local Bluetooth name
   */
  private getLocalName(): string {
    return this.model.getLocalName();
  }

  /**
   * Start BLE broadcasting
   */
  private startAdvertiser(): boolean {
    const result = this.model.startAdvertiser();
    if (result === StartAdvertiserResult.BLUETOOTH_ENABLING) {
      CommonUtils.showToast(CommonUtils.getUIContext(), $r('app.string.bluetooth_enabled_please_wait'));
      return false;
    }
    if (result === StartAdvertiserResult.FAILURE) {
      return false;
    }
    return true;
  }

  /**
   * Push heart rate to connected device
   */
  private notifyCharacteristicChanged(deviceId: string, heartRate: number): void {
    this.model.notifyCharacteristicChanged(deviceId, heartRate);
  }

  private createListener(): BluetoothServerModelListener {
    return {
      onDeviceIdChanged: (deviceId: string) => {
        this.deviceId = deviceId;
      },
      onBluetoothEnableChanged: (enabled: boolean) => {
        this.bluetoothEnable = enabled;
        this.onBluetoothEnableChange();
      }
    };
  }

  /**
   * Watcher: respond to Bluetooth enable/disable events by starting/stopping advertising.
   */
  private onBluetoothEnableChange(): void {
    // Only sync status without showing a prompt when entering the page for the first time with Bluetooth turned off.
    if (!this.bluetoothStateInitialized) {
      this.bluetoothStateInitialized = true;
      if (!this.bluetoothEnable) {
        this.startAdvertiserState = false;
      }
      return;
    }
    if (this.bluetoothEnable) {
      this.toggleAdvertiser();
    } else {
      this.model.stopAdvertiser();
      this.toggleHeartRate(false);
      this.startAdvertiserState = false;
      CommonUtils.showToast(CommonUtils.getUIContext(), $r('app.string.bluetooth_off_Stop_heart_rate_broadcast'));
    }
  }

  /**
   * Control the heart rate broadcasting timer.
   * @param open True to start periodic notifications, false to stop.
   */
  private toggleHeartRate(open: boolean): void {
    clearInterval(this.mIntervalId);
    if (open) {
      this.mIntervalId = setInterval(() => {
        this.heartRate = CommonUtils.getRandomInt(MIN_HEART_RATE, MAX_HEART_RATE);
        if (this.deviceId) {
          this.notifyCharacteristicChanged(this.deviceId, this.heartRate);
        }
      }, 1000)
    }
  }

  /**
   * Compute the byte length of a UTF-8 string.
   * @param val Input string.
   * @returns Number of bytes after UTF-8 encoding.
   */
  private stringToBytes(val: string): number {
    let that = new util.TextEncoder('utf-8');
    let result = that.encodeInto(val);
    return result?.length ?? 0;
  }
}

export default BluetoothServerViewModel;