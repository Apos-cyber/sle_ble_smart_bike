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
import { BusinessError } from '@kit.BasicServicesKit';
import BluetoothDevice from '../../../model/BluetoothDevice';
import { Logger } from '../../../utils/Logger';
import { util } from '@kit.ArkTS';
import CommonUtils from '../../../utils/CommonUtils';
import {
  BLE_CHARACTERISTIC_UUID,
  BLE_DESCRIPTOR_UUID,
  BLE_SERVICE_UUID,
  ConnectionState,
  CUSTOM_MANUFACTURE_ID,
  SCAN_TIMEOUT_MS
} from '../../../contants/CommonConstants';

/**
 * Start BLE scanning result state
 */
export enum StartBLEScanResult {
  SUCCESS = 0,
  BLUETOOTH_ENABLING = 1,
  FAILURE = 2
}

/**
 * Stop BLE scanning result state
 */
export enum StopBLEScanResult {
  SUCCESS = 0,
  FAILURE = 1
}

/**
 * BLE Client Model Layer Event Listener
 */
export interface BluetoothClientModelListener {
  onAvailableDevicesChanged: ((devices: BluetoothDevice[]) => void) | undefined;
  onConnectDeviceChanged: ((device: BluetoothDevice) => void) | undefined;
  onHeartRateChanged: ((heartRate: number) => void) | undefined;
  onPersistentDeviceIdsChanged: ((ids: Array<string>) => void) | undefined;
  onLastConnectedDeviceChanged: ((device: BluetoothDevice) => void) | undefined;
  onBluetoothStateChanged: ((enabled: boolean) => void) | undefined;
}

/**
 * Subset descriptor object used to write CCC values via GATT client.
 */
interface BLEDescriptor {
  serviceUuid: string,
  characteristicUuid: string,
  descriptorValue: ArrayBufferLike,
  descriptorUuid: string
}

/**
 * BLE client business model encapsulating scan/connect/disconnect
 * and auto-reconnect logic. Manages the underlying data layer and business logic implementation.
 */
export default class BluetoothClientModel {
  private listener?: BluetoothClientModelListener;
  private mGattClientDevice: ble.GattClientDevice | null = null;
  private mConnectBluetoothDevice: BluetoothDevice = this.cloneDevice();
  private mAvailableDevices: BluetoothDevice[] = [];
  private mTimeoutID: number = -1;
  private mPersistentDeviceIds: Array<string> = [];
  private mIsAutoReconnecting: boolean = false;
  private mLastConnectedDevice: BluetoothDevice = this.cloneDevice();
  private currentHeartRate: number = 0;
  private bluetoothEnabled: boolean = false;
  private isBTStateChangeSubscribed: boolean = false;
  // [Start BLEConnectionStateChangeFunc]
  /**
   * Handler for connection state changes emitted by ble.GattClientDevice.
   * @param data BLE connection state payload.
   */
  private BLEConnectionStateChangeFunc = async (data: ble.BLEConnectionChangeState): Promise<void> => {
    let state: constant.ProfileConnectionState = data.state;
    if (data) {
      if (state === constant.ProfileConnectionState.STATE_CONNECTED) {
        await this.handleGattConnected();
      } else if (state === constant.ProfileConnectionState.STATE_DISCONNECTED) {
        this.handleGattDisconnected();
        Logger.warn(`GATT link disconnected. GattDisconnectReason reason code: ${data.reason}`);
      } else if (state === constant.ProfileConnectionState.STATE_CONNECTING) {
        Logger.info(`GATT link is connecting.`);
      }
    }
  }
  // [End BLEConnectionStateChangeFunc]

  /**
   * Construct the client model, initialize internal snapshot.
   */
  constructor(listener?: BluetoothClientModelListener) {
    this.bluetoothEnabled = this.isBluetoothEnabled();
    this.syncPersistentDeviceIds();
    if (listener) {
      this.setListener(listener);
    }
  }

  /**
   * Set up listener
   * @param listener Listener instance
   */
  setListener(listener?: BluetoothClientModelListener): void {
    this.listener = listener;
    this.emitAll();
  }

