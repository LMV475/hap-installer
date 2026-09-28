import { common, Want, bundleManager } from '@kit.AbilityKit';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { promptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
import { HapCard } from '../components/HapCard';
import { PillButton } from '../components/PillButton';
import { topInsetVp, bottomInsetVp } from '../common/Immersive';

const PROJECT_REPO: string = 'https://github.com/LMV475/hap-installer';
const RELEASE_API: string = 'https://api.github.com/repos/LMV475/hap-installer/releases/latest';

@Component
struct MoreRow {
  @Prop label: string = '';
  @Prop subText: string = '';
  @Prop type: string = 'arrow';
  @Prop isOn: boolean = false;
  @Prop disabled: boolean = false;
  @Prop tapable: boolean = false;
  onTap: () => void = (): void => {};
  onToggle: (v: boolean) => void = (_v: boolean): void => {};

  build() {
    Row({ space: 8 }) {
      Column({ space: 2 }) {
        Text(this.label)
          .fontSize(15)
          .fontColor(this.disabled
            ? $r('sys.color.ohos_id_color_text_tertiary')
            : $r('sys.color.ohos_id_color_text_primary'))
            .width('100%')
        if (this.subText.length > 0 && this.type !== 'text') {
          Text(this.subText)
            .fontSize(11)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .width('100%')
        }
      }.layoutWeight(1)
      if (this.type === 'switch') {
        Toggle({ type: ToggleType.Switch, isOn: this.isOn })
          .enabled(!this.disabled)
          .onChange((v: boolean): void => { this.onToggle(v); })
      } else if (this.type === 'text') {
        Text(this.subText)
          .fontSize(13)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
      } else if (this.type === 'button') {
        PillButton({ label: this.isOn ? '确定' : '操作', enabled_: !this.disabled,
          onClickAction: (): void => { this.onTap(); } })
      } else {
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([$r('sys.color.ohos_id_color_text_tertiary')])
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 56 })
    .padding({ top: $r('sys.float.padding_level3'), bottom: $r('sys.float.padding_level3') })
    .onClick((): void => {
      if ((this.type === 'arrow' || this.tapable) && !this.disabled) {
        this.onTap();
      }
    })
  }
}

@Component
export struct More {
  @Consume('navStack') pathStack: NavPathStack;
  @StorageLink('followSystemDark') followSystemDark: boolean = true;
  @StorageLink('darkModeOn') darkModeOn: boolean = false;
  @StorageLink('autoPortOn') autoPortOn: boolean = false;
  @StorageLink('safeTopPx') safeTopPx: number = 0;
  @StorageLink('safeBottomPx') safeBottomPx: number = 0;
  @State tipText: string = '';
  @State checkingUpdate: boolean = false;
  /** 签名配置入口：默认隐藏，连点「应用版本」十下才出现，且只在本进程内有效 */
  @State signEntryVisible: boolean = false;
  private versionTaps: number = 0;
  private lastVersionTap: number = 0;
  private appVersion: string = '1.0.0';

  aboutToAppear(): void {
    this.loadThemePrefs();
    this.loadAppVersion();
  }

  private loadAppVersion(): void {
    try {
      const info = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      this.appVersion = info.versionName;
    } catch (e) {
    }
  }

  private async loadThemePrefs(): Promise<void> {
    try {
      const store = await preferences.getPreferences(this.ctx(), 'hapinstaller');
      this.followSystemDark = await store.get('followSystemDark', true) as boolean;
      this.darkModeOn = await store.get('darkModeOn', false) as boolean;
      this.autoPortOn = await store.get('autoPortOn', false) as boolean;
    } catch (e) {
    }
  }

  private saveThemePrefs(): void {
    preferences.getPreferences(this.ctx(), 'hapinstaller').then(async (store): Promise<void> => {
      await store.put('followSystemDark', this.followSystemDark);
      await store.put('darkModeOn', this.darkModeOn);
      await store.put('autoPortOn', this.autoPortOn);
      await store.flush();
    }).catch((): void => {});
  }

  private openSignConfig(): void {
    AppStorage.setOrCreate<number>('selectedTab', 0);
    AppStorage.setOrCreate<number>('signSheetRequest', Date.now());
  }

  /** 用系统浏览器打开 GitHub 仓库 */
  private openRepo(): void {
    const want: Want = {
      action: 'ohos.want.action.viewData',
      uri: PROJECT_REPO,
      entities: ['entity.system.browsable']
    };
    this.ctx().startAbility(want).catch((e: BusinessError): void => {
      this.tipText = '无法打开浏览器: ' + e.message;
    });
  }

  /** 请求 GitHub releases/latest 对比版本号 */
  private async checkUpdate(): Promise<void> {
    if (this.checkingUpdate) {
      return;
    }
    this.checkingUpdate = true;
    promptAction.showToast({ message: '正在检查更新…', duration: 1500 });
    const client = http.createHttp();
    try {
      const resp = await client.request(RELEASE_API, {
        method: http.RequestMethod.GET,
        header: { 'Accept': 'application/vnd.github+json', 'User-Agent': 'HapInstaller' },
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 20000
      });
      if (resp.responseCode !== 200) {
        this.tipText = '检查更新失败（HTTP ' + resp.responseCode + '）';
        return;
      }
      const obj: Record<string, Object> = JSON.parse(String(resp.result)) as Record<string, Object>;
      const tagName: string = String(obj['tag_name'] ?? '');
      const latestVersion: string = tagName.startsWith('v') ? tagName.substring(1) : tagName;
      const htmlUrl: string = String(obj['html_url'] ?? PROJECT_REPO);
      const body: string = String(obj['body'] ?? '');
      if (latestVersion.length === 0) {
        this.tipText = '未获取到版本信息';
        return;
      }
      if (this.compareVersion(latestVersion, this.appVersion) > 0) {
        const releaseNotes: string = body.length > 0 ? '\n\n' + body.substring(0, 200) : '';
        promptAction.showDialog({
          title: '发现新版本 v' + latestVersion,
          message: '当前版本 v' + this.appVersion + releaseNotes,
          buttons: [
            { text: '前往下载', color: '#0A59F7' },
            { text: '稍后', color: '#666666' }
          ]
        }).then((res: promptAction.ShowDialogSuccessResponse): void => {
          if (res.index === 0) {
            const want: Want = {
              action: 'ohos.want.action.viewData',
              uri: htmlUrl,
              entities: ['entity.system.browsable']
            };
            this.ctx().startAbility(want).catch((): void => {});
          }
        }).catch((): void => {});
      } else {
        promptAction.showToast({ message: '已是最新版本 v' + this.appVersion, duration: 2000 });
      }
    } catch (e) {
      const err = e as BusinessError;
      this.tipText = '检查更新失败: ' + err.message;
    } finally {
      client.destroy();
      this.checkingUpdate = false;
    }
  }

  /** 版本号比较：返回 >0 表示 a 更新，=0 相同，<0 a 更旧 */
  private compareVersion(a: string, b: string): number {
    const pa: string[] = a.split('.');
    const pb: string[] = b.split('.');
    const len: number = Math.max(pa.length, pb.length);
    for (let i = 0; i < len; i++) {
      const na: number = parseInt(pa[i] ?? '0', 10);
      const nb: number = parseInt(pb[i] ?? '0', 10);
      if (na !== nb) {
        return na - nb;
      }
    }
    return 0;
  }

  private ctx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  /** 连点十下版本号显示签名配置入口；间隔超过 2s 重新计数 */
  private onVersionTap(): void {
    if (this.signEntryVisible) {
      return;
    }
    const now: number = Date.now();
    this.versionTaps = now - this.lastVersionTap > 2000 ? 1 : this.versionTaps + 1;
    this.lastVersionTap = now;
    if (this.versionTaps >= 10) {
      this.versionTaps = 0;
      this.signEntryVisible = true;
      promptAction.showToast({ message: '已显示「签名配置」入口', duration: 2000 });
    } else if (this.versionTaps >= 7) {
      promptAction.showToast({
        message: '再点 ' + (10 - this.versionTaps) + ' 次显示签名配置', duration: 1000
      });
    }
  }

  private async applyColorMode(): Promise<void> {
    const mode: ConfigurationConstant.ColorMode = this.followSystemDark
      ? ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
      : (this.darkModeOn
        ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
        : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
    try {
      this.ctx().setColorMode(mode);
    } catch (e) {
      const err = e as BusinessError;
      this.tipText = '切换主题失败: ' + err.message;
    }
  }

  private showDirs(): void {
    const c: common.UIAbilityContext = this.ctx();
    promptAction.showDialog({
      title: '应用目录',
      message: 'filesDir: ' + c.filesDir + '\ntempDir: ' + c.tempDir + '\ncacheDir: ' + c.cacheDir,
      buttons: [{ text: '复制 filesDir', color: '#0A59F7' }, { text: '关闭', color: '#666666' }]
    }).then((res: promptAction.ShowDialogSuccessResponse): void => {
      if (res.index === 0) {
        this.tipText = '已显示 filesDir 路径';
      }
    }).catch((): void => {});
  }

  private confirmClear(): void {
    promptAction.showDialog({
      title: '清空数据',
      message: '将删除 preferences 中的证书/目标/登录态记录，签名产物保留。确认继续？',
      buttons: [{ text: '清空', color: '#D9534F' }, { text: '取消', color: '#666666' }]
    }).then((res: promptAction.ShowDialogSuccessResponse): void => {
      if (res.index === 0) {
        this.doClear(false);
      }
    }).catch((): void => {});
  }

  private confirmResetSign(): void {
    promptAction.showDialog({
      title: '重置签名配置',
      message: '仅清除证书链 / Profile / 密钥库路径。确认继续？',
      buttons: [{ text: '重置', color: '#D9534F' }, { text: '取消', color: '#666666' }]
    }).then((res: promptAction.ShowDialogSuccessResponse): void => {
      if (res.index === 0) {
        this.doClear(true);
      }
    }).catch((): void => {});
  }

  private async doClear(signOnly: boolean): Promise<void> {
    try {
      const store = await preferences.getPreferences(this.ctx(), 'hapinstaller');
      if (signOnly) {
        await store.delete('cerPath');
        await store.delete('p7bPath');
        await store.delete('p12Path');
      } else {
        await store.clear();
      }
      await store.flush();
      this.tipText = signOnly ? '签名配置已重置' : '所有数据已清空';
    } catch (e) {
      const err = e as BusinessError;
      this.tipText = '清空失败: ' + err.message;
    }
  }

  private showTips(): void {
    promptAction.showDialog({
      title: '温馨提示',
      message: '① 端侧签名仅用于自用 / 企业分发\n② 只能装华为 CA 链签名的包\n③ 装机后本应用会被替换并自动重启',
      buttons: [{ text: '知道了', color: '#0A59F7' }]
    }).catch((): void => {});
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        if (this.tipText.length > 0) {
          Text(this.tipText)
            .fontSize(11)
            .fontColor($r('sys.color.ohos_id_color_emphasize'))
            .width('100%')
        }

        HapCard({ title: '工具', content: (): void => { this.toolsBody() } })
        HapCard({ title: '设置', content: (): void => { this.settingsBody() } })
        HapCard({ title: '显示', content: (): void => { this.displayBody() } })
        HapCard({ title: '帮助', content: (): void => { this.helpBody() } })
        HapCard({ title: '关于', content: (): void => { this.aboutBody() } })
      }
      .width('100%')
      .padding({ left: $r('sys.float.padding_level6'), right: $r('sys.float.padding_level6'),
        top: topInsetVp(this.getUIContext(), this.safeTopPx),
        bottom: bottomInsetVp(this.getUIContext(), this.safeBottomPx) })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .align(Alignment.TopStart)
    .edgeEffect(EdgeEffect.Spring)
    .scrollBar(BarState.Off)
  }

  @Builder
  toolsBody() {
    Column({ space: 0 }) {
      MoreRow({ label: '命令行工具', subText: '执行 HDC 命令', type: 'arrow',
        onTap: (): void => { this.pathStack.pushPath({ name: 'Terminal' }); } })
      Divider().color($r('sys.color.ohos_id_color_list_separator'))
      MoreRow({ label: 'ACL 权限', subText: 'Profile 申请使用的权限列表', type: 'arrow',
        onTap: (): void => { this.pathStack.pushPath({ name: 'Acl' }); } })
      Divider().color($r('sys.color.ohos_id_color_list_separator'))
      MoreRow({ label: '团队设备', subText: '团队 / 设备 / 历史连接', type: 'arrow',
        onTap: (): void => { this.pathStack.pushPath({ name: 'TeamDevice' }); } })
    }.width('100%')
  }

  @Builder
  settingsBody() {
    Column({ space: 0 }) {
      if (this.signEntryVisible) {
        MoreRow({ label: '签名配置', subText: '证书 / 密钥库 / AGC 申请', type: 'arrow',
          onTap: (): void => { this.openSignConfig(); } })
        Divider().color($r('sys.color.ohos_id_color_list_separator'))
      }
      MoreRow({ label: '清空数据', subText: 'preferences + 登录态', type: 'arrow',
        onTap: (): void => { this.confirmClear(); } })
      Divider().color($r('sys.color.ohos_id_color_list_separator'))
      MoreRow({ label: '重置签名配置', subText: '仅清除证书/Profile/密钥库路径', type: 'arrow',
        onTap: (): void => { this.confirmResetSign(); } })
      Divider().color($r('sys.color.ohos_id_color_list_separator'))
      MoreRow({ label: '自动无线调试端口', type: 'switch', isOn: this.autoPortOn,
        onToggle: (v: boolean): void => {
          this.autoPortOn = v;
          this.saveThemePrefs();
        } })
      Divider().color($r('sys.color.ohos_id_color_list_separator'))
      MoreRow({ label: '查看目录', type: 'arrow',
        onTap: (): void => { this.showDirs(); } })
    }.width('100%')
  }

  @Builder
  displayBody() {
    Column({ space: 0 }) {
      MoreRow({ label: '随系统深色模式', type: 'switch', isOn: this.followSystemDark,
        onToggle: (v: boolean): void => {
          this.followSystemDark = v;
          this.saveThemePrefs();
          this.applyColorMode();
        } })
      Divider().color($r('sys.color.ohos_id_color_list_separator'))
      MoreRow({ label: '深色模式', subText: this.followSystemDark ? '已随系统' : '',
        type: 'switch', isOn: this.darkModeOn, disabled: this.followSystemDark,
        onToggle: (v: boolean): void => {
          this.darkModeOn = v;
          this.saveThemePrefs();
          this.applyColorMode();
        } })
    }.width('100%')
  }

  @Builder
  helpBody() {
    Column({ space: 0 }) {
      MoreRow({ label: '温馨提示', type: 'arrow',
        onTap: (): void => { this.showTips(); } })
      Divider().color($r('sys.color.ohos_id_color_list_separator'))
      MoreRow({ label: '使用教程', type: 'arrow',
        onTap: (): void => { this.pathStack.pushPath({ name: 'UserGuide' }); } })
      Divider().color($r('sys.color.ohos_id_color_list_separator'))
      MoreRow({ label: '免责声明', type: 'arrow',
        onTap: (): void => { this.pathStack.pushPath({ name: 'Privacy' }); } })
    }.width('100%')
  }

  @Builder
  aboutBody() {
    Column({ space: 0 }) {
      MoreRow({ label: '应用版本', subText: this.appVersion, type: 'text', tapable: true,
        onTap: (): void => { this.onVersionTap(); } })
      Divider().color($r('sys.color.ohos_id_color_list_separator'))
      MoreRow({ label: '项目地址', subText: 'GitHub 开源仓库', type: 'arrow',
        onTap: (): void => { this.openRepo(); } })
      Divider().color($r('sys.color.ohos_id_color_list_separator'))
      MoreRow({ label: '检测更新', subText: this.checkingUpdate ? '检查中…' : '获取最新版本',
        type: 'arrow', disabled: this.checkingUpdate,
        onTap: (): void => { this.checkUpdate(); } })
    }.width('100%')
  }
}
