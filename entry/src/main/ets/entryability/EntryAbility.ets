import { AbilityConstant, UIAbility, Want, Configuration, ConfigurationConstant } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window, FrameCallback, UIContext } from '@kit.ArkUI';
import { fileIo } from '@kit.CoreFileKit';
import { preferences } from '@kit.ArkData';
import { logMaterialCapabilities } from '../common/MaterialPolicy';

/** postFrameCallback 收的是 FrameCallback 抽象类实例，ArkTS 不允许用对象字面量顶替 */
class ThemeFrameCallback extends FrameCallback {
  private readonly action: () => void;

  constructor(action: () => void) {
    super();
    this.action = action;
  }

  onFrame(frameTimeInNano: number): void {
    this.action();
  }
}

export default class EntryAbility extends UIAbility {
  private mainWin: window.Window | null = null;
  /** 上次保存的深浅色意图；补枪要等到 loadContent 之后再发，靠这个字段把值带到那一刻 */
  private themeMode: ConfigurationConstant.ColorMode | undefined = undefined;

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

  /**
   * 启动时恢复上次保存的深浅色。用同步读而非 async：只有赶在第一帧之前拿到值，
   * AppStorage.isDark 才能在首帧就是对的，否则首帧按浅色构建、标题白字压浅底，
   * 补枪之后还要多闪一下。
   */
  private restoreTheme(): void {
    try {
      const opts: preferences.Options = { name: 'hapinstaller' };
      const store: preferences.Preferences = preferences.getPreferencesSync(this.context, opts);
      const follow: boolean = store.getSync('followSystemDark', true) as boolean;
      const dark: boolean = store.getSync('darkModeOn', false) as boolean;
      AppStorage.setOrCreate<boolean>('followSystemDark', follow);
      AppStorage.setOrCreate<boolean>('darkModeOn', dark);
      this.themeMode = follow
        ? ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
        : (dark
          ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
          : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
      this.applyThemeMode();
      if (this.themeMode !== ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET) {
        // 显式深浅色时 isDark 由我们自己种，不等 onConfigurationUpdate，首帧的标题墨色才对
        this.applyBarColors(this.themeMode);
      }
    } catch (e) {
      const err = e as BusinessError;
      hilog.error(0x0000, 'HapInstaller', '%{public}s',
        '[theme] 读深浅色偏好失败 code=' + err.code + ' msg=' + err.message);
    }
  }

  private applyThemeMode(): void {
    const mode: ConfigurationConstant.ColorMode | undefined = this.themeMode;
    if (mode === undefined) {
      return;
    }
    try {
      this.context.setColorMode(mode);
    } catch (e) {
      const err = e as BusinessError;
      hilog.error(0x0000, 'HapInstaller', '%{public}s',
        '[theme] setColorMode(' + mode + ') 失败 code=' + err.code + ' msg=' + err.message);
    }
  }

  /**
   * 冷启动补枪：启动期那次 setColorMode 只改到 AbilityRuntime 的 Configuration
   * （实测 config=DARK、AppStorage.isDark=true、onConfigurationUpdate 也到了），
   * 但 ArkUI 的 ResourceManager 尚未挂上配置变更订阅，整屏 sys.color.* 仍按浅色限定解析。
   * 首帧之后再发一次才会走「新建 RM → 全树重解析」那条路。
   * 锚点实测（API 26 模拟器，相对 loadContent 回调）：0ms 与 +74ms 单发均无效；
   * 连续两个 vsync（+50/+105ms）3/3 次翻成深色；固定 500ms 一直有效但留半秒浅色闪帧。
   * vsync 早于 ArkUI 主题初始化时会打空，所以 500ms 兜底不能删 —— 打空的结果不是闪一下，是整程浅色。
   */
  private reapplyThemeAfterFirstFrame(): void {
    if (this.themeMode === undefined ||
      this.themeMode === ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET ||
      this.mainWin === null) {
      return;
    }
    setTimeout((): void => { this.applyThemeMode(); }, 500);
    try {
      const ui: UIContext = this.mainWin.getUIContext();
      ui.postFrameCallback(new ThemeFrameCallback((): void => {
        this.applyThemeMode();
        ui.postFrameCallback(new ThemeFrameCallback((): void => { this.applyThemeMode(); }));
      }));
    } catch (e) {
      const err = e as BusinessError;
      hilog.error(0x0000, 'HapInstaller', '%{public}s',
        '[theme] 帧锚点排期失败（500ms 兜底仍在）code=' + err.code + ' msg=' + err.message);
    }
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    // context.config 在本回调里仍是切换前的旧值，权威值只在 newConfig 里
    this.applyBarColors(newConfig.colorMode);
  }

  private applyBarColors(mode?: ConfigurationConstant.ColorMode): void {
    const colorMode: ConfigurationConstant.ColorMode | undefined = mode !== undefined
      ? mode : this.context.config.colorMode;
    const dark: boolean = colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    // isDark 先写、不依赖 mainWin：onConfigurationUpdate 可能早于窗口就绪，而顶栏档位要靠它选档
    AppStorage.setOrCreate<boolean>('isDark', dark);
    if (this.mainWin === null) {
      return;
    }
    const fg: string = dark ? '#FFFFFF' : '#000000';
    // 沉浸遮罩需要按深浅色给出带透明度的渐变色，token 无法直接取 alpha
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
      this.reapplyThemeAfterFirstFrame();
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
        // 悬浮工具条的 barWidth 只能是绝对 vp（FloatingTabBarWidth 不支持百分比，也未写超宽是否截断），
        // 二级页要让栏体接近满宽 → 由窗口实际宽度换算，而不是按某台设备写死。
        AppStorage.setOrCreate<number>('winWidthPx', win.getWindowProperties().windowRect.width);
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
