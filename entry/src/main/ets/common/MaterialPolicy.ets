import { hilog } from '@kit.PerformanceAnalysisKit';
import { uiMaterial } from '@kit.ArkUI';
import { hdsMaterial, SystemMaterialParams, ScrollEffectType, ScrollEffectOptions,
  TitleBarStyleOptions, HdsNavigationTitleBarOptions, HdsNavigationTitle, TitleBarContentOptions,
  HdsNavigationTitleStyle, HdsTitleBarContentStyle, HdsNavigationTitleBarStyle,
  HdsNavigationBackgroundStyle, TitleSize, BlurStrategy
} from '@kit.UIDesignKit';

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

/** 弹窗/抽屉/Toast 点位的材质开关：false 时这些点位不下发 systemMaterial。顶/底栏按 D7 已无回退分支，不受本开关影响 */
export const USE_SYSTEM_CHROME: boolean = true;

export function useSystemChrome(): boolean {
  return USE_SYSTEM_CHROME && isImmersiveSupported();
}

/**
 * 裸 `Button`（Acl「重置为默认」/「+」，Terminal 加载日志/清空/发送）是否下发组件级材质。
 * 官方《组件适配沉浸光感》口径：Button 属"按钮与选择类"白名单，`ImmersiveOptions` 的
 * interactive（交互形变）+ lightEffect（点光源）"替代组件默认的按压态和悬浮态效果"——
 * 即翻 true 后 ArkUI 原生按压态（`Button.stateEffect`）会被光感反馈顶替，这是设计行为不是 bug。
 * buttonMaterial() 已带 interactive:true + lightEffect，符合官方参数通道。
 * 2026-09-30 置 true 待机主真机验证光感观感；不满意翻回 false 即回到原生按压态。
 */
export const MATERIAL_ON_PLAIN_BUTTON: boolean = true;

/**
 * 材质独占模式（2026-09-30 真机轮结论）：官方 Button 小节第三条——"配置沉浸光感但**未设置**
 * buttonStyle、backgroundColor 等颜色相关属性且未设置材质颜色时，默认生效 Button 主题色的材质样式"。
 * 真机实测（16:10 构建）不透明 `button_normal` 底色压住材质层 → 只剩内建按压态变灰、无点光源与形变。
 * true = 这 5 颗裸按钮不下发 backgroundColor（Optional 重载，common.d.ts:17657，@since 18），
 * 让材质+lightEffect 成为唯一按压反馈；false = 回到 V1（语义底色 + 材质同挂，仅静态无光感）。
 *
 * 注意两条编译器/运行时事实（16:18 崩溃轮取证）：
 * ① stateStyles 的 opacity 蒙层**从未生效过**——编译产物里 `visualState("normal"/"pressed")` 之间
 *    没有任何属性调用（对比 16:10 版 debug 缓存），「按压变灰」一直来自 Button.stateEffect 内建按压态；
 *    该字面量 stateStyles 属于无效但无害的遗留，保留以维持源码与旧版一致。
 * ② stateStyles 值里**不能放函数调用**——ArkTS 编译器的 DSL 转换会把 `{ opacity: fn() }` 错译成
 *    `Button.fn()`（组件上不存在该方法）→ 运行时 "undefined is not callable" JSCrash（Terminal.ts:203）。
 */
/**
 * 材质独占模式 → **已判死，恒 false**（2026-09-30 真机 + 官方 FAQ 双重裁定）：
 * 《沉浸光感常见问题》「组件不在沉浸光感生效范围」——全页面生效的只有弹窗类/PromptAction/Slider/
 * Toggle/Select；**其余组件（含 Button）仅在 Navigation/NavDestination 标题栏或底部 TabBar 中生效**。
 * Acl/Terminal 的按钮在 NavDestination 内容区 → 真机日志实证
 * `Material inactive: out of scope. Use component in navigation title bar or Tabbar.`（Ace 域 WARN），
 * 材质整体不渲染（THIN/materialColor/interactive/lightEffect 全部无效，静止态回落系统默认蓝 #0A59F7）。
 * 官方解决措施原文：「可改用 backgroundColor 等通用属性替代材质效果」→ 本开关只保留 false 语义
 * （语义底色 + 原生按压态）。若未来系统放宽 scope 再翻 true 复测。
 */
export const PLAIN_BUTTON_MATERIAL_ONLY: boolean = false;

