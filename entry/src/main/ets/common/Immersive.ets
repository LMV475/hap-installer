/**
 * 沉浸光感布局的公共尺寸：顶栏由 HdsNavigation 承担、底部为系统悬浮 TabBar。
 * 页面内容铺满到状态栏和导航条之下，再由各页自己按这两个 inset 留出可视区。
 */
export const PILL_BOTTOM_GAP_VP: number = 12;
export const CONTENT_GAP_VP: number = 24;
/**
 * 系统悬浮 TabBar 的真实高度（vp）。
 * 实测（5MT0226114015018，uitest dumpLayout TabBar bounds 高 190px，px2vp(1000)=296.296 → 190×0.296296=56.3vp）：
 * barHeight 给多少系统就画多少，56 成立，保留 56。
 * Fix round 1 已真机证明 bottomInsetVp 接线有效（56→80 时内容底 inset 精确上移 81px）。
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

/**
 * 二级页（ACL/Terminal）工具条悬浮栏的几何。
 * 高度沿用包进 Tabs 底栏时定的 76（TextInput/Button 44 + 上下各 16 padding）。
 *
 * 宽度只认 `FloatingTabBarWidth` 的绝对 vp（tabs.d.ts:775-815「cannot be set in percentage」）：
 * 首轮只给 `barSideMargin: 12` 时栏体停在 **174vp**（模拟器 TabBar [334,2354][922,2620] = 588px），
 * 即悬浮栏默认宽度是按系统档给的、边距不会把它撑成满宽 —— 工具条要满铺就必须显式写 barWidth。
 * 按屏宽写死会随设备变（模拟器 1256px÷3.375=372vp、真机 391vp），所以宽度由窗口实测宽换算。
 */
export const TOOLBAR_BAR_HEIGHT_VP: number = 76;
export const TOOLBAR_SIDE_MARGIN_VP: number = 12;

/** 悬浮工具条的栏体宽度（vp）＝窗口宽 − 左右各让 TOOLBAR_SIDE_MARGIN_VP。 */
export function toolbarBarWidthVp(ui: UIContext, winWidthPx: number): number {
  // winWidthPx 由 EntryAbility 在 setWindowLayoutFullScreen 的 promise 里写入，
  // 早于该回调的帧读到 0 → 宽度不能是负数，钳到 0 让系统按默认档画。
  return Math.max(0, ui.px2vp(winWidthPx) - 2 * TOOLBAR_SIDE_MARGIN_VP);
}

/**
 * 顶栏自身高度（vp，不含状态栏）。73 实测自已删除的原生通道（titleMode=Full + 28vp 大标题，
 * TitleBar bounds [0,132][1320,378] → 246px ÷ 3.375 = 72.9vp）。
 * 现用 HDS + titleMode=MINI 的栏底在 y=320（188px = 55.7vp），本常量未随之改小 → 静止态首行比栏底多留约 17vp。
 */
export const SYSTEM_TITLE_BAR_VP: number = 73;

/**
 * HDS MINI 收缩态顶栏的实体高度（vp，不含状态栏）：真机栏体 [0,132][1320,320] → 188px ÷ 3.375 ≈ 55.7vp。
 * 顶栏覆盖在内容之上，算「栏底之下」要用它 + 状态栏，见 barBottomVp。
 */
export const HDS_TITLE_BAR_VP: number = 56;

export function topInsetVp(ui: UIContext, safeTopPx: number): number {
  // 标题栏压在内容上（NavBarContent bounds 从 y=132 起），所以 inset = 状态栏 + 栏自身高度。
  return ui.px2vp(safeTopPx) + SYSTEM_TITLE_BAR_VP;
}

/**
 * 顶栏栏底相对**屏幕顶**的偏移（vp）＝状态栏 + HDS 栏体 ≈ 95vp（真机 321px）。
 * 下拉刷新的自定义揭示区从 y=0（屏幕顶）起算而不是从内容区顶（132）起算 —— 实测揭示区高度 h 与指示器
 * 顶端满足 ring_top = h − 121（End 对齐），h 小时指示器会落在标题行；所以要么按这个偏移顶下去，
 * 要么内容会出现在标题上方。
 */
export function barBottomVp(ui: UIContext, safeTopPx: number): number {
  return ui.px2vp(safeTopPx) + HDS_TITLE_BAR_VP;
}

/**
 * 下拉刷新指示器（只有一个转圈）的直径 vp。
 * 指示器是画在列表**之上**的浮层，且「栏底—列表首行」的缝未超过它时透明度为 0，
 * 所以它不会被列表或顶栏压住，尺寸不再受静止空档（≈17vp）限制，按常见下拉转圈取 24。
 * 刷新中的保持位移由 refreshOffset 决定（真机实测 cardTop 恒 701px → 缝 380px ≈ 113vp），
 * 与 Refresh 的 builder 高度无关，所以放大到 24 也不会在刷新中被挤进顶栏。
 */
export const REFRESH_INDICATOR_VP: number = 24;

export function bottomInsetVp(ui: UIContext, safeBottomPx: number): number {
  return ui.px2vp(safeBottomPx) + SYSTEM_TAB_BAR_VP + PILL_BOTTOM_GAP_VP + CONTENT_GAP_VP;
}

/**
 * 二级页（HdsNavDestination）内容让位量的两半，分别挂在两个节点上 —— 这点是实测出来的：
 *
 * 顶＝barBottomVp（状态栏 + 栏体 ≈ 95vp），**只能挂在内容容器上**。
 * 挂在 HdsNavDestination 自己的 .padding() 上会把顶栏一起推下去（模拟器实测：栏体从
 * [0,0][1256,332] 变成 [0,332][1256,664]，标题栏整条跑到内容里，页顶只剩空白 + 一个飘在
 * 列表上的返回键）。二级页顶栏要 avoidLayoutSafeArea: true，实测该档位栏体从 y=0 画起
 * （含状态栏带，共 332px），所以内容要让满 95vp 才接得上栏底。
 * 反面档 avoidLayoutSafeArea: false：栏体高 195px 却仍从 y=0 画起，标题与状态栏时钟叠字。
 *
 * 底＝subPageBottom，挂在 HdsNavDestination 上是安全的（底部 padding 不动顶栏）：
 * 二级页**没有**悬浮 TabBar —— 底栏在 Index.bodyContent() 里，属于 HdsNavigation 的内容区，
 * 而 mode(Stack) 下 push 的 NavDestination 会整块替换内容区。模拟器实测两条独立证据：
 * ① dump 里 NavDestination [0,137][1256,2760]、NavDestinationContent 到 2424，且全树无 Tab 标签节点；
 * ② 一级页「更多」在 y=2560 横切亮度 25..30 且有图标尖峰，二级页「命令行工具」同带恒 0。
 * 所以这里只让满安全区 + 一个小间隙，不再叠 SYSTEM_TAB_BAR_VP + PILL_BOTTOM_GAP_VP
 * （那是本注释前一版「TabBar 在二级页依然浮着」的误判留下的，多占 68vp 空白；
 *   若将来把底栏挪到 NavDestination 之外，需把这 68vp 加回来）。
 */
export function subPageBottom(ui: UIContext, safeBottomPx: number): Padding {
  const bottom: number = ui.px2vp(safeBottomPx) + PILL_BOTTOM_GAP_VP;
  const inset: Padding = { bottom: bottom };
  return inset;
}
