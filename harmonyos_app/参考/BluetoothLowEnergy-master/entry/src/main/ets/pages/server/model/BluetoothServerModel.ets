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

import { access, ble, connection, constant } from '@kit.ConnectivityKit';
import { Logger } from '../../../utils/Logger';
import { BusinessError } from '@kit.BasicServicesKit';
import CommonUtils from '../../../utils/CommonUtils';
import {
  BLE_CHARACTERISTIC_UUID,
  BLE_DESCRIPTOR_UUID,
  BLE_SERVICE_UUID,
  CUSTOM_MANUFACTURE_ID
} from '../../../contants/CommonConstants';

/**
 * BLE Server Model Layer Event Listener
 */
export interface BluetoothServerModelListener {
  onDeviceIdChanged: ((deviceId: string) => void) | undefined;
  onBluetoothEnableChanged: ((enabled: boolean) => void) | undefined;
}

/**
 * Start advertiser result status code
 */
export enum StartAdvertiserResult {
  SUCCESS = 0,
  BLUETOOTH_ENABLING = 1,
  FAILURE = 2
}

/**
 * ViewModel for BLE advertising and GATT server behavior encapsulation.
 * This class handles low-level business logic without direct UI operations
 */
export default class BluetoothServerModel {
  private listener?: BluetoothServerModelListener;
  private mGattServer: ble.GattServer | undefined;
  private isConnectStateChangeListening = false;
  private isStateChangeListening = false;
  private isDescriptorWriteListening = false;
  private notifyEnabledMap: Map<string, boolean> = new Map();
  private cachedDeviceId: string = '';
  private cachedBluetoothEnable: boolean = false;

  constructor(listener?: BluetoothServerModelListener) {
    this.cachedBluetoothEnable = this.isBluetoothEnabled();
    if (listener) {
      this.setListener(listener);
    }
  }

  /**
   * Set up listener
   */
  setListener(listener?: BluetoothServerModelListener): void {
    this.listener = listener;
    this.emitAll();
  }

  /**
   * Get the local Bluetooth device name.
   * @returns Local device name string (empty if failed).
   */
  getLocalName(): string {
    let localName = '';
    try {
      localName = connection.getLocalName();
    } catch (err) {
      Logger.error(`getLocalName: err = ${JSON.stringify(err)}`);
    }
    return localName;
  }