/**
 * Terminal 底部工具条探针（2026-09-30 机主授权）：把 TextInput + 发送按钮包进单页签 Tabs 的
 * 自定义底栏（barPosition: End），落入官方《沉浸光感常见问题》认定的组件级材质生效区
 * （Navigation/NavDestination 标题栏或底部 TabBar）。发送按钮在此区域内不再下发 backgroundColor，
 * 材质改挂 plainButtonMaterial（THIN + 半透明 materialColor + interactive + lightEffect），
 * 让光感+形变有机会成为唯一按压反馈。true=探针；false=回到普通 Column 布局（语义底色 + 原生按压态）。
 * 「加载日志/清空」两颗按钮保留在内容区不动，作为 out-of-scope 对照组。
 */
export const TERMINAL_TABBAR_TOOLBAR: boolean = true;

/**
 * Acl 底部工具条（2026-09-30 机主下达「同步修改」）：照搬 Terminal 已被真指确认的 TabBar 包裹方案
 * —— TextInput + 添加按钮进单页签 Tabs 自定义底栏，「重置为默认」留在内容区当对照组。
 * 独立开关而非复用 Terminal 的：两页的光感手感要分别真指判定，任一页要回退不该带走另一页。
 * true=TabBar 包裹；false=原 Column 普通布局（语义底色 + 原生按压态）。
 */
export const ACL_TABBAR_TOOLBAR: boolean = true;

/**
 * 二级页工具条走系统悬浮底栏通道（2026-09-30 机主「试试方案 A」）。
 * 背景：ACL/Terminal 的工具条只是被包进「单页签 Tabs 的自定义底栏」拿进材质生效区，
 * 但那台 Tabs **从没接 barOverlap/barFloatingStyle** —— 生效区里有两条通道，
 * 首页胶囊走的是系统 barFloatingStyle.systemMaterial（REGULAR + 阴影 + 光感，真透色），
 * 这两页走的是控件自身 `.systemMaterial()`（通用容器在 state=DEFAULT 零像素，见 U3），
 * 所以观感是"近白膜 + 阴影"而非透色胶囊。本开关把工具条改挂第一条通道，与首页同源。
 * true=悬浮材质胶囊（barOverlap + barFloatingStyle）；false=原不重叠的满宽栏体。
 * 与 TOOLBAR 开关独立：包进 Tabs 是前提，悬浮化是可退的一步。
 */
export const ACL_TABBAR_FLOATING: boolean = false;
export const TERMINAL_TABBAR_FLOATING: boolean = false;

/**
 * 方案 B（2026-09-30 机主裁定）：工具条搬回页面内容区，底部 Stack 浮层挂 `backgroundEffect`
 * （{radius:60, saturation:1.4} 不加 color —— 与原生顶栏被证实的档同一配方，透色且严格止于栏矩形），
 * 全宽模糊条，黑卡从条下穿过。离开官方「生效区」→ 真机 lightEffect/interactive 拿不到
 * （内容区组件材质 inert，真机轮 3 三证闭环），换来表面色可调 + 不做胶囊。
 * true 优先走浮层分支；false 落回 TABBAR_TOOLBAR / FLOATING 的 TabBar 包裹老路径（仍可退）。
 */
export const ACL_TOOLBAR_OVERLAY: boolean = false;
export const TERMINAL_TOOLBAR_OVERLAY: boolean = false;

/**
 * 方案 B overlay 工具条控件表面色（2026-09-30 探针结论）：语义令牌 button_normal 实为 **#0C000000**
 * （4.7% 透明黑，dumpLayout backgroundColor 字段实证，顶栏/底栏三控件同值）—— 在白页底上读作浅灰
 * （255×0.953≈243，与 V1 历次量数吻合），但 overlay 工具条浮在黑卡模糊条上时只加 2~3 级亮度，
 * 观感即「底色消失」。内容区无材质膜、表面色可调（方案 B 的既得代价）→ overlay 档给半透明白，
 * 在暗色模糊条上读作亮胶囊；翻回 $r('sys.color.ohos_id_color_button_normal') 即恢复旧观感。
 */
export const OVERLAY_CONTROL_BG: ResourceColor = '#99FFFFFF';

export function plainButtonMaterialOnly(): boolean {
  return usePlainButtonMaterial() && PLAIN_BUTTON_MATERIAL_ONLY;
}

/**
 * 工具条控件阴影档（2026-09-30 机主裁定「手挂小阴影」）：applyShadow 是布尔、不可调大小，
 * 返回键同款软阴影在 990px 宽胶囊上横向铺满整条栏（实测页底被压暗 9 级、y2590 全宽 246 平台），
 * 读成「整条栏底下垫了一层灰」的颜色分层。true=材质不带影、控件手挂 .shadow()
 * （radius 8 / offsetY 2 / #14000000，扩散收窄）；false=回到材质层 applyShadow（旧观感）。
 * plainButtonMaterial 的 applyShadow 跟随本开关；控件侧 .shadow() 也按它下发。
 */
