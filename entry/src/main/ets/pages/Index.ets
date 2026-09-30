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
import { PILL_BOTTOM_GAP_VP, SYSTEM_TAB_BAR_VP,
  TAB_BAR_WIDTH_SM_VP, TAB_BAR_WIDTH_MD_VP,
  TAB_BAR_WIDTH_LG_VP } from '../common/Immersive';
import { tabBarMaterial, hdsTitleBarOptions } from '../common/MaterialPolicy';
import { HdsNavigation, HdsNavigationTitleMode, TitleSize } from '@kit.UIDesignKit';

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
    // barFloatingStyle 仅在页签栏与内容重叠（barOverlap(true)）时生效
    .barOverlap(true)
    .barFloatingStyle({
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
