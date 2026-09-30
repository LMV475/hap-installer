import { HdsNavDestination, TitleSize } from '@kit.UIDesignKit';
import { subPageBottom, barBottomVp } from '../common/Immersive';
import { hdsTitleBarOptions } from '../common/MaterialPolicy';
import { HapCard } from '../components/HapCard';

/** 使用教程页（原生 ArkUI 实现，支持顶栏渐隐效果） */
@Component
export struct UserGuide {
  @Consume('navStack') pathStack: NavPathStack;
  /** HDS 幕布背景要按深浅色主题分档（与一级页同源，见 spec §5.5） */
  @StorageLink('isDark') isDark: boolean = false;
  @StorageLink('safeTopPx') safeTopPx: number = 0;
  @StorageLink('safeBottomPx') safeBottomPx: number = 0;
  // Scroll 的 Scroller 必须绑给 HdsNavDestination，栏带幕布才跟着渐隐
  private scrollCtrl: Scroller = new Scroller();

  build() {
    HdsNavDestination() {
      Scroll(this.scrollCtrl) {
        Column({ space: 12 }) {
          // 标题卡片
          HapCard({ content: (): void => { this.titleCard() } })

          // 第一步：登录华为账号
          HapCard({ content: (): void => { this.step1() } })

          // 第二步：连接无线调试
          HapCard({ content: (): void => { this.step2() } })

          // 第三步：选择安装包
          HapCard({ content: (): void => { this.step3() } })

          // 第四步：调试安装 / 已签名安装
          HapCard({ content: (): void => { this.step4() } })

          // 底部提示
          HapCard({ content: (): void => { this.footer() } })
        }
        .width('100%')
        .padding({ left: $r('sys.float.padding_level6'), right: $r('sys.float.padding_level6'),
          top: barBottomVp(this.getUIContext(), this.safeTopPx),
          bottom: $r('sys.float.padding_level6') })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .align(Alignment.TopStart)
      .edgeEffect(EdgeEffect.Spring)
      .scrollBar(BarState.Off)
    }
    .padding(subPageBottom(this.getUIContext(), this.safeBottomPx))
    .bindToScrollable([this.scrollCtrl])
    // 顶栏要 avoidLayoutSafeArea: true，标题才落在状态栏之下；内容顶让满 barBottomVp
    .titleBar(hdsTitleBarOptions('使用教程', this.isDark, TitleSize.TITLE_S, true))
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }

  @Builder
  titleCard() {
    Column({ space: 6 }) {
      Text('使用教程')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .width('100%')
        .textAlign(TextAlign.Center)
      Text('从登录到安装，四步完成 HAP 调试装机')
        .fontSize(13)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .width('100%')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ top: $r('sys.float.padding_level3'), bottom: $r('sys.float.padding_level3') })
  }

  @Builder
  stepHeader(num: string, title: string, bgColor: ResourceColor) {
    Row({ space: 10 }) {
      Text(num)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .width(26)
        .height(26)
        .borderRadius(13)
        .backgroundColor(bgColor)
        .textAlign(TextAlign.Center)
      Text(title)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .layoutWeight(1)
    }
    .width('100%')
    .margin({ bottom: $r('sys.float.padding_level3') })
  }

  @Builder
  stepContent(text: string) {
    Text(text)
      .fontSize(14)
      .fontColor($r('sys.color.ohos_id_color_text_primary'))
      .lineHeight(22)
      .width('100%')
  }

