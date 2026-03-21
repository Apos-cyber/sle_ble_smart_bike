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
import { ConnectionState } from '../contants/CommonConstants';

/**
 * Simple BLE device model used by the client view model and UI.
 */
export default class BluetoothDevice {
  /** Random device address. */
  deviceId: string = '';
  /** Device display name. */
  deviceName: string = '';
  /** Current connection state, defaults to disconnected. */
  connectionState: ConnectionState = ConnectionState.STATE_DISCONNECTED;
}