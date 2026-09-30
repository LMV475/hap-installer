import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { FrameCallback } from '@kit.ArkUI';
import { HdcService } from '../common/HdcService';
import { HdsNavDestination, TitleSize } from '@kit.UIDesignKit';
import { subPageBottom, barBottomVp, TOOLBAR_BAR_HEIGHT_VP, toolbarBarWidthVp } from '../common/Immersive';
import { hdsTitleBarOptions, buttonMaterial, useSystemChrome, usePlainButtonMaterial, plainButtonMaterialOnly, plainButtonMaterial, TERMINAL_TABBAR_TOOLBAR, TERMINAL_TABBAR_FLOATING, TERMINAL_TOOLBAR_OVERLAY, tabBarMaterial, OVERLAY_CONTROL_BG, TOOLBAR_MANUAL_SHADOW, toolbarControlShadow, NO_TOOLBAR_SHADOW } from '../common/MaterialPolicy';

/** HDC 命令行终端页（对应 Flutter terminal_page.dart） */
@Component
export struct Terminal {
  @Consume('navStack') pathStack: NavPathStack;
  @StorageLink('isDark') isDark: boolean = false;
  @StorageLink('safeTopPx') safeTopPx: number = 0;
  @StorageLink('safeBottomPx') safeBottomPx: number = 0;
  @StorageLink('winWidthPx') winWidthPx: number = 0;
  @State cmd: string = 'hdc list targets';
  @State results: string[] = [];
  @State loading: boolean = false;
  private scroller: Scroller = new Scroller();

  private ctx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private scrollBottom(): void {
    const cb: FrameCallback = {
      onFrame: (_t: number): void => {
        if (this.results.length > 0) {
          this.scroller.scrollToIndex(this.results.length - 1);
        }
      },
      onIdle: (): void => {}
    };
    this.getUIContext().postFrameCallback(cb);
  }

  private async send(): Promise<void> {
    const text: string = this.cmd.trim();
    if (text.length === 0 || this.loading) {
      return;
    }
    this.loading = true;
    this.results.push('> ' + text);
    try {
      let bare: string = text;
      if (bare.startsWith('hdc ')) {
        bare = bare.substring(4).trim();
      }
      HdcService.startServer(this.ctx().tempDir);
      const out: string = await HdcService.run(bare, this.ctx().tempDir);
      this.results.push(out);
    } catch (e) {
      const err = e as BusinessError;
      this.results.push('Error: ' + err.message);
    }
    this.loading = false;
    this.scrollBottom();
  }

  private loadLog(): void {
    const path: string = this.ctx().tempDir + '/hdc.log';
    try {
      const log: string = fileIo.readTextSync(path);
      this.results = [log];
    } catch (e) {
      const err = e as BusinessError;
      this.results = ['读取日志失败: ' + err.message];
    }
    this.scrollBottom();
  }

  @Builder
  topToolbar() {
    Row({ space: 8 }) {
      Blank()
      Button('加载日志')
        .fontSize(13)
        .backgroundColor(plainButtonMaterialOnly() ? undefined : $r('sys.color.ohos_id_color_button_normal'))
        .fontColor($r('sys.color.ohos_id_color_emphasize'))
        .systemMaterial(plainButtonMaterialOnly() ? plainButtonMaterial(this.isDark) : usePlainButtonMaterial() ? buttonMaterial() : undefined)
        .stateStyles({ normal: { opacity: 1 }, pressed: { opacity: 0.6 } })
        .accessibilityText('加载日志')
        .onClick((): void => { this.loadLog(); })
      Button('清空')
        .fontSize(13)
        .backgroundColor(plainButtonMaterialOnly() ? undefined : $r('sys.color.ohos_id_color_button_normal'))
        .fontColor($r('sys.color.ohos_id_color_emphasize'))
        .systemMaterial(plainButtonMaterialOnly() ? plainButtonMaterial(this.isDark) : usePlainButtonMaterial() ? buttonMaterial() : undefined)
        .stateStyles({ normal: { opacity: 1 }, pressed: { opacity: 0.6 } })
        .accessibilityText('清空输出')
        .onClick((): void => { this.results = []; })
    }
    .width('100%')
    .padding({ top: 4, bottom: 4 })
  }