export const TOOLBAR_MANUAL_SHADOW: boolean = true;

/** 工具条控件手挂小阴影（单一出口，Acl/Terminal 四处共用；radius 8 / offsetY 2 / 8% 黑，扩散收窄不压整栏）。 */
export function toolbarControlShadow(): ShadowOptions {
  return { radius: 8, color: '#14000000', offsetY: 2 };
}

/** 零影对象：开关关或非 tabbar 档下发，保持 .shadow() 属性链完整（等价于不画影）。 */
export const NO_TOOLBAR_SHADOW: ShadowOptions = { radius: 0, color: Color.Transparent, offsetY: 0 };

/**
 * 裸按钮材质档（Terminal TabBar 探针在用）：**不带 materialColor**——真机 TabBar 生效区内 8%/20% 两档
 * 均零像素信号（膜色不可调），backgroundColor 下发也被膜盖住（实测仍 241）。
 * applyShadow **true**（2026-09-30 机主复验轮）：返回键 = 近白膜 + 软阴影，阴影是它「样式」的一半，
 * 之前 false 导致按钮在浅页底上糊成隐形。THIN 膜浅色实测 241~255 ≈ 返回键正常态 252。
 * interactive+lightEffect 是光感与形变的唯一载体，摘材质=效果全没（机主已判）。
 */
export function plainButtonMaterial(isDark: boolean): uiMaterial.ImmersiveMaterial {
  const lightEffect: uiMaterial.LightEffectOptions = { color: $r('sys.color.ohos_id_color_emphasize') };
  const options: uiMaterial.ImmersiveOptions = {
    style: uiMaterial.ImmersiveStyle.THIN,
    // 阴影改由控件侧 .shadow() 手挂（TOOLBAR_MANUAL_SHADOW），材质层大扩散影在宽胶囊上读成整条分层
    applyShadow: !TOOLBAR_MANUAL_SHADOW,
    interactive: true,
    lightEffect: lightEffect
  };
  return new uiMaterial.ImmersiveMaterial(options);
}

export function usePlainButtonMaterial(): boolean {
  return useSystemChrome() && MATERIAL_ON_PLAIN_BUTTON;
}

/**
 * 底栏材质档位。EXQUISITE→THICK 档在本机实测过白：同一次 fling 前后，栏外内容带帧间 MAD=8.11、
 * 栏内仅 2.55（透色响应约 31%），栏内均值 247/255，观感即"一颗不透明白胶囊"；REGULAR 档透色响应约 78%。
 */
const TAB_BAR_STYLE: uiMaterial.ImmersiveStyle = uiMaterial.ImmersiveStyle.REGULAR;

/**
 * 底栏材质。「光感」= 光感交互反馈，SDK 里由 lightEffect 提供，且文档明确写着
 * "Effective only when interactive is set to true"（@ohos.arkui.uiMaterial.d.ts:416-428），
 * 而 interactive 默认 false、lightEffect 默认 undefined —— 只设 style 时底栏静动无反馈，
 * 观感即"看不出材质"。两者必须显式开。
 */
export function tabBarMaterial(): uiMaterial.ImmersiveMaterial {
  // 光感色跟底栏选中态同源（sys.color.ohos_id_color_emphasize），白光在浅色底上几乎看不出来
  const lightEffect: uiMaterial.LightEffectOptions = { color: $r('sys.color.ohos_id_color_emphasize') };
  const options: uiMaterial.ImmersiveOptions = {
    style: TAB_BAR_STYLE,
    applyShadow: globalLevelName() !== 'SMOOTH',
    interactive: true,
    lightEffect: lightEffect
  };
  return new uiMaterial.ImmersiveMaterial(options);
}

/**
 * HDS（@kit.UIDesignKit）顶栏通道。D7 后顶栏只有这一条路径，没有分叉出口。
 *
 * 版本分层（本机 SDK 声明实测）：
 *   - HdsNavigation / TitleBarStyleOptions / ScrollEffectOptions：@since 5.1.0(18)
 *   - avoidLayoutSafeArea、ScrollEffectType.GRADIENT_BLUR：@since 6.0.0(20)
 *   - SystemMaterialParams、style.systemMaterialEffect、hdsMaterial 整个模块：@since 6.1.0(23)
 * @since 越过 compatible 6.0.1(21) 不影响编译（这些 @23 字段本身不产生 WARN；
 * 存量的 `barFloatingStyle` @26 vs compatible WARN 是底栏那条线，机主已裁定 compatible 保持 21）。
 * 按 D7 只适配鸿蒙 7.1+，低于 23 的设备不再分叉。
 *
 * `hdsTitleBarStyle(isDark, subPage)` = GRADIENT_BLUR 提供越过栏底的渐隐模糊带（实测 MaskBlur 到 y=428，栏底 320）；
 * 幕布背景色按深浅色主题分档（见函数内注释与 spec §5.5）；`subPage` 只决定幕布模糊开关（见 blurStrategy 注释）。
 */