  // [Start tryAutoReconnect]
  /**
   * Try to auto-reconnect using system persistent device ids.
   * Only attempts the first id to keep behavior predictable.
   * @returns True if a connection attempt was initiated.
   */
  async tryAutoReconnect(): Promise<boolean> {
    // Prevent multiple concurrent reconnection attempts
    let isReconnecting: boolean = false;
    if (this.mIsAutoReconnecting) {
      return isReconnecting;
    }
    this.mIsAutoReconnecting = true;
    try {
      // Retrieves the previously persisted Bluetooth virtual MAC addresses by calling the `getPersistentDeviceIds()` method.
      const ids = this.syncPersistentDeviceIds();
      // [StartExclude tryAutoReconnect]
      if (!ids.length) {
        return isReconnecting;
      }
      if (this.mConnectBluetoothDevice.connectionState === ConnectionState.STATE_CONNECTED ||
        this.mConnectBluetoothDevice.connectionState === ConnectionState.STATE_CONNECTING) {
        return isReconnecting;
      }
      // [EndExclude tryAutoReconnect]
      // Get the most recent device ID
      const targetId = ids[0];
      // Retrieve device name and update UI state related
      // [StartExclude tryAutoReconnect]
      const deviceName = connection.getRemoteDeviceName(targetId) ?? '';
      const autoDevice = this.getDevice(targetId, deviceName);
      this.mConnectBluetoothDevice = this.cloneDevice(autoDevice);
      this.notifyConnectDeviceChanged();
      this.upsertAvailableDevice(targetId, deviceName, this.mConnectBluetoothDevice.connectionState);
      // [EndExclude tryAutoReconnect]
      try {
        this.mGattClientDevice = ble.createGattClientDevice(targetId);
        const ret = this.connectInner(this.mGattClientDevice);
        isReconnecting = ret;
        if (!ret) {
          this.resetConnectionState();
        }
      } catch (error) {
        Logger.error(`BluetoothClientModel, createGattClientDevice failed, error info: ${JSON.stringify(error)}`);
      }
    } catch (error) {
      Logger.error(`[BluetoothClientModel.tryAutoReconnect] ${JSON.stringify(error)}`);
    } finally {
      this.mIsAutoReconnecting = false;
    }
    return isReconnecting;
  }
  // [End tryAutoReconnect]

  /**
   * Force disconnect and close current GATT connection immediately.
   */
  forceDisconnect(): void {
    this.disconnectInner(this.mGattClientDevice);
    this.closeInner(this.mGattClientDevice);
  }

  /**
   * Query whether Bluetooth is enabled or turning on.
   * @returns True when enabled or turning on; false otherwise.
   */
  isBluetoothEnabled(): boolean {
    let state: access.BluetoothState = access.BluetoothState.STATE_OFF;
    try {
      state = access.getState();
    } catch (error) {
      Logger.error(`BluetoothClientModel, isBluetoothEnabled failed, error info: ${JSON.stringify(error)}`);
    }
    Logger.info(`isBluetoothEnabled: state = ${state}`);
    if (state === access.BluetoothState.STATE_ON || state === access.BluetoothState.STATE_TURNING_ON) {
      return true;
    }
    return false;
  }

  /**
   * Enable Bluetooth and subscribe to adapter state changes.
   */
  enableBluetooth() {
    this.subscribeBTStateChange();
    try {
      access.enableBluetooth();
    } catch (err) {
      Logger.error(`enableBluetooth: err = ${JSON.stringify(err)}`);
    }
  }

  /**
   * Disable Bluetooth and unsubscribe from adapter state changes.
   */
  disableBluetooth() {
    this.unsubscribeBTStateChange();
    try {
      access.disableBluetooth();
    } catch (err) {
      Logger.error(`disableBluetooth: err = ${JSON.stringify(err)}`);
    }
  }

  // [Start startBLEScan]
  /**
   * Start BLE scan with custom filter;
   * @returns `StartBLEScanResult` status code.
   */
  startBLEScan(): StartBLEScanResult {
    clearTimeout(this.mTimeoutID);
    this.mTimeoutID = -1;
    if (!this.isBluetoothEnabled()) {
      Logger.info('startBLEScan: bluetooth is disable');
      this.enableBluetooth();
      return StartBLEScanResult.BLUETOOTH_ENABLING;
    }
    this.onBLEDeviceFind();
    const ret = this.startBLEScanInner();
    if (ret) {
      // BLE Scanning Timeout Protection
      this.startScanTimeoutCountdown();
    }
    return ret ? StartBLEScanResult.SUCCESS : StartBLEScanResult.FAILURE;
  }
  // [End startBLEScan]

  // [Start stopBLEScan]
  /**
   * Stop BLE scanning and remove discovery callbacks.
   * @returns `StopBLEScanResult` status code.
   */
  stopBLEScan(): StopBLEScanResult {
    clearTimeout(this.mTimeoutID);
    this.mTimeoutID = -1;
    this.offBLEDeviceFind();
    // This method calls ble.stopBLEScan() to stop the BLE scan.
    const ret = this.stopBLEScanInner();
    return ret ? StopBLEScanResult.SUCCESS : StopBLEScanResult.FAILURE;
  }
  // [End stopBLEScan]