  @Builder
  logStack() {
    Stack({ alignContent: Alignment.BottomStart }) {
      List({ space: 4, scroller: this.scroller }) {
        ForEach(this.results, (item: string) => {
          ListItem() {
            Text(item)
              .fontSize(13)
              .fontColor(Color.White)
              .fontFamily('monospace')
              .width('100%')
              .accessibilityText(item)
          }
        }, (item: string, idx: number): string => idx + '_' + item.length)
      }
      .width('100%')
      .height('100%')
      // 悬浮化后 TabContent 铺满整盒（barOverlap(true)），日志卡伸到胶囊底下。
      // 让位用 contentEndOffset 而不是加大 padding（实测）：padding 会同时**裁掉视口**，
      // 行永远不会画进胶囊区 → 帧间 MAD 恒 0.000，透色根本无从发生；
      // contentEndOffset 只延长可滚范围，视口仍是满高，行会从膜下滑过。
      // 方案 B 浮层同要这一让位（条盖在 List 满高视口上）。
      .padding(12)
      .contentEndOffset(TERMINAL_TOOLBAR_OVERLAY || TERMINAL_TABBAR_FLOATING ? TOOLBAR_BAR_HEIGHT_VP : 0)
      // 回弹对齐首页 Scroll；List 默认只在内容超一屏时回弹，所以要显式 alwaysEnabled
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .scrollBar(BarState.Off)

      if (this.loading) {
        LoadingProgress()
          .width(16)
          .height(16)
          .color('#88FFFFFF')
          .margin(12)
      }
    }
    .layoutWeight(1)
    .width('100%')
    // 底色按主题分档：深色下页底实测纯 0，硬编码 Color.Black 会让卡与页底糊成一片 →
    // 深色用与 HapCard 同一张卡面令牌（实测 48）；浅色保持纯黑（白字终端观感是签核态）。
    .backgroundColor(this.isDark ? $r('sys.color.ohos_id_color_card_bg') : Color.Black)
    .borderRadius(16)
    .clip(true)
  }

  /**
   * 工具条三档：'overlay'＝页面内容区底部浮层（方案 B，Row 挂 backgroundEffect 模糊条）；
   * 'tabbar'＝单页签 Tabs 自定义底栏（生效区，控件材质膜、表面色不可调）；'inline'＝普通列内（原形态）。
   */
  @Builder
  cmdBar(mode: 'overlay' | 'tabbar' | 'inline') {
    Row({ space: 8 }) {
      TextInput({ text: this.cmd, placeholder: '输入 HDC 命令...' })
        .layoutWeight(1)
        .height(44)
        .borderRadius(22)
        // 探针轮已证 TextInput 在 TabBar 里材质**真实渲染**（深色下 25→43 出现像素信号），
        // 但膜下疑似掺了组件默认底色（同材质按钮 20、输入框 43）→ 生效区内显式清空为 Transparent；
        // overlay/inline 在内容区，膜不接管，语义底色可调且可用；overlay 浮在暗色模糊条上，
        // button_normal（#0C000000 透明黑）近乎隐形 → 用半透明白（见 MaterialPolicy.OVERLAY_CONTROL_BG）。
        .backgroundColor(mode === 'tabbar' ? Color.Transparent
          : (mode === 'overlay' ? OVERLAY_CONTROL_BG : $r('sys.color.ohos_id_color_button_normal')))
        // tabbar 档挂 plainButtonMaterial（THIN+applyShadow+interactive+lightEffect，与发送按钮同份）；
        // overlay/inline 在内容区材质 inert（真机轮 3 三证），只留语义底色 + 原生按压态。
        .systemMaterial(mode === 'tabbar' ? plainButtonMaterial(this.isDark)
          : (useSystemChrome() ? buttonMaterial() : undefined))
        // 手挂小阴影（TOOLBAR_MANUAL_SHADOW）：radius 8 / offsetY 2 / 8% 黑，替代材质层大扩散 applyShadow
        .shadow(mode === 'tabbar' && TOOLBAR_MANUAL_SHADOW
          ? toolbarControlShadow()
          : NO_TOOLBAR_SHADOW)
        .stateStyles({ normal: { opacity: 1 }, pressed: { opacity: 0.6 } })
        .enabled(!this.loading)
        .onChange((v: string): void => { this.cmd = v; })
        .onSubmit((): void => { this.send(); })
        .accessibilityText('命令输入框')
      Button() {
        if (this.loading) {
          LoadingProgress().width(22).height(22)
            .color($r('sys.color.ohos_id_color_emphasize'))
        } else {
          SymbolGlyph($r('sys.symbol.paperplane_fill'))
            .fontSize(20)
            .fontColor([$r('sys.color.ohos_id_color_emphasize')])
        }
      }
      .width(44)
      .height(44)
      .borderRadius(22)
      // TabBar 生效区内膜会盖住 backgroundColor，表面色不可调 → 不下发，样式走 plainButtonMaterial 的阴影；
      // overlay/inline 在内容区底色可调；overlay 浮在暗色模糊条上，button_normal 透明黑近乎隐形 → 半透明白
      .backgroundColor(mode === 'tabbar' ? undefined
        : (plainButtonMaterialOnly() ? undefined
          : (mode === 'overlay' ? OVERLAY_CONTROL_BG : $r('sys.color.ohos_id_color_button_normal'))))
      .systemMaterial(mode === 'tabbar' ? plainButtonMaterial(this.isDark)
        : (plainButtonMaterialOnly() ? plainButtonMaterial(this.isDark) : usePlainButtonMaterial() ? buttonMaterial() : undefined))
      .shadow(mode === 'tabbar' && TOOLBAR_MANUAL_SHADOW
        ? toolbarControlShadow()
        : NO_TOOLBAR_SHADOW)
      .stateStyles({ normal: { opacity: 1 }, pressed: { opacity: 0.6 } })
      .enabled(!this.loading)
      .accessibilityText('发送命令')
      .onClick((): void => { this.send(); })
    }
    .width('100%')
    .padding(mode === 'inline'
      ? { top: 16, bottom: 16 }
      : { left: $r('sys.float.padding_level6'), right: $r('sys.float.padding_level6'), top: 16, bottom: 16 })
    // 方案 B 的模糊条：与原生顶栏被证实的档同一配方（radius 60 + saturation 1.4，不加 color），
    // 透色且严格止于栏矩形；blur 半径单位 vp，60 在 76vp 高的条上是重模糊，量数后再调。
    .backgroundEffect(mode === 'overlay' ? { radius: 60, saturation: 1.4 } : undefined)
  }

