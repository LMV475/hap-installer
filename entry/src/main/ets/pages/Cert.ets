import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { request } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AgcService, AgcCertInfo, AgcAuthInfo } from '../common/AgcService';
import { HapCard } from '../components/HapCard';
import { PillButton } from '../components/PillButton';
import { HomeSettingItem } from '../components/HomeSettingItem';
import { topInsetVp, bottomInsetVp, barBottomVp, REFRESH_INDICATOR_VP } from '../common/Immersive';
import { dialogMaterial, useSystemChrome } from '../common/MaterialPolicy';
import { putSecret } from '../common/SecureStore';

const AGC_AUTH_ALIAS: string = 'hapinstaller_agc_auth';

@Component
export struct Cert {
  @Consume('navStack') pathStack: NavPathStack;
  @StorageLink('safeTopPx') safeTopPx: number = 0;
  @StorageLink('safeBottomPx') safeBottomPx: number = 0;
  @State certs: AgcCertInfo[] = [];
  @State loading: boolean = false;
  @State isRefreshing: boolean = false;
  /** 下拉距离（vp，Refresh.onOffsetChange 给的单位就是 vp）。指示器用它跟列表一起下移 */
  @State pullOffsetVp: number = 0;
  @State tipText: string = '';
  @State currentName: string = '';
  @State busy: boolean = false;
  // 监听首页登录态变化（agcUser 改变说明刚登录/更换账号）
  @StorageLink('agcUser') @Watch('onAgcUserChanged') agcUser: string = '';
  // 监听 Tab 切换，当切换到证书页时检查登录状态
  @StorageLink('selectedTab') @Watch('onTabChanged') selectedTab: number = 0;
  private lastAgcUser: string = '';
  private lastCheckedTab: number = -1;

  aboutToAppear(): void {
    this.lastAgcUser = this.agcUser;
    hilog.info(0x0000, 'Cert', '[cert] aboutToAppear: agcUser=%{public}s, isLoggedIn=%{public}b', 
      this.agcUser, AgcService.isLoggedIn());
    this.refresh();
  }

  onPageShow(): void {
    // 从其他页面返回时，检查登录状态并刷新证书列表
    const isLoggedIn = AgcService.isLoggedIn();
    const auth = AgcService.getAuth();
    
    hilog.info(0x0000, 'Cert', '[cert] onPageShow 开始检查');
    hilog.info(0x0000, 'Cert', '[cert]   agcUser=%{public}s', this.agcUser);
    hilog.info(0x0000, 'Cert', '[cert]   lastAgcUser=%{public}s', this.lastAgcUser);
    hilog.info(0x0000, 'Cert', '[cert]   isLoggedIn=%{public}b', isLoggedIn);
    hilog.info(0x0000, 'Cert', '[cert]   authIsNull=%{public}b', auth === null);
    if (auth !== null) {
      hilog.info(0x0000, 'Cert', '[cert]   auth.userId=%{public}s', auth.userId);
    }
    hilog.info(0x0000, 'Cert', '[cert]   certs.length=%{public}d', this.certs.length);
    
    // 如果已登录但证书列表为空，或者 agcUser 发生变化，则刷新
    if (isLoggedIn && (this.certs.length === 0 || this.agcUser !== this.lastAgcUser)) {
      hilog.info(0x0000, 'Cert', '[cert] 触发刷新：条件满足');
      this.lastAgcUser = this.agcUser;
      this.refresh();
    } 
    // 如果未登录但之前显示过证书，清空列表
    else if (!isLoggedIn && this.certs.length > 0) {
      hilog.info(0x0000, 'Cert', '[cert] 清空证书：未登录但有证书');
      this.certs = [];
      this.lastAgcUser = '';
    } else {
      hilog.info(0x0000, 'Cert', '[cert] 不刷新：isLoggedIn=%{public}b, certs.length=%{public}d, agcUser==lastAgcUser=%{public}b',
        isLoggedIn, this.certs.length, this.agcUser === this.lastAgcUser);
    }
  }

  onAgcUserChanged(): void {
    // agcUser 变化时立即刷新（包括首次登录后）
    hilog.info(0x0000, 'Cert', '[cert] onAgcUserChanged: agcUser=%{public}s, lastAgcUser=%{public}s, changed=%{public}b',
      this.agcUser, this.lastAgcUser, this.agcUser !== this.lastAgcUser);
    if (this.agcUser !== this.lastAgcUser) {
      this.lastAgcUser = this.agcUser;
      this.refresh();
    }
  }

