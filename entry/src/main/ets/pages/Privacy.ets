import { webview } from '@kit.ArkWeb';
import { safeAreaInsets } from '../common/Immersive';

/** 免责声明页（对应 Flutter privacy_page.dart：本地 assets WebView） */
@Component
export struct Privacy {
  @Consume('navStack') pathStack: NavPathStack;
  @StorageLink('safeTopPx') safeTopPx: number = 0;
  @StorageLink('safeBottomPx') safeBottomPx: number = 0;
  private controller: webview.WebviewController = new webview.WebviewController();

  build() {
    NavDestination() {
      Web({ src: $rawfile('disclaimer.html'), controller: this.controller })
        .width('100%')
        .height('100%')
    }
    .padding(safeAreaInsets(this.getUIContext(), this.safeTopPx, this.safeBottomPx))
    .title('免责声明')
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }
}
