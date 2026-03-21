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

import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from '../utils/Logger';
import CommonUtils from '../utils/CommonUtils';

/**
 * Action configuration for navigation bar buttons.
 */
export interface Action {

  /* Unique identifier for an action, helpful for debugging.*/
  id: string;

  /**
   * Click callback to be invoked when the action is pressed.
   * @param event Optional click event information.
   */
  event: (event?: ClickEvent) => void;
}

@ComponentV2
export default struct NavigationBar {
  // Shared navigation stack for handling back navigation.
  @Consumer('NavPathStack') pathStack: NavPathStack = new NavPathStack();
  // Title text shown in the navigation bar.
  @Param @Require title: ResourceStr | undefined;
  // Whether to show the back indicator button.
  @Param @Require showIndicator: boolean | undefined;
  // Right-side action buttons.
  @Param @Require actions: Array<Action> | undefined;
  // Whether dark mode is enabled (affects title color).
  private darkMode?: boolean;
  // Main window instance reference for orientation control.
  private windowClass: window.Window | undefined = undefined;

  /**
   * Lifecycle: called prior to UI being displayed. Attempts to obtain the main window synchronously.
   */
  aboutToAppear(): void {
    this.windowClass = CommonUtils.getMainWindow();
  }

  /**
   * Set the preferred orientation of the current window.
   * @param orientation Target screen orientation constant.
   */
  setOrientation(orientation: number) {
    this.windowClass?.setPreferredOrientation(orientation)
      .then(() => {
        Logger.info('setWindowOrientation succeeded');
      })
      .catch((err: BusinessError) => {
        Logger.error(`setWindowOrientation failed. Cause: ${JSON.stringify(err)}`);
      })
  }

  build() {
    Row() {
      if (this.showIndicator) {
        Row() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontWeight(FontWeight.Normal)
            .fontSize('24vp')
        }
        .id('iv_back')
        .backgroundColor('#0C000000')
        .borderRadius(40)
        .margin({ left: 24, right: 8 })
        .width(40)
        .height(40)
        .aspectRatio(1)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.setOrientation(window.Orientation.PORTRAIT);
          this.pathStack.pop();
        })
      }

      Text(this.title ?? '')
        .fontColor(this.darkMode ? '#FFFFFF' : '#CE000000')
        .fontSize('20fp')
        .margin({ left: this.showIndicator ? 0 : 16 })
        .fontWeight(FontWeight.Bold)

      Blank()
        .layoutWeight(1)

      // Safely iterate actions (null-safe) for better robustness.
      ForEach(this.actions ?? [], (item: Action) => {
        Row() {
          Image($r('app.media.link_slash'))
            .objectFit(ImageFit.Contain)
            .width(24)
            .aspectRatio(1)
        }
        .id('iv_link_slash')
        .backgroundColor('#0C000000')
        .borderRadius(40)
        .margin({ right: 24 })
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .onClick(item.event)
      }, (item: Action, index: number) => index + '_' + JSON.stringify(item))
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.navigation_bar_bgcolor'))
  }
}