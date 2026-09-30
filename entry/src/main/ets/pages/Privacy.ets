import { HdsNavDestination, TitleSize } from '@kit.UIDesignKit';
import { subPageBottom, barBottomVp } from '../common/Immersive';
import { hdsTitleBarOptions } from '../common/MaterialPolicy';
import { HapCard } from '../components/HapCard';

/** 免责声明页（原生 ArkUI 实现，支持顶栏渐隐效果） */
@Component
export struct Privacy {
  @Consume('navStack') pathStack: NavPathStack;
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

          // 使用范围
          HapCard({ content: (): void => { this.usageScope() } })

          // 安装限制
          HapCard({ content: (): void => { this.installLimit() } })

          // 责任限制
          HapCard({ content: (): void => { this.liabilityLimit() } })

          // 知识产权
          HapCard({ content: (): void => { this.ipRights() } })
        }
        .width('100%')
        .padding({ left: $r('sys.float.padding_level6'), right: $r('sys.float.padding_level6'),
          // barBottomVp 让满标题栏底；额外 +16vp 把 HapCard 推入 GRADIENT_BLUR 模糊带渐隐段
          top: barBottomVp(this.getUIContext(), this.safeTopPx) + 16,
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
    .titleBar(hdsTitleBarOptions('免责声明', this.isDark, TitleSize.TITLE_S, true))
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }

  @Builder
  titleCard() {
    Text('免责声明')
      .fontSize(22)
      .fontWeight(FontWeight.Bold)
      .fontColor($r('sys.color.ohos_id_color_text_primary'))
      .width('100%')
      .textAlign(TextAlign.Center)
      .padding({ top: $r('sys.float.padding_level3'), bottom: $r('sys.float.padding_level3') })
  }

  @Builder
  sectionTitle(title: string) {
    Text(title)
      .fontSize(17)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.ohos_id_color_text_primary'))
      .width('100%')
      .margin({ bottom: $r('sys.float.padding_level3') })
  }

  @Builder
  listItem(text: string) {
    Row({ space: 8 }) {
      Text('•')
        .fontSize(14)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
      Text(text)
        .fontSize(14)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .lineHeight(22)
        .layoutWeight(1)
    }
    .width('100%')
    .margin({ bottom: 8 })
  }

  @Builder
  usageScope() {
    Column({ space: 8 }) {
      this.sectionTitle('使用范围')
      this.listItem('本应用提供的端侧签名能力仅用于开发者对本人为自用设备 / 企业内部分发目的构建的应用进行签名。')
      this.listItem('不得将本应用用于分发未经授权的软件、绕过应用市场审核或其他违反法律法规的用途。')
    }
    .width('100%')
    .padding({ left: $r('sys.float.padding_level5'), right: $r('sys.float.padding_level5') })
  }

  @Builder
  installLimit() {
    Column({ space: 8 }) {
      this.sectionTitle('安装限制')
      this.listItem('设备安装的应用必须可追溯至经华为 CA 链签名的证书，否则系统将拒绝安装。')
      this.listItem('安装 HapInstaller 自身的新版本时会替换当前运行实例，安装后需要重新启动应用。')
    }
    .width('100%')
    .padding({ left: $r('sys.float.padding_level5'), right: $r('sys.float.padding_level5') })
  }

  @Builder
  liabilityLimit() {
    Column({ space: 8 }) {
      this.sectionTitle('责任限制')
      this.listItem('本应用按"现状"提供，不对签名结果、安装成功率或设备数据作任何明示或默示的保证。')
      this.listItem('因使用本应用造成的设备数据丢失、账号风险或其他损失，开发者不承担责任。')
    }
    .width('100%')
    .padding({ left: $r('sys.float.padding_level5'), right: $r('sys.float.padding_level5') })
  }

  @Builder
  ipRights() {
    Column({ space: 8 }) {
      this.sectionTitle('知识产权')
      this.listItem('HDC、DevEco、HarmonyOS 及相关标识的权利归属其各自权利人。')
    }
    .width('100%')
    .padding({ left: $r('sys.float.padding_level5'), right: $r('sys.float.padding_level5') })
  }
}