export function hdsTitleBarStyle(isDark: boolean, subPage: boolean): TitleBarStyleOptions {
  const effect: SystemMaterialParams = {
    materialType: hdsMaterial.MaterialType.ADAPTIVE,
    materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
  };
  const scrollOpts: ScrollEffectOptions = {
    enableScrollEffect: true,
    scrollEffectType: ScrollEffectType.GRADIENT_BLUR
  };
  // HDS 默认 mainTitleColor 不随深色翻转（深色下字形纯黑压黑栏），必须用语义令牌显式翻转；
  // originalStyle 与 scrollEffectStyle 两档都要给，否则滚动后标题颜色回落。
  const titleStyle: HdsNavigationTitleStyle = {
    mainTitleColor: $r('sys.color.ohos_id_color_text_primary')
  };
  const contentStyle: HdsTitleBarContentStyle = { titleStyle: titleStyle };
  const originalBarStyle: HdsNavigationTitleBarStyle = { contentStyle: contentStyle };
  // 幕布背景按「主题 + 页型」分档（轮 8 十二档矩阵 C6/C7，spec §5.5）：HDS 默认幕布自带一层浅色着色，
  // 深色下压不住（滚动后顶栏带 mean 111）；一级页浅色下那层着色正是机主签核态的来源，不设字段才逐像素保持（0.000）。
  // 二级页反过来：页底是纯白 255，默认幕布把滚动后的栏带压成 245.2~252.0 的渐变（MAD 7.36 = 10 级台阶，肉眼可辨），
  // 而 Transparent 在十二档里是比默认幕布更亮的那一档（244.77 vs 240.55）→ 只在二级页下发，一级页根栏留空不动。
  const scrollBg: HdsNavigationBackgroundStyle = { backgroundColor: Color.Transparent };
  const scrollBarStyle: HdsNavigationTitleBarStyle = (isDark || subPage)
    ? { contentStyle: contentStyle, backgroundStyle: scrollBg }
    : { contentStyle: contentStyle };
  const style: TitleBarStyleOptions = {
    scrollEffectOpts: scrollOpts,
    systemMaterialEffect: effect,
    originalStyle: originalBarStyle,
    scrollEffectStyle: scrollBarStyle
  };
  // 二级页幕布模糊要两个条件同时成立，缺一不可。量法：同一串文字在「栏带内」与「带外」各截一帧，
  // 取其 dump 矩形算边缘能量 = mean|Δlum|/px（避开返回键与标题的 x 档）。模拟器 1256×2760。
  // ① blurStrategy 要显式 ENABLE。默认 ADAPTIVE（"按系统策略自适应"）在 HdsNavDestination 上被降级成不模糊：
  //    ADAPTIVE 档「可用设备」带内 7.33~9.29、最暗像素 0（= 仍锐利）；
  //    ENABLE + bind 后「刷新」带内 0.62、最暗 216，带外 22.71、最暗 57 → 97% 高频细节消失，
  //    与一级页根栏同一签名（根栏「清空数据」带内 0.25 vs 带外 8.53，也是 97%）。
  // ② 内容侧的 Scroller 要 bindToScrollable 交给 HdsNavDestination（见 TeamDevice build 尾部）。
  //    只给 ENABLE 不 bind 实测 8.60、最暗 1 = 仍锐利，说明栏不知道该跟着谁渐隐。
  // 根栏不给这个字段（继续走 ADAPTIVE）：它本来就模糊，动它会把 R36 已签核的首页帧改样。
  // 这里用条件赋值而不是 `subPage ? ENABLE : undefined`：显式写 undefined 与不写该键实测同帧（见 ledger 追加修订 8），
  // 但条件赋值不留一个恒为 undefined 的键，读起来更确定。
  if (subPage) {
    style.blurStrategy = BlurStrategy.ENABLE;
  }
  return style;
}

