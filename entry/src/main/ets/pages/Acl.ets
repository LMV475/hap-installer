import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { FrameCallback } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { motion } from '@kit.MultimodalAwarenessKit';
import { DEFAULT_ACL, loadAclList, saveAclList } from '../common/AclDefaults';
import { HdsNavDestination } from '@kit.UIDesignKit';
import { subPageBottom, barBottomVp, TOOLBAR_BAR_HEIGHT_VP, toolbarBarWidthVp } from '../common/Immersive';
import { hdsTitleBarOptions, buttonMaterial, useSystemChrome, usePlainButtonMaterial, plainButtonMaterialOnly, plainButtonMaterial, ACL_TABBAR_TOOLBAR, ACL_TABBAR_FLOATING, ACL_TOOLBAR_OVERLAY, tabBarMaterial, OVERLAY_CONTROL_BG, TOOLBAR_MANUAL_SHADOW, toolbarControlShadow, NO_TOOLBAR_SHADOW, LIGHT_EFFECT_WHITE, chromeAttributesSupported, ButtonChromeModifier, TextInputChromeModifier, FloatingTabBarModifier, TitleSize } from '../common/MaterialPolicy';

/** ACL 权限列表页（对应 Flutter acl_page.dart，terminal 风格） */
@Component
export struct Acl {
  @Consume('navStack') pathStack: NavPathStack;
  @StorageLink('isDark') isDark: boolean = false;
  @StorageLink('safeTopPx') safeTopPx: number = 0;
  @StorageLink('safeBottomPx') safeBottomPx: number = 0;
  @StorageLink('winWidthPx') winWidthPx: number = 0;
  @StorageLink('isLeftHanded') isLeftHanded: boolean = false;
  @State aclList: string[] = [];
  @State input: string = '';
  private scroller: Scroller = new Scroller();

  private ctx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  aboutToAppear(): void {
    loadAclList(this.ctx()).then((list: string[]): void => {
      this.aclList = list;
    });
    this.initHandedness();
  }

  aboutToDisappear(): void {
    try {
      motion.off('holdingHandChanged');
    } catch (_e) {
      // device not supported or subscription not active
    }
  }

  private initHandedness(): void {
    try {
      if (!canIUse('SystemCapability.MultimodalAwareness.Motion')) {
        hilog.warn(0x0000, 'Acl', 'Device does not support Motion capability');
        return;
      }
      motion.on('holdingHandChanged', (status: motion.HoldingHandStatus): void => {
        AppStorage.set<boolean>('isLeftHanded', status === motion.HoldingHandStatus.LEFT_HAND_HELD);
      });
    } catch (e) {
      hilog.warn(0x0000, 'Acl', 'holdingHandChanged not supported: %{public}s', (e as BusinessError).message);
    }
  }

  private scrollBottom(): void {
    const cb: FrameCallback = {
      onFrame: (_t: number): void => {
        if (this.aclList.length > 0) {
          this.scroller.scrollToIndex(this.aclList.length - 1);
        }
      },
      onIdle: (): void => {}
    };
    this.getUIContext().postFrameCallback(cb);
  }

  private addAcl(): void {
    const text: string = this.input.trim();
    if (text.length === 0) {
      return;
    }
    this.aclList.push(text);
    this.input = '';
    saveAclList(this.ctx(), this.aclList);
    this.scrollBottom();
  }

  private resetDefault(): void {
    this.aclList = DEFAULT_ACL.slice();
    saveAclList(this.ctx(), this.aclList);
    this.scrollBottom();
  }

