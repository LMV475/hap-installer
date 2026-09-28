import { webview } from '@kit.ArkWeb';
import { safeAreaInsets } from '../common/Immersive';

const GUIDE_URL: string = 'https://gitee.com/xiaobai-studio/XiaoBaiGuide/blob/master/README.md';

/** 使用教程页（对应 Flutter user_guide_page.dart：WebView 嵌入在线教程） */
@Component
export struct UserGuide {
  @Consume('navStack') pathStack: NavPathStack;
  @StorageLink('safeTopPx') safeTopPx: number = 0;
  @StorageLink('safeBottomPx') safeBottomPx: number = 0;
  private controller: webview.WebviewController = new webview.WebviewController();

  build() {
    NavDestination() {
      Web({ src: GUIDE_URL, controller: this.controller })
        .domStorageAccess(true)
        .javaScriptAccess(true)
        .imageAccess(true)
        .onlineImageAccess(true)
        .mixedMode(MixedMode.All)
        .width('100%')
        .height('100%')
    }
    .padding(safeAreaInsets(this.getUIContext(), this.safeTopPx, this.safeBottomPx))
    .title('使用教程')
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }
}
