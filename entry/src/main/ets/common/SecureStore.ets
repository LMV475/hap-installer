/*
 * Copyright (c) 2025 LMV475
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { asset } from '@kit.AssetStoreKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'HapInstaller';

/**
 * 少量敏感字符串的加密存储。
 *
 * 用系统加密密钥库 ASSET（底层由 HUKS 派生密钥保护，落盘为密文），替代原先明文写进
 * preferences 的做法（登录令牌属于凭据，不宜明文落盘）。
 *
 * ASSET 单条 `SECRET` 上限 1024 字节，而 AGC 的 jwt+access 令牌远超此值，因此按字节分片：
 * `<alias>#0`、`<alias>#1`… 存数据片，`<alias>#n` 存片数（单字节）。
 * 读写失败一律只记日志、返回空值/失败，不向调用方抛异常——调用点都在启动/保存流程里。
 */

// 单片字节数：留出余量（上限 1024）
const CHUNK_BYTES: number = 900;
// 片数上限（片数记在单字节里，故不超过 255）
const MAX_CHUNKS: number = 32;

function encode(value: string): Uint8Array {
  return new util.TextEncoder().encodeInto(value);
}

function decode(bytes: Uint8Array): string {
  return util.TextDecoder.create('utf-8').decodeToString(bytes);
}

/** 按字节切片，且不切开 UTF-8 多字节序列（0x80-0xBF 为续字节） */
function splitBytes(bytes: Uint8Array, size: number): Array<Uint8Array> {
  const out: Array<Uint8Array> = [];
  let start: number = 0;
  while (start < bytes.length) {
    let end: number = Math.min(start + size, bytes.length);
    while (end < bytes.length && (bytes[end] & 0xC0) === 0x80) {
      end--;
    }
    out.push(bytes.subarray(start, end));
    start = end;
  }
  return out;
}

function joinBytes(parts: Array<Uint8Array>): Uint8Array {
  let total: number = 0;
  for (let i = 0; i < parts.length; i++) {
    total += parts[i].length;
  }
  const out: Uint8Array = new Uint8Array(total);
  let at: number = 0;
  for (let i = 0; i < parts.length; i++) {
    out.set(parts[i], at);
    at += parts[i].length;
  }
  return out;
}

async function removeChunk(alias: string): Promise<void> {
  try {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, encode(alias));
    await asset.remove(query);
  } catch (e) {
    // 「The asset is not found.」属正常：add 不接受重复别名，覆盖写前先删
    const miss = e as BusinessError;
    hilog.debug(DOMAIN, TAG, '[secure] %{public}s 无旧记录: %{public}s', alias, miss.message);
  }
}

async function writeChunk(alias: string, bytes: Uint8Array): Promise<void> {
  await removeChunk(alias);
  const attrs: asset.AssetMap = new Map();
  attrs.set(asset.Tag.ALIAS, encode(alias));
  attrs.set(asset.Tag.SECRET, bytes);
  attrs.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED);
  await asset.add(attrs);
}

async function readChunk(alias: string): Promise<Uint8Array> {
  try {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, encode(alias));
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
    const result: Array<asset.AssetMap> = await asset.query(query);
    if (result.length === 0) {
      return new Uint8Array(0);
    }
    const secret: asset.Value | undefined = result[0].get(asset.Tag.SECRET);
    if (secret instanceof Uint8Array) {
      return secret;
    }
    return new Uint8Array(0);
  } catch (e) {
    const err = e as BusinessError;
    hilog.info(DOMAIN, TAG, '[secure] 读取 %{public}s 未命中: %{public}s', alias, err.message);
    return new Uint8Array(0);
  }
}

/** 写入或覆盖一条凭据；返回是否成功 */
export async function putSecret(alias: string, value: string): Promise<boolean> {
  try {
    const chunks: Array<Uint8Array> = splitBytes(encode(value), CHUNK_BYTES);
    if (chunks.length > MAX_CHUNKS) {
      hilog.error(DOMAIN, TAG, '[secure] %{public}s 过大：%{public}d 片', alias, chunks.length);
      return false;
    }
    for (let i = 0; i < chunks.length; i++) {
      await writeChunk(alias + '#' + i, chunks[i]);
    }
    await writeChunk(alias + '#n', new Uint8Array([chunks.length]));
    return true;
  } catch (e) {
    const err = e as BusinessError;
    hilog.error(DOMAIN, TAG, '[secure] 写入 %{public}s 失败: %{public}s', alias, err.message);
    return false;
  }
}

/** 读取一条凭据；不存在、分片缺失或读取失败均返回空串 */
export async function getSecret(alias: string): Promise<string> {
  const head: Uint8Array = await readChunk(alias + '#n');
  if (head.length === 0) {
    return '';
  }
  const count: number = head[0];
  if (count === 0 || count > MAX_CHUNKS) {
    return '';
  }
  const parts: Array<Uint8Array> = [];
  for (let i = 0; i < count; i++) {
    const part: Uint8Array = await readChunk(alias + '#' + i);
    if (part.length === 0) {
      hilog.error(DOMAIN, TAG, '[secure] %{public}s 第 %{public}d 片缺失，视为未保存', alias, i);
      return '';
    }
    parts.push(part);
  }
  return decode(joinBytes(parts));
}