  /**
   * Starts a countdown timer for BLE scan timeout protection.
   * When timeout is reached, automatically stops the BLE scan.
   */
  private startScanTimeoutCountdown(): void {
    clearTimeout(this.mTimeoutID);
    this.mTimeoutID = setTimeout(() => {
      Logger.warn('[BluetoothClientModel.startScanTimeoutCountdown] Scan timeout, stopping BLE scan automatically.');
      this.stopBLEScan();
    }, SCAN_TIMEOUT_MS);
  }

  /**
   * Connect to the specified device. If already created, reuses the client device.
   * @param bluetoothDevice Target device to connect to.
   * @returns True if a connection attempt was issued.
   */
  connect(bluetoothDevice: BluetoothDevice) {
    if (!bluetoothDevice?.deviceId) {
      return false;
    }
    if (this.mGattClientDevice && this.mConnectBluetoothDevice &&
      this.mConnectBluetoothDevice.deviceId === bluetoothDevice.deviceId) {
      const ret: boolean = this.connectInner(this.mGattClientDevice);
      return ret;
    }
    this.close();

    const isConnectionDeviceChanged = this.checkConnectionDeviceChanged(bluetoothDevice);
    if (isConnectionDeviceChanged) {
      this.mConnectBluetoothDevice = this.cloneDevice(bluetoothDevice);
      this.notifyConnectDeviceChanged();
    }
    this.upsertAvailableDevice(this.mConnectBluetoothDevice.deviceId ?? '',
      this.mConnectBluetoothDevice.deviceName ?? '',
      this.mConnectBluetoothDevice.connectionState);
    let ret: boolean = false;
    try {
      this.mGattClientDevice = ble.createGattClientDevice(bluetoothDevice.deviceId);
      ret = this.connectInner(this.mGattClientDevice);
      if (ret) {
        Logger.info('Trying to create a new connection.');
      } else {
        Logger.info('Trying to create a new connection fail.');
        this.close();
      }
    } catch (error) {
      Logger.error(`BluetoothClientModel, createGattClientDevice failed, error info: ${JSON.stringify(error)}`);
    }

    return ret;
  }

  /**
   * Disconnect the current connection (if any).
   */
  disconnect() {
    this.disconnectInner(this.mGattClientDevice);
  }

  /**
   * Close and release the current GATT client device.
   */
  close() {
    this.closeInner(this.mGattClientDevice);
  }

  /**
   * Get the current connection state of the tracked device.
   * @returns Numeric state from ConnectionState.
   */
  getConnectionState(): number {
    return this.mConnectBluetoothDevice.connectionState ?? 0;
  }

  /**
   * Reset connection state to DISCONNECTED (used e.g. on connect timeout).
   */
  changeConnectState() {
    this.resetConnectionState();
  }

  /**
   * Delete a device by id. (Maintains persistent device list concurrently.)
   * @param deviceId Random device address to delete.
   */
  deleteDeviceById(deviceId: string | undefined): void {
    if (!deviceId) {
      Logger.warn('[BluetoothClientModel.deleteDeviceById] deviceId is empty.');
      return;
    }
    const targetId: string = deviceId ? deviceId.trim() : '';
    if (!targetId) {
      Logger.warn('[BluetoothClientModel.deleteDeviceById] deviceId after trim is empty.');
      return;
    }
    const isCurrentDevice: boolean = this.mConnectBluetoothDevice.deviceId === targetId;
    if (isCurrentDevice) {
      this.forceDisconnect();
      this.mConnectBluetoothDevice = this.cloneDevice();
      this.notifyConnectDeviceChanged();
      this.mLastConnectedDevice = this.cloneDevice();
      this.notifyLastConnectedDeviceChanged();
      this.currentHeartRate = 0;
      this.notifyHeartRateChanged(0);
    }
    const originLength: number = this.mAvailableDevices.length;
    this.mAvailableDevices = this.mAvailableDevices.filter(item => item.deviceId !== targetId);
    if (originLength !== this.mAvailableDevices.length) {
      this.notifyAvailableDevicesChanged();
    }
    let ids: Array<string> = [];
    try {
      ids = access.getPersistentDeviceIds() ?? [];
    } catch (error) {
      Logger.error(`Query persistent device ids failed, error info:${JSON.stringify(error)}`);
    }
    if (ids.includes(targetId)) {
      access.deletePersistentDeviceId(targetId)
        .then(() => {
          Logger.info(`Successfully deleted persistent random device address, deleted id:${targetId}`);
          this.syncPersistentDeviceIds();
        })
        .catch(() => {
          Logger.warn(`Failed to delete a persistent random device address, deleted id:${targetId}`);
        })
    } else {
      this.mPersistentDeviceIds = this.mPersistentDeviceIds.filter(item => item !== targetId);
      this.notifyPersistentDeviceIdsChanged();
    }
    Logger.info(`[BluetoothClientModel.deleteDeviceById] targetId=${targetId} removed.`);
  }

