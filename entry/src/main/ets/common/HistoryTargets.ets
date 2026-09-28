import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const KEY: string = 'historyTargets';
const MAX: number = 10;

/** 无线调试历史连接地址列表（对应 Flutter EcoViewModel.historyList） */
export async function loadHistoryTargets(ctx: common.UIAbilityContext): Promise<string[]> {
  try {
    const store = await preferences.getPreferences(ctx, 'hapinstaller');
    const raw: string = await store.get(KEY, '') as string;
    if (raw.length === 0) {
      return [];
    }
    return JSON.parse(raw) as string[];
  } catch (e) {
    return [];
  }
}

/** 记录一次成功连接的地址：去重、置顶、限量 */
export async function addHistoryTarget(ctx: common.UIAbilityContext, addr: string): Promise<void> {
  const list: string[] = await loadHistoryTargets(ctx);
  const next: string[] = list.filter((v: string): boolean => v !== addr);
  next.unshift(addr);
  while (next.length > MAX) {
    next.pop();
  }
  try {
    const store = await preferences.getPreferences(ctx, 'hapinstaller');
    await store.put(KEY, JSON.stringify(next));
    await store.flush();
  } catch (e) {
    // 忽略持久化失败
  }
}

export async function clearHistoryTargets(ctx: common.UIAbilityContext): Promise<void> {
  try {
    const store = await preferences.getPreferences(ctx, 'hapinstaller');
    await store.delete(KEY);
    await store.flush();
  } catch (e) {
    // 忽略
  }
}