  @Builder
  tipBox(content: string) {
    Column({ space: 4 }) {
      Text(content)
        .fontSize(13)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .lineHeight(20)
        .width('100%')
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .borderRadius(8)
    .margin({ top: 10 })
  }

  @Builder
  divider() {
    Divider()
      .color($r('sys.color.ohos_id_color_list_separator'))
      .margin({ top: 14, bottom: 14 })
  }

  @Builder
  demoButton(label: string, bgColor?: Resource) {
    Text(label)
      .fontSize(13)
      .fontColor(Color.White)
      .padding({ left: 14, right: 14, top: 6, bottom: 6 })
      .backgroundColor(bgColor ?? $r('sys.color.ohos_id_color_emphasize'))
      .borderRadius(20)
      .margin({ top: 4, bottom: 4 })
  }

  @Builder
  step1() {
    Column({ space: 12 }) {
      this.stepHeader('1', '登录华为账号', $r('sys.color.ohos_id_color_emphasize'))
      this.stepContent('在首页顶部找到「华为账号」卡片，点击右侧的「登录账号」按钮。')
      this.demoButton('登录账号')
      this.stepContent('系统会自动打开浏览器，跳转到华为开发者授权页面。请在浏览器中完成登录与授权操作。')
      this.tipBox('提示：登录采用 DevEco IDE 授权通道，授权完成后会自动回调本应用，无需手动复制。若长时间未回调，请检查浏览器是否正常打开，或重试一次。')
      this.divider()
      this.stepContent('登录成功后，首页顶部会显示您的 uid，按钮文字变为「更换账号」。如需切换账号，再次点击即可重新走浏览器授权流程。')
    }
    .width('100%')
    .padding({ left: $r('sys.float.padding_level5'), right: $r('sys.float.padding_level5') })
  }

  @Builder
  step2() {
    Column({ space: 12 }) {
      this.stepHeader('2', '连接无线调试', $r('sys.color.ohos_id_color_emphasize'))
      this.stepContent('登录成功后，「设备」卡片会自动出现。点击右侧的「无线调试」按钮，打开连接抽屉。')
      this.demoButton('无线调试')

      this.stepHeader('2.1', '在手机上开启无线调试', $r('sys.color.ohos_id_color_text_tertiary'))
      Column({ space: 6 }) {
        Text('1. 进入手机「设置 → 系统 → 开发者选项」')
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .width('100%')
        Text('2. 打开「无线调试」开关')
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .width('100%')
        Text('3. 点击「无线调试」进入详情页，查看底部的 IP 地址与端口（形如 192.168.1.100:5555）')
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .margin({ top: 12 })

      this.stepHeader('2.2', '在本应用中连接', $r('sys.color.ohos_id_color_text_tertiary'))
      this.stepContent('在弹出的连接抽屉中，分别填入手机上显示的 IP 和端口：')
      Column({ space: 4 }) {
        Text('• IP 地址：例如 192.168.1.100')
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .width('100%')
        Text('• 端 口：例如 5555')
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .margin({ top: 8 })
      this.stepContent('点击「连接」，等待状态栏显示「已连接」。')
      this.tipBox('提示：手机与电脑需在同一局域网。若连接失败，请确认手机无线调试已开启、IP 与端口正确、防火墙未拦截。可在「更多 → 自动无线调试端口」开启自动重连。')
    }
    .width('100%')
    .padding({ left: $r('sys.float.padding_level5'), right: $r('sys.float.padding_level5') })
  }

  @Builder
  step3() {
    Column({ space: 12 }) {
      this.stepHeader('3', '选择安装包', $r('sys.color.ohos_id_color_emphasize'))
      this.stepContent('连接成功后，「软件安装包」卡片会自动出现。点击右侧的「选择」按钮。')
      this.demoButton('选择')
      this.stepContent('在文件选择器中找到您的 .hap / .hsp / .app 安装包文件并确认。')
      this.tipBox('提示：也可以在输入框中粘贴下载地址（http://.../app.hap），点击「下载」自动获取安装包。选包后会自动识别 bundle 名称与大小。')
      this.divider()
      this.stepContent('选中后，卡片会显示包名与文件大小，按钮文字变为「更换」。如需更换安装包，再次点击即可重新选择。')
    }
    .width('100%')
    .padding({ left: $r('sys.float.padding_level5'), right: $r('sys.float.padding_level5') })
  }

  @Builder
  step4() {
    Column({ space: 12 }) {
      this.stepHeader('4', '调试安装 / 已签名安装', $r('sys.color.ohos_id_color_emphasize'))
      this.stepContent('前三步完成后，页面底部会出现两个安装按钮：')

      this.stepHeader('4a', '开始调试（自动签名）', '#34C759')
      this.demoButton('开始调试（自动签名）', $r('sys.color.ohos_id_color_emphasize'))
      this.stepContent('点击此按钮，应用会自动完成签名并安装到设备。适合需要调试的未签名 HAP 包。')
      Column({ space: 4 }) {
        Text('• 自动使用内置签名材料（证书 / 密钥库 / Profile）')
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .width('100%')
        Text('• 签名完成后立即推送安装，无需手动操作')
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .width('100%')
        Text('• 若 Profile 绑定的包名与目标包不一致，会自动切换或申请对应的调试 Profile')
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .margin({ top: 8 })
      this.tipBox('提示：自动签名使用内置签名材料，开箱即用，无需额外配置。')

      this.divider()

      this.stepHeader('4b', '直接安装（需已签名）', '#FF9500')
      this.demoButton('直接安装（需已签名）', $r('sys.color.ohos_id_color_text_tertiary'))
      this.stepContent('点击此按钮，应用会跳过签名步骤，直接将已签名的 HAP 安装到设备。适合已有有效签名的安装包。')
      Column({ space: 4 }) {
        Text('• 安装包必须已通过华为 CA 链签名，否则系统会拒绝安装')
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .width('100%')
        Text('• 若安装本应用自身（HapInstaller），安装后会自动重启')
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .width('100%')
        Text('• 覆盖安装时会弹出确认弹窗，点击「继续安装」即可')
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .margin({ top: 8 })
      this.tipBox('提示：安装失败时请检查日志中的提示信息。常见原因：设备未连接、HAP 未签名、Profile 的 bundle-name 或 UDID 与目标包不匹配。')
    }
    .width('100%')
    .padding({ left: $r('sys.float.padding_level5'), right: $r('sys.float.padding_level5') })
  }

  @Builder
  footer() {
    Column({ space: 4 }) {
      Text('如需查看更多功能，请前往「更多」页面')
        .fontSize(13)
        .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
        .width('100%')
        .textAlign(TextAlign.Center)
      Text('HapInstaller · 端侧签名装机工具')
        .fontSize(12)
        .fontColor($r('sys.color.ohos_id_color_text_hint'))
        .width('100%')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ top: $r('sys.float.padding_level3'), bottom: $r('sys.float.padding_level3') })
  }
}
