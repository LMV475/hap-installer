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
export const PILL_BAR_VP: number = 56;
export const PILL_BOTTOM_GAP_VP: number = 12;
export const CONTENT_GAP_VP: number = 24;
/** 胶囊内边距：选中项圆角 = 外圆角 - 内边距，两圈才同心 */
export const PILL_ITEM_PAD_VP: number = 4;

export function topInsetVp(ui: UIContext, safeTopPx: number): number {
  return ui.px2vp(safeTopPx) + TITLE_TOP_GAP_VP + TITLE_BAR_VP + TITLE_FADE_VP;
}

// 系统悬浮栏模式下的真实高度由 Batch 3 的 Task 8 量测后在此函数内分叉
export function bottomInsetVp(ui: UIContext, safeBottomPx: number): number {
  return ui.px2vp(safeBottomPx) + PILL_BAR_VP + PILL_BOTTOM_GAP_VP + CONTENT_GAP_VP;
}

/** NavDestination 子页用系统标题栏，需要自己把状态栏 / 导航条区域让出来 */
export function safeAreaInsets(ui: UIContext, safeTopPx: number, safeBottomPx: number): Padding {
  const top: number = ui.px2vp(safeTopPx);
  const bottom: number = ui.px2vp(safeBottomPx);
  const inset: Padding = { top: top, bottom: bottom };
  return inset;
}
