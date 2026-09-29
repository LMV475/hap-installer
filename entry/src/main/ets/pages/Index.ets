import { Home } from './Home';
import { Cert } from './Cert';
import { History } from './History';
import { More } from './More';
import { CertWeb } from './CertWeb';
import { Terminal } from './Terminal';
import { Acl } from './Acl';
import { TeamDevice } from './TeamDevice';
import { UserGuide } from './UserGuide';
import { Privacy } from './Privacy';
import { DebugDetail } from './DebugDetail';
import { Breakpoint, syncBreakpoint } from '../components/BreakpointSystem';
import { PILL_BAR_VP, PILL_BOTTOM_GAP_VP, PILL_ITEM_PAD_VP, TITLE_BAR_VP, TITLE_BLUR_VP,
  TITLE_FADE_VP, TITLE_FONT_VP, TITLE_MASK_ALPHA, TITLE_MASK_POS,
  TITLE_TOP_GAP_VP, SYSTEM_TAB_BAR_VP, TAB_BAR_WIDTH_SM_VP, TAB_BAR_WIDTH_MD_VP,
  TAB_BAR_WIDTH_LG_VP } from '../common/Immersive';
import { useSystemTabBar, useSystemTitleBar, tabBarMaterial } from '../common/MaterialPolicy';

@Entry
@Component
struct Index {
  @Provide('navStack') pathStack: NavPathStack = new NavPathStack();
  @StorageLink('currentBreakpoint') currentBreakpoint: string = Breakpoint.SM;
  @StorageLink('selectedTab') selectedTab: number = 0;
  @StorageLink('safeTopPx') safeTopPx: number = 0;
  @StorageLink('safeBottomPx') safeBottomPx: number = 0;
  @StorageLink('isDark') isDark: boolean = false;
  /** Tabs 实际高度（vp），用来把「浮层底部」换算成模糊渐变的收尾比例 */
  @State tabsVp: number = 1;
  private tabTitles: string[] = ['HapInstaller', '证书管理', '调试历史', '更多'];

  @Builder
  pageMap(name: string) {
    if (name === 'CertWeb') {
      CertWeb()
    } else if (name === 'Terminal') {
      Terminal()
    } else if (name === 'Acl') {
      Acl()
    } else if (name === 'TeamDevice') {
      TeamDevice()
    } else if (name === 'UserGuide') {
      UserGuide()
    } else if (name === 'Privacy') {
      Privacy()
    } else if (name === 'DebugDetail') {
      DebugDetail()
    }
  }

