import { common, Want } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { fileIo, picker } from '@kit.CoreFileKit';
import { request, pasteboard } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { promptAction, LengthMetrics } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { HdcService } from '../common/HdcService';
import { SignService, SignOutcome } from '../common/SignService';
import { AgcService, AgcAuthInfo, AgcCertInfo, AgcDeviceInfo } from '../common/AgcService';
import { Store } from '../common/Store';
import { HapCard } from '../components/HapCard';
import { PillButton } from '../components/PillButton';
import { HapInput } from '../components/HapInput';
import { HomeSettingItem } from '../components/HomeSettingItem';
import { ConnectDeviceSheet } from '../components/ConnectDeviceSheet';
import { loadAclList } from '../common/AclDefaults';
import { addHistoryTarget } from '../common/HistoryTargets';
import { HapPeek } from '../common/HapPeek';
import { getSecret, putSecret } from '../common/SecureStore';
import { topInsetVp, bottomInsetVp } from '../common/Immersive';
import { worker, MessageEvents, ErrorEvent, util } from '@kit.ArkTS';

const SELF_BUNDLE: string = 'cn.lxh.hapinstaller';
// 登录态在 ASSET 加密存储中的记录名
const AGC_AUTH_ALIAS: string = 'hapinstaller_agc_auth';

@Component
export struct Home {
  @Consume('navStack') pathStack: NavPathStack;
  @State target: string = '';
  @State status: string = '内核未启动';
  @State busy: boolean = false;
  @State hapPath: string = '';
  @State hapBundle: string = '';
  @State hapLabel: string = '未选择 HAP';
  @State bundleName: string = '';
  @State url: string = '';
  @State cerPath: string = '';
  @State p7bPath: string = '';
  @State p12Path: string = '';
  @State keyPwd: string = '';
  @State keyAlias: string = '';
  @State signedPath: string = '';
  @State udid: string = '';
  @State csrPath: string = '';
  @State agcUser: string = '';
  @State packageName: string = '';
  @State matLabel: string = '证书材料未选择';
  /** 材料来源：'builtin' = 默认使用内置测试链；'custom' = 用户在「签名配置」里自配置的材料 */
  @State matSource: string = 'builtin';
  @State logs: string[] = [];
  @State connectSheetOpen: boolean = false;
  @State signSheetOpen: boolean = false;
  @State ipPart: string = '127.0.0.1';
  @State portPart: string = '';
  @StorageLink('signSheetRequest') @Watch('onSignSheetRequest') signSheetRequest: number = 0;
  @StorageLink('safeTopPx') safeTopPx: number = 0;
  @StorageLink('safeBottomPx') safeBottomPx: number = 0;
  private kernelReady: boolean = false;
  private autoRan: boolean = false;
  private configLoading: Promise<void> = Promise.resolve();

  aboutToAppear(): void {
    this.bootstrapStore();
    const autoSignBare: string | undefined = AppStorage.get<string>('autoSignBare');
    if (autoSignBare === '1' && !this.autoRan) {
      this.autoRan = true;
      this.loadConfig()
        .then((): Promise<void> => this.doBareSign())
        .catch((e: BusinessError): void => {
          this.log('[bare] 异常: ' + e.message);
        });
      return;
    }
    if (!this.kernelReady) {
      this.bootKernel();
      this.configLoading = this.loadConfig();
    }
    if (!this.autoRan) {
      this.autoRan = true;
      this.runAutoParams();
    }
    this.collectWebDownload();
  }

  private async bootstrapStore(): Promise<void> {
    try {
      await Store.init(this.ctx());
      const repaired: number = await Store.repairKilled(this.ctx());
      if (repaired > 0) {
        this.log('[store] 修复了 ' + repaired + ' 条上次装机遗留记录');
      }
    } catch (e) {
      const err = e as BusinessError;
      this.log('[store] 初始化失败: ' + err.message);
    }
  }

  private ctx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private log(line: string): void {
    const stamp: string = new Date().toTimeString().substring(0, 8);
    const parts: string[] = line.split('\n');
    for (const p of parts) {
      if (p.length > 0) {
        this.logs = this.logs.concat(['[' + stamp + '] ' + p]);
        hilog.info(0x0000, 'HapInstaller', '%{public}s', p);
        try {
          const logPath: string = this.ctx().filesDir + '/hapinstaller.log';
          const lf = fileIo.openSync(logPath,
            fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.APPEND);
          fileIo.writeSync(lf.fd, '[' + stamp + '] ' + p + '\n');
          fileIo.closeSync(lf);
        } catch (ignored) {
        }
      }
    }
    if (this.logs.length > 400) {
      this.logs = this.logs.slice(this.logs.length - 400);
    }
  }

  private readTextOr(filePath: string): string {
    try {
      return fileIo.readTextSync(filePath);
    } catch (e) {
      return '';
    }
  }

  private async runAutoParams(): Promise<void> {
    // 非 bare 通道下也支持从 want 参数注入 keyPwd/alias（preferences 出于 §十七 安全考虑不持久化 pwd）
    const kPwd: string | undefined = AppStorage.get<string>('autoKeyPwd');
    if (kPwd !== undefined && kPwd.length > 0) {
      this.keyPwd = kPwd;
    }
    const kAlias: string | undefined = AppStorage.get<string>('autoKeyAlias');
    if (kAlias !== undefined && kAlias.length > 0) {
      this.keyAlias = kAlias;
    }
    // 材料/目标路径由 loadConfig 异步恢复，auto 参数必须等它就绪后再判定
    await this.configLoading;
    // hapPath 兜底：若 preferences 没记录且 temp/picked.hap 存在，视作待签包（与 doBareSign 行为一致）
    if (this.hapPath.length === 0) {
      const fb: string = this.ctx().tempDir + '/picked.hap';
      if (fileIo.accessSync(fb)) {
        this.markPicked(fb);
      }
    }
    const autoConnect: string | undefined = AppStorage.get<string>('autoConnect');
    const autoUrl: string | undefined = AppStorage.get<string>('autoUrl');
    const autoSignMat: string | undefined = AppStorage.get<string>('autoSignMat');
    if (autoConnect !== undefined && autoConnect.length > 0) {
      this.target = autoConnect;
      this.log('[auto] 连接 ' + autoConnect);
      await this.doConnect();
    }
    const autoDumpLogs: string | undefined = AppStorage.get<string>('autoDumpLogs');
    if (autoDumpLogs !== undefined && autoDumpLogs === '1') {
      this.log('[auto] 导出签名器日志');
      await this.exportFile(this.ctx().tempDir + '/sign.out', '/data/local/tmp/sign.out');
      await this.exportFile(this.ctx().tempDir + '/sign_stdout.txt', '/data/local/tmp/sign_stdout.txt');
      await this.exportFile(this.ctx().tempDir + '/signed.hap', '/data/local/tmp/partial_signed.hap');
      await this.exportFile(this.ctx().filesDir + '/hapinstaller-debug.cer', '/data/local/tmp/hapinstaller-debug.cer');
      await this.exportFile(this.ctx().filesDir + '/hapinstaller-debug.p7b', '/data/local/tmp/hapinstaller-debug.p7b');
      await this.exportFile(this.ctx().filesDir + '/hapinstaller.p12', '/data/local/tmp/hapinstaller.p12');
      await this.exportFile(this.ctx().filesDir + '/hapinstaller.log', '/data/local/tmp/hapinstaller.log');
    }

    const autoUdid: string | undefined = AppStorage.get<string>('autoUdid');
    if (autoUdid !== undefined && autoUdid === '1') {
      this.log('[auto] 读取本机 UDID');
      await this.doReadUdid();
    }
    const autoBuiltin: string | undefined = AppStorage.get<string>('autoBuiltin');
    if (autoBuiltin !== undefined && autoBuiltin === '1') {
      this.log('[auto] 使用内置材料');
      await this.doUseBuiltin();
      this.log('[check] 内置材料 p12=' + (fileIo.accessSync(this.p12Path) ? 'OK' : 'MISSING') +
        ' cer=' + (fileIo.accessSync(this.cerPath) ? 'OK' : 'MISSING') +
        ' p7b=' + (fileIo.accessSync(this.p7bPath) ? 'OK' : 'MISSING'));
    }
    const autoLogin: string | undefined = AppStorage.get<string>('autoLogin');
    if (autoLogin !== undefined && autoLogin === '1') {
      this.log('[auto] 登录华为账号');
      await this.doLogin();
    }
    const autoCert: string | undefined = AppStorage.get<string>('autoCert');
    if (autoCert !== undefined && autoCert === '1') {
      const t0: number = Date.now();
      await this.doApplyCert();
      this.log('[check] 证书步骤耗时 ' + Math.round((Date.now() - t0) / 1000) + ' 秒，cer=' +
        (fileIo.accessSync(this.cerPath) ? 'OK' : 'MISSING'));
    }
    const autoProfile: string | undefined = AppStorage.get<string>('autoProfile');
    if (autoProfile !== undefined && autoProfile === '1') {
      const t1: number = Date.now();
      await this.doApplyProfile();
      this.log('[check] Profile 步骤耗时 ' + Math.round((Date.now() - t1) / 1000) + ' 秒，p7b=' +
        (fileIo.accessSync(this.p7bPath) ? 'OK' : 'MISSING'));
    }
    const autoGenCsr: string | undefined = AppStorage.get<string>('autoGenCsr');
    if (autoGenCsr !== undefined && autoGenCsr === '1') {
      const autoPwd: string | undefined = AppStorage.get<string>('autoKeyPwd');
      if (autoPwd !== undefined && autoPwd.length > 0) {
        this.keyPwd = autoPwd;
      }
      const autoAlias: string | undefined = AppStorage.get<string>('autoKeyAlias');
      if (autoAlias !== undefined && autoAlias.length > 0) {
        this.keyAlias = autoAlias;
      }
      this.log('[auto] 生成密钥库 + CSR');
      await this.doGenKey();
      await this.doGenCsr();
      await this.exportFile(this.ctx().tempDir + '/sign.out', '/data/local/tmp/gen_sign.out');
      await this.exportFile(this.ctx().filesDir + '/app.csr', '/data/local/tmp/app.csr');
      await this.exportFile(this.ctx().filesDir + '/app.p12', '/data/local/tmp/app.p12');
    }
    const autoWebUrl: string | undefined = AppStorage.get<string>('autoWebUrl');
    if (autoWebUrl !== undefined && autoWebUrl.length > 0) {
      this.log('[auto] 内嵌 Web 打开 ' + autoWebUrl);
      this.openCertWeb(autoWebUrl);
    }
    const autoAgc: string | undefined = AppStorage.get<string>('autoAgc');
    if (autoAgc !== undefined && autoAgc === '1') {
      await this.openAgc('cert');
    }
    if (autoUrl !== undefined && autoUrl.length > 0) {
      this.url = autoUrl;
      this.log('[step] 下载待签包: ' + autoUrl);
      const p: string = await this.downloadTo(autoUrl, 'picked.hap');
      if (p.length > 0) {
        this.markPicked(p);
      }
    }
    if (autoSignMat !== undefined && autoSignMat.length > 0) {
      const parts: string[] = autoSignMat.split(',');
      if (parts.length >= 5) {
        this.cerPath = await this.downloadTo(parts[0], 'chain.cer');
        this.p7bPath = await this.downloadTo(parts[1], 'profile.p7b');
        this.p12Path = await this.downloadTo(parts[2], 'app.p12');
        this.keyPwd = parts[3];
        this.keyAlias = parts[4];
        this.matSource = 'custom';
        this.matLabel = '材料就绪（alias=' + this.keyAlias + '）';
        this.log('[auto] 签名材料已就绪');
        const autoExport: string | undefined = AppStorage.get<string>('autoExport');
        if (autoExport !== undefined && autoExport === '1') {
          await this.doSignWithDiagnostics();
          await this.exportFile(this.ctx().tempDir + '/signed.hap', '/data/local/tmp/signed.hap');
        } else {
          await this.doSign();
        }
      }
    }
    const autoSign: string | undefined = AppStorage.get<string>('autoSign');
    if (autoSign !== undefined && autoSign === '1') {
      this.log('[step] 开始签名，hap=' + this.hapPath + ' cer=' + this.cerPath + ' p7b=' + this.p7bPath);
      // doSign 内部已带 60 秒超时 + 一次重试，这里不再额外死等
      await this.doSign();
      await this.exportFile(this.ctx().tempDir + '/sign.out', '/data/local/tmp/sign.out');
      await this.exportFile(this.ctx().tempDir + '/sign_stdout.txt', '/data/local/tmp/sign_stdout.txt');
      await this.exportFile(this.ctx().tempDir + '/signed.hap', '/data/local/tmp/signed.hap');
      await this.exportFile(this.ctx().filesDir + '/hapinstaller-debug.cer', '/data/local/tmp/hapinstaller-debug.cer');
      await this.exportFile(this.ctx().filesDir + '/hapinstaller-debug.p7b', '/data/local/tmp/hapinstaller-debug.p7b');
      await this.exportFile(this.ctx().filesDir + '/hapinstaller.log', '/data/local/tmp/hapinstaller.log');
    }
    this.log('[step] 自动流程结束');
    await this.exportFile(this.ctx().filesDir + '/hapinstaller.log', '/data/local/tmp/hapinstaller.log');
    const autoInstall: string | undefined = AppStorage.get<string>('autoInstall');
    if (autoInstall !== undefined && autoInstall === '1' && this.signedPath.length > 0) {
      // T2 回归：走 App 内 HdcService 的 install 通道；同 bundle 替换会 kill 本进程，最后几行日志可能丢，属预期
      this.log('[auto] 即将自装: ' + this.signedPath);
      await this.exportFile(this.ctx().filesDir + '/hapinstaller.log', '/data/local/tmp/hapinstaller-preinstall.log');
      await this.doInstall();
    }
  }