  @Builder
  topToolbar() {
    Row({ space: 8 }) {
      Blank()
      Button('重置为默认')
        .fontSize(13)
        .height(40)
        .borderRadius($r('sys.float.corner_radius_level8'))
        .backgroundColor(plainButtonMaterialOnly() ? undefined : $r('sys.color.ohos_id_color_button_normal'))
        .fontColor($r('sys.color.ohos_id_color_emphasize'))
        // .systemMaterial（@since 26）挪进 ButtonChromeModifier 按能力位下发（见 MaterialPolicy 低版本兼容层）
        .attributeModifier(new ButtonChromeModifier(
          plainButtonMaterialOnly() ? plainButtonMaterial(this.isDark)
            : usePlainButtonMaterial() ? buttonMaterial() : undefined, undefined))
        .stateStyles({ normal: { opacity: 1 }, pressed: { opacity: 0.6 } })
        .accessibilityText('重置为默认权限列表')
        .onClick((): void => { this.resetDefault(); })
    }
    .width('100%')
    .padding({ left: $r('sys.float.padding_level6'), right: $r('sys.float.padding_level6'), top: 12, bottom: 12 })
  }

  @Builder
  aclStack() {
    List({ space: 4, scroller: this.scroller }) {
      ForEach(this.aclList, (item: string, idx: number) => {
        ListItem() {
          Text(item)
            .fontSize(13)
            .fontColor(Color.White)
            .fontFamily('monospace')
            .width('100%')
            .accessibilityText(item)
        }
      }, (item: string, idx: number): string => idx + '_' + item)
    }
    .width('100%')
    .layoutWeight(1)
    // 悬浮化后 TabContent 铺满整盒（barOverlap(true)），黑卡伸到胶囊底下。
    // 让位用 contentEndOffset 而不是加大 padding（实测）：padding 会同时**裁掉视口**，
    // 行永远不会画进胶囊区 → 胶囊底下只有静止卡底，帧间 MAD 恒 0.000，透色根本无从发生；
    // contentEndOffset 只延长可滚范围，视口仍是满高，行会从膜下滑过。
    // 方案 B 浮层同要这一让位（条盖在 List 满高视口上）。
    .padding(12)
    .contentEndOffset(ACL_TOOLBAR_OVERLAY || ACL_TABBAR_FLOATING ? TOOLBAR_BAR_HEIGHT_VP : 0)
    // 回弹对齐首页 Scroll；List 默认只在内容超一屏时回弹，所以要显式 alwaysEnabled
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .scrollBar(BarState.Off)
    // 黑卡底色按主题分档：深色下页底 sys.color.ohos_id_color_background 实测纯 0，硬编码 Color.Black
    // 会让卡与页底同值糊成一片 → 深色改用与 HapCard 同一张卡面令牌（深色实测 48）；
    // 浅色保持纯黑（终端观感 + 白字对比度都是签核态，不动）。
    .backgroundColor(this.isDark ? $r('sys.color.ohos_id_color_card_bg') : Color.Black)
    .borderRadius(16)
    .clip(true)
  }

  /**
   * 工具条三档：'overlay'＝页面内容区底部浮层（方案 B，Row 挂 backgroundEffect 模糊条）；
   * 'tabbar'＝单页签 Tabs 自定义底栏（生效区，控件材质膜、表面色不可调）；'inline'＝普通列内（原形态）。
   * 根据握持方向（isLeftHanded）自动调换输入框与按钮顺序：
   * 右手→输入框在左、按钮在右；左手→按钮在左、输入框在右。
   */
  @Builder
  cmdBar(mode: 'overlay' | 'tabbar' | 'inline') {
    Row({ space: 8 }) {
      if (this.isLeftHanded) {
        this.cmdButton(mode)
        this.cmdInput(mode)
      } else {
        this.cmdInput(mode)
        this.cmdButton(mode)
      }
    }
    .width('100%')
    .padding(mode === 'inline'
      ? { top: 16, bottom: 16 }
      : { left: $r('sys.float.padding_level6'), right: $r('sys.float.padding_level6'), top: 16, bottom: 16 })
    // 方案 B 的模糊条：与原生顶栏被证实的档同一配方（radius 60 + saturation 1.4，不加 color），
    // 透色且严格止于栏矩形；blur 半径单位 vp，60 在 76vp 高的条上是重模糊，量数后再调。
    .backgroundEffect(mode === 'overlay' ? { radius: 60, saturation: 1.4 } : undefined)
  }

