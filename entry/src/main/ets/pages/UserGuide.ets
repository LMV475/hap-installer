import { webview } from '@kit.ArkWeb';
import { HdsNavDestination, TitleSize } from '@kit.UIDesignKit';
import { subPageBottom, barBottomVp } from '../common/Immersive';
import { hdsTitleBarOptions } from '../common/MaterialPolicy';

/** 使用教程页（本地 rawfile WebView，与免责声明同结构，不跳转外部网页） */
@Component
export struct UserGuide {
  @Consume('navStack') pathStack: NavPathStack;
  /** HDS 幕布背景要按深浅色主题分档（与一级页同源，见 spec §5.5） */
  @StorageLink('isDark') isDark: boolean = false;
  @StorageLink('safeTopPx') safeTopPx: number = 0;
  @StorageLink('safeBottomPx') safeBottomPx: number = 0;
  private controller: webview.WebviewController = new webview.WebviewController();

  build() {
    HdsNavDestination() {
      // Web 自身的 padding 不会让网页内容下移（实测无效），必须由外层容器让出栏底
      Column() {
        Web({ src: $rawfile('user_guide.html'), controller: this.controller })
          .domStorageAccess(true)
          .javaScriptAccess(true)
          .imageAccess(true)
          .width('100%')
          .height('100%')
      }
      .width('100%')
      .height('100%')
      .padding({ top: barBottomVp(this.getUIContext(), this.safeTopPx) })
    }
    .padding(subPageBottom(this.getUIContext(), this.safeBottomPx))
    // 顶栏要 avoidLayoutSafeArea: true，标题才落在状态栏之下；内容顶让满 barBottomVp（见其注释实测记录）
    .titleBar(hdsTitleBarOptions('使用教程', this.isDark, TitleSize.TITLE_S, true))
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }
}
