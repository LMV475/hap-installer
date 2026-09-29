import { useSystemTabBar } from './MaterialPolicy';

/**
 * 沉浸光感布局的公共尺寸：顶部标题浮层 / 底部悬浮胶囊。
 * 页面内容铺满到状态栏和导航条之下，再由各页自己按这两个 inset 留出可视区。
 */
/** 状态栏与标题之间的留白 */
export const TITLE_TOP_GAP_VP: number = 8;
/** 标题行高度（标题在行内垂直居中） */
export const TITLE_BAR_VP: number = 44;
/** 标题字号 */
export const TITLE_FONT_VP: number = 28;
/** 标题下方额外留出的渐变过渡带；模糊与蒙层在这段里收尾，太窄会看出硬边 */
export const TITLE_FADE_VP: number = 20;
/**
 * 顶部渐变模糊的模糊强度（作用在 Tabs 上，按屏幕位置连续渐变）。
 * 系统侧的 HdsNavigation scrollEffectOpts 在本 SDK 拿不到，但 linearGradientBlur 本身就是
 * 线性渐变的内容模糊，加在页面容器上等效：内容滚到顶部时被逐级糊掉，没有分段、没有台阶。
 */
export const TITLE_BLUR_VP: number = 45;
/**
 * 标题区蒙层的多档不透明度与对应位置，固定成一张连续曲线：分段渐变在接缝处斜率突变会看出色阶，
 * 所以这里用一整条多档曲线，并且只在标题行下方才开始明显衰减。
 */
export const TITLE_MASK_ALPHA: number[] = [0.9, 0.9, 0.89, 0.87, 0.82, 0.68, 0.5, 0.3, 0.14, 0];
export const TITLE_MASK_POS: number[] = [0, 0.28, 0.5, 0.65, 0.78, 0.85, 0.9, 0.94, 0.97, 1];
/** 旧手搓胶囊高度（legacy 设计 token）。与 SYSTEM_TAB_BAR_VP 当前刻意等值（56）但来源独立（此为设计值、彼为系统实测值），允许各自漂移，勿合并 */
export const PILL_BAR_VP: number = 56;
export const PILL_BOTTOM_GAP_VP: number = 12;
export const CONTENT_GAP_VP: number = 24;
/** 胶囊内边距：选中项圆角 = 外圆角 - 内边距，两圈才同心 */
export const PILL_ITEM_PAD_VP: number = 4;
/**
 * 系统悬浮 TabBar 的真实高度（vp）。初值沿用旧胶囊，Task 8 Step 6 用 px2vp 比值实测校正。
 * 实测（5MT0226114015018，uitest dumpLayout TabBar bounds 高 190px，px2vp(1000)=296.296 → 190×0.296296=56.3vp）：
 * barHeight 给多少系统就画多少，56 成立，保留 56。
 * 与 PILL_BAR_VP 当前刻意等值但来源独立（系统实测 vs legacy 设计 token），Fix round 1 已真机证明 bottomInsetVp 分叉接线有效（56→80 时内容底 inset 精确上移 81px）。
 */
export const SYSTEM_TAB_BAR_VP: number = 56;
/**
 * 悬浮 TabBar 在 sm/md/lg 三档断点下的绝对宽度（vp）。百分比不被 FloatingTabBarWidth 支持（tabs.d.ts:783-813）。
 * sm 档实测（同上设备，屏宽 391vp 落在 sm）：TabBar bounds 宽 1148px×0.296296=340.1vp，340 原样生效；
 * md/lg 档该直板机无法呈现，仅代码证据。
 */
export const TAB_BAR_WIDTH_SM_VP: number = 340;
export const TAB_BAR_WIDTH_MD_VP: number = 560;
export const TAB_BAR_WIDTH_LG_VP: number = 720;

export function topInsetVp(ui: UIContext, safeTopPx: number): number {
  return ui.px2vp(safeTopPx) + TITLE_TOP_GAP_VP + TITLE_BAR_VP + TITLE_FADE_VP;
}

// 系统悬浮 TabBar 模式下用实测高度分叉（Task 8）；依赖方向为常量层(Immersive) → 策略层(MaterialPolicy)，禁止反向 import
export function bottomInsetVp(ui: UIContext, safeBottomPx: number): number {
  const barVp: number = useSystemTabBar() ? SYSTEM_TAB_BAR_VP : PILL_BAR_VP;
  return ui.px2vp(safeBottomPx) + barVp + PILL_BOTTOM_GAP_VP + CONTENT_GAP_VP;
}

/** NavDestination 子页用系统标题栏，需要自己把状态栏 / 导航条区域让出来 */
export function safeAreaInsets(ui: UIContext, safeTopPx: number, safeBottomPx: number): Padding {
  const top: number = ui.px2vp(safeTopPx);
  const bottom: number = ui.px2vp(safeBottomPx);
  const inset: Padding = { top: top, bottom: bottom };
  return inset;
}