export function hdsTitleBarOptions(mainTitle: ResourceStr, isDark: boolean,
  size: TitleSize, subPage: boolean): HdsNavigationTitleBarOptions {
  // 主标题字号：HDS 只给 TITLE_S（小号）/ TITLE_ML（中等偏大）两档，只在 MINI 模式生效（我们正是 MINI）。
  // 真机实测（SN 5MT0226114015018，density 3.375，量 "H" cap 高）：TITLE_S ≈ 20fp（cap 49px = 14.5vp）、
  // TITLE_ML ≈ 26fp（cap 64px = 19.0vp），比值 1.30。「不设字段」与显式 TITLE_S 逐像素相同（标题宽都是 395px），
  // 即 HDS 的 MINI 默认档就是 TITLE_S。一级页（四个 Tab）按规范取中大号 → TITLE_ML；
  // 二级页栏内要让位给返回键，取 TITLE_S。
  const title: HdsNavigationTitle = { mainTitle: mainTitle, mainTitleSize: size };
  const content: TitleBarContentOptions = { title: title };
  const options: HdsNavigationTitleBarOptions = {
    // 二级页（HdsNavDestination）必须为 true：模拟器 1256×2760（density 3.5）实测 true 时栏体从 y=0 画起
    // 共 332px、标题落在 193..275（状态栏时钟之下）；false 时栏体只有 195px 却仍从 y=0 画起，
    // 标题与状态栏时钟叠字，不可用。代价是内容原点被抬到 y=0，故内容要自己让满 barBottomVp（见 Immersive）。
    // 一级页（HdsNavigation 系统标题栏）实测本机（API 26）该字段无效果，栏体仍从状态栏下缘 y=132 起，
    // 与原生通道试 expandSafeArea 的结果一致，属平台约束（见 spec §5.2）。保留为前瞻点位。
    avoidLayoutSafeArea: true,
    style: hdsTitleBarStyle(isDark, subPage),
    content: content
  };
  return options;
}

/** 半模态抽屉材质：detent 抽屉比浮层更需要薄档，避免遮挡内容透色过度 */
export function sheetMaterial(): uiMaterial.ImmersiveMaterial {
  const options: uiMaterial.ImmersiveOptions = {
    style: uiMaterial.ImmersiveStyle.REGULAR,
    applyShadow: false
  };
  return new uiMaterial.ImmersiveMaterial(options);
}

/** 确认弹窗材质：实测 state=DEFAULT 下 showDialog 不自动获得材质，需显式设置；浮层用厚档保文字对比度 */
export function dialogMaterial(): uiMaterial.ImmersiveMaterial {
  const options: uiMaterial.ImmersiveOptions = {
    style: uiMaterial.ImmersiveStyle.THICK,
    applyShadow: false
  };
  return new uiMaterial.ImmersiveMaterial(options);
}

/**
 * 中性小面积浮层材质（CommonMethod.systemMaterial，@since 26.0.0）：中性按钮 + Acl/Terminal 底部输入框共用这一档。
 * SDK 文档称本属性接管 backgroundColor / borderColor / shadow，**但本机（API 26 模拟器）实测不接管**：自设底色照常生效，
 * 反过来删掉底色会让中性胶囊在浅灰幕布上整体消失（剖面 235 vs 236，落差 1）→ 定稿是**语义底色 + 材质同时下发**（234 vs 222）。
 * **模拟器上组件级材质零渲染（V2/V3 两轮实验）**：删自设底色后输入框 243→255（胶囊消失、Button 裸露成系统蓝 #FF0A59F7），
 * 把着色改放进材质层的 `materialColor` 也仍是 255.00（`$r()` 与字面量 `'#0C000000'` 两种写法各测一轮，逐像素相同）
 * → 材质在这类控件上没有任何可测像素信号，静止观感完全由语义底色决定；按压光感另有一条独立死路（合成触摸 MAD=0.00）。
 * 结论：这两处的材质效果**只能上真机用真指判定**，模拟器继续翻条件是量渲染器不是量设计。
 * REGULAR 档：这类控件面积小、文字本来就是语义前景，厚档会把底色推白、对比度反而过冲。
 * 光感（lightEffect）与底栏同源色；interactive 必须显式开，否则静动无反馈（见 tabBarMaterial 注释）。
 */
export function buttonMaterial(): uiMaterial.ImmersiveMaterial {
  const lightEffect: uiMaterial.LightEffectOptions = { color: $r('sys.color.ohos_id_color_emphasize') };
  const options: uiMaterial.ImmersiveOptions = {
    style: uiMaterial.ImmersiveStyle.REGULAR,
    applyShadow: false,
    interactive: true,
    lightEffect: lightEffect
  };
  return new uiMaterial.ImmersiveMaterial(options);
}