  onTabChanged(): void {
    // 当切换到证书页（tab 1）时，检查登录状态并刷新
    if (this.selectedTab === 1 && this.lastCheckedTab !== 1) {
      hilog.info(0x0000, 'Cert', '[cert] onTabChanged: 切换到证书页');
      this.lastCheckedTab = 1;
      
      const isLoggedIn = AgcService.isLoggedIn();
      const auth = AgcService.getAuth();
      
      hilog.info(0x0000, 'Cert', '[cert]   agcUser=' + this.agcUser);
      hilog.info(0x0000, 'Cert', '[cert]   isLoggedIn=' + isLoggedIn);
      hilog.info(0x0000, 'Cert', '[cert]   authIsNull=' + (auth === null));
      if (auth !== null) {
        hilog.info(0x0000, 'Cert', '[cert]   auth.userId=' + auth.userId);
      }
      hilog.info(0x0000, 'Cert', '[cert]   certs.length=' + this.certs.length);
      
      // 如果已登录但证书列表为空，或者 agcUser 发生变化，则刷新
      if (isLoggedIn && (this.certs.length === 0 || this.agcUser !== this.lastAgcUser)) {
        hilog.info(0x0000, 'Cert', '[cert] 触发刷新：条件满足');
        this.lastAgcUser = this.agcUser;
        this.refresh();
      } 
      // 如果未登录但之前显示过证书，清空列表
      else if (!isLoggedIn && this.certs.length > 0) {
        hilog.info(0x0000, 'Cert', '[cert] 清空证书：未登录但有证书');
        this.certs = [];
        this.lastAgcUser = '';
      } else {
        hilog.info(0x0000, 'Cert', '[cert] 不刷新：isLoggedIn=' + isLoggedIn + ', certs.length=' + this.certs.length);
      }
    } else if (this.selectedTab !== 1) {
      this.lastCheckedTab = this.selectedTab;
    }
  }

  private ctx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private finishRefresh(): void {
    this.loading = false;
    this.isRefreshing = false;
  }