  /**
   * Get snapshot of currently available devices
   */
  getAvailableDevicesSnapshot(): Array<BluetoothDevice> {
    return this.mAvailableDevices.map(item => this.cloneDevice(item));
  }

  /**
   * Get snapshot of currently connected devices
   */
  getConnectDeviceSnapshot(): BluetoothDevice {
    return this.cloneDevice(this.mConnectBluetoothDevice);
  }

  /**
   * Get snapshot of last connected device
   */
  getLastConnectedDeviceSnapshot(): BluetoothDevice {
    return this.cloneDevice(this.mLastConnectedDevice);
  }

  /**
   * Get snapshot of persistent device ID list
   */
  getPersistentDeviceIdsSnapshot(): Array<string> {
    return [...this.mPersistentDeviceIds];
  }

  /**
   * Get snapshot of current heart rate value
   */
  getHeartRateSnapshot(): number {
    return this.currentHeartRate;
  }

  /**
   * Get snapshot of Bluetooth switch status
   */
  getBluetoothEnableSnapshot(): boolean {
    return this.bluetoothEnabled;
  }

  // [Start onBLECharacteristicChange]
  /**
   * Characteristic change handler that parses a simple HR Measurement (Flags, HR).
   * @param data Characteristic payload event.
   */
  private BLECharacteristicChangeFunc = (data: ble.BLECharacteristic): void => {
    let characteristicValue: ArrayBuffer = data.characteristicValue;
    let byteArr = CommonUtils.arrayBuffer2ByteArray(characteristicValue);
    if (!byteArr || byteArr.length < 2) {
      Logger.warn(`[BluetoothClientModel.BLECharacteristicChangeFunc] Invalid heart rate payload: ${JSON.stringify(byteArr)}`);
      return;
    }
    let heartRate = byteArr[1];
    this.currentHeartRate = heartRate;
    this.notifyHeartRateChanged(heartRate);
  }

  /**
   * Register a listener for characteristic value changes.
   */
  private onBLECharacteristicChange() {
    if (!this.mGattClientDevice) {
      return;
    }
    try {
      this.mGattClientDevice.on('BLECharacteristicChange', this.BLECharacteristicChangeFunc);
    } catch (error) {
      Logger.error(`BluetoothClientModel, onBLECharacteristicChange failed, error info:${JSON.stringify(error)}`);
    }
  }
  // [End onBLECharacteristicChange]

  /**
   * Unregister characteristic change listener.
   */
  private offBLECharacteristicChange() {
    if (!this.mGattClientDevice) {
      return;
    }
    try {
      this.mGattClientDevice.off('BLECharacteristicChange');
    } catch (err) {
      Logger.error(`offBLECharacteristicChange: err = ${JSON.stringify(err)}`);
    }
  }

  // [Start client_subscribeBTStateChange]
  /**
   * Bluetooth adapter state change listener.
   * @param data New Bluetooth state.
   */
  private stateChangeFunc = (data: access.BluetoothState): void => {
    if (data === access.BluetoothState.STATE_ON) {
      this.bluetoothEnabled = true;
      this.notifyBluetoothStateChanged(true);
      this.startBLEScan();
    } else if (data === access.BluetoothState.STATE_OFF) {
      // Clear discovered device list and current connection status.
      // [StartExclude client_subscribeBTStateChange]
      this.bluetoothEnabled = false;
      this.notifyBluetoothStateChanged(false);
      this.mAvailableDevices = [];
      this.notifyAvailableDevicesChanged();
      this.mConnectBluetoothDevice = this.cloneDevice();
      this.notifyConnectDeviceChanged();
      this.mLastConnectedDevice = this.cloneDevice();
      this.notifyLastConnectedDeviceChanged();
      this.currentHeartRate = 0;
      this.notifyHeartRateChanged(0);
      // [EndExclude client_subscribeBTStateChange]
    }
  }

  /**
   * Subscribe to Bluetooth adapter state changes.
   */
  private subscribeBTStateChange() {
    if (this.isBTStateChangeSubscribed) {
      return;
    }
    try {
      access.on('stateChange', this.stateChangeFunc);
      this.isBTStateChangeSubscribed = true;
    } catch (err) {
      this.isBTStateChangeSubscribed = false;
      Logger.error(`onBTSateChange: err = ${JSON.stringify(err)}`);
    }
  }
  // [End client_subscribeBTStateChange]

