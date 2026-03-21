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

import { Permissions } from '@kit.AbilityKit';

// Minimum heart rate used in random demo broadcasting.
export const MIN_HEART_RATE = 40;

// Maximum heart rate used in random demo broadcasting.
export const MAX_HEART_RATE = 200;

// Maximum the byte length of bluetooth name.
export const MAX_BLUETOOTH_NAME_LENGTH = 22;

// Permissions required by BLE advertising and persistent device id usage.
export const PERMISSION_LIST: Array<Permissions> = [
  'ohos.permission.ACCESS_BLUETOOTH'
];

/**
 * Connection state constants (mirrors typical lifecycle).
 */
export enum ConnectionState {
  STATE_CONNECTING = 1,
  STATE_CONNECTED = 2,
  STATE_DISCONNECTING = 3,
  STATE_DISCONNECTED = 4
}

// Vertical spacing between list items.
export const LIST_SPACE: number = 20;

// Connection timeout threshold (milliseconds).
export const CONNECT_TIMEOUT_MS: number = 10000;

// Maximum BLE scanning duration to prevent unlimited scanning (milliseconds).
export const SCAN_TIMEOUT_MS: number = 15000;

// `Constants used in the HeartRate.ets page`
// Navigation bar height in vp.
export const HEIGHT_NAVIGATION_BAR = 64;

// Height of each top-row statistic box.
export const HEIGHT_TOP_ROW = 40;

// Horizontal margin around the graph/statistics area.
export const MARGIN_HORIZONTAL = 60;

// Threshold for "too low" heart rate warning (bpm).
export const HEART_RATE_TOO_LOW = 50;

// Threshold for "too high" heart rate warning (bpm).
export const HEART_RATE_TOO_HIGH = 100;

// `Constants used in the Index.ets page`
export const BLUETOOTH_SERVER_PAGE_NAME = 'BluetoothServerView';

export const BLUETOOTH_CLIENT_PAGE_NAME = 'BluetoothClientView';

export const HEART_RATE_PAGE_NAME = 'HeartRateView';

// `Constants used in the HeartRateGraph.ets page`
// Number of samples preserved/displayed on the graph.
export const SIZE: number = 12;

// Number of horizontal/vertical coordinate lines.
export const COORDINATE_SIZE: number = 5;

// Color of the heart rate polyline.
export const COLOR_LINE: string = '#FF0A59F7';

// Placeholder text for timestamps when disconnected/inactive.
export const TIME_PLACEHOLDER: string = '--:--:--';

// Common BLE UUID constants to avoid magic strings.
export const BLE_SERVICE_UUID: string = '0000180D-0000-1000-8000-00805F9B34FB';

export const BLE_CHARACTERISTIC_UUID: string = '00002A37-0000-1000-8000-00805F9B34FB';

export const BLE_DESCRIPTOR_UUID: string = '00002902-0000-1000-8000-00805F9B34FB';

// AppStorage key for persistent device id list snapshot.
export const PERSISTENT_DEVICE_STORAGE_KEY: string = 'persistentDeviceIds';

// AppStorage key for last connected device snapshot.
export const LAST_CONNECTED_DEVICE_KEY: string = 'lastConnectedDevice';

// Custom manufacturer device ID
export const CUSTOM_MANUFACTURE_ID: number = 0x027D;
