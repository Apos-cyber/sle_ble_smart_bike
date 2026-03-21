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
import BluetoothDevice from '../../model/BluetoothDevice';
import { Logger } from '../../utils/Logger';
import CommonUtils from '../../utils/CommonUtils';
import BluetoothClientModel, {
  BluetoothClientModelListener,
  StartBLEScanResult,
  StopBLEScanResult
} from './model/BluetoothClientModel';

/**
 * ViewModel layer connects View and Model, managing UI state and interaction logic.
 */
@ObservedV2
class BluetoothClientViewModel {
  private static instance: BluetoothClientViewModel;
  @Trace availableDevices: Array<BluetoothDevice> = [];
  @Trace connectBluetoothDevice: BluetoothDevice = new BluetoothDevice();
  @Trace heartRate: number = 0;
  @Trace persistentDeviceIds: Array<string> = [];
  @Trace lastConnectedDevice: BluetoothDevice = new BluetoothDevice();
  @Trace bluetoothEnable: boolean = false;
  @Trace heartRateTop: number = 0;
  @Trace heartRateBottom: number = 0;
  @Trace heartRateAverage: number = 0;
  @Trace heartRateSampleCount: number = 0;
  private model: BluetoothClientModel;

  private constructor() {
    this.model = new BluetoothClientModel();
    this.syncInitialState();
    this.model.setListener(this.createListener());
  }

  public static getInstance(): BluetoothClientViewModel {
    if (!BluetoothClientViewModel.instance) {
      BluetoothClientViewModel.instance = new BluetoothClientViewModel();
    }
    return BluetoothClientViewModel.instance;
  }

  /**
   * Attempt automatic reconnection
   */
  async tryAutoReconnect(): Promise<boolean> {
    return await this.model.tryAutoReconnect();
  }

  /**
   * Force disconnect
   */
  forceDisconnect(): void {
    this.model.forceDisconnect();
  }

  /**
   * Start scanning, notify user based on results
   */
  startBLEScan(): boolean {
    const result = this.model.startBLEScan();
    if (result === StartBLEScanResult.BLUETOOTH_ENABLING) {
      CommonUtils.showToast(CommonUtils.getUIContext(), $r('app.string.bluetooth_enabled_please_wait'));
      return false;
    }
    if (result === StartBLEScanResult.FAILURE) {
      Logger.warn('startBLEScan failed.');
      return false;
    }
    return true;
  }

  /**
   * Stop BLE scanning
   */
  stopBLEScan(): void {
    const result = this.model.stopBLEScan();
    if (result === StopBLEScanResult.SUCCESS) {
      CommonUtils.showToast(CommonUtils.getUIContext(), $r('app.string.bLE_scanning_has_been_stopped'));
    } else {
      Logger.warn('stopBLEScan failed.');
    }
  }

  /**
   * Connect to specified device
   */
  connect(bluetoothDevice: BluetoothDevice): boolean {
    return this.model.connect(bluetoothDevice);
  }

  /**
   * Disconnect current connection
   */
  disconnect(): void {
    this.model.disconnect();
  }

  /**
   * Close GATT connection
   */
  close(): void {
    this.model.close();
  }

  /**
   * Reset connection state (for timeout scenarios).
   */
  changeConnectState(): void {
    this.model.changeConnectState();
  }

  /**
   * Remove specified device
   */
  deleteDeviceById(deviceId: string | undefined): void {
    this.model.deleteDeviceById(deviceId);
  }

  /**
   * Reset heart rate statistics to initial values.
   */
  resetHeartRateStatistics(): void {
    this.heartRateTop = 0;
    this.heartRateBottom = 0;
    this.heartRateAverage = 0;
    this.heartRateSampleCount = 0;
  }

  /**
   * Reset heart rate value to zero while preserving statistics state.
   */
  resetHeartRateValue(): void {
    this.heartRate = 0;
  }

  /**
   * Sync Model state to ViewModel on initialization
   */
  private syncInitialState(): void {
    this.resetHeartRateStatistics();
    this.updateAvailableDevices(this.model.getAvailableDevicesSnapshot());
    this.updateConnectBluetoothDevice(this.model.getConnectDeviceSnapshot());
    this.updateHeartRate(this.model.getHeartRateSnapshot());
    this.updatePersistentDeviceIds(this.model.getPersistentDeviceIdsSnapshot());
    this.updateLastConnectedDevice(this.model.getLastConnectedDeviceSnapshot());
    this.bluetoothEnable = this.model.getBluetoothEnableSnapshot();
  }

  /**
   * Create model event listener
   */
  private createListener(): BluetoothClientModelListener {
    const listener: BluetoothClientModelListener = {
      onAvailableDevicesChanged: (devices: BluetoothDevice[]) => {
        this.updateAvailableDevices(devices);
      },
      onConnectDeviceChanged: (device: BluetoothDevice) => {
        this.updateConnectBluetoothDevice(device);
      },
      onHeartRateChanged: (heartRate: number) => {
        this.updateHeartRate(heartRate);
      },
      onPersistentDeviceIdsChanged: (ids: Array<string>) => {
        this.updatePersistentDeviceIds(ids);
      },
      onLastConnectedDeviceChanged: (device: BluetoothDevice) => {
        this.updateLastConnectedDevice(device);
      },
      onBluetoothStateChanged: (enabled: boolean) => {
        this.bluetoothEnable = enabled;
      }
    };
    return listener;
  }

  /**
   * Watcher: log device list changes for diagnostics.
   */
  private updateAvailableDevices(devices: Array<BluetoothDevice>): void {
    this.availableDevices = devices;
    Logger.info(`onAvailableDevicesChange: availableDevices = ${JSON.stringify(this.availableDevices)}`);
  }

  /**
   * Watcher: log connection device changes for diagnostics.
   */
  private updateConnectBluetoothDevice(device: BluetoothDevice): void {
    this.connectBluetoothDevice = device;
    Logger.info(`onConnectBluetoothDeviceChange,${JSON.stringify(this.connectBluetoothDevice)}`);
  }

  private updatePersistentDeviceIds(ids: Array<string>): void {
    this.persistentDeviceIds = [...ids];
  }

  private updateLastConnectedDevice(device: BluetoothDevice): void {
    this.lastConnectedDevice = device;
  }

  private updateHeartRate(heartRate: number): void {
    this.heartRate = heartRate;
    this.updateHeartRateStatistics(heartRate);
  }

  private updateHeartRateStatistics(heartRate: number): void {
    if (heartRate <= 0) {
      return;
    }
    const previousSampleCount = this.heartRateSampleCount;
    const nextSampleCount = previousSampleCount + 1;
    const cumulativeTotal = this.heartRateAverage * previousSampleCount + heartRate;
    this.heartRateSampleCount = nextSampleCount;
    this.heartRateTop = Math.max(this.heartRateTop, heartRate);
    this.heartRateBottom = this.heartRateBottom === 0 ? heartRate : Math.min(this.heartRateBottom, heartRate);
    this.heartRateAverage = cumulativeTotal / nextSampleCount;
  }
}

export default BluetoothClientViewModel;