  /**
   * Unsubscribe from Bluetooth adapter state changes.
   */
  private unsubscribeBTStateChange() {
    if (!this.isBTStateChangeSubscribed) {
      return;
    }
    try {
      access.off('stateChange');
      this.isBTStateChangeSubscribed = false;
    } catch (err) {
      this.isBTStateChangeSubscribed = false;
      Logger.error(`offBTSateChange: err = ${JSON.stringify(err)}`);
    }
  }

  // [Start onBLEDeviceFind]
  /**
   * Device discovery handler; de-duplicates、 update and insert devices.
   * @param arr List of scan results.
   */
  private BLEDeviceFindFunc = (arr: Array<ble.ScanResult>): void => {
    if (!arr.length) {
      return;
    }
    for (const result of arr) {
      let deviceId: string = result.deviceId;
      if (!deviceId) {
        continue;
      }
      let deviceName: string = result.deviceName;
      if (!deviceName) {
        try {
          let data: ArrayBuffer = result.data;
          deviceName = util.TextDecoder.create('utf-8', {
            ignoreBOM: true
          }).decodeToString(new Uint8Array(data), { stream: false });
        } catch (error) {
          Logger.error(`decode deviceName fail: ${JSON.stringify(error)}`);
        }
      }
      this.upsertAvailableDevice(deviceId, deviceName);
    }
  }

  /**
   * Subscribe to BLE device discovery events.
   */
  private onBLEDeviceFind() {
    try {
      ble.on('BLEDeviceFind', (arr: Array<ble.ScanResult>) => {
        this.BLEDeviceFindFunc(arr);
      });
    } catch (err) {
      Logger.info(`onBLEDeviceFind: err = ${JSON.stringify(err)}`);
    }
  }
  // [End onBLEDeviceFind]

  /**
   * Unsubscribe from BLE device discovery events.
   */
  private offBLEDeviceFind() {
    try {
      ble.off('BLEDeviceFind');
    } catch (err) {
      Logger.error(`offBLEDeviceFind: err = ${JSON.stringify(err)}`);
    }
  }

  // [Start onBLEConnectionStateChange]
  // [Start enableHeartRateNotification]
  /**
   * Subscribe to connection state changes on the current GATT client device.
   */
  private onBLEConnectionStateChange() {
    if (!this.mGattClientDevice) {
      return;
    }
    try {
      this.mGattClientDevice.on('BLEConnectionStateChange', this.BLEConnectionStateChangeFunc);
    } catch (err) {
      Logger.error(`onBLEConnectionStateChange: err = ${JSON.stringify(err)}`);
    }
  }

  /**
   * Handle successful GATT connection: update state, persist device and enable notifications.
   */
  private async handleGattConnected(): Promise<void> {
    // [StartExclude enableHeartRateNotification]
    this.markConnectionState(ConnectionState.STATE_CONNECTED);
    this.mLastConnectedDevice = this.cloneDevice(this.mConnectBluetoothDevice);
    this.notifyLastConnectedDeviceChanged();
    this.savePersistentDeviceId(this.mConnectBluetoothDevice.deviceId);
    // [EndExclude enableHeartRateNotification]
    // Stop scanning after connection.
    this.stopBLEScan();
    await this.enableHeartRateNotification();
  }

  // [StartExclude enableHeartRateNotification]
  /**
   * Save a random device id to system persistent list if valid and not already saved.
   * @param deviceId Random device address to persist.
   */
  private savePersistentDeviceId(deviceId: string | undefined) {
    // Validate whether the deviceId to be persisted is legal.
    // [StartExclude onBLEConnectionStateChange]
    if (!deviceId) {
      return;
    }
    if (this.mPersistentDeviceIds.includes(deviceId)) {
      return;
    }
    let isValid = false;
    try {
      isValid = access.isValidRandomDeviceId(deviceId);
    } catch (error) {
      Logger.warn(`the randomized device address application can still be used, error info: ${JSON.stringify(error)}`);
    }
    if (!isValid) {
      return;
    }
    // [EndExclude onBLEConnectionStateChange]
    access.addPersistentDeviceId(deviceId)
      .then(() => {
        this.syncPersistentDeviceIds();
      })
      .catch((err: BusinessError) => {
        Logger.warn(`Failed to persist Bluetooth device virtual MAC address, error info: ${JSON.stringify(err)}`)
      })
  }
  // [EndExclude enableHeartRateNotification]
  // [End onBLEConnectionStateChange]