  private async refresh(): Promise<void> {
    hilog.info(0x0000, 'Cert', '[cert] refresh 开始: isLoggedIn=%{public}b, loading=%{public}b, isRefreshing=%{public}b',
      AgcService.isLoggedIn(), this.loading, this.isRefreshing);
    
    if (!AgcService.isLoggedIn()) {
      hilog.info(0x0000, 'Cert', '[cert] 未登录，清空证书列表');
      this.certs = [];
      this.finishRefresh();
      hilog.info(0x0000, 'Cert', '[cert] refresh: not logged in, cleared certs');
      return;
    }
    // 下拉刷新时不显示 loading 文本，避免闪烁；只有首次加载才显示
    if (!this.isRefreshing) {
      this.loading = true;
    }
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
      // 直接从本地列表中移除，避免 refresh() 造成的闪烁
      this.certs = this.certs.filter((item: AgcCertInfo): boolean => item.id !== c.id);
      // 如果删除的是当前使用的证书，清空 currentName
      if (this.currentName === c.certName) {
        this.currentName = '';
      }
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

  private async goLogin(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.tipText = '等待浏览器完成登录…';
    
    const port: number = 3333 + Math.floor(Math.random() * 1000);
    try {
      const waiting: Promise<string> = AgcService.waitForCallback(port, 180000);
      await AgcService.openLoginPage(this.ctx(), port);
      this.tipText = '已打开授权页（端口 ' + port + '），请在浏览器中登录';
      
      const tempToken: string = await waiting;
      if (tempToken.length === 0) {
        this.tipText = '未收到回调（超时或已取消）';
        this.busy = false;
        return;
      }
      
      const auth = await AgcService.exchangeToken(tempToken);
      
      // 持久化保存登录态到 SecureStore
      const saved = await this.saveAuthToSecureStore(auth);
      if (!saved) {
        this.tipText = '登录成功但保存失败，重启后需重新登录';
      }
      
      // 同步到 AppStorage
      AppStorage.setOrCreate<string>('agcUser', auth.userId);
      hilog.info(0x0000, 'Cert', '[cert] 登录成功 agcUser=%{public}s', auth.userId);
      
      this.tipText = '登录成功：' + auth.userId;
      // 触发刷新证书列表
      this.lastAgcUser = auth.userId;
      await this.refresh();
    } catch (e) {
      const err = e as BusinessError;
      this.tipText = '登录失败: ' + err.message;
    }
    this.busy = false;
  }

  /** 打包登录态为单行字符串（同 Home.packAuth 语义） */
  private packAuth(auth: AgcAuthInfo): string {
    return auth.jwtToken + '\n' + auth.accessToken + '\n' + auth.userId + '\n' + auth.teamId;
  }

  /** 将登录态保存到 SecureStore（加密存储） */
  private async saveAuthToSecureStore(auth: AgcAuthInfo): Promise<boolean> {
    try {
      const blob = this.packAuth(auth);
      return await putSecret(AGC_AUTH_ALIAS, blob);
    } catch (e) {
      const err = e as BusinessError;
      hilog.error(0x0000, 'Cert', '[cert] 保存登录态失败: %{public}s', err.message);
      return false;
    }
  }

  /** 指示器居中在「栏底—列表首行」之间：中点 = 栏底 + (静止间距 + 下拉距离) / 2，再减去自身半径 */
  private indicatorTopVp(): number {
    const gap: number = topInsetVp(this.getUIContext(), this.safeTopPx) -
      barBottomVp(this.getUIContext(), this.safeTopPx) + this.pullOffsetVp;
    return barBottomVp(this.getUIContext(), this.safeTopPx) + gap / 2 - REFRESH_INDICATOR_VP / 2;
  }

  /** 顶栏与列表的间距（= 下拉距离）超过指示器高度才开始渐显，到 1.5 倍高度完全不透明 */
  private indicatorOpacity(): number {
    if (this.isRefreshing) {
      return 1;
    }
    const gap: number = this.pullOffsetVp;
    const h: number = REFRESH_INDICATOR_VP;
    if (gap <= h) {
      return 0;
    }
    const t: number = (gap - h) / (h * 0.5);
    return t > 1 ? 1 : t;
  }

  /** Refresh 自己的揭示区从屏幕顶算起、又排在 Scroll 之下，指示器放里面必然被栏体/列表压住；
   *  所以刷新区留空，指示器改用 Stack 上层的浮层（见 spec §5.5） */
  @Builder
  emptyIndicator() {
    Column().width('100%')
  }

  @Builder
  refreshIndicator() {
    Column() {
      LoadingProgress()
        .width(REFRESH_INDICATOR_VP)
        .height(REFRESH_INDICATOR_VP)
        .color($r('sys.color.ohos_id_color_emphasize'))
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .position({ x: 0, y: this.indicatorTopVp() })
    .opacity(this.indicatorOpacity())
    // 浮层压在拖拽区上方，不能吃手势
    .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  pageBody() {
    Refresh({ refreshing: $$this.isRefreshing, builder: this.emptyIndicator() }) {
      Scroll() {
        Column({ space: 12 }) {
          HapCard({ content: (): void => { this.tipBody() } })

          if (this.agcUser.length === 0) {
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
        // 顶栏内边距必须作为滚动内容的内边距（同 More.ets）：放在页面根上会把 Scroll 视口压到栏底之下，
        // 内容永远进不了栏下的幕布带，HDS 的 GRADIENT_BLUR 滚动档就永远不生效（见 spec §5.5 一致性缺陷）
        .padding({ left: $r('sys.float.padding_level6'), right: $r('sys.float.padding_level6'),
          top: topInsetVp(this.getUIContext(), this.safeTopPx),
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
    .refreshOffset(96)
    .onOffsetChange((offset: number): void => { this.pullOffsetVp = offset; })
    .onRefreshing(() => {
      this.refresh();
    })
  }

  build() {
    Stack() {
      this.pageBody()

      if (this.pullOffsetVp > 0 || this.isRefreshing) {
        this.refreshIndicator()
      }
    }
    .width('100%')
    .height('100%')
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
          .textAlign(TextAlign.Start)
        Text('于 ' + this.fmtDate(c.expireTime) + ' 过期')
          .fontSize(11)
          .fontColor(this.isExpired(c)
            ? $r('sys.color.ohos_id_color_warning')
            : $r('sys.color.ohos_id_color_text_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
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
