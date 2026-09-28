import { worker, MessageEvents, ThreadWorkerGlobalScope } from '@kit.ArkTS';
import signtool from 'libsigntool.so';

// 独立 JS 运行时里执行签名：即使原生侧卡住，主线程与看门狗仍然存活
const workerPort: ThreadWorkerGlobalScope = worker.workerPort;

workerPort.onmessage = (e: MessageEvents): void => {
  const cmd: string = e.data.cmd as string;
  const tempDir: string = e.data.tempDir as string;
  try {
    signtool.signHap(cmd, tempDir, (code: number, output: string): void => {
      workerPort.postMessage({ code: code });
    });
  } catch (err) {
    workerPort.postMessage({ code: -99 });
  }
};
