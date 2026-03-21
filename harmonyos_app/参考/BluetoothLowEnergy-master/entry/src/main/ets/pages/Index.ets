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

import {
  BLUETOOTH_CLIENT_PAGE_NAME,
  BLUETOOTH_SERVER_PAGE_NAME,
} from '../contants/CommonConstants';


/**
 * Application entry page responsible for navigation control.
 */
@Entry
@ComponentV2
struct Index {
  // Shared navigation stack for page transitions.
  @Provider('NavPathStack') pathStack: NavPathStack = new NavPathStack();

  build() {
    Navigation(this.pathStack) {
      Column() {
        Text($r('app.string.bluetooth_low_energy'))
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .width('100%')
          .height(56)
          .margin({ top: 56 })
        Column({ space: 12 }) {
          Button($r('app.string.ble_server'))
            .onClick(() => {
              this.pathStack.pushPath({ name: BLUETOOTH_SERVER_PAGE_NAME });
            })
            .width('100%')
          Button($r('app.string.ble_client'))
            .onClick(() => {
              this.pathStack.pushPath({ name: BLUETOOTH_CLIENT_PAGE_NAME });
            })
            .width('100%')
        }
        .height(248)
        .width('100%')
        .justifyContent(FlexAlign.End)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .padding({
        top: 32,
        left: 16,
        right: 16,
        bottom: 32
      })
    }
    .mode(NavigationMode.Stack)
    .hideToolBar(true)
    .backgroundColor('#F1F3F5')
  }
}