  private async downloadTo(url: string, dstName: string): Promise<string> {
    const dst: string = this.ctx().tempDir + '/' + dstName;
    try {
      try {
        fileIo.unlinkSync(dst);
      } catch (ignored) {
      }
      const config: request.DownloadConfig = { url: url, filePath: dst };
      const task: request.DownloadTask = await request.downloadFile(this.ctx(), config);
      await new Promise<void>((resolve: () => void) => {
        task.on('complete', () => {
          resolve();
        });
        setTimeout(() => {
          resolve();
        }, 60000);
      });
      if (fileIo.accessSync(dst)) {
        this.log('下载完成: ' + dstName + ' (' + fileIo.statSync(dst).size + ' bytes)');
        return dst;
      }
      this.log('下载失败: ' + url);
      return '';
    } catch (e) {
      const err = e as BusinessError;
      this.log('下载异常: ' + err.message);
      return '';
    }
  }

  private bootKernel(): void {
    try {
      HdcService.startServer(this.ctx().tempDir);
      this.kernelReady = true;
      this.status = '内核已就绪（hdc host 运行中）';
      this.log('hdc 内核已启动，沙箱目录 ' + this.ctx().tempDir);
    } catch (e) {
      const err = e as BusinessError;
      this.status = '内核启动失败';
      this.log('内核启动失败: ' + err.message);
    }
  }

  private async exec(cmd: string): Promise<string> {
    this.log('$ hdc ' + cmd);
    const out: string = await HdcService.run(cmd, this.ctx().tempDir);
    this.log(out.trim());
    return out;
  }

  private async doConnect(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    try {
      const out: string = await this.exec('tconn ' + this.target.trim());
      const ok: boolean = out.indexOf('Connect OK') >= 0;
      this.status = ok ? '已连接 ' + this.target.trim() : '连接结果见日志';
      if (ok) {
        addHistoryTarget(this.ctx(), this.target.trim());
        await this.saveConfig();
      }
      await this.doRefresh();
    } catch (e) {
      const err = e as BusinessError;
      this.log('连接异常: ' + err.message);
    }
    this.busy = false;
  }

  private async doRefresh(): Promise<void> {
    try {
      const out: string = await this.exec('list targets');
      const lines: string[] = out.split('\n').filter((l: string): boolean => l.trim().length > 0);
      this.status = lines.length > 0 ? ('发现 ' + lines.length + ' 个目标') : '未发现目标';
    } catch (e) {
      const err = e as BusinessError;
      this.log('刷新异常: ' + err.message);
    }
  }

  /** 读取本机 UDID：hdc shell bm get --udid（需先连接无线调试目标） */
  /** 收取 CertWeb 页面下载到沙箱的材料，按扩展名自动归类 */
  private collectWebDownload(): void {
    const path: string | undefined = AppStorage.get<string>('lastDownload');
    if (path === undefined || path.length === 0) {
      return;
    }
    AppStorage.setOrCreate<string>('lastDownload', '');
    if (!fileIo.accessSync(path)) {
      return;
    }
    if (path.endsWith('.cer')) {
      this.cerPath = path;
    } else if (path.endsWith('.p7b')) {
      this.p7bPath = path;
    } else if (path.endsWith('.p12') || path.endsWith('.jks')) {
      this.p12Path = path;
    } else {
      this.log('已下载（未识别类型）: ' + path);
      return;
    }
    const ready: number = (this.cerPath.length > 0 ? 1 : 0) + (this.p7bPath.length > 0 ? 1 : 0) +
      (this.p12Path.length > 0 ? 1 : 0);
    this.matSource = 'custom';
    this.matLabel = '证书材料 ' + ready + '/3 已选（含网页下载）';
    this.log('网页下载材料已导入: ' + path);
    this.saveConfig();
  }

  private async saveConfig(): Promise<void> {
    try {
      const store = await preferences.getPreferences(this.ctx(), 'hapinstaller');
      await store.put('target', this.target);
      if (this.hapPath.length > 0 && fileIo.accessSync(this.hapPath)) {
        await store.put('hapPath', this.hapPath);
      }
      await store.put('cerPath', this.cerPath);
      await store.put('p7bPath', this.p7bPath);
      await store.put('p12Path', this.p12Path);
      await store.put('keyAlias', this.keyAlias);
      await store.put('matSource', this.matSource);
      if (this.udid.length === 64) {
        await store.put('udid', this.udid);
      }
      const auth: AgcAuthInfo | null = AgcService.exportAuth();
      if (auth !== null) {
        // 令牌属凭据，写入系统加密密钥库（ASSET），不再明文进 preferences
        const saved: boolean = await putSecret(AGC_AUTH_ALIAS, this.packAuth(auth));
        if (!saved) {
          this.log('警告：登录态写入加密存储失败，重启后需重新登录');
        }
      }
      await store.flush();
    } catch (e) {
      const err = e as BusinessError;
      this.log('保存配置失败: ' + err.message);
    }
  }

  /** 登录态打包：4 个字段按行拼接（令牌不含换行），整体存为一条加密记录 */
  private packAuth(auth: AgcAuthInfo): string {
    return auth.jwtToken + '\n' + auth.accessToken + '\n' + auth.userId + '\n' + auth.teamId;
  }

  private unpackAuth(blob: string): AgcAuthInfo {
    const parts: string[] = blob.split('\n');
    if (parts.length < 4) {
      return { jwtToken: '', accessToken: '', userId: '', teamId: '' };
    }
    return { jwtToken: parts[0], accessToken: parts[1], userId: parts[2], teamId: parts[3] };
  }

  private async loadConfig(): Promise<void> {
    try {
      const store = await preferences.getPreferences(this.ctx(), 'hapinstaller');
      const target: string = await store.get('target', this.target) as string;
      const cachedHap: string = await store.get('hapPath', '') as string;
      const cer: string = await store.get('cerPath', '') as string;
      const p7b: string = await store.get('p7bPath', '') as string;
      const p12: string = await store.get('p12Path', '') as string;
      const alias: string = await store.get('keyAlias', this.keyAlias) as string;
      const matSource: string = await store.get('matSource', this.matSource) as string;
      const cachedUdid: string = await store.get('udid', '') as string;
      this.target = target;
      this.matSource = matSource;
      if (cachedUdid.length === 64) {
        this.udid = cachedUdid;
      }
      if (cer.length > 0 && fileIo.accessSync(cer)) {
        this.cerPath = cer;
      }
      if (p7b.length > 0 && fileIo.accessSync(p7b)) {
        this.p7bPath = p7b;
      }
      if (p12.length > 0 && fileIo.accessSync(p12)) {
        this.p12Path = p12;
      }
      // 内置测试链：alias/口令不回填输入框（保持「默认无填充」），
      // 留空时由 useAlias()/usePwd() 按内置默认值兜底
      if (this.p12Path === this.ctx().filesDir + '/hapinstaller.p12') {
        this.keyAlias = '';
        this.keyPwd = '';
      } else {
        this.keyAlias = alias;
      }
      if (cachedHap.length > 0 && fileIo.accessSync(cachedHap)) {
        this.applyPicked(cachedHap);
        this.log('恢复上次选中的安装包: ' + cachedHap);
      }
      const healed: string[] = this.healMaterials();
      if (healed.length > 0) {
        this.log('材料自愈回填：' + healed.join('、'));
        this.saveConfig();
      }
      const ready: number = (this.cerPath.length > 0 ? 1 : 0) + (this.p7bPath.length > 0 ? 1 : 0) +
        (this.p12Path.length > 0 ? 1 : 0);
      this.matLabel = this.matSource !== 'custom'
        ? '内置测试链（alias=hapinstaller）'
        : (ready === 3 ? '证书材料已就绪（来自上次配置）' : ('证书材料 ' + ready + '/3 已选'));
      const authBlob: string = await getSecret(AGC_AUTH_ALIAS);
      const auth: AgcAuthInfo = this.unpackAuth(authBlob);
      if (auth.jwtToken.length > 0 && auth.userId.length > 0) {
        const restored: AgcAuthInfo = {
          jwtToken: auth.jwtToken,
          accessToken: auth.accessToken,
          userId: auth.userId,
          teamId: auth.teamId.length > 0 ? auth.teamId : auth.userId
        };
        AgcService.importAuth(restored);
        this.agcUser = auth.userId;
      }
      this.log('已载入上次配置：目标 ' + target + '，材料 ' + ready + '/3' +
        (auth.jwtToken.length > 0 ? '，登录态已恢复' : ''));
    } catch (e) {
      const err = e as BusinessError;
      this.log('载入配置失败: ' + err.message);
    }
  }

