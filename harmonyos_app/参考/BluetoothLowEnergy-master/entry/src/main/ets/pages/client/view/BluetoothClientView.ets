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
import { Logger } from '../../../utils/Logger';
import { AlertDialog, window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import BluetoothClientViewModel from '../BluetoothClientViewModel';
import BluetoothDevice from '../../../model/BluetoothDevice';
import CommonUtils from '../../../utils/CommonUtils';
import {
  CONNECT_TIMEOUT_MS,
  ConnectionState,
  HEART_RATE_PAGE_NAME,
  LIST_SPACE,
  PERMISSION_LIST
} from '../../../contants/CommonConstants';

// Map device key to timeout id, allowing restoration across component rebuilds.
const connectTimeoutMap: Map<string, number> = new Map();

@Builder
export function BluetoothClientViewBuilder() {
  BluetoothClientView();
}

/**
 * BLE client device list page.
 */
@ComponentV2
export struct BluetoothClientView {
  @Local bluetoothClientViewModel: BluetoothClientViewModel = BluetoothClientViewModel.getInstance();
  // Reference to the main window for orientation control.
  private windowClass: window.Window | undefined = undefined;
  // Page-level timeout id used during auto-reconnect attempts.
  private timeoutId: number | undefined = undefined;

  private get availableDevices(): Array<BluetoothDevice> {
    return this.bluetoothClientViewModel.availableDevices;
  }

  private get connectBluetoothDevice(): BluetoothDevice {
    return this.bluetoothClientViewModel.connectBluetoothDevice;
  }

  /**
   * Set the window orientation.
   * @param orientation Orientation constant.
   */
  setOrientation(orientation: number) {
    this.windowClass?.setPreferredOrientation(orientation).then(() => {
      Logger.info('setWindowOrientation Succeeded');
    }).catch((err: BusinessError) => {
      Logger.error(`setWindowOrientation Failed. Cause:${JSON.stringify(err)}`);
    })
  }

  /**
   * Lifecycle: called when the page becomes visible.
   * Resets to unspecified orientation to allow system choice.
   */
  async onPageShow(): Promise<void> {
    this.setOrientation(window.Orientation.UNSPECIFIED);
  }

  /**
   * Lifecycle: called before the page is shown.
   * Acquires the main window, requests permissions, sets portrait orientation,
   * and attempts auto-reconnect with a timeout reminder.
   */
  async aboutToAppear() {
    this.windowClass = CommonUtils.getMainWindow();
    CommonUtils.checkPermissions(PERMISSION_LIST, this.getUIContext());
    this.setOrientation(window.Orientation.PORTRAIT);
    const isReconnecting = await this.bluetoothClientViewModel.tryAutoReconnect();
    if (isReconnecting) {
      clearTimeout(this.timeoutId);
      this.timeoutId = setTimeout(() => {
        // Only show when still connecting after the timeout.
        if (this.connectBluetoothDevice.connectionState === ConnectionState.STATE_CONNECTING) {
          CommonUtils.showToast(this.getUIContext(), $r('app.string.connection_failed_please_rescan'));
          // Reset to allow another attempt
          this.bluetoothClientViewModel.changeConnectState();
        }
      }, CONNECT_TIMEOUT_MS);
    }
  }

  /**
   * Lifecycle: stop scanning, close connection, and restore portrait orientation.
   */
  aboutToDisappear(): void {
    clearTimeout(this.timeoutId);
    this.timeoutId = undefined;
    this.bluetoothClientViewModel.stopBLEScan();
    this.bluetoothClientViewModel.close();
    this.setOrientation(window.Orientation.PORTRAIT);
  }

  /**
   * Title builder for the navigation destination.
   */
  @Builder
  NavDestinationTitle() {
    Column() {
      Text($r('app.string.list_of_bluetooth_devices'))
        .fontSize(20)
        .lineHeight(42)
        .fontWeight(700)
        .width('100%')
        .padding({ left: 12 })
        .opacity(0.9)
    }
    .width('100%')
  }

  /**
   * Build the BLE client page UI with a device list and scan button.
   */
  build() {
    NavDestination() {
      Column() {
        if (this.availableDevices && this.availableDevices.length > 0 && this.availableDevices[0].deviceId) {
          List({ space: LIST_SPACE, initialIndex: 0 }) {
            ForEach(this.availableDevices as BluetoothDevice[], (item: BluetoothDevice, index: number) => {
              ListItem() {
                BluetoothDeviceItem({
                  bluetoothDevice: item,
                  index: index,
                  viewModel: this.bluetoothClientViewModel
                })
              }
              .id(item.deviceId ?? `available-${index}`)
              .width('100%')
              .height(76)
              .borderRadius(16)
              .backgroundColor(Color.White)
            }, (device: BluetoothDevice, index: number) => index + '_' + JSON.stringify(device));
          }
          .scrollBar(BarState.Auto)
          .width('100%')
          .height('100%')
          .layoutWeight(1)
          .padding({
            left: 16,
            top: 16,
            right: 16,
            bottom: 0
          })
        } else {
          EmptyPageBuilder($r('app.media.bg_empty_page'), $r('app.string.no_equipment'))
        }
        Row() {
          Button($r('app.string.search_device'))
            .id('btn_start_scan')
            .fontSize(16)
            .onClick(() => {
              const ret = this.bluetoothClientViewModel.startBLEScan();
              if (!ret) {
                Logger.info(`startBLEScan: ret= ${ret}`);
              }
            })
            .width('100%')
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
      .width('100%')
      .height('100%')
    }
    .padding({
      top: 32,
      bottom: 32
    })
    .title(this.NavDestinationTitle())
    .backgroundColor('#F1F3F5')
  }
}

/**
 * List item component for a single Bluetooth device record.
 */
@ComponentV2
struct BluetoothDeviceItem {
  // Device model for this row (received via @Prop).
  @Param @Require bluetoothDevice: BluetoothDevice;
  // Row index in the list.
  @Param @Require index: number;
  // Client ViewModel singleton instance for data operations.
  @Param @Require viewModel: BluetoothClientViewModel;
  // Current connection state for this row device.
  @Local curConnectionState: number | undefined = ConnectionState.STATE_DISCONNECTED;
  // Navigation stack for pushing the HeartRate page.
  @Consumer('NavPathStack') pathStack: NavPathStack = new NavPathStack();
  // Timeout id for connection timeout reminder.
  private connectTimeout: number = -1;
  // Long press confirm dialog to delete the device from records.
  private dialogControllerConfirm: CustomDialogController = new CustomDialogController({
    builder: AlertDialog({
      primaryTitle: $r('app.string.alertDialog_primary_title'),
      secondaryTitle: this.bluetoothDevice.deviceId,
      content: $r('app.string.alertDialog_content'),
      primaryButton: {
        value: $r('app.string.alertDialog_primary_button_value'),
        action: () => {
        },
      },
      secondaryButton: {
        value: $r('app.string.alertDialog_secondary_button_value'),
        role: ButtonRole.ERROR,
        action: () => {
          this.viewModel.deleteDeviceById(this.bluetoothDevice.deviceId);
        }
      },
    }),
  });

  /**
   * Lifecycle: initialize language flag and restore timeout if connecting.
   */
  aboutToAppear(): void {
    this.curConnectionState = this.bluetoothDevice.connectionState;
    if (this.curConnectionState === ConnectionState.STATE_CONNECTING) {
      this.restoreConnectTimeout();
    } else {
      this.clearConnectTimeout();
    }
  }

  /**
   * Lifecycle: clear timeout only when not connecting to avoid interrupting pending reminder.
   */
  aboutToDisappear(): void {
    if (this.curConnectionState !== ConnectionState.STATE_CONNECTING) {
      this.clearConnectTimeout();
    }
  }

  /**
   * Prop watcher: synchronize row state from the updated device information.
   */
  @Monitor('bluetoothDevice.connectionState')
  onBluetoothDeviceChange(): void {
    this.curConnectionState = this.bluetoothDevice.connectionState;
    if (this.curConnectionState === ConnectionState.STATE_CONNECTING) {
      this.restoreConnectTimeout();
    } else {
      this.clearConnectTimeout();
    }
  }

  /**
   * Build a row with device name/id, connect/disconnect button, and connected indicator.
   */
  build() {
    Row() {
      Column() {
        Text(this.bluetoothDevice.deviceName)
          .fontSize(16)
          .fontColor('#333333')
          .textAlign(TextAlign.Start)
          .width('100%')

        Text(this.bluetoothDevice.deviceId)
          .fontSize(14)
          .fontColor(Color.Black)
          .opacity(0.6)
          .margin({ top: 6 })
          .textAlign(TextAlign.Start)
          .width('100%')
      }
      .width('60%')
      .height('100%')
      .justifyContent(FlexAlign.Center)

      Button({ type: ButtonType.Capsule, stateEffect: true }) {
        Row() {
          if (this.curConnectionState === ConnectionState.STATE_CONNECTING) {
            LoadingProgress().width(20).height(20).margin({ left: 12 }).color('#FF0A59F7')
          }
          Text(this.getConnectionStateDescription())
            .fontSize(16)
            .fontColor('#FF0A59F7')
            .margin({ left: this.curConnectionState === ConnectionState.STATE_CONNECTING ? 5 : 12, right: 12 })
        }
        .alignItems(VerticalAlign.Center)
        .justifyContent(FlexAlign.Center)
      }
      .id(`btn_connect_capsule${this.index}`)
      .height(40)
      .backgroundColor('#0D000000')
      .visibility(this.isConnectButtonVisible() ? Visibility.Visible : Visibility.None)
      .enabled(this.isConnectButtonEnabled())
      .onClick(() => {
        if (this.curConnectionState === ConnectionState.STATE_DISCONNECTED) {
          const isConnected = this.viewModel.connect(this.bluetoothDevice);
          if (isConnected) {
            this.startConnectTimeout();
          } else {
            CommonUtils.showToast(this.getUIContext(), $r('app.string.connection_failed_please_rescan'));
          }
        } else if (this.curConnectionState === ConnectionState.STATE_CONNECTED) {
          this.viewModel.disconnect();
        }
      })

      Row() {
        Text($r('app.string.connected'))
          .fontSize(16)
          .fontColor(Color.Black)
          .opacity(0.6)
          .margin({ right: 8 })

        Image($r('app.media.ic_public_arrow_right'))
          .width(13)
          .height(13)
      }
      .visibility(this.curConnectionState === ConnectionState.STATE_CONNECTED ? Visibility.Visible :
        Visibility.None)
      .justifyContent(FlexAlign.End)
    }
    .id(`list_item${this.index}`)
    .width('100%')
    .height('100%')
    .padding({
      left: 16,
      right: 16,
    })
    .justifyContent(FlexAlign.SpaceBetween)
    .onClick(() => {
      if (this.curConnectionState === ConnectionState.STATE_CONNECTED) {
        this.pathStack.pushPath({ name: HEART_RATE_PAGE_NAME });
      }
    })
    .gesture(
      LongPressGesture({ repeat: false })
        .onAction(() => {
          this.dialogControllerConfirm.open();
        })
    )
  }

  /**
   * Create a stable key to bind timeout ids either by device id or list index.
   * @returns Key string.
   */
  private getDeviceKey(): string {
    return this.bluetoothDevice.deviceId && this.bluetoothDevice.deviceId.length > 0 ?
      this.bluetoothDevice.deviceId : `index-${this.index}`;
  }

  /**
   * Restore timeout id from global map when the row is recreated during connecting state.
   */
  private restoreConnectTimeout(): void {
    const key = this.getDeviceKey();
    if (connectTimeoutMap.has(key)) {
      this.connectTimeout = connectTimeoutMap.get(key)!;
    }
  }

  /**
   * Start a connect timeout reminder that shows a toast and resets state if still connecting.
   */
  private startConnectTimeout(): void {
    this.clearConnectTimeout();
    const key = this.getDeviceKey();
    const timeoutId: number = setTimeout(() => {
      connectTimeoutMap.delete(key);
      this.connectTimeout = -1;
      if (this.curConnectionState === ConnectionState.STATE_CONNECTING) {
        CommonUtils.showToast(this.getUIContext(), $r('app.string.connection_failed_please_rescan'));
        this.viewModel.changeConnectState();
      }
    }, CONNECT_TIMEOUT_MS);
    this.connectTimeout = timeoutId;
    connectTimeoutMap.set(key, timeoutId);
  }

  /**
   * Clear and cancel the connect timeout if present.
   */
  private clearConnectTimeout(): void {
    const key = this.getDeviceKey();
    const timeoutId = this.connectTimeout !== -1 ? this.connectTimeout : connectTimeoutMap.get(key);
    if (timeoutId !== undefined && timeoutId !== -1) {
      clearTimeout(timeoutId);
    }
    connectTimeoutMap.delete(key);
    this.connectTimeout = -1;
  }

  /**
   * Whether the connect button should be visible (hidden when already connected).
   * @returns True if visible.
   */
  private isConnectButtonVisible(): boolean {
    return this.curConnectionState !== ConnectionState.STATE_CONNECTED;
  }

  /**
   * Whether the connect button should be enabled (disabled while connecting).
   * @returns True if enabled.
   */
  private isConnectButtonEnabled(): boolean {
    return this.curConnectionState === ConnectionState.STATE_DISCONNECTED;
  }

  /**
   * Get user-facing text for the connect/disconnect button based on current state.
   * @returns Localized ResourceStr for the button title.
   */
  private getConnectionStateDescription(): ResourceStr {
    let description = $r('app.string.connect');
    switch (this.curConnectionState) {
      case ConnectionState.STATE_CONNECTING:
        description = $r('app.string.connecting');
        break;
      case ConnectionState.STATE_DISCONNECTING:
        description = $r('app.string.disconnecting');
        break;
      case ConnectionState.STATE_CONNECTED:
        description = $r('app.string.connect');
        break;
      default:
        description = $r('app.string.connect');
    }
    return description;
  }
}

@Builder
function EmptyPageBuilder(img: ResourceStr | PixelMap, message: ResourceStr) {
  Column() {
    Image(img)
      .width(120)
      .aspectRatio(1)

    Text(message)
      .fontSize(14)
      .fontColor(Color.Black)
      .opacity(0.9)
      .margin({ top: 8 })
  }
  .width('100%')
  .height('100%')
  .justifyContent(FlexAlign.Center)
  .alignItems(HorizontalAlign.Center)
  .layoutWeight(1)
}