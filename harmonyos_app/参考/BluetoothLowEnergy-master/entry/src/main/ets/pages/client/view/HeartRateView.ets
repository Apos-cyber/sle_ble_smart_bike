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
import { display, window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from '../../../utils/Logger';
import BluetoothClientViewModel from '../BluetoothClientViewModel';
import NavigationBar from '../../../uicomponents/NavigationBar';
import HeartRateGraph from '../../../uicomponents/HeartRateGraph';
import CommonUtils from '../../../utils/CommonUtils';
import {
  ConnectionState,
  HEART_RATE_TOO_HIGH,
  HEART_RATE_TOO_LOW,
  HEIGHT_NAVIGATION_BAR
} from '../../../contants/CommonConstants';

@Builder
export function HeartRateViewBuilder() {
  HeartRateView();
}

/**
 * Heart rate detail page that renders real-time data and provides a disconnect action.
 */
@ComponentV2
export struct HeartRateView {
  @Local bluetoothClientViewModel: BluetoothClientViewModel = BluetoothClientViewModel.getInstance();
  @Local windowSize: window.Size = {
    width: 0,
    height: 0
  };
  // Reference to the main window for orientation/system bar control.
  private windowClass: window.Window | undefined = undefined;

  private get isConnected(): boolean {
    return this.bluetoothClientViewModel.connectBluetoothDevice?.connectionState === ConnectionState.STATE_CONNECTED;
  }

  private get heartRateTop(): number {
    return this.bluetoothClientViewModel.heartRateTop;
  }

  private get heartRateBottom(): number {
    return this.bluetoothClientViewModel.heartRateBottom;
  }

  private get heartRateAverage(): number {
    return Math.floor(this.bluetoothClientViewModel.heartRateAverage);
  }

  private get heartRate(): number {
    return this.bluetoothClientViewModel.heartRate;
  }

  /**
   * Whether warning reminder needs to be shown.
   * @returns True if heart rate is too high or too low.
   */
  showWarningReminder(): boolean {
    return this.tooHigh() || this.tooLow();
  }

  /**
   * Lifecycle: initialize window reference, display info, and state listeners.
   */
  aboutToAppear() {
    this.windowClass = CommonUtils.getMainWindow();
    const curDisplay = this.getDisplay();
    this.windowSize = { width: curDisplay?.width ?? 0, height: curDisplay?.height ?? 0 };
    this.setOrientation(window.Orientation.LANDSCAPE);
    this.setCurWindowSystemBarEnable([]);
    this.bluetoothClientViewModel.resetHeartRateStatistics();
    this.windowClass?.on('windowSizeChange', (size: window.Size) => {
      this.windowSize = size;
    })
  }

  /**
   * Lifecycle: reset orientation back to portrait when leaving the page.
   */
  aboutToDisappear(): void {
    this.setOrientation(window.Orientation.PORTRAIT);
    this.setCurWindowSystemBarEnable(['status', 'navigation']);
  }

  build() {
    NavDestination() {
      NavigationBar({
        title: $r('app.string.real_time_heart_rate_graph'),
        showIndicator: true,
        actions: [{
          id: 'btn_disconnect',
          event: () => {
            this.handleDisconnectAction();
          }
        }]
      })
        .height(HEIGHT_NAVIGATION_BAR)

      Row() {
        // Left statistics card: max/min heart rate.
        Row() {
          Image($r('app.media.heart_fill'))
            .width(36)
            .aspectRatio(1)
            .margin({ left: 24 })
          Row() {
            Column() {
              Row() {
                Text(`${this.heartRateTop}`)
                  .fontColor(Color.Black)
                  .opacity(0.9)
                  .fontSize(26)
                  .fontWeight(FontWeight.Bold)
                Text($r('app.string.times_per_minute'))
                  .fontColor(Color.Black)
                  .fontSize(10)
                  .opacity(0.6)
              }
              .width(90)

              Text($r('app.string.maximum_heart_rate'))
                .fontColor(Color.Black)
                .opacity(0.6)
                .width(90)
            }

            Column() {
              Row() {
                Text(`${this.heartRateBottom}`)
                  .fontColor(Color.Black)
                  .opacity(0.9)
                  .fontSize(26)
                  .fontWeight(FontWeight.Bold)
                Text($r('app.string.times_per_minute'))
                  .fontColor(Color.Black)
                  .fontSize(10)
                  .opacity(0.6)
              }
              .width(90)

              Text($r('app.string.minimum_heart_rate'))
                .fontColor(Color.Black)
                .opacity(0.6)
                .width(90)
            }
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.SpaceEvenly)
        }
        .alignItems(VerticalAlign.Center)
        .width((this.getCurWindowWidth() - 24 - 24 - 16) * 0.5)
        .height(90)
        .backgroundColor(Color.White)
        .borderRadius(12)

        Blank().width(16)

        // Right statistics card: average and current heart rate.
        Row() {
          Image($r('app.media.waveform_path_ecg_heart_fill'))
            .width(36)
            .aspectRatio(1)
            .margin({ left: 24 })

          Row() {
            Column() {
              Row() {
                Text(`${this.heartRateAverage}`)
                  .fontColor(Color.Black)
                  .opacity(0.9)
                  .fontSize(26)
                  .fontWeight(FontWeight.Bold)
                Text($r('app.string.times_per_minute'))
                  .fontColor(Color.Black)
                  .fontSize(10)
                  .opacity(0.6)
              }
              .width(90)

              Text($r('app.string.mean_heart_rate'))
                .fontColor(Color.Black)
                .opacity(0.6)
                .width(90)
            }

            Column() {
              Row() {
                Text(`${this.heartRate}`)
                  .fontColor(Color.Black)
                  .opacity(0.9)
                  .fontSize(26)
                  .fontWeight(FontWeight.Bold)
                Text($r('app.string.times_per_minute'))
                  .fontColor(Color.Black)
                  .fontSize(10)
                  .opacity(0.6)
              }
              .width(90)

              Text($r('app.string.current_heart'))
                .fontColor(Color.Black)
                .opacity(0.6)
                .width(90)
            }
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.SpaceEvenly)
        }
        .alignItems(VerticalAlign.Center)
        .width((this.getCurWindowWidth() - 24 - 24 - 16) * 0.5)
        .height(90)
        .backgroundColor(Color.White)
        .borderRadius(12)
      }
      .width('100%')
      .height(90)
      .justifyContent(FlexAlign.Center)
      .margin({ bottom: 24 })
      .padding({ left: 24, right: 24 })

      Column() {
        HeartRateGraph({
          viewWidth: this.getUIContext().px2vp(this.windowSize.width) - 48,
          viewHeight: this.getUIContext().px2vp(this.windowSize.height * 0.5 * 0.9),
          isActive: this.isConnected,
          heartRate: this.heartRate
        })
      }
      .borderRadius(12)
      .layoutWeight(1)
      .margin({
        left: 24,
        right: 24,
        bottom: 16
      })

    }
    .hideTitleBar(true)
    .backgroundColor('#F1F3F5')
  }

  /**
   * @returns True if heart rate is above the high threshold.
   */
  private tooHigh(): boolean {
    return this.heartRate > HEART_RATE_TOO_HIGH;
  }

  /**
   * @returns True if heart rate is below the low threshold but greater than zero.
   */
  private tooLow(): boolean {
    return this.heartRate > 0 && this.heartRate < HEART_RATE_TOO_LOW;
  }

  /**
   * Set orientation and optionally hide system bars.
   * @param orientation Orientation constant.
   */
  private setOrientation(orientation: number) {
    this.windowClass?.setPreferredOrientation(orientation)
      .then(() => {
        Logger.info('setWindowOrientation succeeded');
      })
      .catch((err: BusinessError) => {
        Logger.error(`setWindowOrientation failed. Cause: ${JSON.stringify(err)}`);
      })
  }

  private setCurWindowSystemBarEnable(names: Array<'status' | 'navigation'>) {
    this.windowClass?.setWindowSystemBarEnable(names).catch(() => {
      Logger.error('HeartRate setWindowSystemBarEnable failed.')
    });
  }

  /**
   * Get the default display information.
   * @returns Display information or undefined if failed.
   */
  private getDisplay(): display.Display | undefined {
    let curDisplay: display.Display | undefined = undefined;
    try {
      curDisplay = display.getDefaultDisplaySync();
    } catch (error) {
      Logger.error(`Failed to obtain the default display, error info: ${JSON.stringify(error)}`);
    }
    return curDisplay;
  }

  /**
   * Handle click of the disconnect action in the navigation bar.
   * Force disconnects the client, stops graph updates, and resets UI.
   */
  private handleDisconnectAction(): void {
    if (!this.isConnected) {
      CommonUtils.showToast(this.getUIContext(), $r('app.string.disconnected'));
      return;
    }
    this.bluetoothClientViewModel.forceDisconnect();
    this.bluetoothClientViewModel.resetHeartRateValue();
    this.bluetoothClientViewModel.resetHeartRateStatistics();
    CommonUtils.showToast(this.getUIContext(), $r('app.string.disconnected'));
  }

  private getCurWindowWidth(): number {
    return this.getUIContext().px2vp(this.windowSize.width);
  }
}