  build() {
    HdsNavDestination() {
      if (TERMINAL_TOOLBAR_OVERLAY) {
        // 方案 B：工具条为内容区底部浮层（Stack 底对齐），模糊条全宽，日志黑卡从条下穿过；
        // 列表视口满高，末行让位走 contentEndOffset（加大 padding 会连视口一起裁掉，见 logStack 注释）。
        Stack({ alignContent: Alignment.Bottom }) {
          Column({ space: 0 }) {
            this.topToolbar()
            this.logStack()
          }
          .width('100%')
          .height('100%')
          .padding({ left: $r('sys.float.padding_level6'), right: $r('sys.float.padding_level6'),
            top: barBottomVp(this.getUIContext(), this.safeTopPx) })
          this.cmdBar('overlay')
        }
        .width('100%')
        .height('100%')
      } else if (TERMINAL_TABBAR_TOOLBAR) {
        // 探针结构：命令输入条放进单页签 Tabs 的自定义底栏，落入官方认定的组件级材质生效区
        // （底部 TabBar，barPosition: End）；页面内容（顶部工具条 + 日志）作为唯一页签。
        Tabs({ barPosition: BarPosition.End, index: 0 }) {
          TabContent() {
            Column({ space: 0 }) {
              this.topToolbar()
              this.logStack()
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
        // 方案 A（2026-09-30）：工具条改挂首页同一条系统悬浮底栏通道。
        // barFloatingStyle 仅在 barOverlap(true) 时生效（Task 8 实测前置条件）；
        // barBottomMargin 0 —— HdsNavDestination 的 subPageBottom 已把 Tabs 盒上移 px2vp(safeBottom)+12，
        // 与首页胶囊同高，不再叠一次。
        .barOverlap(TERMINAL_TABBAR_FLOATING)
        .barFloatingStyle({
          barWidth: {
            smallBarWidth: toolbarBarWidthVp(this.getUIContext(), this.winWidthPx),
            mediumBarWidth: toolbarBarWidthVp(this.getUIContext(), this.winWidthPx),
            largeBarWidth: toolbarBarWidthVp(this.getUIContext(), this.winWidthPx)
          },
          barBottomMargin: 0,
          adaptToHandedness: false,
          systemMaterial: tabBarMaterial()
        })
        .width('100%')
        .height('100%')
      } else {
        Column({ space: 0 }) {
          this.topToolbar()
          this.logStack()
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
    .titleBar(hdsTitleBarOptions('命令行工具', this.isDark, TitleSize.TITLE_S, true))
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }
}
