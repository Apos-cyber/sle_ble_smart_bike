import { BLEManager, BLEDevice } from '../common/BLEManager'
import { NearLinkManager, NearLinkDevice } from '../common/NearLinkManager'
import { common } from '@kit.AbilityKit'
import { ConnectionType } from '../constants/BLEConstants'

// BLE扫描弹窗
@CustomDialog
export struct BLEScanDialog {
  controller: CustomDialogController
  bleManager!: BLEManager
  onDeviceSelected!: (device: BLEDevice) => void

  @State devices: BLEDevice[] = []
  @State isScanning: boolean = false

  build() {
    Column() {
      // 标题
      Text($r('app.string.ScanDevices'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .margin({ bottom: 16 })

      // 设备列表
      if (this.devices.length === 0 && !this.isScanning) {
        Text($r('app.string.NoDevicesFound'))
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .height(200)
          .width('100%')
          .textAlign(TextAlign.Center)
      } else {
        List() {
          ForEach(this.devices, (device: BLEDevice) => {
            ListItem() {
              Row() {
                Column() {
                  Text(device.deviceName)
                    .fontSize(16)
                    .fontColor($r('app.color.text_primary'))
                  Text(device.deviceId)
                    .fontSize(12)
                    .fontColor($r('app.color.text_secondary'))
                }
                .alignItems(HorizontalAlign.Start)

                Blank()

                Text(device.rssi.toString() + ' dBm')
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
              }
              .width('100%')
              .padding(10)
              .onClick(() => {
                this.onDeviceSelected(device)
              })
            }
            .padding(5)
          })
        }
        .height(200)
        .width('100%')
        .divider({ strokeWidth: 1, color: $r('app.color.border') })
      }

      // 扫描按钮
      Text(this.isScanning ? '停止扫描' : $r('app.string.Scan'))
        .fontSize(16)
        .fontColor($r('app.color.primary'))
        .margin({ top: 16 })
        .onClick(() => {
          if (this.isScanning) {
            this.bleManager.stopScan()
            this.isScanning = false
          } else {
            this.startScan()
          }
        })
    }
    .width('90%')
    .padding(20)
    .backgroundColor($r('app.color.white'))
    .borderRadius(10)
  }

  aboutToAppear(): void {
    this.startScan()
  }

  aboutToDisappear(): void {
    this.bleManager.stopScan()
  }

  private startScan(): void {
    this.isScanning = true
    this.bleManager.startScan((devices: BLEDevice[]) => {
      this.devices = devices
    })
  }
}

// 连接方式弹窗
@CustomDialog
export struct ConnectionDialog {
  controller: CustomDialogController
  onBluetoothClick!: () => void
  onStarflashClick!: () => void

  build() {
    Column() {
      Text($r('app.string.ConnectionMethod'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .margin({ bottom: 20 })

      // 蓝牙按钮
      Row() {
        Image($r('app.media.ic_public_bluetooth'))
          .width(24)
          .height(24)
          .margin({ right: 12 })
        Text($r('app.string.Bluetooth'))
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
      }
      .width('80%')
      .height(48)
      .backgroundColor('#FFFFFF')
      .border({
        width: 1,
        color: '#E5E5E5',
        radius: 24
      })
      .justifyContent(FlexAlign.Center)
      .margin({ bottom: 12 })
      .onClick(() => {
        // 蓝牙点击直接打开扫描
        this.controller.close()
        this.onBluetoothClick()
      })

      // 星闪按钮
      Row() {
        Image($r('app.media.ic_public_starflash'))
          .width(24)
          .height(24)
          .margin({ right: 12 })
        Text($r('app.string.Starflash'))
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
      }
      .width('80%')
      .height(48)
      .backgroundColor('#FFFFFF')
      .border({
        width: 1,
        color: '#E5E5E5',
        radius: 24
      })
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.controller.close()
        this.onStarflashClick()
      })
    }
    .width('80%')
    .padding(20)
    .backgroundColor($r('app.color.white'))
    .borderRadius(10)
  }
}

// 连接结果提示弹窗
@CustomDialog
export struct ResultDialog {
  controller: CustomDialogController
  @Prop message: string = ''
  @Prop isSuccess: boolean = false

  build() {
    Column() {
      Text(this.isSuccess ? '✓' : '✗')
        .fontSize(40)
        .fontColor(this.isSuccess ? '#07C160' : '#FF3B30')
        .margin({ bottom: 10 })

      Text(this.message)
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
    }
    .width('60%')
    .padding(30)
    .backgroundColor($r('app.color.white'))
    .borderRadius(10)
  }
}

// 星闪设备名称输入弹窗
@CustomDialog
export struct StarflashInputDialog {
  controller: CustomDialogController
  onDeviceNameConfirm!: (deviceName: string) => void

  @State deviceName: string = ''

  build() {
    Column() {
      Text('星闪连接')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .margin({ bottom: 16 })

      Text('请输入设备名称')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .margin({ bottom: 8 })

      TextInput({ placeholder: '设备名称' })
        .width('100%')
        .height(44)
        .fontSize(16)
        .borderRadius(8)
        .backgroundColor('#F5F5F5')
        .margin({ bottom: 20 })
        .onChange((value: string) => {
          this.deviceName = value
        })

      Row() {
        Button('取消')
          .width('45%')
          .height(40)
          .backgroundColor('#E5E5E5')
          .fontColor('#333333')
          .borderRadius(20)
          .onClick(() => {
            this.controller.close()
          })

        Button('确定')
          .width('45%')
          .height(40)
          .backgroundColor($r('app.color.primary'))
          .fontColor('#FFFFFF')
          .borderRadius(20)
          .onClick(() => {
            this.controller.close()
            if (this.deviceName.length > 0) {
              this.onDeviceNameConfirm(this.deviceName)
            }
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('85%')
    .padding(24)
    .backgroundColor($r('app.color.white'))
    .borderRadius(12)
  }
}

@Component
export struct ControlPage {
  private bleManager: BLEManager = BLEManager.getInstance()
  private nearLinkManager: NearLinkManager = NearLinkManager.getInstance()
  private connectionDialogController!: CustomDialogController
  private bleScanDialogController: CustomDialogController | null = null
  private resultDialogController: CustomDialogController | null = null
  private starflashDialogController: CustomDialogController | null = null

  @State connectionType: ConnectionType = ConnectionType.None
  @State connectedDeviceName: string = ''

  aboutToAppear(): void {
    this.connectionDialogController = new CustomDialogController({
      builder: ConnectionDialog({
        onBluetoothClick: () => {
          this.openBLEScanDialog()
        },
        onStarflashClick: () => {
          this.openStarflashInputDialog()
        }
      }),
      alignment: DialogAlignment.Center,
      backgroundColor: 0xFFFFFFFF
    })

    // 设置 BLE 连接状态回调
    this.bleManager.setConnectionCallback((connected: boolean, deviceId: string) => {
      if (connected) {
        this.connectionType = ConnectionType.BLE
        this.connectedDeviceName = deviceId
      } else {
        if (this.connectionType === ConnectionType.BLE) {
          this.connectionType = ConnectionType.None
          this.connectedDeviceName = ''
        }
      }
    })

    // 设置星闪连接状态回调
    this.nearLinkManager.setConnectionCallback((success: boolean, message: string) => {
      if (success) {
        this.connectionType = ConnectionType.NearLink
        this.connectedDeviceName = '星闪设备'
      }
      this.showResult(success, message)
    })
  }

  build() {
    Column() {
      // 顶部信息栏 - 白色背景
      Row() {
        // 连接状态图标 - 点击可断开连接
        if (this.connectionType === ConnectionType.BLE) {
          Row() {
            Image($r('app.media.ic_public_bluetooth'))
              .width(18)
              .height(18)
              .margin({ right: 4 })
            Text('已连接')
              .fontSize(12)
              .fontColor($r('app.color.primary'))
            Image($r('app.media.ic_public_cancel'))
              .width(14)
              .height(14)
              .margin({ left: 4 })
              .fillColor('#999999')
          }
          .height(30)
          .padding({ left: 10, right: 10 })
          .borderRadius(15)
          .backgroundColor('#E6F7FF')
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .margin({ right: 8 })
          .onClick(() => {
            this.disconnectCurrent()
          })
        } else if (this.connectionType === ConnectionType.NearLink) {
          Row() {
            Image($r('app.media.ic_public_starflash'))
              .width(18)
              .height(18)
              .margin({ right: 4 })
            Text('已连接')
              .fontSize(12)
              .fontColor($r('app.color.primary'))
            Image($r('app.media.ic_public_cancel'))
              .width(14)
              .height(14)
              .margin({ left: 4 })
              .fillColor('#999999')
          }
          .height(30)
          .padding({ left: 10, right: 10 })
          .borderRadius(15)
          .backgroundColor('#FFF7E6')
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .margin({ right: 8 })
          .onClick(() => {
            this.disconnectCurrent()
          })
        }

        Row() {
          Image($r('app.media.ic_public_link'))
            .width(18)
            .height(18)
            .margin({ right: 6 })
          Text($r('app.string.Connection'))
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
        }
        .height(30)
        .padding({ left: 16, right: 16 })
        .borderRadius(15)
        .backgroundColor('#FFFFFF')
        .border({
          width: 1,
          color: '#E5E5E5'
        })
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          this.connectionDialogController.open()
        })
      }
      .width('100%')
      .height(50)
      .padding({ left: 16, right: 16 })
      .backgroundColor($r('app.color.white'))
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)

      // 内容区域 - 白色背景
      Column() {
        Text($r('app.string.Control'))
          .fontSize(50)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }

  private openBLEScanDialog(): void {
    // 设置上下文
    const context = getContext(this) as common.UIAbilityContext
    this.bleManager.setContext(context)

    // 请求权限
    this.bleManager.requestPermissions().then((granted: boolean) => {
      if (!granted) {
        this.showResult(false, '权限申请失败')
        return
      }

      // 创建并打开扫描弹窗
      this.bleScanDialogController = new CustomDialogController({
        builder: BLEScanDialog({
          bleManager: this.bleManager,
          onDeviceSelected: (device: BLEDevice) => {
            this.connectDevice(device)
          }
        }),
        alignment: DialogAlignment.Center,
        backgroundColor: 0xFFFFFFFF
      })

      this.bleScanDialogController.open()
    })
  }

  private openStarflashInputDialog(): void {
    // 创建并打开星闪设备名称输入弹窗
    this.starflashDialogController = new CustomDialogController({
      builder: StarflashInputDialog({
        onDeviceNameConfirm: (deviceName: string) => {
          this.startStarflashScan(deviceName)
        }
      }),
      alignment: DialogAlignment.Center,
      backgroundColor: 0xFFFFFFFF
    })
    this.starflashDialogController.open()
  }

  private startStarflashScan(deviceName: string): void {
    // 互斥逻辑：如果当前已连接蓝牙，先断开
    if (this.connectionType === ConnectionType.BLE) {
      this.bleManager.disconnect()
      this.bleManager.close()
    }

    // 显示扫描提示
    this.showResult(true, `正在扫描: ${deviceName}`)

    // 设置连接状态回调
    this.nearLinkManager.setConnectionCallback((success: boolean, message: string) => {
      this.showResult(success, message)
    })

    // 开始星闪扫描（发现设备后自动连接）
    this.nearLinkManager.startScan(deviceName, (devices: NearLinkDevice[]) => {
      console.info('NearLink scan devices:', devices.length)
    })
  }

  private async connectDevice(device: BLEDevice): Promise<void> {
    // 关闭扫描弹窗
    if (this.bleScanDialogController) {
      this.bleScanDialogController.close()
      this.bleScanDialogController = null
    }

    // 互斥逻辑：如果当前已连接星闪，先断开
    if (this.connectionType === ConnectionType.NearLink) {
      this.nearLinkManager.disconnect()
    }

    // 显示连接中
    this.showResult(true, '连接中...')

    // 连接设备
    const success: boolean = await this.bleManager.connect(device.deviceId)

    // 显示结果（连接状态会通过回调更新图标）
    this.showResult(success, success ? '连接成功' : '连接失败')
  }

  /**
   * 断开当前连接
   */
  private disconnectCurrent(): void {
    if (this.connectionType === ConnectionType.BLE) {
      this.bleManager.disconnect()
      this.bleManager.close()
      this.connectionType = ConnectionType.None
      this.connectedDeviceName = ''
      this.showResult(true, '蓝牙已断开')
    } else if (this.connectionType === ConnectionType.NearLink) {
      this.nearLinkManager.disconnect()
      this.connectionType = ConnectionType.None
      this.connectedDeviceName = ''
      this.showResult(true, '星闪已断开')
    }
  }

  private showResult(isSuccess: boolean, message: string): void {
    this.resultDialogController = new CustomDialogController({
      builder: ResultDialog({
        isSuccess: isSuccess,
        message: message
      }),
      alignment: DialogAlignment.Center,
      backgroundColor: 0x00000000
    })
    this.resultDialogController.open()

    // 2秒后自动关闭
    setTimeout(() => {
      if (this.resultDialogController) {
        this.resultDialogController.close()
        this.resultDialogController = null
      }
    }, 2000)
  }
}
