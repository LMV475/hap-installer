import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { request } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { preferences } from '@kit.ArkData';
import { AgcService, AgcCertInfo } from '../common/AgcService';
import { HapCard } from '../components/HapCard';
import { PillButton } from '../components/PillButton';
import { HomeSettingItem } from '../components/HomeSettingItem';
import { topInsetVp, bottomInsetVp } from '../common/Immersive';
import { dialogMaterial, useSystemChrome } from '../common/MaterialPolicy';

@Component
export struct Cert {
  @Consume('navStack') pathStack: NavPathStack;
  @StorageLink('safeTopPx') safeTopPx: number = 0;
  @StorageLink('safeBottomPx') safeBottomPx: number = 0;
  @State certs: AgcCertInfo[] = [];
  @State loading: boolean = false;
  @State isRefreshing: boolean = false;
  @State tipText: string = '';
  @State currentName: string = '';

  aboutToAppear(): void {
    this.refresh();
  }

  private ctx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private finishRefresh(): void {
    this.loading = false;
    this.isRefreshing = false;
  }

  private async refresh(): Promise<void> {
    if (!AgcService.isLoggedIn()) {
      this.certs = [];
      this.finishRefresh();
      return;
    }
    this.loading = true;
    this.tipText = '';
    try {
      try {
        this.certs = await AgcService.getCertList();
      } catch (e) {
        const err0 = e as BusinessError;
        const msg: string = err0.message || '';
        if (msg.indexOf('过期') < 0 && msg.indexOf('401') < 0) {
          this.tipText = '加载失败: ' + msg;
          this.finishRefresh();
          return;
        }
        const ok: boolean = await AgcService.refreshAuth();
        if (!ok) {
          this.tipText = '登录已过期，请在首页重新登录华为账号';
          this.finishRefresh();
          return;
        }
        this.certs = await AgcService.getCertList();
        this.tipText = '登录态已自动刷新';
      }
      const store = await preferences.getPreferences(this.ctx(), 'hapinstaller');
      const cerPath: string = await store.get('cerPath', '') as string;
      this.currentName = cerPath.length > 0 ? this.inferNameFromCerts(cerPath) : '';
    } catch (e) {
      const err = e as BusinessError;
      this.tipText = '加载失败: ' + err.message;
    }
    this.finishRefresh();
  }

  private inferNameFromCerts(_cerPath: string): string {
    for (const c of this.certs) {
      if (c.certName === 'hapinstaller-debug') {
        return c.certName;
      }
    }
    return '';
  }

