import { AbilityConstant, UIAbility, Want, Configuration, ConfigurationConstant } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { fileIo } from '@kit.CoreFileKit';
import { preferences } from '@kit.ArkData';
import { logMaterialCapabilities } from '../common/MaterialPolicy';

export default class EntryAbility extends UIAbility {
  private mainWin: window.Window | null = null;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      const params: Record<string, Object> | undefined = want.parameters;
      if (params !== undefined) {
        this.putString(params, 'autoConnect');
        this.putString(params, 'autoUrl');
        this.putString(params, 'autoSignMat');
        this.putString(params, 'autoExport');
        this.putString(params, 'autoUdid');
        this.putString(params, 'autoAgc');
        this.putString(params, 'autoWebUrl');
        this.putString(params, 'autoGenCsr');
        this.putString(params, 'autoBuiltin');
        this.putString(params, 'autoSign');
        this.putString(params, 'autoDumpLogs');
        this.putString(params, 'autoProfile');
        this.putString(params, 'autoCert');
        this.putString(params, 'autoLogin');
        this.putString(params, 'autoKeyPwd');
        this.putString(params, 'autoKeyAlias');
        this.putString(params, 'autoSignBare');
        this.putString(params, 'autoInstall');
      }
    } catch (e) {
      hilog.error(0x0000, 'HapInstaller', '%{public}s', 'read want params failed');
    }
    // 文件管理器/其他应用以"打开方式"传入安装包：把文件复制进沙盒，留给首页加载
    this.ingestExternalHap(want);
    this.restoreTheme();
    this.appendLifecycle('start', 'launchReason=' + launchParam.launchReason);
  }

  /** 浏览器授权页回跳（hapinstaller://）时被系统拉起：确保回到首页 */
  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'HapInstaller', '%{public}s', '[ability] onNewWant uri=' + (want.uri ?? ''));
    // 从文件管理器再次"打开方式"传文件时，也复制进沙盒供首页刷新
    this.ingestExternalHap(want);
    AppStorage.setOrCreate<number>('selectedTab', 0);
    this.appendLifecycle('foreground', 'reentry uri=' + (want.uri ?? ''));
  }

  onDestroy(): void {
    this.appendLifecycle('end', '');
  }

  /**
   * 心跳日志：每次冷启追加一行 start，正常退出追加一行 end。
   * 若一段会话只有 start 没有 end，即说明进程消失（被系统杀或原生崩溃）。
   */
  private appendLifecycle(phase: string, extra: string): void {
    try {
      const path: string = this.context.filesDir + '/lifecycle.log';
      const line: string = '[' + phase + '] ' + new Date().toISOString() +
        (extra.length > 0 ? (' ' + extra) : '') + '\n';
      const lf = fileIo.openSync(path,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.APPEND);
      fileIo.writeSync(lf.fd, line);
      fileIo.closeSync(lf);
    } catch (ignored) {
    }
  }

  private putString(params: Record<string, Object>, key: string): void {
    const v: Object | undefined = params[key];
    if (v !== undefined) {
      AppStorage.setOrCreate<string>(key, v.toString());
    }
  }

  /**
   * 文件管理器/其他应用以"打开方式"传入安装包文件时：
   * want.uri 形如 file://.../xxx.hap，系统已临时授权读取权限。
   * 把它复制进沙盒 tempDir/picked.hap，再通过 AppStorage('lastPickedHap') 交给首页显示。
   * 复制后原 URI 的临时权限即失效，沙盒副本可长期访问。
   */
  private ingestExternalHap(want: Want): void {
    const uri: string | undefined = want.uri;
    if (uri === undefined || uri.length === 0) {
      return;
    }
    // 只处理 file:// 且扩展名为 .hap/.hsp/.app 的 URI，避免误吞 hapinstaller:// 回跳
    if (!uri.startsWith('file://')) {
      return;
    }
    const lower: string = uri.toLowerCase();
    if (!lower.endsWith('.hap') && !lower.endsWith('.hsp') && !lower.endsWith('.app')) {
      return;
    }
    try {
      const dst: string = this.context.tempDir + '/picked.hap';
      const inFile = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      const outFile = fileIo.openSync(dst,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      fileIo.copyFileSync(inFile.fd, outFile.fd);
      fileIo.closeSync(inFile);
      fileIo.closeSync(outFile);
      // 用路径 + 递增序号双写：路径供 aboutToAppear 单次消费，序号供在前台时 @Watch 触发刷新
      const seq: number = (AppStorage.get<number>('lastPickedHapSeq') ?? 0) + 1;
      AppStorage.setOrCreate<string>('lastPickedHap', dst);
      AppStorage.setOrCreate<number>('lastPickedHapSeq', seq);
      hilog.info(0x0000, 'HapInstaller', '%{public}s', '[ability] 外部安装包已导入: ' + dst);
    } catch (e) {
      hilog.error(0x0000, 'HapInstaller', '%{public}s', '[ability] 导入外部安装包失败: ' + (e as Error).message);
    }
  }

  /** 启动时恢复上次保存的深浅色设置，保证「跟随系统」在进 App 前就生效 */
  private restoreTheme(): void {
    preferences.getPreferences(this.context, 'hapinstaller').then(async (store): Promise<void> => {
      const follow: boolean = await store.get('followSystemDark', true) as boolean;
      const dark: boolean = await store.get('darkModeOn', false) as boolean;
      AppStorage.setOrCreate<boolean>('followSystemDark', follow);
      AppStorage.setOrCreate<boolean>('darkModeOn', dark);
      const mode: ConfigurationConstant.ColorMode = follow
        ? ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
        : (dark
          ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
          : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
      this.context.setColorMode(mode);
    }).catch((): void => {});
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    // context.config 在本回调里仍是切换前的旧值，权威值只在 newConfig 里
    this.applyBarColors(newConfig.colorMode);
  }

  private applyBarColors(mode?: ConfigurationConstant.ColorMode): void {
    if (this.mainWin === null) {
      return;
    }
    const colorMode: ConfigurationConstant.ColorMode | undefined = mode !== undefined
      ? mode : this.context.config.colorMode;
    const dark: boolean = colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    // 沉浸遮罩需要按深浅色给出带透明度的渐变色，token 无法直接取 alpha
    AppStorage.setOrCreate<boolean>('isDark', dark);
    const fg: string = dark ? '#FFFFFF' : '#000000';
    this.mainWin.setWindowSystemBarProperties({
      statusBarColor: '#00000000',
      navigationBarColor: '#00000000',
      statusBarContentColor: fg,
      navigationBarContentColor: fg
    }).catch((): void => {});
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'HapInstaller', 'loadContent failed: %{public}s', JSON.stringify(err));
      }
      this.setupImmersiveWindow(windowStage);
      logMaterialCapabilities();
    });
  }

  /** 沉浸光感：窗口全屏布局 + 状态栏/导航条透明，避让区高度写入 AppStorage 由页面自行留出 */
  private setupImmersiveWindow(windowStage: window.WindowStage): void {
    try {
      const win: window.Window = windowStage.getMainWindowSync();
      this.mainWin = win;
      win.setWindowLayoutFullScreen(true).then((): void => {
        const sysArea: window.AvoidArea =
          win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
        const navArea: window.AvoidArea =
          win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
        AppStorage.setOrCreate<number>('safeTopPx', sysArea.topRect.height);
        AppStorage.setOrCreate<number>('safeBottomPx', navArea.bottomRect.height);
        this.applyBarColors();
      }).catch((): void => {});
      win.on('avoidAreaChange', (data: window.AvoidAreaOptions): void => {
        if (data.type === window.AvoidAreaType.TYPE_SYSTEM) {
          AppStorage.setOrCreate<number>('safeTopPx', data.area.topRect.height);
        } else if (data.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
          AppStorage.setOrCreate<number>('safeBottomPx', data.area.bottomRect.height);
        }
      });
    } catch (e) {
      hilog.error(0x0000, 'HapInstaller', '%{public}s', 'immersive setup failed');
    }
  }

  onWindowStageDestroy(): void {
    this.mainWin = null;
  }
}
