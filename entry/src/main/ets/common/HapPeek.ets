import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';

interface HapAppInfo {
  bundleName: string;
}

interface HapPermInfo {
  name: string;
}

interface HapModuleBody {
  requestPermissions?: HapPermInfo[];
}

interface HapModuleJson {
  app: HapAppInfo;
  module?: HapModuleBody;
}

/** 根部 module.json 里的关键信息：包名与申请到的权限名 */
export interface HapPeekInfo {
  bundleName: string;
  permissions: string[];
}

/** 只读 HAP(ZIP) 中央目录提取根部 module.json；仅支持 Stored 条目（hvigor 产物均如此），失败返回空值由调用方回退 */
export class HapPeek {
  static bundleNameOf(hapPath: string): string {
    return HapPeek.infoOf(hapPath).bundleName;
  }

  static permissionsOf(hapPath: string): string[] {
    return HapPeek.infoOf(hapPath).permissions;
  }

  static infoOf(hapPath: string): HapPeekInfo {
    const empty: HapPeekInfo = { bundleName: '', permissions: [] };
    let fd: fileIo.File | undefined = undefined;
    try {
      const size: number = fileIo.statSync(hapPath).size;
      fd = fileIo.openSync(hapPath, fileIo.OpenMode.READ_ONLY);
      const tailLen: number = Math.min(size, 4194304);
      const tailBase: number = size - tailLen;
      const tail: Uint8Array = HapPeek.readAt(fd.fd, tailBase, tailLen);
      const dvTail = new DataView(tail.buffer, tail.byteOffset, tail.byteLength);
      let eocd: number = -1;
      for (let i = tail.length - 22; i >= 0; i--) {
        if (dvTail.getUint32(i, true) === 0x06054b50) {
          const cdSize: number = dvTail.getUint32(i + 12, true);
          const cdOff: number = dvTail.getUint32(i + 16, true);
          if (cdOff + cdSize <= size) {
            eocd = i;
            break;
          }
        }
      }
      if (eocd < 0) {
        return empty;
      }
      const cdSize: number = dvTail.getUint32(eocd + 12, true);
      const cdOff: number = dvTail.getUint32(eocd + 16, true);
      let cd: Uint8Array;
      if (cdOff >= tailBase) {
        const st: Uint8Array = tail.subarray(cdOff - tailBase);
        cd = new Uint8Array(st.slice(0, Math.min(cdSize, st.length)));
      } else {
        cd = HapPeek.readAt(fd.fd, cdOff, Math.min(cdSize, 8388608));
      }
      const dvCd = new DataView(cd.buffer, cd.byteOffset, cd.byteLength);
      const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
      let p: number = 0;
      while (p + 46 <= cd.length && dvCd.getUint32(p, true) === 0x02014b50) {
        const method: number = dvCd.getUint16(p + 10, true);
        const compSize: number = dvCd.getUint32(p + 20, true);
        const nameLen: number = dvCd.getUint16(p + 28, true);
        const extraLen: number = dvCd.getUint16(p + 30, true);
        const commentLen: number = dvCd.getUint16(p + 32, true);
        const localOff: number = dvCd.getUint32(p + 42, true);
        const name: string = decoder.decodeToString(cd.subarray(p + 46, p + 46 + nameLen));
        if (name === 'module.json' && method === 0) {
          return HapPeek.readModuleJson(fd.fd, localOff, compSize, decoder);
        }
        p += 46 + nameLen + extraLen + commentLen;
      }
      return empty;
    } catch (e) {
      return empty;
    } finally {
      if (fd !== undefined) {
        try {
          fileIo.closeSync(fd);
        } catch (ignored) {
        }
      }
    }
  }

  private static readModuleJson(fd: number, localOff: number, compSize: number,
    decoder: util.TextDecoder): HapPeekInfo {
    const empty: HapPeekInfo = { bundleName: '', permissions: [] };
    if (compSize <= 0 || compSize > 4194304) {
      return empty;
    }
    const head: Uint8Array = HapPeek.readAt(fd, localOff, 30);
    const dvHead = new DataView(head.buffer, head.byteOffset, head.byteLength);
    if (dvHead.getUint32(0, true) !== 0x04034b50) {
      return empty;
    }
    const lNameLen: number = dvHead.getUint16(26, true);
    const lExtraLen: number = dvHead.getUint16(28, true);
    const data: Uint8Array = HapPeek.readAt(fd, localOff + 30 + lNameLen + lExtraLen, compSize);
    try {
      const parsed: HapModuleJson = JSON.parse(decoder.decodeToString(data)) as HapModuleJson;
      const perms: string[] = [];
      const req: HapPermInfo[] | undefined = parsed.module !== undefined
        ? parsed.module.requestPermissions : undefined;
      if (req !== undefined) {
        for (const item of req) {
          if (item.name.length > 0) {
            perms.push(item.name);
          }
        }
      }
      return { bundleName: parsed.app.bundleName, permissions: perms };
    } catch (e) {
      return empty;
    }
  }

  private static readAt(fd: number, offset: number, len: number): Uint8Array {
    const buf: ArrayBuffer = new ArrayBuffer(len);
    const got: number = fileIo.readSync(fd, buf, { offset: offset, length: len });
    const u8: Uint8Array = new Uint8Array(buf);
    return got === len ? u8 : u8.subarray(0, Math.max(got, 0));
  }
}