  @Builder
  cmdInput(mode: 'overlay' | 'tabbar' | 'inline') {
    TextInput({ text: this.input, placeholder: '输入权限名，如 ohos.permission.XXX' })
      .layoutWeight(1)
      .height(44)
      .borderRadius(22)
      // 与 Terminal 探针同结论（2026-09-30 真机）：生效区内 TextInput 材质真实渲染，但内建默认底色
      // 要用 Color.Transparent 才剥得掉（undefined 剥不掉），剥完与添加按钮逐像素同色。
      // overlay/inline 在内容区，膜不接管，语义底色可调且可用；overlay 浮在暗色模糊条上，
      // button_normal（#0C000000 透明黑）近乎隐形 → 用半透明白（见 MaterialPolicy.OVERLAY_CONTROL_BG）。
      .backgroundColor(mode === 'tabbar' ? Color.Transparent
        : (mode === 'overlay' ? OVERLAY_CONTROL_BG : $r('sys.color.ohos_id_color_button_normal')))
      // 输入框是"编辑位"不是"操作位"（机主 2026-10-01）：同膜同影，仅光源换白档
      // 材质 + 手挂小阴影一并交给 TextInputChromeModifier，**内部顺序仍是材质 → 小阴影**，
      // 与改前链上 .systemMaterial() → .shadow() 的先后一致（低版本只跳材质，阴影照发）。
      // 手挂小阴影（TOOLBAR_MANUAL_SHADOW）：radius 8 / offsetY 2 / 8% 黑，替代材质层大扩散 applyShadow；
      // 关闭或非 tabbar 档下发零影对象（radius 0 + 透明）保持属性链完整
      .attributeModifier(new TextInputChromeModifier(
        mode === 'tabbar' ? plainButtonMaterial(this.isDark, LIGHT_EFFECT_WHITE)
          : (useSystemChrome() ? buttonMaterial() : undefined),
        TOOLBAR_MANUAL_SHADOW ? toolbarControlShadow() : NO_TOOLBAR_SHADOW))
      .stateStyles({ normal: { opacity: 1 }, pressed: { opacity: 0.6 } })
      .onChange((v: string): void => { this.input = v; })
      .onSubmit((): void => { this.addAcl(); })
      .accessibilityText('权限输入框')
      .transition(TransitionEffect.opacity(0)
        .combine(TransitionEffect.scale({ x: 0.9, y: 0.9 }))
        .animation({ duration: 250, curve: Curve.EaseInOut }))
  }

  @Builder
  cmdButton(mode: 'overlay' | 'tabbar' | 'inline') {
    Button() {
      SymbolGlyph($r('sys.symbol.plus'))
        .fontSize(20)
        .fontColor([$r('sys.color.ohos_id_color_emphasize')])
    }
    .width(44)
    .height(44)
    .borderRadius(22)
    // TabBar 生效区内膜会盖住 backgroundColor，表面色不可调 → 不下发，样式走 plainButtonMaterial 的阴影；
    // overlay 浮在暗色模糊条上，button_normal 透明黑近乎隐形 → 半透明白（OVERLAY_CONTROL_BG）
    // API<26 无材质膜（Button 露出系统蓝底，emphasize 蓝图标蓝底不可见）→ 按 inline 档给语义底色
    .backgroundColor((mode === 'tabbar' && chromeAttributesSupported()) ? undefined
      : (plainButtonMaterialOnly() ? undefined
        : (mode === 'overlay' ? OVERLAY_CONTROL_BG : $r('sys.color.ohos_id_color_button_normal'))))
    .attributeModifier(new ButtonChromeModifier(
      mode === 'tabbar' ? plainButtonMaterial(this.isDark)
        : (plainButtonMaterialOnly() ? plainButtonMaterial(this.isDark) : usePlainButtonMaterial() ? buttonMaterial() : undefined),
      TOOLBAR_MANUAL_SHADOW ? toolbarControlShadow() : NO_TOOLBAR_SHADOW))
    .stateStyles({ normal: { opacity: 1 }, pressed: { opacity: 0.6 } })
    .accessibilityText('添加权限')
    .onClick((): void => { this.addAcl(); })
    .transition(TransitionEffect.opacity(0)
      .combine(TransitionEffect.scale({ x: 0.9, y: 0.9 }))
      .animation({ duration: 250, curve: Curve.EaseInOut }))
  }

