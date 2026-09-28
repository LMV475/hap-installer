import signtool from 'libsigntool.so';
import { hilog } from '@kit.PerformanceAnalysisKit';

export interface SignOutcome {
  code: number;
  output: string;
}

/** 端侧签名（OpenHarmony developtools_hapsigner）的 ArkTS 封装 */
export class SignService {
  /** 执行 signtool 命令；回调只回传返回码（0 = 成功），详情读沙箱内的 sign.out */
  static sign(cmd: string, tempDir: string): Promise<SignOutcome> {
    return new Promise<SignOutcome>((resolve: (v: SignOutcome) => void) => {
      signtool.signHap(cmd, tempDir, (code: number, output: string): void => {
        hilog.info(0x0000, 'HAPKIT', '%{public}s', 'signHap returned ' + code);
        const text: string = (output === undefined || output === null) ? '' : output;
        resolve({ code: code, output: text });
      });
    });
  }
}
