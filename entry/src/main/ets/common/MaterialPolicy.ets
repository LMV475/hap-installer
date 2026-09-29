import { hilog } from '@kit.PerformanceAnalysisKit';
import { uiMaterial } from '@kit.ArkUI';

export function isImmersiveSupported(): boolean {
  try {
    return uiMaterial.isImmersiveMaterialSupported();
  } catch (e) {
    hilog.error(0x0000, 'HapInstaller', 'isImmersiveMaterialSupported threw: %{public}s', String(e));
    return false;
  }
}

export function globalLevelName(): string {
  try {
    const level: uiMaterial.MaterialLevel = uiMaterial.getGlobalMaterialLevel();
    if (level === uiMaterial.MaterialLevel.EXQUISITE) {
      return 'EXQUISITE';
    }
    if (level === uiMaterial.MaterialLevel.GENTLE) {
      return 'GENTLE';
    }
    if (level === uiMaterial.MaterialLevel.SMOOTH) {
      return 'SMOOTH';
    }
    return 'UNKNOWN(' + level + ')';
  } catch (e) {
    return 'THREW(' + String(e) + ')';
  }
}

export function materialInfoStateName(): string {
  try {
    const info: uiMaterial.MaterialInfo = uiMaterial.getMaterialInfo();
    if (info.state === uiMaterial.MaterialState.ENABLE) {
      return 'ENABLE';
    }
    if (info.state === uiMaterial.MaterialState.DISABLE) {
      return 'DISABLE';
    }
    return 'DEFAULT';
  } catch (e) {
    return 'THREW(' + String(e) + ')';
  }
}

export function logMaterialCapabilities(): void {
  hilog.info(0x0000, 'HapInstaller',
    'material probe: supported=%{public}s level=%{public}s state=%{public}s',
    String(isImmersiveSupported()), globalLevelName(), materialInfoStateName());
}
