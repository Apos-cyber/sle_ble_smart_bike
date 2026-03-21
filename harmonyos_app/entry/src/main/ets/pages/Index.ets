import { ControlPage } from './ControlPage'
import { RidePage } from './RidePage'
import { SettingsPage } from './SettingsPage'

@Entry
@Component
struct Index {
  @State currentIndex: number = 0

  build() {
    Column() {
      Tabs({ index: this.currentIndex, controller: this.controller }) {
        TabContent() {
          ControlPage()
        }
        .tabBar(this.TabBarBuilder(0, $r('app.media.ic_public_app'), $r('app.media.ic_public_app_filled'), $r('app.string.Control')))

        TabContent() {
          RidePage()
        }
        .tabBar(this.TabBarBuilder(1, $r('app.media.ic_public_email_send'), $r('app.media.ic_public_email_send_filled'), $r('app.string.Ride')))

        TabContent() {
          SettingsPage()
        }
        .tabBar(this.TabBarBuilder(2, $r('app.media.ic_public_settings'), $r('app.media.ic_public_settings_filled'), $r('app.string.Settings')))
      }
      .barPosition(BarPosition.End)
      .onChange((index: number) => {
        this.currentIndex = index
      })
      .barHeight(60)
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.white'))
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }

  private controller: TabsController = new TabsController()

  @Builder
  TabBarBuilder(index: number, icon: Resource, iconSelected: Resource, text: Resource) {
    Column() {
      Image(this.currentIndex === index ? iconSelected : icon)
        .width(24)
        .height(24)
        .objectFit(ImageFit.Contain)
      Text(text)
        .fontSize(12)
        .fontColor(this.currentIndex === index ? $r('app.color.primary') : $r('app.color.text_secondary'))
        .margin({ top: 4 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .opacity(this.currentIndex === index ? 1 : 0.6)
  }
}