  /**
   * PC 端 initSignConfig 的默认值兜底语义：
   * 材料路径缺失/失效时回填沙箱默认材料（缺失则从内置 rawfile 释放）；
   * 口令仅在密钥库为内置 hapinstaller.p12 时内存回填，绝不落盘（§十七）。
   */
  private healMaterials(): string[] {
    const f: string = this.ctx().filesDir;
    const healed: string[] = [];
    const builtinP12: string = f + '/hapinstaller.p12';
    // 默认使用内置测试链。自定义密钥库的口令出于安全考虑不落盘（见 README「未开源模块」），
    // 冷启动无法续用，故只有在「签名配置」里主动配过材料（matSource === 'custom'）
    // 才保留自定义材料；想改用自定义材料，打开「签名配置」重新选择并填入口令。
    if (this.matSource !== 'custom') {
      const freshCer: string = f + '/hapinstaller-debug.cer';
      const freshP7b: string = f + '/hapinstaller-debug.p7b';
      const builtinCer: string = f + '/hapinstaller-builtin.cer';
      const builtinP7b: string = f + '/hapinstaller-builtin.p7b';
      if (!fileIo.accessSync(builtinP12)) {
        this.releaseBuiltin('hapinstaller.p12');
      }
      if (fileIo.accessSync(builtinP12) && this.p12Path !== builtinP12) {
        this.p12Path = builtinP12;
        healed.push('密钥库(内置)');
      }
      if (!fileIo.accessSync(freshCer) && !fileIo.accessSync(builtinCer)) {
        this.releaseBuiltin('hapinstaller-builtin.cer');
      }
      if (!fileIo.accessSync(freshP7b) && !fileIo.accessSync(builtinP7b)) {
        this.releaseBuiltin('hapinstaller-builtin.p7b');
      }
      // 证书链与 Profile 必须来自同一套（AGC 配 AGC、内置配内置）：
      // 「AGC 证书 + 内置 Profile」这类错配仍能签出 HAP，但装包阶段会报
      // code:9568257 fail to verify pkcs7 file。AGC Profile 由 doApplyProfile 按目标包名落盘，
      // 所以「当前 Profile 是已存在的非内置/非 fresh 文件」即代表处于 AGC 套件。
      const curP7bIsAgc: boolean = this.p7bPath.length > 0 && fileIo.accessSync(this.p7bPath)
        && this.p7bPath !== builtinP7b && this.p7bPath !== freshP7b;
      const agcP7b: string = fileIo.accessSync(freshP7b) ? freshP7b : (curP7bIsAgc ? this.p7bPath : '');
      const useAgc: boolean = agcP7b.length > 0 && fileIo.accessSync(freshCer);
      const cerPick: string = useAgc ? freshCer : builtinCer;
      const p7bPick: string = useAgc ? agcP7b : builtinP7b;
      if (fileIo.accessSync(cerPick) && this.cerPath !== cerPick) {
        this.cerPath = cerPick;
        healed.push(useAgc ? '证书链(AGC)' : '证书链(内置)');
      }
      if (fileIo.accessSync(p7bPick) && this.p7bPath !== p7bPick) {
        this.p7bPath = p7bPick;
        healed.push(useAgc ? 'Profile(AGC)' : 'Profile(内置)');
      }
      // 内置链的 alias/口令不再回填输入框（保持「默认无填充」）：
      // 留空时由 useAlias()/usePwd() 在签名时按内置默认值兜底
      return healed;
    }
    if (this.p12Path.length === 0 || !fileIo.accessSync(this.p12Path)) {
      const def: string = f + '/hapinstaller.p12';
      if (!fileIo.accessSync(def)) {
        this.releaseBuiltin('hapinstaller.p12');
      }
      if (fileIo.accessSync(def)) {
        this.p12Path = def;
        healed.push('密钥库');
      }
    }
    if (this.cerPath.length === 0 || !fileIo.accessSync(this.cerPath)) {
      const fresh: string = f + '/hapinstaller-debug.cer';
      const builtin: string = f + '/hapinstaller-builtin.cer';
      if (!fileIo.accessSync(fresh) && !fileIo.accessSync(builtin)) {
        this.releaseBuiltin('hapinstaller-builtin.cer');
      }
      const pick: string = fileIo.accessSync(fresh) ? fresh : builtin;
      if (fileIo.accessSync(pick)) {
        this.cerPath = pick;
        healed.push('证书链');
      }
    }
    if (this.p7bPath.length === 0 || !fileIo.accessSync(this.p7bPath)) {
      const fresh: string = f + '/hapinstaller-debug.p7b';
      const builtin: string = f + '/hapinstaller-builtin.p7b';
      if (!fileIo.accessSync(fresh) && !fileIo.accessSync(builtin)) {
        this.releaseBuiltin('hapinstaller-builtin.p7b');
      }
      const pick: string = fileIo.accessSync(fresh) ? fresh : builtin;
      if (fileIo.accessSync(pick)) {
        this.p7bPath = pick;
        healed.push('Profile');
      }
    }
    return healed;
  }

