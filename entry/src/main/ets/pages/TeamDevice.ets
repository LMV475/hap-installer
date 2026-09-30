import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { promptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { AgcService } from '../common/AgcService';
import { HdcService } from '../common/HdcService';
import { loadHistoryTargets, clearHistoryTargets } from '../common/HistoryTargets';
import { HapCard } from '../components/HapCard';
import { HdsNavDestination, TitleSize } from '@kit.UIDesignKit';
import { subPageBottom, barBottomVp } from '../common/Immersive';
import { hdsTitleBarOptions } from '../common/MaterialPolicy';

/** 团队设备页（对应 Flutter team_device_page.dart：团队 / 可用设备 / 历史连接 三张卡片） */
@Component
export struct TeamDevice {
  @Consume('navStack') pathStack: NavPathStack;
  @StorageLink('isDark') isDark: boolean = false;
  @StorageLink('safeTopPx') safeTopPx: number = 0;
  @StorageLink('safeBottomPx') safeBottomPx: number = 0;
  @State loggedIn: boolean = false;
  @State devices: string[] = [];
  @State currentTarget: string = '';
  @State history: string[] = [];
  @State refreshing: boolean = false;
  // Scroll 的 Scroller 必须绑给 HdsNavDestination，栏带幕布才跟着渐隐（见 hdsTitleBarStyle 的 blurStrategy 注释）
  private scrollCtrl: Scroller = new Scroller();

  private ctx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  aboutToAppear(): void {
    this.loggedIn = AgcService.isLoggedIn();
    this.loadCurrent();
    this.loadHist();
    this.refreshDevices();
  }

  private async loadCurrent(): Promise<void> {
    try {
      const store = await preferences.getPreferences(this.ctx(), 'hapinstaller');
      this.currentTarget = await store.get('target', '') as string;
    } catch (e) {
      // 保持空
    }
  }

  private async loadHist(): Promise<void> {
    this.history = await loadHistoryTargets(this.ctx());
  }

  private async refreshDevices(): Promise<void> {
    this.refreshing = true;
    try {
      HdcService.startServer(this.ctx().tempDir);
      const timeout: Promise<string> = new Promise<string>((resolve: (v: string) => void): void => {
        setTimeout((): void => { resolve(''); }, 8000);
      });
      const raw: string[] = await Promise.race([HdcService.run('list targets', this.ctx().tempDir), timeout])
        .then((o: string): string[] => o.split('\n'));
      this.devices = raw
        .map((l: string): string => l.trim())
        .filter((l: string): boolean => l.length > 0 && l.indexOf(' ') < 0 && l.indexOf('[') < 0);
    } catch (e) {
      this.devices = [];
    }
    this.refreshing = false;
  }

  private async setDefault(target: string): Promise<void> {
    try {
      const store = await preferences.getPreferences(this.ctx(), 'hapinstaller');
      await store.put('target', target);
      await store.flush();
      this.currentTarget = target;
      promptAction.showToast({ message: '已设为当前设备: ' + target });
    } catch (e) {
      const err = e as BusinessError;
      promptAction.showToast({ message: '设置失败: ' + err.message });
    }
  }

  /** 历史连接：等价 Flutter tryConnectToDevice */
  private async connect(addr: string): Promise<void> {
    try {
      HdcService.startServer(this.ctx().tempDir);
      const out: string = await HdcService.run('tconn ' + addr, this.ctx().tempDir);
      if (out.indexOf('Connect OK') >= 0) {
        this.setDefault(addr);
        this.refreshDevices();
      } else {
        promptAction.showToast({ message: '连接失败: ' + out.trim() });
      }
    } catch (e) {
      const err = e as BusinessError;
      promptAction.showToast({ message: '连接异常: ' + err.message });
    }
  }

  private async doClearHistory(): Promise<void> {
    await clearHistoryTargets(this.ctx());
    this.history = [];
  }

  @Builder
  emptyText(text: string) {
    Text(text)
      .fontSize(13)
      .fontColor($r('sys.color.ohos_id_color_text_secondary'))
      .width('100%')
      .padding({ top: $r('sys.float.padding_level3'), bottom: $r('sys.float.padding_level3') })
  }

  @Builder
  selectableRow(label: string, sub: string, selected: boolean, tap: () => void) {
    Row({ space: 8 }) {
      Column({ space: 2 }) {
        Text(label)
          .fontSize(15)
          .fontColor(selected
            ? $r('sys.color.ohos_id_color_emphasize')
            : $r('sys.color.ohos_id_color_text_primary'))
          .maxLines(1)
          .width('100%')
        if (sub.length > 0) {
          Text(sub)
            .fontSize(11)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .maxLines(1)
            .width('100%')
        }
      }.layoutWeight(1)
      if (selected) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
          .fontSize(16)
          .fontColor([$r('sys.color.ohos_id_color_emphasize')])
      }
    }
    .width('100%')
    .padding({ top: $r('sys.float.padding_level3'), bottom: $r('sys.float.padding_level3') })
    .accessibilityText(label + (sub.length > 0 ? (' ' + sub) : ''))
    .onClick((): void => { tap(); })
  }

  @Builder
  teamBody() {
    Column({ space: 0 }) {
      if (!this.loggedIn) {
        this.emptyText('请先登录')
      } else {
        this.emptyText('暂无团队')
      }
    }.width('100%')
  }

  @Builder
  deviceBody() {
    Column({ space: 0 }) {
      if (this.devices.length === 0) {
        // 内联 Text：@Builder 值传参不随状态刷新
        Text(this.refreshing ? '刷新中…' : '暂无设备')
          .fontSize(13)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          .width('100%')
          .padding({ top: $r('sys.float.padding_level3'), bottom: $r('sys.float.padding_level3') })
      } else {
        ForEach(this.devices, (item: string) => {
          this.selectableRow(item, '', this.currentTarget === item, (): void => {
            this.setDefault(item);
          })
          Divider().color($r('sys.color.ohos_id_color_list_separator'))
        }, (item: string): string => item)
      }
    }.width('100%')
  }

  @Builder
  historyBody() {
    Column({ space: 0 }) {
      if (this.history.length === 0) {
        this.emptyText('暂无历史连接')
      } else {
        ForEach(this.history, (item: string) => {
          this.selectableRow(item, '点击重新连接', this.currentTarget === item, (): void => {
            this.connect(item);
          })
          Divider().color($r('sys.color.ohos_id_color_list_separator'))
        }, (item: string): string => item)
      }
    }.width('100%')
  }

  build() {
    HdsNavDestination() {
      Scroll(this.scrollCtrl) {
        Column({ space: 12 }) {
          HapCard({ title: '团队', content: (): void => { this.teamBody() } })
          HapCard({
            title: '可用设备',
            actionText: '刷新',
            onAction: (): void => { this.refreshDevices(); },
            content: (): void => { this.deviceBody() }
          })
          HapCard({
            title: '历史连接',
            actionText: this.history.length > 0 ? '清除' : '',
            onAction: (): void => { this.doClearHistory(); },
            content: (): void => { this.historyBody() }
          })
        }
        .width('100%')
        .padding({ left: $r('sys.float.padding_level6'), right: $r('sys.float.padding_level6'),
          top: barBottomVp(this.getUIContext(), this.safeTopPx),
          bottom: $r('sys.float.padding_level6') })
      }
      .width('100%')
      .height('100%')
      .align(Alignment.TopStart)
      // 与首页根 Scroll 同档（Home.ets 那处也是这两行）：到边回弹 + 不显示滚动条。
      // Scroll 的 edgeEffect 默认 EdgeEffect.None（scroll.d.ts:1249），不给就是硬停；
      // alwaysEnabled 在 Scroll 上默认已为 true，内容不足一屏也能拉动回弹。
      .edgeEffect(EdgeEffect.Spring)
      .scrollBar(BarState.Off)
    }
    .padding(subPageBottom(this.getUIContext(), this.safeBottomPx))
    .bindToScrollable([this.scrollCtrl])
    // 顶栏要 avoidLayoutSafeArea: true，标题才落在状态栏之下；内容顶让满 barBottomVp（见其注释实测记录）
    .titleBar(hdsTitleBarOptions('团队设备', this.isDark, TitleSize.TITLE_S, true))
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }
}