  /**
   * Enable heart rate notifications by toggling notification and writing CCC descriptor.
   */
  private async enableHeartRateNotification(): Promise<void> {
    const device = this.mGattClientDevice;
    if (!device) {
      Logger.warn('[BluetoothClientModel.enableHeartRateNotification] GATT client device unavailable.');
      return;
    }
    try {
      const services: ble.GattService[] = await device.getServices();
      // Perform filtering operations to precisely locate target characteristic values and their configuration descriptors within the GATT service structure
      // [StartExclude enableHeartRateNotification]
      if (!services || services.length === 0) {
        Logger.error('[BluetoothClientModel.enableHeartRateNotification] No services found on device.');
        return;
      }

      const service = services.find(item => item.serviceUuid === BLE_SERVICE_UUID);
      if (!service) {
        Logger.error('[BluetoothClientModel.enableHeartRateNotification] Heart Rate service not found.');
        return;
      }

      const characteristic = service.characteristics?.find(item => item.characteristicUuid === BLE_CHARACTERISTIC_UUID);
      if (!characteristic) {
        Logger.error('[BluetoothClientModel.enableHeartRateNotification] Heart Rate characteristic not found.');
        return;
      }

      if (!(characteristic.properties)) {
        Logger.error('[enableHeartRateNotification] Characteristic does NOT support notify');
        return;
      }

      const descriptor = characteristic.descriptors?.find(item => item.descriptorUuid === BLE_DESCRIPTOR_UUID);
      if (!descriptor || !descriptor.serviceUuid || !descriptor.characteristicUuid || !descriptor.descriptorUuid) {
        Logger.error('[BluetoothClientModel.enableHeartRateNotification] CCC descriptor missing or incomplete.');
        return;
      }
      // [EndExclude enableHeartRateNotification]

      await new Promise<void>((resolve, reject) => {
        device.setCharacteristicChangeNotification(characteristic, true, (err: BusinessError) => {
          if (err) {
            reject(err);
          } else {
            resolve();
          }
        });
      });

      const descriptorObj: BLEDescriptor = {
        serviceUuid: descriptor.serviceUuid,
        characteristicUuid: descriptor.characteristicUuid,
        descriptorUuid: descriptor.descriptorUuid,
        descriptorValue: CommonUtils.byteArray2ArrayBuffer([0x01, 0x00])
      };
      await device.writeDescriptorValue(descriptorObj);
      Logger.info('[BluetoothClientModel.enableHeartRateNotification] Notification enabled successfully.');
    } catch (error) {
      Logger.error(`BluetoothClientModel, enableHeartRateNotification failed, error info:${JSON.stringify(error)}`);
    }
  }
  // [End enableHeartRateNotification]

  /**
   * Unsubscribe from connection state changes on the current GATT client device.
   */
  private offBLEConnectionStateChange() {
    if (!this.mGattClientDevice) {
      return;
    }
    try {
      this.mGattClientDevice.off('BLEConnectionStateChange');
    } catch (err) {
      Logger.error(`offBLEConnectionStateChange: err = ${JSON.stringify(err)}`);
    }
  }

  // [Start startBLEScanInner]
  /**
   * Internal helper to start scanning using a custom filter.
   * @returns True if scan started successfully.
   */
  private startBLEScanInner(): boolean {
    try {
      const scanFilter = this.createCustomScanFilter();
      const scanOptions: ble.ScanOptions = {
        interval: 500,
        dutyMode: ble.ScanDuty.SCAN_MODE_LOW_POWER,
        matchMode: ble.MatchMode.MATCH_MODE_AGGRESSIVE
      }
      ble.startBLEScan([scanFilter], scanOptions);
      return true;
    } catch (err) {
      Logger.error(`startBLEScanInner: err = ${JSON.stringify(err)}`);
    }
    return false;
  }

  /**
   * Create a custom scan filter that matches the demo server's manufacturer data and service UUID.
   * @returns ble.ScanFilter object.
   */
  private createCustomScanFilter(): ble.ScanFilter {
    // Manufacturer data broadcast by the server.
    const manufactureValueBuffer: Uint8Array = new Uint8Array([1, 2, 3, 4]);
    // Mask: 0xFF means match required, 0x00 means ignore that position.
    const manufactureDataMask: Uint8Array = new Uint8Array([0xFF, 0xFF, 0x00, 0x00]);
    const scanFilter: ble.ScanFilter = {
      serviceUuid: BLE_SERVICE_UUID,
      manufactureId: CUSTOM_MANUFACTURE_ID,
      manufactureData: manufactureValueBuffer.buffer,
      manufactureDataMask: manufactureDataMask.buffer
    }
    return scanFilter;
  }
  // [End startBLEScanInner]

