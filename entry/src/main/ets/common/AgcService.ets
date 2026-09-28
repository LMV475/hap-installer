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

import { common } from '@kit.AbilityKit';

/**
 * AGC（华为 AppGallery Connect）证书 / Profile / 设备管理接口 —— 功能空实现（stub）。
 *
 * 本仓库入库的版本**不包含任何华为内部接口的实现**，仅保留与业务代码一致的接口签名，
 * 目的是让 `git clone` 得到的仓库可以直接编译：页面 Cert.ets / Home.ets / TeamDevice.ets
 * 均依赖本模块，若缺少该文件则无法构建。
 *
 * 所有方法在未实现时给出明确失败语义而非静默成功：
 *   - isLoggedIn() 恒为 false，页面会自然引导到「请先登录」分支；
 *   - 查询类接口返回空集合；
 *   - 变更/网络类接口抛出明确的「未实现」错误。
 *
 * 如需启用 AGC 相关功能，请自行实现等价模块并覆盖本文件，详见 README「未开源模块」。
 */

export interface AgcAuthInfo {
  jwtToken: string;
  accessToken: string;
  userId: string;
  teamId: string;
}

export interface AgcCertInfo {
  id: string;
  certName: string;
  certObjectId: string;
  status: number;
  certType: number;
  expireTime: number;
}

export interface AgcDeviceInfo {
  id: string;
  udid: string;
  deviceName: string;
}

const NOT_IMPLEMENTED: string =
  'AGC 模块未实现：请自行实现 entry/src/main/ets/common/AgcService.ets（见 README「未开源模块」）';

export class AgcService {
  static getAuth(): AgcAuthInfo | null {
    return null;
  }

  static isLoggedIn(): boolean {
    return false;
  }

  static exportAuth(): AgcAuthInfo | null {
    return null;
  }

  static importAuth(auth: AgcAuthInfo): void {
    // stub：不保存任何登录态，参数仅为保持接口兼容
  }

  static async refreshAuth(): Promise<boolean> {
    return false;
  }

  static async waitForCallback(port: number, timeoutMs: number): Promise<string> {
    throw new Error(NOT_IMPLEMENTED);
  }

  static async exchangeToken(tempToken: string): Promise<AgcAuthInfo> {
    throw new Error(NOT_IMPLEMENTED);
  }

  static async getCertList(): Promise<AgcCertInfo[]> {
    return [];
  }

  static async createCert(name: string, certType: number, csr: string): Promise<AgcCertInfo> {
    throw new Error(NOT_IMPLEMENTED);
  }

  static async removeCert(certId: string): Promise<void> {
    throw new Error(NOT_IMPLEMENTED);
  }

  static async deviceList(): Promise<AgcDeviceInfo[]> {
    return [];
  }

  static async createDevice(deviceName: string, udid: string): Promise<void> {
    throw new Error(NOT_IMPLEMENTED);
  }

  static async createProfile(name: string, certId: string, deviceIds: string[],
                             acl: string[], packageName: string): Promise<string> {
    throw new Error(NOT_IMPLEMENTED);
  }

  static async certDownloadUrl(certObjectId: string): Promise<string> {
    throw new Error(NOT_IMPLEMENTED);
  }

  static loginUrl(port: number): string {
    return '';
  }

  static async openLoginPage(ctx: common.UIAbilityContext, port: number): Promise<void> {
    throw new Error(NOT_IMPLEMENTED);
  }
}