  private fmtDate(ms: number): string {
    const d: Date = new Date(ms);
    const pad = (n: number): string => n.toString().padStart(2, '0');
    return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate());
  }

  private typeLabel(t: number): string {
    return t === 2 ? '发布' : '调试';
  }

  private isExpired(c: AgcCertInfo): boolean {
    return c.status === 2 || c.expireTime < Date.now();
  }

  private async useCert(c: AgcCertInfo): Promise<void> {
    try {
      const url: string = await AgcService.certDownloadUrl(c.certObjectId);
      const dst: string = this.ctx().filesDir + '/hapinstaller-' + c.id + '.cer';
      try {
        fileIo.unlinkSync(dst);
      } catch (ignored) {
      }
      const config: request.DownloadConfig = { url: url, filePath: dst };
      const task: request.DownloadTask = await request.downloadFile(this.ctx(), config);
      await new Promise<void>((resolve: () => void) => {
        task.on('complete', (): void => { resolve(); });
        setTimeout((): void => { resolve(); }, 60000);
      });
      if (!fileIo.accessSync(dst)) {
        this.tipText = '下载失败';
        return;
      }
      const store = await preferences.getPreferences(this.ctx(), 'hapinstaller');
      await store.put('cerPath', dst);
      await store.flush();
      this.currentName = c.certName;
      this.tipText = '已切换证书: ' + c.certName;
    } catch (e) {
      const err = e as BusinessError;
      this.tipText = '切换失败: ' + err.message;
    }
  }

  private async deleteCert(c: AgcCertInfo): Promise<void> {
    try {
      await AgcService.removeCert(c.id);
      this.tipText = '已删除: ' + c.certName;
      await this.refresh();
    } catch (e) {
      const err = e as BusinessError;
      this.tipText = '删除失败: ' + err.message;
    }
  }

  private confirmDelete(c: AgcCertInfo): void {
    this.getUIContext().getPromptAction().showDialog({
      title: '删除证书',
      message: '确认删除 ' + c.certName + '？此操作不可撤销。',
      buttons: [
        { text: '删除', color: '#D9534F' },
        { text: '取消', color: '#666666' }
      ],
      systemMaterial: useSystemChrome() ? dialogMaterial() : undefined
    }).then((res: promptAction.ShowDialogSuccessResponse): void => {
      if (res.index === 0) {
        this.deleteCert(c);
      }
    }).catch((e: BusinessError): void => {
      this.tipText = '弹窗异常: ' + e.message;
    });
  }

  private goLogin(): void {
    AppStorage.setOrCreate<number>('selectedTab', 0);
    this.getUIContext().getPromptAction().showToast({ message: '请在首页点击登录账号' });
  }

  build() {
    Refresh({ refreshing: $$this.isRefreshing }) {
      Scroll() {
        Column({ space: 12 }) {
          HapCard({ content: (): void => { this.tipBody() } })

          if (!AgcService.isLoggedIn()) {
            HapCard({ content: (): void => { this.loginPrompt() } })
          } else if (this.loading) {
            Text('加载中…').fontSize(13)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .width('100%')
              .padding($r('sys.float.padding_level5'))
          } else if (this.certs.length === 0) {
            HapCard({ content: (): void => { this.emptyBody() } })
          } else {
            Column({ space: 0 }) {
              ForEach(this.certs, (c: AgcCertInfo): void => {
                this.certRow(c)
                if (this.certs.indexOf(c) < this.certs.length - 1) {
                  Divider().color($r('sys.color.ohos_id_color_list_separator'))
                }
              }, (c: AgcCertInfo): string => c.id)
            }
            .width('100%')
            .padding({ left: $r('sys.float.padding_level5'), right: $r('sys.float.padding_level5') })
            .borderRadius($r('sys.float.corner_radius_level6'))
            .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
          }
        }
        .width('100%')
        .padding({ left: $r('sys.float.padding_level6'), right: $r('sys.float.padding_level6'),
          bottom: bottomInsetVp(this.getUIContext(), this.safeBottomPx) })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .align(Alignment.TopStart)
      .edgeEffect(EdgeEffect.Spring)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .padding({ top: topInsetVp(this.getUIContext(), this.safeTopPx) })
    .refreshOffset(32)
    .onRefreshing(() => {
      this.refresh();
    })
  }

  @Builder
  tipBody() {
    Column({ space: 4 }) {
      Text('温馨提示')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
      Text('① 调试证书数量有上限，超限请先删除旧证书 ② 切换证书后需重新申请 Profile ③ 删除不可恢复')
        .fontSize(11)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
      if (this.tipText.length > 0) {
        Text(this.tipText)
          .fontSize(11)
          .fontColor($r('sys.color.ohos_id_color_emphasize'))
      }
    }.width('100%')
  }

  @Builder
  loginPrompt() {
    HomeSettingItem({
      title: '未登录',
      description: '华为开发者账号',
      icon: $r('sys.symbol.person_crop_circle_fill_1'),
      buttonLabel: '登录账号',
      isActive: false,
      onButtonTap: (): void => { this.goLogin(); }
    })
  }

  @Builder
  emptyBody() {
    Column({ space: 6 }) {
      Text('暂无证书')
        .fontSize(14)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
      Text('请在 更多 → 签名配置 → 申请证书')
        .fontSize(11)
        .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
    }.width('100%').padding($r('sys.float.padding_level5'))
  }

  @Builder
  certRow(c: AgcCertInfo) {
    Row({ space: 12 }) {
      SymbolGlyph(c.certType === 2 ? $r('sys.symbol.lock_fill') : $r('sys.symbol.checkmark_shield'))
        .fontSize(28)
        .fontColor([this.isExpired(c)
          ? $r('sys.color.ohos_id_color_text_tertiary')
          : $r('sys.color.ohos_id_color_emphasize')])
        .width(36)
      Column({ space: 2 }) {
        Text(this.typeLabel(c.certType) + ': ' + c.certName)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isExpired(c)
            ? $r('sys.color.ohos_id_color_text_tertiary')
            : $r('sys.color.ohos_id_color_text_primary'))
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text('于 ' + this.fmtDate(c.expireTime) + ' 过期')
          .fontSize(11)
          .fontColor(this.isExpired(c)
            ? $r('sys.color.ohos_id_color_warning')
            : $r('sys.color.ohos_id_color_text_secondary'))
      }.layoutWeight(1)
      if (this.currentName === c.certName) {
        Text('正在使用').fontSize(12)
          .fontColor($r('sys.color.ohos_id_color_emphasize'))
      } else if (!this.isExpired(c)) {
        PillButton({ label: '使用',
          onClickAction: (): void => { this.useCert(c); } })
      }
      PillButton({ label: '删除', variant: 'danger',
        onClickAction: (): void => { this.confirmDelete(c); } })
    }
    .width('100%')
    .padding({ top: $r('sys.float.padding_level3'), bottom: $r('sys.float.padding_level3') })
  }
}
