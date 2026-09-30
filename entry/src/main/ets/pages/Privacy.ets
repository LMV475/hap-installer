import { webview } from '@kit.ArkWeb';
import { HdsNavDestination, TitleSize } from '@kit.UIDesignKit';
import { subPageBottom, barBottomVp } from '../common/Immersive';
import { hdsTitleBarOptions } from '../common/MaterialPolicy';

/** 免责声明页（对应 Flutter privacy_page.dart：本地 assets WebView） */
@Component
export struct Privacy {
  @Consume('navStack') pathStack: NavPathStack;
  @StorageLink('isDark') isDark: boolean = false;
  @StorageLink('safeTopPx') safeTopPx: number = 0;
  @StorageLink('safeBottomPx') safeBottomPx: number = 0;
  private controller: webview.WebviewController = new webview.WebviewController();

  build() {
    HdsNavDestination() {
      // Web 自身的 padding 不会让网页内容下移（实测无效），必须由外层容器让出栏底
      Column() {
        Web({ src: $rawfile('disclaimer.html'), controller: this.controller })
          .width('100%')
          .height('100%')
      }
      .width('100%')
      .height('100%')
      .padding({ top: barBottomVp(this.getUIContext(), this.safeTopPx) })
    }
    .padding(subPageBottom(this.getUIContext(), this.safeBottomPx))
    // 顶栏要 avoidLayoutSafeArea: true，标题才落在状态栏之下；内容顶让满 barBottomVp（见其注释实测记录）
    .titleBar(hdsTitleBarOptions('免责声明', this.isDark, TitleSize.TITLE_S, true))
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }
}
