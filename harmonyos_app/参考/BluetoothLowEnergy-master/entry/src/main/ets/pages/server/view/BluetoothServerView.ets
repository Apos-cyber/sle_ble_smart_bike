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

import CommonUtils from '../../../utils/CommonUtils';
import {
  PERMISSION_LIST
} from '../../../contants/CommonConstants';
import BluetoothServerViewModel from '../BluetoothServerViewModel';

@Builder
export function BluetoothServerViewBuilder() {
  BluetoothServerView();
}

@ComponentV2
export struct BluetoothServerView {
  @Local bluetoothServerViewModel: BluetoothServerViewModel = BluetoothServerViewModel.getInstance();

  /**
   * Lifecycle: request necessary permissions upon entering the page.
   */
  aboutToAppear(): void {
    CommonUtils.checkPermissions(PERMISSION_LIST, this.getUIContext());
  }

  /**
   * Lifecycle: stop advertising when leaving the page.
   */
  aboutToDisappear(): void {
    this.bluetoothServerViewModel.stopAdvertiser();
    if (this.bluetoothServerViewModel.mIntervalId >= 0) {
      clearInterval(this.bluetoothServerViewModel.mIntervalId);
    }
  }

  /**
   * Builder for page title node.
   */
  @Builder
  NavDestinationTitle() {
    Column() {
      Text($r('app.string.ble_server'))
        .fontSize(20)
        .lineHeight(42)
        .fontWeight(700)
        .width('100%')
        .padding({ left: 12 })
        .opacity(0.9)
    }
    .width('100%')
  }

  build() {
    NavDestination() {
      Column() {
        Column({ space: 12 }) {
          Row() {
            Text($r('app.string.bluetooth_name', this.bluetoothServerViewModel.localName))
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .align(Alignment.Start)
          }
          .width('100%')
          .height(54)
          .backgroundColor(Color.White)
          .borderRadius(18)
          .padding({ left: 12 })

          Row() {
            Text($r('app.string.current_heart_rate'))
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .align(Alignment.Start)
            Text((this.bluetoothServerViewModel.heartRate > 0 ?
              this.bluetoothServerViewModel.heartRate.toString() + 'bpm' : ''))
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .align(Alignment.Start)
          }
          .width('100%')
          .height(54)
          .backgroundColor(Color.White)
          .borderRadius(18)
          .padding({ left: 12 })
        }

        Row() {
          Button(this.bluetoothServerViewModel.startAdvertiserState ?
            $r('app.string.turn_off_ble_heart_rate_broadcast') :
            $r('app.string.enable_ble_heart_rate_broadcast'))
            .onClick(() => {
              this.bluetoothServerViewModel.toggleAdvertiser();
            })
            .width('100%')
        }

      }
      .width('100%')
      .height('100%')
      .padding({
        left: 16,
        right: 16,
      })
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .padding({
      top: 32,
      bottom: 32
    })
    .backgroundColor('#F1F3F5')
    .title(this.NavDestinationTitle())
  }
}