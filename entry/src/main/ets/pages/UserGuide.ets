import { webview } from '@kit.ArkWeb';
import { safeAreaInsets } from '../common/Immersive';

/** 使用教程页（本地 rawfile WebView，与免责声明同结构，不跳转外部网页） */
@Component
export struct UserGuide {
  @Consume('navStack') pathStack: NavPathStack;
  @StorageLink('safeTopPx') safeTopPx: number = 0;
  @StorageLink('safeBottomPx') safeBottomPx: number = 0;
  private controller: webview.WebviewController = new webview.WebviewController();

  build() {
    NavDestination() {
      Web({ src: $rawfile('user_guide.html'), controller: this.controller })
        .domStorageAccess(true)
        .javaScriptAccess(true)
        .imageAccess(true)
        .width('100%')
        .height('100%')
    }
    .padding(safeAreaInsets(this.getUIContext(), this.safeTopPx, this.safeBottomPx))
    .title('使用教程')
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }
}
