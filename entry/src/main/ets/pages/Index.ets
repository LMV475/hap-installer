import { Home } from './Home';
import { Cert } from './Cert';
import { History } from './History';
import { More } from './More';
import { CertWeb } from './CertWeb';
import { Terminal } from './Terminal';
import { Acl } from './Acl';
// import { TeamDevice } from './TeamDevice'; // 暂时屏蔽
import { UserGuide } from './UserGuide';
import { Privacy } from './Privacy';
import { DebugDetail } from './DebugDetail';
import { Breakpoint, syncBreakpoint } from '../components/BreakpointSystem';
import { PILL_BOTTOM_GAP_VP, SYSTEM_TAB_BAR_VP,
  TAB_BAR_WIDTH_SM_VP, TAB_BAR_WIDTH_MD_VP,
  TAB_BAR_WIDTH_LG_VP, classicBarBottomInsetVp } from '../common/Immersive';
import { tabBarMaterial, hdsTitleBarOptions, TitleSize,
  chromeAttributesSupported, FloatingTabBarModifier } from '../common/MaterialPolicy';
import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';

@Entry
@Component
struct Index {
  @Provide('navStack') pathStack: NavPathStack = new NavPathStack();
  @StorageLink('currentBreakpoint') currentBreakpoint: string = Breakpoint.SM;
  @StorageLink('selectedTab') selectedTab: number = 0;
  @StorageLink('safeBottomPx') safeBottomPx: number = 0;
  /** HDS 幕布背景要按深浅色主题分档（spec §5.5），EntryAbility.onConfigurationUpdate 里写这个键 */
  @StorageLink('isDark') isDark: boolean = false;
  private tabTitles: string[] = ['HapInstaller', '证书管理', '调试历史', '更多'];

  @Builder
  pageMap(name: string) {
    if (name === 'CertWeb') {
      CertWeb()
    } else if (name === 'Terminal') {
      Terminal()
    } else if (name === 'Acl') {
      Acl()
    // } else if (name === 'TeamDevice') { // 暂时屏蔽
    //   TeamDevice()
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
    // 悬浮 TabBar 下选中态由系统高亮表达，不自绘底色/圆角（Task 8 Step 5）
    .accessibilityText(text + (this.selectedTab === idx ? '，已选中' : ''))
    .onClick((): void => {
      this.selectedTab = idx;
    })
  }

  private pageTitle(): string {
    const idx: number = this.selectedTab;
    if (idx < 0 || idx >= this.tabTitles.length) {
      return '';
    }
    return this.tabTitles[idx];
  }

  /** 页面主体：四个 TabContent + 系统悬浮底栏，作为 HdsNavigation 的内容区。 */
  @Builder
  bodyContent() {
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
    .barMode(BarMode.Fixed)
    .barHeight(SYSTEM_TAB_BAR_VP)
    .barBackgroundColor(Color.Transparent)
    // barFloatingStyle 仅在页签栏与内容重叠（barOverlap(true)）时生效；
    // 悬浮栏属性通道（Tabs.barFloatingStyle，@since 26）在 API<26 运行时不存在，
    // 由 FloatingTabBarModifier 按能力位下发，低版本回落成经典满宽栏 → barOverlap 同步取 false，
    // 否则满宽透明栏会压在内容上（内容底 inset 是按悬浮档算的）。
    .barOverlap(chromeAttributesSupported())
    .attributeModifier(new FloatingTabBarModifier({
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
    }))
    // 低版本经典满宽档：栏体贴在 Tabs 盒底，而窗口是全屏布局的，盒底在系统导航条之下，
    // 所以整盒要按导航条避让区上抬；悬浮档该值恒 0（离底已由上面的 barBottomMargin 负责）。
    // 用 padding 而不是 margin：Tabs 上 `.margin({bottom:28vp})` 实测**完全无效**
    //（margin 版 dump 仍为 Tabs [0,137][1280,2832]、TabBar [0,2636][1280,2832]），因为该子节点的
    // height('100%') 在 HdsNavigation 内容区里按拉伸处理，margin 落在盒外被吞；padding 缩的是
    // 内部布局区，满宽栏随之内收到 padding 上缘。实测（本模拟器 safe area bottom=98px）：
    // TabBar [0,2636][1280,2832] → [0,2538][1280,2735]，页签文字底边 2797 → 2699，
    // 与手势指示条像素带 2796..2816 之间空出 97px。≥26 档反向取证：临时把
    // CHROME_ATTR_MIN_API 设 21 强制 chrome=true，TabBar 逐字回到 [0,2636][1280,2832]。
    .padding({
      bottom: classicBarBottomInsetVp(this.getUIContext(), this.safeBottomPx, chromeAttributesSupported())
    })
    .width('100%')
    .height('100%')
  }

  build() {
    // HDS 顶栏：GRADIENT_BLUR 给越过栏底的渐隐模糊带（MaskBlur 实测到 y=428，比栏底 320 多 108px），
    // systemMaterialEffect 走 hdsMaterial 材质。
    // avoidLayoutSafeArea 实测**没有**把栏体推到 y=0：Navigation/NavBar/TitleBar 仍全部从 132（状态栏下缘）起，
    // 与原生通道试 expandSafeArea/ignoreLayoutSafeArea/setWindowLayoutFullScreen 的结果一致 —— 平台约束，HDS 也绕不过。
    HdsNavigation(this.pathStack) {
      this.bodyContent()
    }
    .navDestination(this.pageMap)
    .mode(NavigationMode.Stack)
    .titleBar(hdsTitleBarOptions(this.pageTitle(), this.isDark, TitleSize.TITLE_ML, false))
    // MINI = 固定收缩态。FREE（默认）会让大标题随列表滚动展开/折叠，机主要的是不随滚动变化。
    .titleMode(HdsNavigationTitleMode.MINI)
    // HDS 根栏的返回按钮默认显示（hideBackButton 默认 false），且不按 NavPathStack 是否为空自动隐藏；
    // 四个 Tab 都是一级页、栈里没有可回退目标，所以显式隐藏。二级页的返回键是 NavDestination 自己的
    // （id=__NavdestinationField__BackButton__Back__），不受此开关影响（已真机验证）。
    .hideBackButton(true)
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .onAreaChange((_oldValue: Area, newValue: Area): void => {
      syncBreakpoint(Number(newValue.width));
    })
  }
}