  build() {
    HdsNavDestination() {
      if (ACL_TOOLBAR_OVERLAY) {
        // 方案 B：工具条为内容区底部浮层（Stack 底对齐），模糊条全宽，黑卡从条下穿过；
        // 列表视口满高，末行让位走 contentEndOffset（加大 padding 会连视口一起裁掉，见 aclStack 注释）。
        Stack({ alignContent: Alignment.Bottom }) {
          Column({ space: 0 }) {
            this.topToolbar()
            this.aclStack()
          }
          .width('100%')
          .height('100%')
          .padding({ left: $r('sys.float.padding_level6'), right: $r('sys.float.padding_level6'),
            top: barBottomVp(this.getUIContext(), this.safeTopPx) })
          this.cmdBar('overlay')
        }
        .width('100%')
        .height('100%')
      } else if (ACL_TABBAR_TOOLBAR) {
        // 工具条放进单页签 Tabs 的自定义底栏，落入官方认定的组件级材质生效区（底部 TabBar，barPosition: End）；
        // tabBar 必须写直接调用形式 this.cmdBar('tabbar')，箭头包裹会编译合法但运行时渲染空白（Terminal 同坑）。
        Tabs({ barPosition: BarPosition.End, index: 0 }) {
          TabContent() {
            Column({ space: 0 }) {
              this.topToolbar()
              this.aclStack()
            }
            .width('100%')
            .height('100%')
            .padding({ left: $r('sys.float.padding_level6'), right: $r('sys.float.padding_level6'),
              top: barBottomVp(this.getUIContext(), this.safeTopPx) })
          }
          .tabBar(this.cmdBar('tabbar'))
        }
        .scrollable(false)
        .barHeight(TOOLBAR_BAR_HEIGHT_VP)
        .barBackgroundColor(Color.Transparent)
        // 方案 A（2026-09-30）：把工具条改挂首页同一条系统悬浮底栏通道。
        // barFloatingStyle 只在 barOverlap(true) 时生效（Task 8 实测前置条件）；
        // barBottomMargin 0 —— HdsNavDestination 已经用 subPageBottom 把 Tabs 盒整体上移
        // px2vp(safeBottom)+12，与首页胶囊的 barBottomMargin 同高，不必再叠一次。
        // 悬浮栏属性通道（Tabs.barFloatingStyle，@since 26）由 FloatingTabBarModifier 按能力位下发；
        // API<26 拿不到悬浮栏，barOverlap 同步取 false → 回到不重叠的满宽栏体。
        .barOverlap(ACL_TABBAR_FLOATING && chromeAttributesSupported())
        .attributeModifier(new FloatingTabBarModifier({
          barWidth: {
            smallBarWidth: toolbarBarWidthVp(this.getUIContext(), this.winWidthPx),
            mediumBarWidth: toolbarBarWidthVp(this.getUIContext(), this.winWidthPx),
            largeBarWidth: toolbarBarWidthVp(this.getUIContext(), this.winWidthPx)
          },
          barBottomMargin: 0,
          adaptToHandedness: false,
          systemMaterial: tabBarMaterial()
        }))
        .width('100%')
        .height('100%')
      } else {
        Column({ space: 0 }) {
          this.topToolbar()
          this.aclStack()
          this.cmdBar('inline')
        }
        .width('100%')
        .height('100%')
        .padding({ left: $r('sys.float.padding_level6'), right: $r('sys.float.padding_level6'),
          top: barBottomVp(this.getUIContext(), this.safeTopPx) })
      }
    }
    .padding(subPageBottom(this.getUIContext(), this.safeBottomPx))
    // 顶栏要 avoidLayoutSafeArea: true，标题才落在状态栏之下；内容顶让满 barBottomVp（见其注释实测记录）
    .titleBar(hdsTitleBarOptions('ACL 权限列表', this.isDark, TitleSize.TITLE_S, true))
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }
}