  // [Start startAdvertiser]
  /**
   * Start BLE advertising and initialize a simple Heart Rate service.
   * Also registers connection and descriptor write listeners.
   * @returns `StartAdvertiserResult` status code.
   */
  startAdvertiser(): StartAdvertiserResult {
    if (!this.isBluetoothEnabled()) {
      this.enableBluetooth();
      return StartAdvertiserResult.BLUETOOTH_ENABLING;
    }
    if (!this.isStateChangeListening) {
      // Register Bluetooth state change listener.
      this.onBTStateChange();
    }
    if (this.mGattServer) {
      Logger.warn('[BluetoothServerModel] Existing GATT server detected. Releasing previous instance before starting a new one.');
      // Release GATT server resources and reset state flags.
      this.releaseGattServer();
    }
    // [StartExclude startAdvertiser]
    this.notifyEnabledMap.clear();
    this.cachedDeviceId = '';
    this.notifyDeviceIdChanged();
    // [EndExclude startAdvertiser]
    this.mGattServer = ble.createGattServer();
    this.onDescriptorWriteChange();
    // [StartExclude startAdvertiser]
    const descriptors: Array<ble.BLEDescriptor> = [];
    const descriptorDefaultValue = CommonUtils.byteArray2ArrayBuffer([0x00, 0x00]);
    const descriptor: ble.BLEDescriptor = {
      serviceUuid: BLE_SERVICE_UUID,
      characteristicUuid: BLE_CHARACTERISTIC_UUID,
      descriptorUuid: BLE_DESCRIPTOR_UUID,
      descriptorValue: descriptorDefaultValue
    }
    descriptors[0] = descriptor;
    const characteristics: Array<ble.BLECharacteristic> = [];
    const characteristicDefaultValue = CommonUtils.byteArray2ArrayBuffer([0x00, 0x00]);
    const characteristic: ble.BLECharacteristic = {
      serviceUuid: BLE_SERVICE_UUID,
      characteristicUuid: BLE_CHARACTERISTIC_UUID,
      characteristicValue: characteristicDefaultValue,
      descriptors: descriptors
    }
    characteristics[0] = characteristic;
    // [EndExclude startAdvertiser]
    // Construct server-side service data.
    const service: ble.GattService = {
      serviceUuid: BLE_SERVICE_UUID,
      isPrimary: true,
      characteristics: characteristics,
      includeServices: []
    }
    try {
      this.mGattServer.addService(service);
    } catch (err) {
      Logger.error(`addService: err = ${JSON.stringify(err)}`);
      this.releaseGattServer();
      return StartAdvertiserResult.FAILURE;
    }
    try {
      // Register connection state change listener on GATT server.
      this.onConnectStateChange();
      // [StartExclude startAdvertiser]
      const setting: ble.AdvertiseSetting = {
        interval: 160,
        txPower: 1,
        connectable: true
      }

      const customManufactureValueBuffer = new Uint8Array([1, 2, 3, 4]);
      const customManufactureDataUnit: ble.ManufactureData = {
        manufactureId: CUSTOM_MANUFACTURE_ID,
        manufactureValue: customManufactureValueBuffer.buffer
      };

      const advData: ble.AdvertiseData = {
        serviceUuids: [BLE_SERVICE_UUID],
        manufactureData: [customManufactureDataUnit],
        serviceData: [],
        includeDeviceName: false
      }

      const advResponse: ble.AdvertiseData = {
        serviceUuids: [BLE_SERVICE_UUID],
        manufactureData: [],
        serviceData: [],
        includeDeviceName: true
      }
      // [EndExclude startAdvertiser]
      ble.startAdvertising(setting, advData, advResponse);
      return StartAdvertiserResult.SUCCESS;
    } catch (err) {
      Logger.error(`startAdvertiser: err = ${JSON.stringify(err)}`);
      this.releaseGattServer();
    }
    return StartAdvertiserResult.FAILURE;
  }
  // [End startAdvertiser]

  // [Start stopAdvertiser]
  /**
   * Stop BLE advertising and disable Bluetooth (for demo cleanup).
   */
  stopAdvertiser() {
    if (!this.mGattServer) {
      Logger.warn('[BluetoothServerModel] stopAdvertiser invoked but GATT server is not initialized.');
      return;
    }
    this.offBTStateChange();
    try {
      ble.stopAdvertising();
    } catch (err) {
      Logger.error(`stopAdvertiser: err = ${JSON.stringify(err)}`);
    }
    this.releaseGattServer();
    this.cachedDeviceId = '';
    this.notifyDeviceIdChanged();
  }
  // [End stopAdvertiser]

  // [Start notifyCharacteristicChanged]
  /**
   * Notify a connected client with a heart rate value.
   * @param deviceId Target device random address.
   * @param heartRate Heart rate (bpm) to send.
   */
  notifyCharacteristicChanged(deviceId: string, heartRate: number) {
    // Validate deviceId and GattServer for legitimacy
    // [StartExclude notifyCharacteristicChanged]
    if (!deviceId) {
      return;
    }
    if (!this.mGattServer) {
      Logger.warn('[BluetoothServerModel] notifyCharacteristicChanged aborted: GATT server unavailable.');
      return;
    }
    if (this.notifyEnabledMap.get(deviceId) !== true) {
      Logger.warn(`[BluetoothServerModel] Skip notify because notifications not enabled for device=${deviceId}`);
      return;
    }
    // [EndExclude notifyCharacteristicChanged]
    const sanitizedHeartRate = Math.max(0, Math.min(255, heartRate));
    const notifyCharacteristic: ble.NotifyCharacteristic = {
      serviceUuid: BLE_SERVICE_UUID,
      characteristicUuid: BLE_CHARACTERISTIC_UUID,
      characteristicValue: CommonUtils.byteArray2ArrayBuffer([0x00, sanitizedHeartRate]),
      confirm: false
    }
    this.mGattServer.notifyCharacteristicChanged(deviceId, notifyCharacteristic, (err: BusinessError) => {
      if (err) {
        Logger.error(`notifyCharacteristicChanged callback failed: err = ${JSON.stringify(err)}`);
      } else {
        Logger.info(`[BluetoothServerModel] Heart rate notify success, device=${deviceId}, value=${sanitizedHeartRate}`);
      }
    })
  }
  // [End notifyCharacteristicChanged]