  private releaseBuiltin(name: string): void {
    try {
      const target: string = this.ctx().filesDir + '/' + name;
      const data: Uint8Array = this.ctx().resourceManager.getRawFileContentSync('store/' + name);
      const outFile = fileIo.openSync(target,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(outFile.fd, data.buffer as ArrayBuffer);
      fileIo.closeSync(outFile);
    } catch (e) {
      const err = e as BusinessError;
      this.log('内置材料释放失败(' + name + '): ' + err.message);
    }
  }

  private async doReadUdid(): Promise<void> {
    try {
      if (!await this.ensureConnected()) {
        this.log('未连接调试目标，无法读取 UDID');
        return;
      }
      const out: string = await this.exec('shell bm get --udid');
      const found: RegExpMatchArray | null = out.match(new RegExp('[0-9a-fA-F]{64}'));
      const value: string = found !== null ? found[0] : '';
      if (value.length === 64) {
        this.udid = value;
        this.log('本机 UDID: ' + value);
      } else {
        this.log('未解析到 UDID，请确认已连接调试目标');
      }
    } catch (e) {
      const err = e as BusinessError;
      this.log('读取 UDID 失败: ' + err.message);
    }
  }

  /** 应用内嵌 Web 打开 AGC（下载自动落沙箱） */
  private openCertWeb(customUrl: string): void {
    AppStorage.setOrCreate<string>('webUrl', customUrl);
    this.pathStack.pushPath({ name: 'CertWeb' });
  }

  /** 登录华为开发者账号（DevEco IDE 授权通道，自用）；「更换账号」始终走浏览器重新授权 */
  private async doLogin(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.status = '等待浏览器完成登录…';
    const port: number = 3333 + Math.floor(Math.random() * 1000);
    try {
      const waiting: Promise<string> = AgcService.waitForCallback(port, 180000);
      await AgcService.openLoginPage(this.ctx(), port);
      this.log('已打开授权页（端口 ' + port + '），请在浏览器中登录');
      const tempToken: string = await waiting;
      if (tempToken.length === 0) {
        this.log('未收到回调（超时或已取消）');
        this.status = '登录未完成';
        this.busy = false;
        return;
      }
      const auth: AgcAuthInfo = await AgcService.exchangeToken(tempToken);
      this.agcUser = auth.userId;
      await this.saveConfig();
      this.status = '已登录（uid ' + auth.userId + '）';
      this.log('登录成功：uid=' + auth.userId + ' teamId=' + auth.teamId);
    } catch (e) {
      const err = e as BusinessError;
      this.log('登录失败: ' + err.message);
      this.status = '登录失败';
    }
    this.busy = false;
  }

  /** 用内置 CSR 向 AGC 申请/续期调试证书，并下载到沙箱 */
  private async doApplyCert(): Promise<void> {
    if (!AgcService.isLoggedIn()) {
      this.log('请先登录华为账号');
      return;
    }
    this.busy = true;
    this.status = '申请证书中…';
    try {
      const csrPath: string = this.ctx().filesDir + '/hapinstaller.csr';
      if (!fileIo.accessSync(csrPath)) {
        const data: Uint8Array = this.ctx().resourceManager.getRawFileContentSync('store/hapinstaller.csr');
        const outFile = fileIo.openSync(csrPath,
          fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
        fileIo.writeSync(outFile.fd, data.buffer as ArrayBuffer);
        fileIo.closeSync(outFile);
      }
      const csr: string = this.readTextOr(csrPath);
      const certs: AgcCertInfo[] = await AgcService.getCertList();
      let target: AgcCertInfo | undefined = undefined;
      for (const c of certs) {
        if (c.certName === 'hapinstaller-debug') {
          target = c;
        }
      }
      const now: number = Date.now();
      if (target !== undefined && target.status === 2) {
        this.log('旧证书已失效，删除后重建');
        await AgcService.removeCert(target.id);
        target = undefined;
      }
      if (target === undefined) {
        this.log('向 AGC 提交 CSR 申请证书…');
        target = await AgcService.createCert('hapinstaller-debug', 1, csr);
      } else {
        this.log('复用已有证书: ' + target.id);
      }
      const url: string = await AgcService.certDownloadUrl(target.certObjectId);
      const cerPath: string = this.ctx().filesDir + '/hapinstaller-debug.cer';
      await this.downloadTo(url, 'hapinstaller-debug.cer');
      const tmpCer: string = this.ctx().tempDir + '/hapinstaller-debug.cer';
      if (fileIo.accessSync(tmpCer)) {
        fileIo.copyFileSync(tmpCer, cerPath);
        this.cerPath = cerPath;
        this.log('证书已下载: ' + cerPath);
      }
      this.p12Path = this.ctx().filesDir + '/hapinstaller.p12';
      this.matSource = 'builtin';
      await this.saveConfig();
      this.status = '证书就绪';
    } catch (e) {
      const err = e as BusinessError;
      this.log('申请证书失败: ' + err.message);
      this.status = '证书申请失败';
    }
    this.busy = false;
  }

  /** 目标 HAP 声明的权限 ∩ ACL 白名单（PC EcoService.getAcl 语义） */
  private async aclForTarget(): Promise<string[]> {
    if (this.hapPath.length === 0) {
      return [];
    }
    const declared: string[] = HapPeek.permissionsOf(this.hapPath);
    if (declared.length === 0) {
      return [];
    }
    const whitelist: string[] = await loadAclList(this.ctx());
    const out: string[] = [];
    for (const name of declared) {
      if (whitelist.indexOf(name) >= 0 && out.indexOf(name) < 0) {
        out.push(name);
      }
    }
    return out;
  }

  /** 注册本机 UDID 并申请 Profile，下载到沙箱 */
  private async doApplyProfile(): Promise<void> {    if (!AgcService.isLoggedIn()) {
      this.log('请先登录华为账号');
      return;
    }
    if (this.udid.length === 0) {
      this.log('请先读取 UDID');
      return;
    }
    const pkg: string = this.packageName.trim().length > 0 ? this.packageName.trim() : 'cn.lxh.hapinstaller';
    this.busy = true;
    this.status = '申请 Profile 中…';
    try {
      let devices: AgcDeviceInfo[] = await AgcService.deviceList();
      let found: boolean = false;
      for (const d of devices) {
        if (d.udid === this.udid) {
          found = true;
        }
      }
      if (!found) {
        this.log('注册设备 UDID 到 AGC…');
        await AgcService.createDevice('hapinstaller-' + this.udid.substring(0, 10), this.udid);
        devices = await AgcService.deviceList();
      }
      const ids: string[] = [];
      for (const d of devices) {
        ids.push(d.id);
      }
      const certs: AgcCertInfo[] = await AgcService.getCertList();
      const seen: string[] = [];
      for (const c of certs) {
        seen.push(c.certName + '(id=' + c.id + ',status=' + c.status + ')');
      }
      this.log('AGC 证书列表: ' + (seen.length > 0 ? seen.join('、') : '（空）'));
      let certId: string = '';
      let certObjectId: string = '';
      for (const c of certs) {
        if (c.certName === 'hapinstaller-debug') {
          certId = c.id;
          certObjectId = c.certObjectId;
        }
      }
      if (certId.length === 0) {
        // 签名只能用本机持有的密钥库，所以 Profile 只能绑定「由本机 CSR 签发」的证书；
        // 账号里没有就现场申请（去网页手工申请会绑到别的密钥上，签出来装不上）
        this.log('未找到 hapinstaller-debug 证书，自动用内置 CSR 申请一张…');
        this.busy = false;
        await this.doApplyCert();
        this.busy = true;
        const again: AgcCertInfo[] = await AgcService.getCertList();
        for (const c of again) {
          if (c.certName === 'hapinstaller-debug') {
            certId = c.id;
            certObjectId = c.certObjectId;
          }
        }
      }
      if (certId.length === 0) {
        this.log('证书仍不可用：AGC 调试证书数量超限。请到「签名配置 → 打开 AGC」的「证书管理」里删掉不用的调试证书'
          + '（务必保留 DevEco 自动签名那张，删了 DevEco 就编译不了本应用），再点「开始调试」重试');
        this.busy = false;
        return;
      }
      // 关键：AGC Profile 绑定的就是「hapinstaller-debug」这张证书，签名必须用同一张，
      // 否则签出的 HAP 在装包阶段报 code:9568257 fail to verify pkcs7 file。
      await this.alignCertToAgcProfile(certObjectId);
      const profileName: string = 'hapinstaller-debug_' + pkg.replace(/\./g, '_');
      // 对齐 PC getAcl：只申请目标包真正声明、且落在 ACL 白名单内的受限权限
      const acl: string[] = await this.aclForTarget();
      this.log('申请 Profile: ' + profileName + '，ACL: ' + (acl.length > 0 ? acl.join('、') : '无'));
      const url: string = await AgcService.createProfile(profileName, certId, ids, acl, pkg);
      // 按包名落盘（对齐 PC 的 <pkg>.p7b），避免覆盖 HapInstaller 自身的调试 Profile
      const fname: string = pkg.replace(/\./g, '_') + '.p7b';
      await this.downloadTo(url, fname);
      const tmp: string = this.ctx().tempDir + '/' + fname;
      if (fileIo.accessSync(tmp)) {
        const dst: string = this.ctx().filesDir + '/' + fname;
        fileIo.copyFileSync(tmp, dst);
        this.p7bPath = dst;
        this.log('Profile 已下载: ' + dst);
      }
      await this.saveConfig();
      this.status = 'Profile 就绪';
    } catch (e) {
      const err = e as BusinessError;
      this.log('申请 Profile 失败: ' + err.message);
      this.status = 'Profile 申请失败';
    }
    this.busy = false;
  }

  /**
   * 让签名用的证书链与 AGC Profile 配套。
   * AGC Profile 绑定的就是「hapinstaller-debug」这张证书，签名必须用同一张，
   * 否则签出的 HAP 能通过 sign-app，却在装包阶段报 code:9568257 fail to verify pkcs7 file。
   * 该证书由内置 CSR 签发，私钥在内置密钥库 hapinstaller.p12，所以三者是配套的。
   * certObjectId 传空时自行查一次证书列表。
   */
  private async alignCertToAgcProfile(certObjectId: string): Promise<void> {
    let objectId: string = certObjectId;
    if (objectId.length === 0 && AgcService.isLoggedIn()) {
      const certs: AgcCertInfo[] = await AgcService.getCertList();
      for (const c of certs) {
        if (c.certName === 'hapinstaller-debug') {
          objectId = c.certObjectId;
        }
      }
    }
    const certFile: string = this.ctx().filesDir + '/hapinstaller-debug.cer';
    if (!fileIo.accessSync(certFile) && objectId.length > 0) {
      this.log('下载与 Profile 配套的 AGC 证书…');
      const certUrl: string = await AgcService.certDownloadUrl(objectId);
      await this.downloadTo(certUrl, 'hapinstaller-debug.cer');
      const tmpCer: string = this.ctx().tempDir + '/hapinstaller-debug.cer';
      if (fileIo.accessSync(tmpCer)) {
        fileIo.copyFileSync(tmpCer, certFile);
      }
    }
    if (fileIo.accessSync(certFile)) {
      const pairP12: string = this.ctx().filesDir + '/hapinstaller.p12';
      if (!fileIo.accessSync(pairP12)) {
        this.releaseBuiltin('hapinstaller.p12');
      }
      this.cerPath = certFile;
      this.p12Path = pairP12;
      this.matSource = 'builtin';
      this.log('签名材料已对齐 Profile：证书链 = hapinstaller-debug.cer，密钥库 = hapinstaller.p12');
    } else {
      this.log('警告：AGC 证书未就位；证书链与 Profile 不配套时会在装包阶段报 pkcs7 校验失败');
    }
  }

  /** 使用内置材料（密钥库 + 证书链 + Profile，来自 assets/store），免去生成与上传 */
  private async doUseBuiltin(): Promise<void> {
    this.busy = true;
    try {
      const files: string[] = ['hapinstaller.p12', 'hapinstaller-builtin.cer', 'hapinstaller-builtin.p7b'];
      for (const name of files) {
        const target: string = this.ctx().filesDir + '/' + name;
        const data: Uint8Array = this.ctx().resourceManager.getRawFileContentSync('store/' + name);
        const outFile = fileIo.openSync(target,
          fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
        fileIo.writeSync(outFile.fd, data.buffer as ArrayBuffer);
        fileIo.closeSync(outFile);
        this.log('内置材料已释放: ' + name + ' (' + fileIo.statSync(target).size + ' B)');
      }
      const freshCer: string = this.ctx().filesDir + '/hapinstaller-debug.cer';
      const freshP7b: string = this.ctx().filesDir + '/hapinstaller-debug.p7b';
      this.p12Path = this.ctx().filesDir + '/hapinstaller.p12';
      // 内置的是自签名测试链，若已有 AGC 新签发材料则优先使用
      this.cerPath = fileIo.accessSync(freshCer) ? freshCer : this.ctx().filesDir + '/hapinstaller-builtin.cer';
      this.p7bPath = fileIo.accessSync(freshP7b) ? freshP7b : this.ctx().filesDir + '/hapinstaller-builtin.p7b';
      this.keyAlias = 'hapinstaller';
      this.keyPwd = 'hapinstaller123';
      this.matSource = 'builtin';
      this.matLabel = '内置测试链（alias=hapinstaller）';
      await this.saveConfig();
      this.log('内置材料就绪：alias=hapinstaller，可直接签名');
    } catch (e) {
      const err = e as BusinessError;
      this.log('释放内置材料失败: ' + err.message);
    }
    this.busy = false;
  }

  /** 端侧生成密钥库（.p12）：私钥始终留在手机上 */
  private async doGenKey(): Promise<void> {
    if (this.keyPwd.length === 0 || this.keyAlias.trim().length === 0) {
      this.log('请先填 keyAlias 与密码');
      return;
    }
    this.busy = true;
    const p12: string = this.ctx().filesDir + '/hapinstaller-key.p12';
    try {
      const cmd: string = 'signtool generate-keypair -keyAlias ' + this.keyAlias.trim() +
        ' -keyAlg ECC -keySize NIST-P-256 -keystoreFile ' + p12 +
        ' -keyPwd ' + this.keyPwd + ' -keystorePwd ' + this.keyPwd;
      this.log('$ ' + cmd.replace(this.keyPwd, '***'));
      const outcome: SignOutcome = await SignService.sign(cmd, this.ctx().tempDir);
      this.log('生成密钥库返回码: ' + outcome.code);
      this.log(this.readTextOr(this.ctx().tempDir + '/sign.out'));
      if (fileIo.accessSync(p12)) {
        this.p12Path = p12;
        this.matSource = 'custom';
        this.log('密钥库已生成: ' + p12 + ' (' + fileIo.statSync(p12).size + ' bytes)');
        await this.saveConfig();
      }
    } catch (e) {
      const err = e as BusinessError;
      this.log('生成密钥库异常: ' + err.message);
    }
    this.busy = false;
  }

  /** 端侧生成 CSR（用于在 AGC 上传申请调试证书） */
  private async doGenCsr(): Promise<void> {
    if (this.p12Path.length === 0) {
      this.log('请先生成密钥库或导入 .p12');
      return;
    }
    const alias: string = this.useAlias();
    const pwd: string = this.usePwd();
    if (alias.length === 0 || pwd.length === 0) {
      this.log('请先填 keyAlias 与密码');
      return;
    }
    this.busy = true;
    const csr: string = this.ctx().filesDir + '/app.csr';
    try {
      const subject: string = 'CN=' + alias;
      const cmd: string = 'signtool generate-csr -keyAlias ' + alias +
        ' -keyPwd ' + pwd + ' -subject ' + subject + ' -signAlg SHA256withECDSA' +
        ' -keystoreFile ' + this.p12Path + ' -keystorePwd ' + pwd + ' -outFile ' + csr;
      this.log('$ ' + cmd.replace(pwd, '***'));
      const outcome: SignOutcome = await SignService.sign(cmd, this.ctx().tempDir);
      this.log('生成 CSR 返回码: ' + outcome.code);
      this.log(this.readTextOr(this.ctx().tempDir + '/sign.out'));
      if (fileIo.accessSync(csr)) {
        this.csrPath = csr;
        this.log('CSR 已生成: ' + csr + ' (' + fileIo.statSync(csr).size + ' bytes)');
      }
    } catch (e) {
      const err = e as BusinessError;
      this.log('生成 CSR 异常: ' + err.message);
    }
    this.busy = false;
  }

  /** 把 CSR 保存到用户可见位置（浏览器上传 AGC 时需要） */
  private async doSaveCsr(): Promise<void> {
    if (this.csrPath.length === 0) {
      this.log('请先生成 CSR');
      return;
    }
    try {
      const options = new picker.DocumentSaveOptions();
      options.newFileNames = ['hapinstaller.csr'];
      const documentPicker = new picker.DocumentViewPicker(this.ctx());
      const uris: string[] = await documentPicker.save(options);
      if (uris.length === 0) {
        return;
      }
      const inFile = fileIo.openSync(this.csrPath, fileIo.OpenMode.READ_ONLY);
      const outFile = fileIo.openSync(uris[0], fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      fileIo.copyFileSync(inFile.fd, outFile.fd);
      fileIo.closeSync(inFile);
      fileIo.closeSync(outFile);
      this.log('CSR 已保存，可在浏览器里选择该文件上传 AGC');
    } catch (e) {
      const err = e as BusinessError;
      this.log('保存 CSR 失败: ' + err.message);
    }
  }

  private async doCopyUdid(): Promise<void> {
    if (this.udid.length === 0) {
      this.log('请先读取 UDID');
      return;
    }
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.udid);
      await pasteboard.getSystemPasteboard().setData(data);
      this.log('UDID 已复制到剪贴板');
    } catch (e) {
      const err = e as BusinessError;
      this.log('复制失败: ' + err.message);
    }
  }

  /** 用系统浏览器打开 AGC 通用入口（证书/设备管理都在里面）；不硬编码具体项目 id */
  private async openAgc(which: string): Promise<void> {
    const url: string = 'https://developer.huawei.com/consumer/cn/service/josp/agc/index.html';
    try {
      await this.ctx().openLink(url);
      this.log('已打开浏览器（' + which + '）: ' + url);
      return;
    } catch (e) {
      const err = e as BusinessError;
      this.log('openLink 失败(' + err.message + ')，改用 startAbility');
    }
    try {
      const want: Want = {
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'],
        uri: url
      };
      await this.ctx().startAbility(want);
      this.log('已打开: ' + url);
    } catch (e) {
      const err = e as BusinessError;
      this.log('打开浏览器失败: ' + err.message);
    }
  }

  private async pickFile(filters: string[], dstName: string): Promise<string> {
    const documentPicker = new picker.DocumentViewPicker(this.ctx());
    const uris: string[] = await documentPicker.select({
      maxSelectNumber: 1,
      fileSuffixFilters: filters
    });
    if (uris.length === 0) {
      return '';
    }
    const persistent: boolean = dstName.endsWith('.cer') || dstName.endsWith('.p7b') || dstName.endsWith('.p12');
    const dst: string = (persistent ? this.ctx().filesDir : this.ctx().tempDir) + '/' + dstName;
    const inFile = fileIo.openSync(uris[0], fileIo.OpenMode.READ_ONLY);
    const outFile = fileIo.openSync(dst,
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    fileIo.copyFileSync(inFile.fd, outFile.fd);
    fileIo.closeSync(inFile);
    fileIo.closeSync(outFile);
    return dst;
  }

  private async doPick(): Promise<void> {
    try {
      const p: string = await this.pickFile(['.hap', '.hsp', '.app'], 'picked.hap');
      if (p.length > 0) {
        this.markPicked(p);
      }
    } catch (e) {
      const err = e as BusinessError;
      this.log('选择文件失败: ' + err.message);
    }
  }

  private async pickMat(kind: string): Promise<void> {
    try {
      let picked: string = '';
      if (kind === 'cer') {
        picked = await this.pickFile(['.cer'], 'chain.cer');
        if (picked.length > 0) {
          this.cerPath = picked;
        }
      } else if (kind === 'p7b') {
        picked = await this.pickFile(['.p7b'], 'profile.p7b');
        if (picked.length > 0) {
          this.p7bPath = picked;
        }
      } else {
        picked = await this.pickFile(['.p12', '.jks'], 'app.p12');
        if (picked.length > 0) {
          this.p12Path = picked;
        }
      }
      if (picked.length === 0) {
        this.log('未选择文件，材料保持不变');
        return;
      }
      // 用户主动选了自定义材料：切到 custom 模式，不再被内置链覆盖
      this.matSource = 'custom';
      const ready: number = (this.cerPath.length > 0 ? 1 : 0) + (this.p7bPath.length > 0 ? 1 : 0) +
        (this.p12Path.length > 0 ? 1 : 0);
      this.matLabel = '证书材料 ' + ready + '/3 已选（自定义）';
      await this.saveConfig();
    } catch (e) {
      const err = e as BusinessError;
      this.log('选择材料失败: ' + err.message);
    }
  }

  /** 只按文件本身回填安装包信息（选包与冷启恢复共用） */
  private applyPicked(dst: string): void {
    const size: number = fileIo.statSync(dst).size;
    this.hapPath = dst;
    this.hapBundle = HapPeek.bundleNameOf(dst);
    this.hapLabel = this.hapBundle.length > 0
      ? this.hapBundle + ' · ' + Math.round(size / 1024) + ' KB'
      : '已选：' + Math.round(size / 1024) + ' KB';
  }

  private markPicked(dst: string): void {
    this.applyPicked(dst);
    this.saveConfig();
    const size: number = fileIo.statSync(dst).size;
    this.log('待处理包: ' + dst + ' (' + size + ' bytes)' +
      (this.hapBundle.length > 0 ? ' bundle=' + this.hapBundle : ' bundle=未识别(回退到输入项)'));
  }

  /** 当前密钥库是否为内置测试链（内置的 alias/口令是固定值，输入框留空时按此兜底） */
  private isBuiltinKeystore(): boolean {
    return this.p12Path === this.ctx().filesDir + '/hapinstaller.p12';
  }

  /** 生效 alias：输入框优先，留空且为内置密钥库时用内置默认值 */
  private useAlias(): string {
    const t: string = this.keyAlias.trim();
    if (t.length > 0) {
      return t;
    }
    return this.isBuiltinKeystore() ? 'hapinstaller' : '';
  }

  /** 生效口令：输入框优先，留空且为内置密钥库时用内置默认值（非内置件留空即视为未填） */
  private usePwd(): string {
    if (this.keyPwd.length > 0) {
      return this.keyPwd;
    }
    return this.isBuiltinKeystore() ? 'hapinstaller123' : '';
  }

  private buildSignCmd(inPath: string, outPath: string): string {
    const alias: string = this.useAlias();
    const pwd: string = this.usePwd();
    return 'signtool sign-app -mode localSign -keyAlias ' + alias +
      ' -appCertFile ' + this.cerPath + ' -profileFile ' + this.p7bPath +
      ' -inFile ' + inPath + ' -signAlg SHA256withECDSA' +
      ' -keystoreFile ' + this.p12Path + ' -keystorePwd ' + pwd +
      ' -keyPwd ' + pwd + ' -outFile ' + outPath;
  }

  private async doCsrExport(): Promise<void> {
    if (this.csrPath.length === 0 && AppStorage.get<string>('autoCsr') === undefined) {
      this.log('请先生成 CSR');
      return;
    }
    await this.doSaveCsr();
  }

  /** 粗校验：HAP 是 zip，头四字节应为 PK\x03\x04 */
  private looksLikeZip(p: string): boolean {
    try {
      const size: number = fileIo.statSync(p).size;
      if (size < 1024) {
        return false;
      }
      const rf = fileIo.openSync(p, fileIo.OpenMode.READ_ONLY);
      const buf: ArrayBuffer = new ArrayBuffer(4);
      fileIo.readSync(rf.fd, buf);
      fileIo.closeSync(rf);
      const b: Uint8Array = new Uint8Array(buf);
      return b[0] === 0x50 && b[1] === 0x4B;
    } catch (e) {
      return false;
    }
  }

  /** 调试 Profile（p7b）内嵌明文 JSON，绑定了唯一 bundle-name，签名前必须与目标包一致 */
  private profileBundleName(): string {
    try {
      const size: number = fileIo.statSync(this.p7bPath).size;
      const rf = fileIo.openSync(this.p7bPath, fileIo.OpenMode.READ_ONLY);
      const buf: ArrayBuffer = new ArrayBuffer(size);
      fileIo.readSync(rf.fd, buf);
      fileIo.closeSync(rf);
      const text: string = util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(buf));
      const key: string = '"bundle-name":"';
      const i: number = text.indexOf(key);
      if (i < 0) {
        return '';
      }
      const j: number = text.indexOf('"', i + key.length);
      return j > i ? text.substring(i + key.length, j) : '';
    } catch (e) {
      return '';
    }
  }

  /** 签名前校验：材料齐全 + 口令已填（避免退化到过期/缺失材料上白跑） */
  private precheckSign(): string[] {
    // 先自愈一次：loadConfig 只在首屏 kernelReady 为 false 时跑，本页重建时可能不再跑，
    // 导致配置里的材料路径已失效却没人回填。healMaterials 幂等（仅空/不存在时才回填内置件）。
    const healed: string[] = this.healMaterials();
    if (healed.length > 0) {
      this.log('签名前自愈回填：' + healed.join('、'));
      this.saveConfig();
    }
    const missing: string[] = [];
    if (this.hapPath.length === 0 || !fileIo.accessSync(this.hapPath)) {
      missing.push('待签名包');
    } else if (!this.looksLikeZip(this.hapPath)) {
      missing.push('待签名包（文件不是有效 HAP/ZIP，可能下载中断）');
    }
    if (this.cerPath.length === 0 || !fileIo.accessSync(this.cerPath)) {
      missing.push('证书链 .cer');
    }
    if (this.p7bPath.length === 0 || !fileIo.accessSync(this.p7bPath)) {
      missing.push('Profile .p7b');
    }
    if (this.p12Path.length === 0 || !fileIo.accessSync(this.p12Path)) {
      missing.push('密钥库 .p12');
    }
    if (this.usePwd().length === 0) {
      missing.push('密钥口令');
      // 口令出于安全考虑不落盘（见 §十七），冷启动必然为空；内置密钥库留空时自动兜底
      this.log('密钥口令未填：当前密钥库 = ' + this.p12Path
        + '（非内置件，口令需自行填写；想改用内置测试链请点「用内置材料」）');
    }
    return missing;
  }

  /** Profile 与目标包名不一致时返回 [Profile 绑定包名, 目标包名]；一致或信息不足返回空数组 */
  private profileMismatch(): string[] {
    const target: string = this.hapBundle.length > 0 ? this.hapBundle :
      (this.hapPath.length > 0 ? HapPeek.bundleNameOf(this.hapPath) : '');
    const bound: string = this.p7bPath.length > 0 ? this.profileBundleName() : '';
    if (target.length === 0 || bound.length === 0 || target === bound) {
      return [];
    }
    return [bound, target];
  }

  /** 对齐 PC autoCreateProfile：按目标包名切换 Profile，命中沙箱缓存直接复用，否则向 AGC 申请 */
  private async ensureProfileFor(pkg: string): Promise<boolean> {
    const dst: string = this.ctx().filesDir + '/' + pkg.replace(/\./g, '_') + '.p7b';
    if (fileIo.accessSync(dst)) {
      this.p7bPath = dst;
      if (this.profileBundleName() === pkg) {
        this.log('[sign] 复用已缓存 Profile: ' + dst);
        // 缓存命中会跳过 doApplyProfile，这里仍需把证书链对齐，否则会用内置自签链签名
        await this.alignCertToAgcProfile('');
        return true;
      }
    }
    if (this.udid.length === 0) {
      await this.doReadUdid();
    }
    if (this.udid.length === 0) {
      this.log('[sign] 未取得本机 UDID，无法申请 Profile');
      return false;
    }
    this.packageName = pkg;
    await this.doApplyProfile();
    return this.profileBundleName() === pkg;
  }

  /** 单次签名：放到独立 ThreadWorker 里跑，主线程与看门狗定时器不受原生卡死影响 */
  private signViaWorker(cmd: string, ms: number, onDone: (code: number) => void): void {
    let settled: boolean = false;
    const w: worker.ThreadWorker = new worker.ThreadWorker('entry/ets/workers/SignWorker.ets');
    let watchdog: number = -1;
    const finish = (code: number): void => {
      if (settled) {
        return;
      }
      settled = true;
      if (watchdog >= 0) {
        clearTimeout(watchdog);
      }
      try {
        w.terminate();
      } catch (ignored) {
      }
      onDone(code);
    };
    w.onmessage = (e: MessageEvents): void => {
      const code: number = Number(e.data.code);
      this.log('signHap 返回码: ' + code);
      finish(code);
    };
    w.onerror = (err: ErrorEvent): void => {
      this.log('签名 worker 错误: ' + err.message);
      finish(-98);
    };
    w.postMessage({ cmd: cmd, tempDir: this.ctx().tempDir });
    watchdog = setTimeout(() => {
      this.log('[看门狗] 签名 worker 超过 ' + Math.round(ms / 1000) + ' 秒无返回，已终止该 worker');
      try {
        w.terminate();
      } catch (ignored) {
      }
      finish(-97);
    }, ms);
  }

  private signWithTimeout(cmd: string, out: string, ms: number): Promise<boolean> {
    return new Promise<boolean>((resolve: (v: boolean) => void) => {
      this.signViaWorker(cmd, ms, (code: number): void => {
        resolve(fileIo.accessSync(out));
      });
    });
  }

  private dumpSignLog(): void {
    const detail: string = this.readTextOr(this.ctx().tempDir + '/sign.out');
    if (detail.length > 0) {
      this.log(detail.length > 1500 ? detail.substring(detail.length - 1500) : detail);
    }
  }

  private async doSign(): Promise<void> {
    const missing: string[] = this.precheckSign();
    if (missing.length > 0) {
      this.log('签名前校验未通过，缺少：' + missing.join('、'));
      if (missing.indexOf('密钥口令') >= 0) {
        // 口令出于安全考虑不落盘（§十七），冷启动必为空；只有内置密钥库能自动回填。
        // 而「签名配置」面板是唯一的填写入口，其入口在 More 页要连点「应用版本」十下才出现，
        // 普通用户根本找不到 —— 这里直接替用户打开，否则此路不通。
        this.signSheetOpen = true;
        this.status = '缺少密钥口令 —— 已打开「签名配置」，请在「keystore/key 密码」里填写';
        this.log('已自动打开「签名配置」：在「keystore/key 密码」填入该密钥库的口令后重试；'
          + '若想直接用内置测试链，点「用内置材料」一键补齐（口令 hapinstaller123）');
      } else {
        this.status = '材料不完整（缺少：' + missing.join('、') + '）';
      }
      return;
    }
    const mismatch: string[] = this.profileMismatch();
    if (mismatch.length === 2) {
      this.log('[sign] Profile 绑定《' + mismatch[0] + '》，改用目标包《' + mismatch[1] + '》的调试 Profile');
      if (!await this.ensureProfileFor(mismatch[1])) {
        this.status = 'Profile 申请失败';
        return;
      }
    }
    this.busy = true;
    this.status = '正在签名…';
    const out: string = this.ctx().tempDir + '/signed.hap';
    try {
      fileIo.unlinkSync(out);
    } catch (ignored) {
    }
    const cmd: string = this.buildSignCmd(this.hapPath, out);
    for (let attempt = 1; attempt <= 2; attempt++) {
      this.log('$ ' + cmd + (attempt > 1 ? '   （第 ' + attempt + ' 次尝试）' : ''));
      const started: number = Date.now();
      const done: boolean = await this.signWithTimeout(cmd, out, 60000);
      const used: number = Math.round((Date.now() - started) / 1000);
      if (done && fileIo.accessSync(out)) {
        this.signedPath = out;
        this.status = '签名完成（' + Math.round(fileIo.statSync(out).size / 1024) + ' KB，' + used + ' 秒）';
        this.log('签名产物: ' + out + '（耗时 ' + used + ' 秒）');
        this.busy = false;
        return;
      }
      this.log('第 ' + attempt + ' 次签名 ' + used + ' 秒未产出文件');
      this.dumpSignLog();
      if (attempt === 1) {
        this.log('重试一次…');
      }
    }
    this.dumpSignLog();
    this.status = '签名失败（材料可能已过期，请刷新证书/Profile 后重试）';
    this.log('签名两次均未产出，建议：刷新证书/Profile（AGC 调试证书有有效期）');
    this.busy = false;
  }

  /**
   * 最小复现路径（对应 鸿蒙迁移方案.md 第十九节的"下一轮推荐第一步"）：
   * 不启动 hdc 内核、不连设备、不下载、不查 AGC，直接用沙箱里已有的材料签一个本地 hap，
   * 用于把 fsverity 卡死/进程消失与 hdc 内核共存隔离开来。
   */
  private async doBareSign(): Promise<void> {
    this.log('[bare] 最小复现：跳过 hdc 内核 / 连接 / 下载 / AGC');
    const autoPwd: string | undefined = AppStorage.get<string>('autoKeyPwd');
    if (autoPwd !== undefined && autoPwd.length > 0) {
      this.keyPwd = autoPwd;
    }
    const autoAlias: string | undefined = AppStorage.get<string>('autoKeyAlias');
    if (autoAlias !== undefined && autoAlias.length > 0) {
      this.keyAlias = autoAlias;
    }
    const fallback: string = this.ctx().tempDir + '/picked.hap';
    if (this.hapPath.length === 0 && fileIo.accessSync(fallback)) {
      this.markPicked(fallback);
    }
    if (this.hapPath.length === 0 || !fileIo.accessSync(this.hapPath)) {
      this.log('[bare] 未找到待签 hap：hapPath 为空且 ' + fallback + ' 也不存在');
      this.log('[bare] 请先用 hdc file send 把未签名 hap 放到该路径，或在 UI 里选包');
      return;
    }
    if (!this.looksLikeZip(this.hapPath)) {
      this.log('[bare] hap 不是有效 ZIP/PK 头，放弃');
      return;
    }
    this.log('[bare] hap=' + this.hapPath +
      ' cer=' + (this.cerPath.length > 0 ? 'OK' : '-') +
      ' p7b=' + (this.p7bPath.length > 0 ? 'OK' : '-') +
      ' p12=' + (this.p12Path.length > 0 ? 'OK' : '-') +
      ' alias=' + this.keyAlias +
      ' pwd=' + (this.keyPwd.length > 0 ? 'set(' + this.keyPwd.length + ')' : 'empty'));
    this.log('[bare] HdcService.isServerStarted()=' + HdcService.isServerStarted());
    await this.doSign();
    this.log('[bare] 签名流程返回，产物: ' + (this.signedPath.length > 0 ? this.signedPath : '未产出'));
    this.log('[bare] 请把 filesDir/hapinstaller.log、filesDir/lifecycle.log、tempDir/sign.out、tempDir/sign_stdout.txt 从沙箱导出核对');
  }

  private async exportFile(local: string, remote: string): Promise<void> {
    if (!fileIo.accessSync(local)) {
      this.log('跳过导出（不存在）: ' + local);
      return;
    }
    try {
      await this.exec('file send ' + local + ' ' + remote);
    } catch (e) {
      const err = e as BusinessError;
      this.log('导出失败 ' + local + ': ' + err.message);
    }
  }

  /** 签名 + 超时兜底：无论签名是否回调，都把日志/产物导出，便于排查 */
  private async doSignWithDiagnostics(): Promise<void> {
    const signing: Promise<void> = this.doSign();
    const timeout: Promise<void> = new Promise<void>((resolve: () => void) => {
      setTimeout(() => {
        this.log('[诊断] 签名 45 秒未回调，先导出沙箱文件');
        resolve();
      }, 45000);
    });
    await Promise.race([signing, timeout]);
    await this.exportFile(this.ctx().tempDir + '/sign_out.txt', '/data/local/tmp/sign_out.txt');
    await this.exportFile(this.ctx().tempDir + '/sign.out', '/data/local/tmp/sign.out');
    await this.exportFile(this.ctx().tempDir + '/signed.hap', '/data/local/tmp/signed.hap');
    await this.exec('shell ls -l /data/local/tmp/sign_out.txt /data/local/tmp/signed.hap');
  }

  private async doExport(): Promise<void> {
    if (this.signedPath.length === 0) {
      this.log('还没有签名产物');
      return;
    }
    try {
      await this.exec('file send ' + this.signedPath + ' /data/local/tmp/signed.hap');
      this.status = '已导出到 /data/local/tmp/signed.hap';
    } catch (e) {
      const err = e as BusinessError;
      this.log('导出异常: ' + err.message);
    }
  }

  onSignSheetRequest(): void {
    if (this.signSheetRequest > 0) {
      this.signSheetOpen = true;
    }
  }

  private async execTimeout(cmd: string, ms: number): Promise<string> {
    const timeout: Promise<string> = new Promise<string>((resolve: (v: string) => void): void => {
      setTimeout((): void => { resolve(''); }, ms);
    });
    return Promise.race<string>([this.exec(cmd), timeout]);
  }

  /** 进程内 hdc 的 list targets 会残留已断开的会话，用一条真实命令探活 */
  private async probeLive(): Promise<boolean> {
    const out: string = await this.execTimeout('shell echo hapinstaller-alive', 6000);
    return out.indexOf('hapinstaller-alive') >= 0;
  }

  /** 安装前置检查：确认进程内 hdc 有一条可用目标，必要时用保存的 target 重连 */
  private async ensureConnected(): Promise<boolean> {
    if (await this.probeLive()) {
      return true;
    }
    const t: string = this.target.trim();
    if (t.length === 0) {
      return false;
    }
    this.log('[conn] 目标已失效，重连 ' + t);
    await this.execTimeout('tconn ' + t, 8000);
    if (await this.probeLive()) {
      this.log('[conn] 重连成功');
      return true;
    }
    this.log('[conn] 重连失败，请在「连接设备」里确认无线调试端口');
    return false;
  }

  private async confirmInstall(message: string): Promise<boolean> {
    try {
      const opts: promptAction.ShowDialogOptions = {
        title: '确认装机',
        message: message,
        buttons: [
          { text: '继续安装', color: '#0A59F7' },
          { text: '取消', color: '#666666' }
        ]
      };
      const res: promptAction.ShowDialogSuccessResponse = await promptAction.showDialog(opts);
      return res.index === 0;
    } catch (e) {
      const err = e as BusinessError;
      this.log('[install] 弹窗异常: ' + err.message);
      return false;
    }
  }

  private async doInstall(): Promise<void> {
    const target: string = this.signedPath.length > 0 ? this.signedPath : this.hapPath;
    if (this.busy || target.length === 0) {
      this.log('请先选择 HAP 文件');
      return;
    }
    const instBundle: string = this.hapBundle.length > 0 ? this.hapBundle
      : (this.bundleName.trim().length > 0 ? this.bundleName.trim()
        : (this.packageName.trim().length > 0 ? this.packageName.trim() : SELF_BUNDLE));
    const isSelf: boolean = instBundle === SELF_BUNDLE;
    this.busy = true;
    const conn: boolean = await this.ensureConnected();
    if (!conn) {
      this.status = '设备未连接';
      this.log('[install] 当前没有已连接的 hdc 目标，安装中止。请在「设备」里更新无线调试 IP:端口 后重试');
      this.busy = false;
      return;
    }
    let message: string = '';
    if (isSelf) {
      message = '将在设备上覆盖安装 HapInstaller（本应用），装机后本应用会自动重启。';
    } else {
      const st: number = await this.probeInstalled(instBundle);
      if (st === 0) {
        message = '';
        this.log('[install] 设备未安装过《' + instBundle + '》，直接首次安装');
      } else if (st === 1) {
        message = '将在设备上覆盖安装《' + instBundle + '》。';
      } else {
        message = '将在设备上安装《' + instBundle + '》。';
      }
    }
    if (message.length > 0) {
      const ok: boolean = await this.confirmInstall(message);
      if (!ok) {
        this.log('[install] 用户取消');
        this.busy = false;
        return;
      }
    }
    this.status = '正在安装…';
    const rowId: number = await Store.insertHistory(
      instBundle, this.target, target, isSelf ? 'killed_expected' : 'pending',
      this.ctx().filesDir + '/hapinstaller.log');
    try {
      const out: string = await this.exec('install -r ' + target);
      const success: boolean = out.indexOf('successfully') >= 0;
      this.status = success ? '安装成功' : '安装结束（见日志）';
      if (!success) {
        if (out.indexOf('connect-key') >= 0 || out.indexOf('[Fail]') >= 0) {
          this.log('提示：设备连接已断开，请重新连接无线调试后再次安装');
        } else if (out.indexOf('no signature file') >= 0) {
          this.log('提示：该 HAP 未签名，请改用「开始调试（自动签名）」');
        } else if (out.indexOf('verify signature failed') >= 0) {
          this.log('提示：签名校验未通过，多为 Profile 的 bundle-name 或设备 UDID 与目标包不匹配');
        }
        await Store.updateHistory(rowId, 'failed', out.trim());
      } else if (!isSelf) {
        await Store.updateHistory(rowId, 'success', '');
      }
    } catch (e) {
      const err = e as BusinessError;
      this.log('安装异常: ' + err.message);
      await Store.updateHistory(rowId, 'failed', err.message);
    }
    this.busy = false;
  }

  /** 查包是否已安装（同 PC dumpAppInstallTime）：1=已装 0=未装 -1=查不到（hdc 卡死/未连接） */
  private async probeInstalled(bundle: string): Promise<number> {
    try {
      const timeout: Promise<string> = new Promise<string>((resolve: (v: string) => void): void => {
        setTimeout((): void => { resolve(''); }, 8000);
      });
      const out: string = await Promise.race<string>(
        [this.exec('shell bm dump -n ' + bundle), timeout]);
      if (out.length === 0 || out.indexOf('connect-key') >= 0 || out.indexOf('[Fail]') >= 0) {
        return -1;
      }
      return out.indexOf('installTime') >= 0 ? 1 : 0;
    } catch (e) {
      return -1;
    }
  }

  private async doUninstall(): Promise<void> {
    if (this.busy || this.bundleName.trim().length === 0) {
      this.log('请填写要卸载的包名');
      return;
    }
    this.busy = true;
    try {
      await this.exec('uninstall ' + this.bundleName.trim());
      this.status = '卸载命令已执行';
    } catch (e) {
      const err = e as BusinessError;
      this.log('卸载异常: ' + err.message);
    }
    this.busy = false;
  }

  @Builder
  connectBody() {
    Row({ space: 8 }) {
      HapInput({ text: $target, placeholder: 'IP:端口' })
        .layoutWeight(1)
      PillButton({ label: '连接', variant: 'primary', enabled_: !this.busy,
        onClickAction: (): void => { this.doConnect(); } })
      PillButton({ label: '刷新', enabled_: !this.busy,
        onClickAction: (): void => { this.doRefresh(); } })
    }.width('100%')
  }

  @Builder
  pickBody() {
    Row({ space: 8 }) {
      PillButton({ label: '选择 HAP', enabled_: !this.busy,
        onClickAction: (): void => { this.doPick(); } })
      Text(this.hapLabel)
        .fontSize(12)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .layoutWeight(1)
        .maxLines(2)
    }.width('100%').margin({ bottom: $r('sys.float.padding_level3') })
    Row({ space: 8 }) {
      HapInput({ text: $url, placeholder: '或填下载地址 http://.../app.hap' })
        .layoutWeight(1)
      PillButton({ label: '下载', enabled_: !this.busy,
        onClickAction: (): void => { this.doUrlDownload(); } })
    }.width('100%')
  }

  @Builder
  certBody() {
    Text('① 读取并复制 UDID ② 到 AGC 设备管理添加该设备 ③ 申请/下载调试证书与 Profile ④ 回到下方导入')
      .fontSize(11)
      .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
      .width('100%')
      .margin({ bottom: $r('sys.float.padding_level2') })
    Text(this.udid.length > 0 ? ('UDID: ' + this.udid) : 'UDID: 未读取')
      .fontSize(11)
      .fontColor($r('sys.color.ohos_id_color_text_primary'))
      .width('100%')
      .maxLines(2)
      .margin({ bottom: $r('sys.float.padding_level3') })
    Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(6), cross: LengthMetrics.vp(6) } }) {
      PillButton({ label: this.agcUser.length > 0 ? '已登录' : '登录华为账号',
        variant: 'primary', enabled_: !this.busy,
        onClickAction: (): void => { this.doLogin(); } })
      PillButton({ label: '读取 UDID', enabled_: !this.busy,
        onClickAction: (): void => { this.doReadUdid(); } })
      PillButton({ label: '复制', onClickAction: (): void => { this.doCopyUdid(); } })
      PillButton({ label: '打开 AGC', onClickAction: (): void => { this.openAgc('cert'); } })
      PillButton({ label: '应用内打开', onClickAction: (): void => { this.openCertWeb(''); } })
    }.width('100%')
  }

  @Builder
  signBody() {
    Text(this.matLabel)
      .fontSize(11)
      .fontColor($r('sys.color.ohos_id_color_text_secondary'))
      .width('100%')
      .margin({ bottom: $r('sys.float.padding_level3') })
    Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(6), cross: LengthMetrics.vp(6) } }) {
      PillButton({ label: '证书链', onClickAction: (): void => { this.pickMat('cer'); } })
      PillButton({ label: 'Profile', onClickAction: (): void => { this.pickMat('p7b'); } })
      PillButton({ label: '密钥库', onClickAction: (): void => { this.pickMat('p12'); } })
    }.width('100%').margin({ bottom: $r('sys.float.padding_level3') })
    Row({ space: 8 }) {
      HapInput({ text: $keyAlias, placeholder: 'keyAlias' }).layoutWeight(1)
      HapInput({ text: $keyPwd, placeholder: '密码', isPassword: true }).layoutWeight(1)
    }.width('100%').margin({ bottom: $r('sys.float.padding_level3') })
    Row({ space: 8 }) {
      PillButton({ label: '申请证书', enabled_: !this.busy,
        onClickAction: (): void => { this.doApplyCert(); } })
      PillButton({ label: '申请 Profile', enabled_: !this.busy,
        onClickAction: (): void => { this.doApplyProfile(); } })
    }.width('100%').margin({ bottom: $r('sys.float.padding_level3') })
    HapInput({ text: $packageName, placeholder: '目标包名（Profile 绑定，留空=本应用）' })
      .width('100%')
      .margin({ bottom: $r('sys.float.padding_level3') })
    Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(6), cross: LengthMetrics.vp(6) } }) {
      PillButton({ label: '用内置材料', variant: 'primary', enabled_: !this.busy,
        onClickAction: (): void => { this.doUseBuiltin(); } })
      PillButton({ label: '生成密钥库', enabled_: !this.busy,
        onClickAction: (): void => { this.doGenKey(); } })
      PillButton({ label: '生成 CSR', enabled_: !this.busy,
        onClickAction: (): void => { this.doGenCsr(); } })
      PillButton({ label: '导出 CSR', onClickAction: (): void => { this.doCsrExport(); } })
    }.width('100%').margin({ bottom: $r('sys.float.padding_level3') })
    Row({ space: 8 }) {
      PillButton({ label: '签名', variant: 'primary', enabled_: !this.busy,
        onClickAction: (): void => { this.doSign(); } })
      PillButton({ label: '导出签名包', onClickAction: (): void => { this.doExport(); } })
    }.width('100%')
  }

  @Builder
  installBody() {
    Row({ space: 8 }) {
      PillButton({ label: this.busy ? '执行中…' : '安装到设备',
        variant: 'primary', enabled_: !this.busy && this.hapPath.length > 0,
        onClickAction: (): void => { this.doInstall(); } })
      PillButton({ label: '卸载', variant: 'danger', enabled_: !this.busy,
        onClickAction: (): void => { this.doUninstall(); } })
    }.width('100%').margin({ bottom: $r('sys.float.padding_level3') })
    HapInput({ text: $bundleName, placeholder: '卸载用包名' }).width('100%')
  }

  @Builder
  logsBody() {
    Row({ space: 8 }) {
      Text('操作日志')
        .fontSize(13)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .layoutWeight(1)
      PillButton({ label: '清空', onClickAction: (): void => { this.logs = []; } })
    }.width('100%').margin({ bottom: $r('sys.float.padding_level3') })
    Scroll() {
      Column({ space: 2 }) {
        ForEach(this.logs, (item: string, idx: number): void => {
          Text(item)
            .fontSize(10)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .width('100%')
            .textAlign(TextAlign.Start)
        }, (item: string, idx: number): string => idx + '_' + item.length)
      }.width('100%').alignItems(HorizontalAlign.Start)
    }
    .height(220)
    .width('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .padding($r('sys.float.padding_level3'))
    .borderRadius($r('sys.float.corner_radius_level4'))
  }

  @Builder
  signConfigSheet() {
    Column({ space: 10 }) {
      Text(this.matLabel)
        .fontSize(12)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .width('100%')
      Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(6), cross: LengthMetrics.vp(6) } }) {
        PillButton({ label: '证书链', onClickAction: (): void => { this.pickMat('cer'); } })
        PillButton({ label: 'Profile', onClickAction: (): void => { this.pickMat('p7b'); } })
        PillButton({ label: '密钥库', onClickAction: (): void => { this.pickMat('p12'); } })
        PillButton({ label: '用内置材料', variant: 'primary', enabled_: !this.busy,
          onClickAction: (): void => { this.doUseBuiltin(); } })
      }.width('100%')
      Row({ space: 8 }) {
        HapInput({ text: $keyAlias, placeholder: 'keyAlias' }).layoutWeight(1)
        HapInput({ text: $keyPwd, placeholder: '密码', isPassword: true }).layoutWeight(1)
      }.width('100%')
      Divider().color($r('sys.color.ohos_id_color_list_separator'))
      Text('AGC 证书 / Profile 申请')
        .fontSize(14)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .width('100%')
      Text(this.udid.length > 0 ? ('UDID: ' + this.udid) : 'UDID: 未读取')
        .fontSize(11)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .width('100%')
        .maxLines(2)
      Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(6), cross: LengthMetrics.vp(6) } }) {
        PillButton({ label: '读取 UDID', enabled_: !this.busy,
          onClickAction: (): void => { this.doReadUdid(); } })
        PillButton({ label: '复制 UDID', onClickAction: (): void => { this.doCopyUdid(); } })
        PillButton({ label: '打开 AGC', onClickAction: (): void => { this.openAgc('cert'); } })
        PillButton({ label: '应用内打开', onClickAction: (): void => { this.openCertWeb(''); } })
      }.width('100%')
      Row({ space: 8 }) {
        PillButton({ label: '申请证书', enabled_: !this.busy,
          onClickAction: (): void => { this.doApplyCert(); } }).layoutWeight(1)
        PillButton({ label: '申请 Profile', enabled_: !this.busy,
          onClickAction: (): void => { this.doApplyProfile(); } }).layoutWeight(1)
      }.width('100%')
      HapInput({ text: $packageName, placeholder: '目标包名（Profile 绑定，留空=本应用）' }).width('100%')
      Divider().color($r('sys.color.ohos_id_color_list_separator'))
      Text('密钥库 / CSR')
        .fontSize(14)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .width('100%')
      Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(6), cross: LengthMetrics.vp(6) } }) {
        PillButton({ label: '生成密钥库', enabled_: !this.busy,
          onClickAction: (): void => { this.doGenKey(); } })
        PillButton({ label: '生成 CSR', enabled_: !this.busy,
          onClickAction: (): void => { this.doGenCsr(); } })
        PillButton({ label: '导出 CSR', onClickAction: (): void => { this.doCsrExport(); } })
        PillButton({ label: '导出签名包', onClickAction: (): void => { this.doExport(); } })
      }.width('100%')
      Divider().color($r('sys.color.ohos_id_color_list_separator'))
      Text('日志')
        .fontSize(14)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .width('100%')
      Scroll() {
        Column({ space: 2 }) {
          ForEach(this.logs, (item: string, idx: number): void => {
            Text(item)
              .fontSize(10)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .width('100%')
              .textAlign(TextAlign.Start)
          }, (item: string, idx: number): string => idx + '_' + item.length)
        }.width('100%').alignItems(HorizontalAlign.Start)
      }
      .height(200)
      .width('100%')
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
      .padding($r('sys.float.padding_level3'))
      .borderRadius($r('sys.float.corner_radius_level4'))
      PillButton({ label: '完成', variant: 'primary',
        onClickAction: (): void => { this.signSheetOpen = false; } }).width('100%')
    }
    .width('100%')
    .padding({ top: $r('sys.float.padding_level4'),
      left: $r('sys.float.padding_level6'),
      right: $r('sys.float.padding_level6'),
      bottom: $r('sys.float.padding_level6') })
  }

  private canStartDebug(): boolean {
    return this.agcUser.length > 0 && this.target.length > 0 && this.hapPath.length > 0;
  }

  private async startDebug(autoSign: boolean): Promise<void> {
    if (autoSign) {
      await this.doSign();
      if (this.signedPath.length > 0) {
        await this.doInstall();
      }
    } else {
      const saved: string = this.signedPath;
      this.signedPath = '';
      try {
        this.signedPath = saved.length > 0 ? saved : this.hapPath;
        await this.doInstall();
      } finally {
        this.signedPath = saved;
      }
    }
  }

  private openConnectSheet(): void {
    const idx: number = this.target.lastIndexOf(':');
    if (idx > 0) {
      // target 只在连接成功时落盘，所以这两个值就是"上一次有效输入"
      this.ipPart = this.target.substring(0, idx);
      this.portPart = this.target.substring(idx + 1);
    }
    this.connectSheetOpen = true;
  }

  private async onConnectConfirm(t: string): Promise<void> {
    this.connectSheetOpen = false;
    this.target = t;
    await this.doConnect();
  }

  build() {
    Column({ space: 12 }) {
      Column({ space: 0 }) {
        HomeSettingItem({
          title: this.agcUser.length > 0 ? this.agcUser : '未登录',
          description: '华为账号',
          icon: $r('sys.symbol.person_crop_circle_fill_1'),
          buttonLabel: this.agcUser.length > 0 ? '更换账号' : '登录账号',
          isActive: this.agcUser.length > 0,
          buttonEnabled: !this.busy,
          onButtonTap: (): void => { this.doLogin(); }
        })
        Divider().color($r('sys.color.ohos_id_color_list_separator'))
          .visibility(this.agcUser.length > 0 ? Visibility.Visible : Visibility.None)
        HomeSettingItem({
          title: this.target.length > 0 ? this.target : '未连接',
          description: '设备',
          icon: $r('sys.symbol.wifi'),
          buttonLabel: this.target.length > 0 ? '更换地址' : '无线调试',
          isActive: this.target.length > 0,
          buttonEnabled: !this.busy,
          show: this.agcUser.length > 0,
          onButtonTap: (): void => { this.openConnectSheet(); }
        })
        Divider().color($r('sys.color.ohos_id_color_list_separator'))
          .visibility(this.agcUser.length > 0 && this.target.length > 0
            ? Visibility.Visible : Visibility.None)
        HomeSettingItem({
          title: this.hapPath.length > 0 ? this.hapLabel : '未选择',
          description: '软件安装包',
          icon: $r('sys.symbol.doc'),
          buttonLabel: this.hapPath.length > 0 ? '更换' : '选择',
          isActive: this.hapPath.length > 0,
          buttonEnabled: !this.busy,
          show: this.agcUser.length > 0 && this.target.length > 0,
          onButtonTap: (): void => { this.doPick(); }
        })
      }
      .width('100%')
      .padding({ left: $r('sys.float.padding_level6'), right: $r('sys.float.padding_level6'),
        top: $r('sys.float.padding_level2'), bottom: $r('sys.float.padding_level2') })
      .borderRadius($r('sys.float.corner_radius_level6'))
      .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
      // 一个组件只能绑一个半模态：两个 bindSheet 链在同一节点上时，先绑的会被后绑的覆盖，
      // 所以连接抽屉挂在这张卡片上，签名配置抽屉挂在页面根节点上
      .bindSheet($$this.connectSheetOpen, this.connectSheetBuilder(), {
        detents: [SheetSize.MEDIUM, SheetSize.LARGE],
        title: { title: '无线调试' },
        backgroundColor: $r('sys.color.ohos_id_color_card_bg')
      })

      Text(this.status)
        .fontSize(12)
        .fontColor(this.kernelReady
          ? $r('sys.color.ohos_id_color_text_secondary')
          : $r('sys.color.ohos_id_color_warning'))
        .width('100%')

      if (this.canStartDebug()) {
        Column({ space: 8 }) {
          PillButton({ label: '开始调试（自动签名）', variant: 'primary', enabled_: !this.busy,
            onClickAction: (): void => { this.startDebug(true); } })
          PillButton({ label: '直接安装（需已签名）', enabled_: !this.busy,
            onClickAction: (): void => { this.startDebug(false); } })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: $r('sys.float.padding_level6'), right: $r('sys.float.padding_level6'),
      top: topInsetVp(this.getUIContext(), this.safeTopPx),
      bottom: bottomInsetVp(this.getUIContext(), this.safeBottomPx) })
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .alignItems(HorizontalAlign.Start)
    .bindSheet($$this.signSheetOpen, this.signConfigSheet(), {
      detents: [SheetSize.LARGE],
      title: { title: '签名配置' },
      backgroundColor: $r('sys.color.ohos_id_color_card_bg')
    })
  }

  @Builder
  connectSheetBuilder() {
    ConnectDeviceSheet({
      ip: $ipPart,
      port: $portPart,
      onConfirm: (t: string): void => { this.onConnectConfirm(t); },
      onClose: (): void => { this.connectSheetOpen = false; }
    })
  }

  private async doUrlDownload(): Promise<void> {
    if (this.url.trim().length === 0) {
      this.log('请填写下载地址');
      return;
    }
    const p: string = await this.downloadTo(this.url.trim(), 'picked.hap');
    if (p.length > 0) {
      this.markPicked(p);
    }
  }
}