  /**
   * Internal helper to stop scanning.
   */
  private stopBLEScanInner(): boolean {
    try {
      ble.stopBLEScan();
      return true;
    } catch (err) {
      Logger.error(`stopBLEScanInner: err = ${JSON.stringify(err)}`);
    }
    return false;
  }

  // [Start connectInner]
  /**
   * Internal helper to connect, set listeners, and update state to CONNECTING.
   * @param gattClientDevice Target GATT client device.
   * @returns True if connect() call was issued without throwing.
   */
  private connectInner(gattClientDevice: ble.GattClientDevice): boolean {
    try {
      if (!gattClientDevice) {
        return false;
      }
      this.onBLEConnectionStateChange();
      this.onBLECharacteristicChange();
      this.markConnectionState(ConnectionState.STATE_CONNECTING);
      gattClientDevice.connect();
      return true;
    } catch (err) {
      Logger.error(`connectInner: err = ${JSON.stringify(err)}`);
      return false;
    }
  }
  // [End connectInner]

  /**
   * Internal helper to disconnect and update state to DISCONNECTING.
   * @param gattClientDevice Current GATT client device.
   */
  private disconnectInner(gattClientDevice: ble.GattClientDevice | null) {
    try {
      if (!gattClientDevice) {
        return;
      }
      this.offBLEConnectionStateChange();
      this.offBLECharacteristicChange();
      this.markConnectionState(ConnectionState.STATE_DISCONNECTING);
      gattClientDevice.disconnect();
    } catch (err) {
      Logger.error(`disconnectInner: err = ${JSON.stringify(err)}`);
    }
  }

  /**
   * Internal helper to close the client device and reset internal state.
   * @param gattClientDevice Current GATT client device.
   */
  private closeInner(gattClientDevice: ble.GattClientDevice | null) {
    try {
      if (!gattClientDevice) {
        this.resetConnectionState();
        return;
      }
      gattClientDevice.close();
    } catch (err) {
      Logger.error(`closeInner: err = ${JSON.stringify(err)}`);
    }
    this.resetConnectionState();
    this.release();
  }

  /**
   * Release references to the current GATT client device and timeouts.
   */
  private release() {
    this.mGattClientDevice = null;
    this.mTimeoutID = -1;
  }

  /**
   * Create a BluetoothDevice by id and name with DISCONNECTED default state.
   * @param deviceId Random device address.
   * @param deviceName Friendly name.
   * @returns New BluetoothDevice instance.
   */
  private getDevice(deviceId: string, deviceName: string): BluetoothDevice {
    return this.cloneDevice(undefined, {
      deviceId,
      deviceName,
      connectionState: ConnectionState.STATE_DISCONNECTED
    });
  }

  /**
   * Synchronize system-persistent random device IDs into cache and notify the upper layer.
   * @returns Array of persistent ids.
   */
  private syncPersistentDeviceIds(): Array<string> {
    let ids: Array<string> = [];
    try {
      ids = access.getPersistentDeviceIds() ?? [];
    } catch (error) {
      Logger.warn(`[BluetoothClientModel.syncPersistentDeviceIds] ${JSON.stringify(error)}`);
    }
    this.mPersistentDeviceIds = ids;
    this.notifyPersistentDeviceIdsChanged();
    return ids;
  }

  /**
   * Handle GATT disconnection by resetting state and releasing resources.
   */
  private handleGattDisconnected(): void {
    this.resetConnectionState();
    this.release();
  }

  /**
   * Centralized connection state reset and LocalStorage synchronization.
   */
  private resetConnectionState(): void {
    const deviceId = this.mConnectBluetoothDevice?.deviceId;
    if (deviceId) {
      this.markConnectionState(ConnectionState.STATE_DISCONNECTED);
    } else {
      this.mConnectBluetoothDevice = this.cloneDevice();
      this.notifyConnectDeviceChanged();
      this.notifyAvailableDevicesChanged();
    }
    this.currentHeartRate = 0;
    this.notifyHeartRateChanged(0);
  }

  /**
   * Update current connection state's snapshot and reflect in the available list.
   * @param state New connection state.
   */
  private markConnectionState(state: number): void {
    const isStateChanged = state !== this.mConnectBluetoothDevice.connectionState;
    if (isStateChanged) {
      this.mConnectBluetoothDevice = this.cloneDevice(this.mConnectBluetoothDevice, { connectionState: state });
      this.notifyConnectDeviceChanged();
    }
    const deviceId = this.mConnectBluetoothDevice.deviceId ?? '';
    const deviceName = this.mConnectBluetoothDevice.deviceName ?? '';
    if (deviceId) {
      this.upsertAvailableDevice(deviceId, deviceName, state);
    } else {
      this.notifyAvailableDevicesChanged();
    }
  }