  /**
   * Get current device ID snapshot
   */
  getDeviceIdSnapshot(): string {
    return this.cachedDeviceId;
  }

  /**
   * Get Bluetooth switch status snapshot
   */
  getBluetoothEnableSnapshot(): boolean {
    return this.cachedBluetoothEnable;
  }

  // [Start server_onBTStateChange]
  /**
   * Internal: Bluetooth adapter state change handler to reflect enable/disable.
   * @param data Current Bluetooth state.
   */
  private stateChangeFunc = (data: access.BluetoothState): void => {
    if (data === access.BluetoothState.STATE_ON) {
      this.cachedBluetoothEnable = true;
      this.notifyBluetoothEnableChanged(true);
    } else if (data === access.BluetoothState.STATE_OFF) {
      this.cachedBluetoothEnable = false;
      this.notifyBluetoothEnableChanged(false);
      this.notifyEnabledMap.clear();
      this.cachedDeviceId = '';
      this.notifyDeviceIdChanged();
    }
  }

  /**
   * Register Bluetooth state change listener.
   */
  private onBTStateChange() {
    if (this.isStateChangeListening) {
      return;
    }
    try {
      access.on('stateChange', this.stateChangeFunc);
      this.isStateChangeListening = true;
    } catch (err) {
      this.isStateChangeListening = false;
      Logger.error(`onBTSateChange: err = ${JSON.stringify(err)}`);
    }
  }
  // [End server_onBTStateChange]

  /**
   * Unregister Bluetooth state change listener.
   */
  private offBTStateChange() {
    if (!this.isStateChangeListening) {
      return;
    }
    try {
      access.off('stateChange');
      this.isStateChangeListening = false;
    } catch (err) {
      this.isStateChangeListening = false;
      Logger.error(`offBTSateChange: err = ${JSON.stringify(err)}`);
    }
  }

  // [Start server_onConnectStateChange]
  /**
   * Internal: Connection state change handler to track the connected device id.
   * @param data Connection state payload.
   */
  private connectionStateChangeFunc = (data: ble.BLEConnectionChangeState): void => {
    if (data) {
      if (data.state === constant.ProfileConnectionState.STATE_CONNECTED) {
        let deviceId = data.deviceId;
        this.notifyEnabledMap.set(deviceId, false);
        this.cachedDeviceId = deviceId;
        this.notifyDeviceIdChanged();
      } else if (data.state === constant.ProfileConnectionState.STATE_DISCONNECTED) {
        const deviceId = data.deviceId;
        this.notifyEnabledMap.delete(deviceId);
        this.cachedDeviceId = '';
        this.notifyDeviceIdChanged();
        CommonUtils.showToast(CommonUtils.getUIContext(), $r('app.string.disconnection_prompt'));
      }
    }
  }

  /**
   * Register connection state change listener on GATT server.
   */
  private onConnectStateChange() {
    if (!this.mGattServer || this.isConnectStateChangeListening) {
      return;
    }
    try {
      this.mGattServer.on('connectionStateChange', this.connectionStateChangeFunc);
      this.isConnectStateChangeListening = true;
    } catch (err) {
      Logger.error(`connectInner: err = ${JSON.stringify(err)}`);
      this.isConnectStateChangeListening = false;
    }
  }
  // [End server_onConnectStateChange]

  /**
   * Unregister connection state change listener on GATT server.
   */
  private offConnectStateChange() {
    if (!this.mGattServer) {
      return;
    }
    try {
      this.mGattServer.off('connectionStateChange');
      this.isConnectStateChangeListening = false;
    } catch (err) {
      this.isConnectStateChangeListening = false;
      Logger.error(`offConnectStateChange: err = ${JSON.stringify(err)}`);
    }
  }

