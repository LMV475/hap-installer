import { common } from '@kit.AbilityKit';
import { Store, HistoryRow } from '../common/Store';
import { PillButton } from '../components/PillButton';
import { HapCard } from '../components/HapCard';
import { BusinessError } from '@kit.BasicServicesKit';
import { topInsetVp, bottomInsetVp } from '../common/Immersive';

@Component
export struct History {
  @Consume('navStack') pathStack: NavPathStack;
  @StorageLink('safeTopPx') safeTopPx: number = 0;
  @StorageLink('safeBottomPx') safeBottomPx: number = 0;
  @State rows: HistoryRow[] = [];
  @State loading: boolean = false;
  @State tipText: string = '';
  @State expandedId: number = -1;

  aboutToAppear(): void {
    this.refresh();
  }

  private ctx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private async refresh(): Promise<void> {
    this.loading = true;
    try {
      await Store.init(this.ctx());
      this.rows = await Store.listHistory(100);
    } catch (e) {
      const err = e as BusinessError;
      this.tipText = '加载失败: ' + err.message;
    }
    this.loading = false;
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

  private statusColor(s: string): ResourceColor {
    if (s === 'success') {
      return $r('sys.color.ohos_id_color_emphasize');
    }
    if (s === 'failed') {
      return $r('sys.color.ohos_id_color_warning');
    }
    return $r('sys.color.ohos_id_color_sub_background');
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

  private baseName(p: string): string {
    const idx: number = Math.max(p.lastIndexOf('/'), p.lastIndexOf('\\'));
    return idx >= 0 ? p.substring(idx + 1) : p;
  }

  private chipFg(s: string): ResourceColor {
    if (s === 'success' || s === 'failed') {
      return Color.White;
    }
    return $r('sys.color.ohos_id_color_text_secondary');
  }

  private openDetail(r: HistoryRow): void {
    this.pathStack.pushPath({ name: 'DebugDetail', param: r });
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        if (this.tipText.length > 0) {
          Text(this.tipText)
            .fontSize(11)
            .fontColor($r('sys.color.ohos_id_color_emphasize'))
            .width('100%')
        }

        if (this.loading) {
          Text('加载中…').fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .width('100%')
            .padding($r('sys.float.padding_level5'))
        } else if (this.rows.length === 0) {
          HapCard({ content: (): void => { this.emptyBody() } })
        } else {
          Column({ space: 0 }) {
            ForEach(this.rows, (r: HistoryRow): void => {
              this.rowView(r)
              if (this.rows.indexOf(r) < this.rows.length - 1) {
                Divider().color($r('sys.color.ohos_id_color_list_separator'))
              }
            }, (r: HistoryRow): string => r.id.toString())
          }
          .width('100%')
          .padding({ left: $r('sys.float.padding_level5'), right: $r('sys.float.padding_level5') })
          .borderRadius($r('sys.float.corner_radius_level6'))
          .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
        }

        Row() {
          PillButton({ label: this.loading ? '刷新中…' : '刷新列表',
            enabled_: !this.loading,
            onClickAction: (): void => { this.refresh(); } })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .padding({ left: $r('sys.float.padding_level6'), right: $r('sys.float.padding_level6'),
        top: topInsetVp(this.getUIContext(), this.safeTopPx),
        bottom: bottomInsetVp(this.getUIContext(), this.safeBottomPx) })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .align(Alignment.TopStart)
    .edgeEffect(EdgeEffect.Spring)
    .scrollBar(BarState.Off)
  }

  @Builder
  emptyBody() {
    Column({ space: 6 }) {
      Text('暂无调试历史')
        .fontSize(14)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
      Text('完成一次装机后会自动记录')
        .fontSize(11)
        .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
    }.width('100%').padding($r('sys.float.padding_level5'))
  }

  @Builder
  rowView(r: HistoryRow) {
    Column({ space: 4 }) {
      Row({ space: 8 }) {
        Text(this.statusLabel(r.status))
          .fontSize(11)
          .fontColor(this.chipFg(r.status))
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .borderRadius($r('sys.float.corner_radius_level4'))
          .backgroundColor(this.statusColor(r.status))
        Text(this.baseName(r.hapPath))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        SymbolGlyph(this.expandedId === r.id
          ? $r('sys.symbol.chevron_up')
          : $r('sys.symbol.chevron_down'))
          .fontSize(16)
          .fontColor([$r('sys.color.ohos_id_color_text_tertiary')])
      }
      .width('100%')
      .onClick((): void => {
        this.expandedId = this.expandedId === r.id ? -1 : r.id;
      })
      Text(this.fmt(r.startedAt) + '  ·  ' + r.target)
        .fontSize(11)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .width('100%')
      if (this.expandedId === r.id) {
        Column({ space: 4 }) {
          this.kv('包名', r.bundleName)
          this.kv('开始', this.fmt(r.startedAt))
          this.kv('结束', this.fmt(r.finishedAt))
          this.kv('HAP', r.hapPath)
          if (r.errorText.length > 0) {
            this.kv('错误', r.errorText)
          }
          Row() {
            PillButton({ label: '调试详情（完整日志）', variant: 'primary',
              onClickAction: (): void => { this.openDetail(r); } })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .margin({ top: 4 })
        }
        .width('100%')
        .padding($r('sys.float.padding_level3'))
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
        .borderRadius($r('sys.float.corner_radius_level4'))
      }
    }
    .width('100%')
    .padding({ top: $r('sys.float.padding_level3'), bottom: $r('sys.float.padding_level3') })
  }

  @Builder
  kv(k: string, v: string) {
    Row({ space: 6 }) {
      Text(k)
        .fontSize(11)
        .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
        .width(48)
      Text(v)
        .fontSize(11)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .layoutWeight(1)
        .wordBreak(WordBreak.BREAK_ALL)
    }.width('100%')
  }
}