  /**
   * Insert or update a device in the available list; minimizes UI flicker.
   * @param deviceId Random device address.
   * @param deviceName Human-readable name if available.
   * @param connectionState Optional connection state override.
   */
  private upsertAvailableDevice(deviceId: string, deviceName: string, connectionState?: number): void {
    if (!deviceId) {
      return;
    }
    const index = this.mAvailableDevices.findIndex(item => item.deviceId === deviceId);
    let updated = false;
    if (index >= 0) {
      const current = this.mAvailableDevices[index];
      const currentName = current.deviceName ?? '';
      const candidateName = deviceName || currentName;
      const currentState = current.connectionState ?? ConnectionState.STATE_DISCONNECTED;
      const candidateState = connectionState ?? currentState;
      const isNameChanged = candidateName !== currentName;
      const isStateChanged = candidateState !== currentState;
      if (!isNameChanged && !isStateChanged) {
        return;
      }
      const merged = this.cloneDevice(current, {
        deviceId,
        deviceName: candidateName,
        connectionState: candidateState
      });
      this.mAvailableDevices.splice(index, 1, merged);
      updated = true;
    } else {
      const newDevice = this.cloneDevice(undefined, {
        deviceId,
        deviceName,
        connectionState
      });
      this.mAvailableDevices.push(newDevice);
      updated = true;
    }
    if (updated) {
      this.notifyAvailableDevicesChanged();
    }
  }

  /**
   * Check whether the connection target device differs from the current one.
   * @param bluetoothDevice Candidate device.
   * @returns True if any of id/name/state changed.
   */
  private checkConnectionDeviceChanged(bluetoothDevice: BluetoothDevice): boolean {
    const isIdChanged = bluetoothDevice.deviceId !== this.mConnectBluetoothDevice.deviceId;
    const isNameChanged = bluetoothDevice.deviceName !== this.mConnectBluetoothDevice.deviceName;
    const isStateChanged = bluetoothDevice.connectionState !== this.mConnectBluetoothDevice.connectionState;
    if (isIdChanged || isNameChanged || isStateChanged) {
      return true;
    } else {
      return false;
    }
  }

  private notifyAvailableDevicesChanged(): void {
    const snapshot = this.mAvailableDevices.map(item => this.cloneDevice(item));
    this.listener?.onAvailableDevicesChanged?.(snapshot);
  }

  private notifyConnectDeviceChanged(): void {
    this.listener?.onConnectDeviceChanged?.(this.cloneDevice(this.mConnectBluetoothDevice));
  }

  private notifyHeartRateChanged(heartRate: number): void {
    this.listener?.onHeartRateChanged?.(heartRate);
  }

  private notifyPersistentDeviceIdsChanged(): void {
    this.listener?.onPersistentDeviceIdsChanged?.([...this.mPersistentDeviceIds]);
  }

  private notifyLastConnectedDeviceChanged(): void {
    this.listener?.onLastConnectedDeviceChanged?.(this.cloneDevice(this.mLastConnectedDevice));
  }

  private notifyBluetoothStateChanged(enabled: boolean = this.bluetoothEnabled): void {
    this.listener?.onBluetoothStateChanged?.(enabled);
  }

  private emitAll(): void {
    this.notifyAvailableDevicesChanged();
    this.notifyConnectDeviceChanged();
    this.notifyHeartRateChanged(this.currentHeartRate);
    this.notifyPersistentDeviceIdsChanged();
    this.notifyLastConnectedDeviceChanged();
    this.notifyBluetoothStateChanged(this.bluetoothEnabled);
  }

  /**
   * Helper to clone a BluetoothDevice and optionally override fields.
   * @param device Source device to copy from.
   * @param updates Partial overrides.
   * @returns A new BluetoothDevice instance with merged values.
   */
  private cloneDevice(device?: BluetoothDevice,
    updates: Partial<BluetoothDevice> = {}): BluetoothDevice {
    const clone = new BluetoothDevice();
    clone.deviceId = updates.deviceId ?? device?.deviceId ?? '';
    clone.deviceName = updates.deviceName ?? device?.deviceName ?? '';
    if (updates.connectionState !== undefined) {
      clone.connectionState = updates.connectionState;
    } else if (device?.connectionState !== undefined) {
      clone.connectionState = device.connectionState;
    } else {
      clone.connectionState = ConnectionState.STATE_DISCONNECTED;
    }
    return clone;
  }
}