  // [Start isBluetoothEnabled]
  /**
   * Check whether Bluetooth is enabled or turning on.
   * @returns True if enabled or turning on; false otherwise.
   */
  private isBluetoothEnabled(): boolean {
    let state: access.BluetoothState = access.BluetoothState.STATE_OFF;
    try {
      state = access.getState();
    } catch (error) {
      Logger.error(`BluetoothServerModel, isBluetoothEnabled failed, error info: ${JSON.stringify(error)}`);
    }
    Logger.info(`isBluetoothEnabled: state = ${state}`);
    if (state === access.BluetoothState.STATE_ON || state === access.BluetoothState.STATE_TURNING_ON) {
      return true;
    }
    return false;
  }
  // [End isBluetoothEnabled]

  /**
   * Enable Bluetooth and register state listener.
   */
  private enableBluetooth() {
    this.onBTStateChange();
    try {
      // [Start enableBluetooth]
      access.enableBluetooth();
      // [End enableBluetooth]
    } catch (err) {
      Logger.error(`enableBluetooth: err = ${JSON.stringify(err)}`);
    }
  }

  /**
   * Descriptor write event handler; responds to CCC writes.
   * @param descriptorWriteRequest Descriptor write request info.
   */
  private onDescriptorWrite = (descriptorWriteRequest: ble.DescriptorWriteRequest) => {
    const deviceId: string = descriptorWriteRequest.deviceId;
    if (!deviceId) {
      Logger.warn('[BluetoothServerModel] descriptorWrite received empty deviceId.');
      return;
    }

    const valueView = new Uint8Array(descriptorWriteRequest.value ?? new ArrayBuffer(0));
    const notifyEnabled = valueView.length > 0 && (valueView[0] & 0x01) === 0x01;
    const indicateEnabled = valueView.length > 0 && (valueView[0] & 0x02) === 0x02;
    const isEnabled = notifyEnabled || indicateEnabled;
    this.notifyEnabledMap.set(deviceId, isEnabled);
    Logger.info(`[BluetoothServerModel] descriptorWrite device=${deviceId}, notify=${notifyEnabled}, indicate=${indicateEnabled}`);

    const serverResponse: ble.ServerResponse = {
      deviceId: deviceId,
      transId: descriptorWriteRequest.transId,
      status: 0,
      offset: descriptorWriteRequest.offset,
      value: descriptorWriteRequest.value
    };

    try {
      this.mGattServer?.sendResponse(serverResponse);
    } catch (err) {
      Logger.error(`sendResponse failed: ${JSON.stringify(err)}`);
    }
  }

  private onDescriptorWriteChange() {
    if (!this.mGattServer || this.isDescriptorWriteListening) {
      return;
    }
    try {
      this.mGattServer.on('descriptorWrite', this.onDescriptorWrite);
      this.isDescriptorWriteListening = true;
    } catch (error) {
      this.isDescriptorWriteListening = false;
      Logger.error(`Subscription descriptor write event exception occurred, error info: ${JSON.stringify(error)}`);
    }
  }

  private offDescriptorWriteChange() {
    if (!this.mGattServer) {
      return;
    }
    try {
      this.mGattServer.off('descriptorWrite');
      this.isDescriptorWriteListening = false;
    } catch (error) {
      this.isDescriptorWriteListening = false;
      Logger.error(`Failed to remove the write listener for the descriptor, error info:${JSON.stringify(error)}`);
    }
  }

  /**
   * Release GATT server resources and reset state flags.
   */
  private releaseGattServer(): void {
    if (!this.mGattServer) {
      this.notifyEnabledMap.clear();
      this.isConnectStateChangeListening = false;
      this.isDescriptorWriteListening = false;
      return;
    }

    this.offConnectStateChange();
    this.offDescriptorWriteChange();

    try {
      this.mGattServer.close();
    } catch (error) {
      Logger.error(`Failed to closes this GattServer object and unregisters its callbacks.`);
    }

    this.mGattServer = undefined;
    this.notifyEnabledMap.clear();
    this.isConnectStateChangeListening = false;
    this.isDescriptorWriteListening = false;
  }

  private notifyDeviceIdChanged(deviceId: string = this.cachedDeviceId): void {
    this.listener?.onDeviceIdChanged?.(deviceId);
  }

  private notifyBluetoothEnableChanged(enabled: boolean = this.cachedBluetoothEnable): void {
    this.listener?.onBluetoothEnableChanged?.(enabled);
  }

  private emitAll(): void {
    this.notifyDeviceIdChanged();
    this.notifyBluetoothEnableChanged();
  }
}