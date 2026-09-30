import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { FrameCallback } from '@kit.ArkUI';
import { HistoryRow } from '../common/Store';
import { HapCard } from '../components/HapCard';
import { PillButton } from '../components/PillButton';
import { HdsNavDestination, TitleSize } from '@kit.UIDesignKit';
import { subPageBottom, barBottomVp } from '../common/Immersive';
import { hdsTitleBarOptions } from '../common/MaterialPolicy';

/** 调试详情页（对应 Flutter debug_detail_page.dart）：单次调试的元信息 + 完整日志 */
@Component
export struct DebugDetail {
  @Consume('navStack') pathStack: NavPathStack;
  @StorageLink('isDark') isDark: boolean = false;
  @StorageLink('safeTopPx') safeTopPx: number = 0;
  @StorageLink('safeBottomPx') safeBottomPx: number = 0;
  @State row: HistoryRow | undefined = undefined;
  @State logLines: string[] = [];
  private scroller: Scroller = new Scroller();

  private ctx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private fmt(ts: number): string {
    if (ts === 0) {
      return '—';
    }
    const d: Date = new Date(ts);
    const pad = (n: number): string => n.toString().padStart(2, '0');
    return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) + ' ' +
      pad(d.getHours()) + ':' + pad(d.getMinutes()) + ':' + pad(d.getSeconds());
  }

  private statusLabel(s: string): string {
    if (s === 'success') {
      return '成功';
    }
    if (s === 'failed') {
      return '失败';
    }
    if (s === 'killed_expected') {
      return '待确认';
    }
    if (s === 'pending') {
      return '进行中';
    }
    return s;
  }

  private loadLog(): void {
    const r: HistoryRow | undefined = this.row;
    const path: string = (r !== undefined && r.logPath.length > 0)
      ? r.logPath : this.ctx().filesDir + '/hapinstaller.log';
    let text: string = '';
    try {
      text = fileIo.readTextSync(path);
    } catch (e) {
      text = '';
    }
    const lines: string[] = text.split('\n').filter((l: string): boolean => l.trim().length > 0);
    this.logLines = lines.length > 800 ? lines.slice(lines.length - 800) : lines;
    const cb: FrameCallback = {
      onFrame: (_t: number): void => {
        if (this.logLines.length > 0) {
          this.scroller.scrollToIndex(this.logLines.length - 1);
        }
      },
      onIdle: (): void => {}
    };
    this.getUIContext().postFrameCallback(cb);
  }

  private copyLog(): void {
    const data: pasteboard.PasteData = pasteboard.createData(
      pasteboard.MIMETYPE_TEXT_PLAIN, this.logLines.join('\n'));
    pasteboard.getSystemPasteboard().setData(data).then((): void => {
      this.getUIContext().getPromptAction().showToast({ message: '日志已复制' });
    }).catch((): void => {});
  }

  build() {
    HdsNavDestination() {
      Column({ space: 12 }) {
        HapCard({ title: '任务信息', content: (): void => { this.metaBody() } })

        Row({ space: 8 }) {
          Text('完整日志')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .layoutWeight(1)
          PillButton({ label: '复制', onClickAction: (): void => { this.copyLog(); } })
          PillButton({ label: '刷新', onClickAction: (): void => { this.loadLog(); } })
        }.width('100%')

        List({ space: 2, scroller: this.scroller }) {
          ForEach(this.logLines, (item: string, idx: number) => {
            ListItem() {
              Text(item)
                .fontSize(12)
                .fontColor(Color.White)
                .fontFamily('monospace')
                .width('100%')
                .wordBreak(WordBreak.BREAK_ALL)
                .accessibilityText(item)
            }
          }, (item: string, idx: number): string => idx + '_' + item.length)
        }
        .width('100%')
        .layoutWeight(1)
        .padding(12)
        // 回弹对齐首页 Scroll；List 默认只在内容超一屏时回弹，所以要显式 alwaysEnabled
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .scrollBar(BarState.Off)
        // 底色按主题分档：深色下页底实测纯 0，硬编码 Color.Black 会让日志卡与页底糊成一片 →
        // 深色用与上方 HapCard 同一张卡面令牌（实测 48）；浅色保持纯黑（白字终端观感是签核态）。
        .backgroundColor(this.isDark ? $r('sys.color.ohos_id_color_card_bg') : Color.Black)
        .borderRadius($r('sys.float.corner_radius_level6'))
        .clip(true)
      }
      .width('100%')
      .height('100%')
      .padding({ left: $r('sys.float.padding_level6'), right: $r('sys.float.padding_level6'),
        top: barBottomVp(this.getUIContext(), this.safeTopPx),
        bottom: $r('sys.float.padding_level6') })
    }
    .padding(subPageBottom(this.getUIContext(), this.safeBottomPx))
    // 顶栏要 avoidLayoutSafeArea: true，标题才落在状态栏之下；内容顶让满 barBottomVp（见其注释实测记录）
    .titleBar(hdsTitleBarOptions('调试详情', this.isDark, TitleSize.TITLE_S, true))
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .onReady((ctx: NavDestinationContext): void => {
      const p: Object | undefined = ctx.pathInfo.param as Object | undefined;
      if (p !== undefined && p !== null) {
        this.row = p as HistoryRow;
      }
      this.loadLog();
    })
  }

  @Builder
  metaBody() {
    Column({ space: 4 }) {
      if (this.row !== undefined) {
        this.kv('状态', this.statusLabel(this.row.status))
        this.kv('包名', this.row.bundleName)
        this.kv('设备', this.row.target)
        this.kv('HAP', this.row.hapPath)
        this.kv('开始', this.fmt(this.row.startedAt))
        this.kv('结束', this.fmt(this.row.finishedAt))
        if (this.row.errorText.length > 0) {
          this.kv('错误', this.row.errorText)
        }
      } else {
        Text('未获取到任务信息')
          .fontSize(13)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          .width('100%')
      }
    }.width('100%')
  }

  @Builder
  kv(k: string, v: string) {
    Row({ space: 6 }) {
      Text(k)
        .fontSize(12)
        .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
        .width(48)
      Text(v)
        .fontSize(12)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .layoutWeight(1)
        .wordBreak(WordBreak.BREAK_ALL)
    }.width('100%')
  }
}
