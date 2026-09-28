import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { FrameCallback } from '@kit.ArkUI';
import { HdcService } from '../common/HdcService';
import { safeAreaInsets } from '../common/Immersive';

/** HDC 命令行终端页（对应 Flutter terminal_page.dart） */
@Component
export struct Terminal {
  @Consume('navStack') pathStack: NavPathStack;
  @StorageLink('safeTopPx') safeTopPx: number = 0;
  @StorageLink('safeBottomPx') safeBottomPx: number = 0;
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

  build() {
    NavDestination() {
      Column({ space: 0 }) {
        Row({ space: 8 }) {
          Blank()
          Button('加载日志')
            .fontSize(13)
            .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
            .fontColor($r('sys.color.ohos_id_color_emphasize'))
            .accessibilityText('加载日志')
            .onClick((): void => { this.loadLog(); })
          Button('清空')
            .fontSize(13)
            .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
            .fontColor($r('sys.color.ohos_id_color_emphasize'))
            .accessibilityText('清空输出')
            .onClick((): void => { this.results = []; })
        }
        .width('100%')
        .padding({ top: 4, bottom: 4 })

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
          .padding(12)
          .scrollBar(BarState.Auto)

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
        .backgroundColor(Color.Black)
        .borderRadius(16)
        .clip(true)

        Row({ space: 8 }) {
          TextInput({ text: this.cmd, placeholder: '输入 HDC 命令...' })
            .layoutWeight(1)
            .height(44)
            .borderRadius(22)
            .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
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
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
          .enabled(!this.loading)
          .accessibilityText('发送命令')
          .onClick((): void => { this.send(); })
        }
        .width('100%')
        .padding({ top: 16, bottom: 16 })
      }
      .width('100%')
      .height('100%')
      .padding({ left: $r('sys.float.padding_level6'), right: $r('sys.float.padding_level6') })
    }
    .padding(safeAreaInsets(this.getUIContext(), this.safeTopPx, this.safeBottomPx))
    .title('命令行工具')
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }
}
