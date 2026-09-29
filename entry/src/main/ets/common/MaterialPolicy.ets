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

/** 回退总开关：false 时全站回到手搓浮层，不做任何材质设置 */
export const USE_SYSTEM_CHROME: boolean = true;
/** 底栏交回 Tabs.barFloatingStyle 的分面开关（Batch 3 置 true） */
export const ENABLE_SYSTEM_TAB_BAR: boolean = false;
/** 顶栏交回 Navigation.title 的分面开关（Batch 4 置 true） */
export const ENABLE_SYSTEM_TITLE_BAR: boolean = false;

export function useSystemChrome(): boolean {
  return USE_SYSTEM_CHROME && isImmersiveSupported();
}

export function useSystemTabBar(): boolean {
  return USE_SYSTEM_CHROME && ENABLE_SYSTEM_TAB_BAR && isImmersiveSupported();
}

export function useSystemTitleBar(): boolean {
  return USE_SYSTEM_CHROME && ENABLE_SYSTEM_TITLE_BAR && isImmersiveSupported();
}

export function chromeStyle(): uiMaterial.ImmersiveStyle {
  const name: string = globalLevelName();
  if (name === 'EXQUISITE') {
    return uiMaterial.ImmersiveStyle.THICK;
  }
  if (name === 'GENTLE') {
    return uiMaterial.ImmersiveStyle.REGULAR;
  }
  return uiMaterial.ImmersiveStyle.ULTRA_THIN;
}

export function tabBarMaterial(): uiMaterial.ImmersiveMaterial {
  const options: uiMaterial.ImmersiveOptions = {
    style: chromeStyle(),
    applyShadow: globalLevelName() !== 'SMOOTH'
  };
  return new uiMaterial.ImmersiveMaterial(options);
}

export function titleBarMaterial(): uiMaterial.ImmersiveMaterial {
  const options: uiMaterial.ImmersiveOptions = {
    style: chromeStyle(),
    applyShadow: false
  };
  return new uiMaterial.ImmersiveMaterial(options);
}
