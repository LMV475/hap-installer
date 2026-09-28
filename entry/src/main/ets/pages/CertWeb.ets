import { webview } from '@kit.ArkWeb';
import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { safeAreaInsets } from '../common/Immersive';

const AGC_URL: string = 'https://developer.huawei.com/consumer/cn/service/josp/agc/index.html#/harmonyOSDevPlatform/9249519184596237889';

@Component
export struct CertWeb {
  @Consume('navStack') pathStack: NavPathStack;
  @StorageLink('safeTopPx') safeTopPx: number = 0;
  @StorageLink('safeBottomPx') safeBottomPx: number = 0;
  private controller: webview.WebviewController = new webview.WebviewController();
  @State url: string = AGC_URL;
  @State status: string = '加载中…';
  @State progress: number = 0;
  @State downloads: string = '';
  private delegateReady: boolean = false;

  aboutToAppear(): void {
    const custom: string | undefined = AppStorage.get<string>('webUrl');
    if (custom !== undefined && custom.length > 0) {
      this.url = custom;
    }
  }

  private ctx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  /** 下载完成后按扩展名写入配置，主页下次加载即可直接用 */
  private async persistMaterial(target: string): Promise<void> {
    let key: string = '';
    if (target.endsWith('.cer')) {
      key = 'cerPath';
    } else if (target.endsWith('.p7b')) {
      key = 'p7bPath';
    } else if (target.endsWith('.p12') || target.endsWith('.jks')) {
      key = 'p12Path';
    }
    if (key.length === 0) {
      return;
    }
    try {
      const store = await preferences.getPreferences(this.ctx(), 'hapinstaller');
      await store.put(key, target);
      await store.flush();
      hilog.info(0x0000, 'HapInstaller', '%{public}s', '[web] 材料已写入配置 ' + key + '=' + target);
    } catch (e) {
      const err = e as BusinessError;
      hilog.error(0x0000, 'HapInstaller', '[web] 写入配置失败 %{public}s', err.message);
    }
  }

  private targetPath(name: string): string {
    return this.ctx().filesDir + '/' + name;
  }

  /** 拦截网页下载：证书/profile/密钥库直接落到应用沙箱 */
  private setupDownload(): void {
    if (this.delegateReady) {
      return;
    }
    this.delegateReady = true;
    try {
      const delegate = new webview.WebDownloadDelegate();
      delegate.onBeforeDownload((item: webview.WebDownloadItem): void => {
        const name: string = item.getSuggestedFileName();
        const target: string = this.targetPath(name);
        try {
          item.start(target);
          AppStorage.setOrCreate<string>('lastDownload', target);
          this.downloads = '下载中: ' + name;
          hilog.info(0x0000, 'HapInstaller', '%{public}s', '[web] 开始下载 ' + name + ' -> ' + target);
        } catch (e) {
          const err = e as BusinessError;
          hilog.error(0x0000, 'HapInstaller', '[web] start 下载失败 %{public}s', err.message);
        }
      });
      delegate.onDownloadFinish((item: webview.WebDownloadItem): void => {
        const name: string = item.getSuggestedFileName();
        const target: string = this.targetPath(name);
        let size: number = 0;
        try {
          size = fileIo.statSync(target).size;
        } catch (e) {
          size = -1;
        }
        AppStorage.setOrCreate<string>('lastDownload', target);
        this.persistMaterial(target);
        this.downloads = '已下载: ' + name + ' (' + size + ' bytes)';
        hilog.info(0x0000, 'HapInstaller', '%{public}s', '[web] 下载完成 ' + target + ' size=' + size);
      });
      delegate.onDownloadFailed((item: webview.WebDownloadItem): void => {
        this.downloads = '下载失败: ' + item.getSuggestedFileName();
        hilog.error(0x0000, 'HapInstaller', '%{public}s', '[web] 下载失败 ' + item.getSuggestedFileName());
      });
      this.controller.setDownloadDelegate(delegate);
      hilog.info(0x0000, 'HapInstaller', '%{public}s', '[web] 下载代理已注册');
    } catch (e) {
      const err = e as BusinessError;
      hilog.error(0x0000, 'HapInstaller', '[web] 注册下载代理失败 %{public}s', err.message);
    }
  }

  build() {
    NavDestination() {
      Column() {
        Row({ space: 8 }) {
          Button('返回')
            .fontSize(13)
            .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .onClick((): void => {
              this.pathStack.pop();
            })
          Text(this.status)
            .fontSize(12)
            .layoutWeight(1)
            .maxLines(1)
        }
        .width('100%')
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })

      if (this.progress < 100) {
        Progress({ value: this.progress, total: 100, type: ProgressType.Linear })
          .width('100%')
      }

      if (this.downloads.length > 0) {
        Text(this.downloads)
          .fontSize(11)
          .fontColor('#1a7f37')
          .width('100%')
          .padding({ left: 10, bottom: 4 })
      }

      Web({ src: this.url, controller: this.controller })
        .domStorageAccess(true)
        .fileAccess(true)
        .javaScriptAccess(true)
        .imageAccess(true)
        .onlineImageAccess(true)
        .databaseAccess(true)
        .mixedMode(MixedMode.All)
        .onControllerAttached((): void => {
          this.setupDownload();
        })
        .onPageBegin((event) => {
          if (event) {
            hilog.info(0x0000, 'HapInstaller', '%{public}s', '[web] 开始加载 ' + event.url);
          }
        })
        .onPageEnd((): void => {
          let cur: string = '';
          try {
            cur = this.controller.getUrl();
          } catch (e) {
            cur = '(unknown)';
          }
          this.status = '已加载: ' + cur;
          hilog.info(0x0000, 'HapInstaller', '%{public}s', '[web] 页面加载完成 url=' + cur);
        })
        .onLoadIntercept((event) => {
          if (event) {
            hilog.info(0x0000, 'HapInstaller', '%{public}s', '[web] 导航 ' + event.data.getRequestUrl());
          }
          return false;
        })
        .onProgressChange((event) => {
          this.progress = event.newProgress;
        })
        .width('100%')
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
    }
    .padding(safeAreaInsets(this.getUIContext(), this.safeTopPx, this.safeBottomPx))
    .title('AGC 证书')
    .hideTitleBar(false)
  }
}
