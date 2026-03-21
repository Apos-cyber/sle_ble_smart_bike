@Component
export struct RidePage {
  build() {
    Column() {
      Text($r('app.string.Ride'))
        .fontSize(50)
        .fontWeight(FontWeight.Bold)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
