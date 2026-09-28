import hdc from 'libhdc_z.so';
import { hilog } from '@kit.PerformanceAnalysisKit';

/** hdc 内核的 ArkTS 封装：进程内 server + 回调式命令执行 */
export class HdcService {
  private static serverStarted: boolean = false;

  static startServer(tempDir: string): void {
    if (HdcService.serverStarted) {
      return;
    }
    hdc.hdcStartServer(tempDir);
    HdcService.serverStarted = true;
    hilog.info(0x0000, 'HapInstaller', '%{public}s', 'hdc server started, tempDir=' + tempDir);
  }

  static isServerStarted(): boolean {
    return HdcService.serverStarted;
  }

  /** 执行一条 hdc 命令，Promise 返回其输出 */
  static run(cmd: string, tempDir: string): Promise<string> {
    return new Promise<string>((resolve: (v: string) => void) => {
      hdc.hdcRun(cmd, tempDir, (output: string): void => {
        resolve(output);
      });
    });
  }
}