  @Builder
  tabLabel(text: string, sym: Resource, idx: number) {
    Column({ space: 2 }) {
      SymbolGlyph(sym)
        .fontSize(22)
        .fontColor(this.selectedTab === idx
          ? [$r('sys.color.ohos_id_color_emphasize')]
          : [$r('sys.color.ohos_id_color_text_secondary')])
      Text(text)
        .fontSize(10)
        .fontColor(this.selectedTab === idx
          ? $r('sys.color.ohos_id_color_emphasize')
          : $r('sys.color.ohos_id_color_text_secondary'))
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    // 系统悬浮 TabBar 下选中底色/圆角交回系统高亮表达（Task 8 Step 5）；
    // 回退分支（!useSystemTabBar()，含 USE_SYSTEM_CHROME=false）保留手搓选中态，观感与 Batch 3 前一致
    .borderRadius(useSystemTabBar() ? 0 : PILL_BAR_VP / 2 - PILL_ITEM_PAD_VP)
    .backgroundColor(!useSystemTabBar() && this.selectedTab === idx
      ? (this.isDark ? '#26FFFFFF' : '#14000000')
      : Color.Transparent)
    .accessibilityText(text + (this.selectedTab === idx ? '，已选中' : ''))
    .onClick((): void => {
      this.selectedTab = idx;
    })
  }

  /**
   * 顶部标题浮层只有两层：一整条连续的多档蒙层 + 独立的标题文字。
   * 模糊不在这里——它由 Tabs 上的 linearGradientBlur 按屏幕位置连续渐变地糊页面内容，
   * 所以不存在分段模糊带的色阶，也永远不会糊到标题文字。
   */
  @Builder
  legacyTopBar() {
    Stack({ alignContent: Alignment.Top }) {
      Column()
        .width('100%')
        .height(this.topHeightVp())
        .linearGradient({ angle: 180, colors: this.maskStops() })

      Row() {
        Text(this.pageTitle())
          .fontSize(TITLE_FONT_VP)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
      }
      .width('100%')
      .height(TITLE_BAR_VP)
      .padding({ left: $r('sys.float.padding_level6'), right: $r('sys.float.padding_level6') })
      .margin({ top: this.getUIContext().px2vp(this.safeTopPx) + TITLE_TOP_GAP_VP })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(this.topHeightVp())
    .hitTestBehavior(HitTestMode.None)
  }

  /** 浮层高度占整屏的比例：模糊渐变正好在浮层底部收到 0，内容刚出浮层就是清晰的 */
  private blurFraction(): number {
    const h: number = Math.max(1, this.tabsVp);
    return Math.min(0.4, this.topHeightVp() / h);
  }

  private blurFractions(): FractionStop[] {
    const f: number = this.blurFraction();
    const stops: FractionStop[] = [[1, 0], [0.75, f * 0.22], [0.45, f * 0.5], [0.18, f * 0.78], [0, f]];
    return stops;
  }

  private topHeightVp(): number {
    return this.getUIContext().px2vp(this.safeTopPx) + TITLE_TOP_GAP_VP + TITLE_BAR_VP + TITLE_FADE_VP;
  }

  /** 底部悬浮胶囊：圆角矩形 + 毛玻璃，浮在页面内容之上 */
  @Builder
  legacyBottomBar() {
    Row() {
      this.tabLabel('首页', $r('sys.symbol.house'), 0)
      this.tabLabel('证书', $r('sys.symbol.doc_text'), 1)
      this.tabLabel('历史', $r('sys.symbol.clock'), 2)
      this.tabLabel('更多', $r('sys.symbol.ellipsis_circle'), 3)
    }
    .width('92%')
    .height(PILL_BAR_VP)
    .padding(PILL_ITEM_PAD_VP)
    .borderRadius(PILL_BAR_VP / 2)
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .border({ width: 1, color: this.isDark ? '#33FFFFFF' : '#14000000' })
    .shadow({ radius: 24, color: '#29000000', offsetY: 6 })
    .margin({ bottom: this.getUIContext().px2vp(this.safeBottomPx) + PILL_BOTTOM_GAP_VP })
  }

  private pageTitle(): string {
    const idx: number = this.selectedTab;
    if (idx < 0 || idx >= this.tabTitles.length) {
      return '';
    }
    return this.tabTitles[idx];
  }

  /** 一整条连续的多档蒙层曲线：标题行内基本不衰减，衰减集中在浮层下半段 */
  private maskStops(): Array<[ResourceColor, number]> {
    const base: string = this.isDark ? '000000' : 'F1F3F5';
    const stops: Array<[ResourceColor, number]> = [];
    for (let i = 0; i < TITLE_MASK_ALPHA.length; i++) {
      stops.push([this.argb(TITLE_MASK_ALPHA[i], base), TITLE_MASK_POS[i]]);
    }
    return stops;
  }

  /** '#AARRGGBB'：base 不带 '#'，避免拼出 '#E6#F1F3F5' 这种非法颜色（ArkUI 会整条渐变不绘制） */
  private argb(alpha: number, base: string): string {
    const clamped: number = Math.min(1, Math.max(0, alpha));
    const v: number = Math.round(clamped * 255);
    return '#' + (v < 16 ? '0' : '') + v.toString(16).toUpperCase() + base;
  }

  build() {
    Navigation(this.pathStack) {
      Stack({ alignContent: Alignment.Bottom }) {
        Tabs({ barPosition: BarPosition.End, index: this.selectedTab }) {
          TabContent() {
            Home()
          }
          .tabBar(this.tabLabel('首页', $r('sys.symbol.house'), 0))

          TabContent() {
            Cert()
          }
          .tabBar(this.tabLabel('证书', $r('sys.symbol.doc_text'), 1))

          TabContent() {
            History()
          }
          .tabBar(this.tabLabel('历史', $r('sys.symbol.clock'), 2))

          TabContent() {
            More()
          }
          .tabBar(this.tabLabel('更多', $r('sys.symbol.ellipsis_circle'), 3))
        }
        .onChange((idx: number): void => { this.selectedTab = idx; })
        .onAreaChange((_oldValue: Area, newValue: Area): void => {
          this.tabsVp = Math.max(1, Number(newValue.height));
        })
        .linearGradientBlur(TITLE_BLUR_VP,
          { fractionStops: this.blurFractions(), direction: GradientDirection.Bottom })
        .barMode(BarMode.Fixed)
        .barHeight(useSystemTabBar() ? SYSTEM_TAB_BAR_VP : 0)
        .barBackgroundColor(Color.Transparent)
        // barFloatingStyle 仅在页签栏与内容重叠（barOverlap(true)）时生效，与悬浮分支同开同关
        .barOverlap(useSystemTabBar())
        .barFloatingStyle(useSystemTabBar() ? {
          barWidth: {
            smallBarWidth: TAB_BAR_WIDTH_SM_VP,
            mediumBarWidth: TAB_BAR_WIDTH_MD_VP,
            largeBarWidth: TAB_BAR_WIDTH_LG_VP
          },
          barBottomMargin: this.getUIContext().px2vp(this.safeBottomPx) + PILL_BOTTOM_GAP_VP,
          // 真机（5MT0226114015018，直板机）左右手操作下悬浮栏始终居中（bounds 86..1234），未观察到可见偏置；
          // 单手模式无法经 shell 切换验证，按 Task 8 Step 7③ 置 false 并在 spec 记录
          adaptToHandedness: false,
          systemMaterial: tabBarMaterial()
        } : undefined)
        .width('100%')
        .height('100%')

        Stack({ alignContent: Alignment.Top }) {
          if (!useSystemTitleBar()) {
            this.legacyTopBar()
          }
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None)

        if (!useSystemTabBar()) {
          this.legacyBottomBar()
        }
      }
      .width('100%')
      .height('100%')
    }
    .navDestination(this.pageMap)
    .mode(NavigationMode.Stack)
    .hideTitleBar(!useSystemTitleBar())
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .onAreaChange((_oldValue: Area, newValue: Area): void => {
      const w: number = Number(newValue.width);
      syncBreakpoint(w);
    })
  }
}
