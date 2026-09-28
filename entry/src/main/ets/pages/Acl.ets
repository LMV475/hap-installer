import { common } from '@kit.AbilityKit';
import { FrameCallback } from '@kit.ArkUI';
import { DEFAULT_ACL, loadAclList, saveAclList } from '../common/AclDefaults';
import { safeAreaInsets } from '../common/Immersive';

/** ACL 权限列表页（对应 Flutter acl_page.dart，terminal 风格） */
@Component
export struct Acl {
  @Consume('navStack') pathStack: NavPathStack;
  @StorageLink('safeTopPx') safeTopPx: number = 0;
  @StorageLink('safeBottomPx') safeBottomPx: number = 0;
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

  build() {
    NavDestination() {
      Column({ space: 0 }) {
        Row({ space: 8 }) {
          Blank()
          Button('重置为默认')
            .fontSize(13)
            .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
            .fontColor($r('sys.color.ohos_id_color_emphasize'))
            .accessibilityText('重置为默认权限列表')
            .onClick((): void => { this.resetDefault(); })
        }
        .width('100%')
        .padding({ top: 4, bottom: 4 })

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
        .padding(12)
        .scrollBar(BarState.Auto)
        .backgroundColor(Color.Black)
        .borderRadius(16)
        .clip(true)

        Row({ space: 8 }) {
          TextInput({ text: this.input, placeholder: '输入权限名，如 ohos.permission.XXX' })
            .layoutWeight(1)
            .height(44)
            .borderRadius(22)
            .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
            .onChange((v: string): void => { this.input = v; })
            .onSubmit((): void => { this.addAcl(); })
            .accessibilityText('权限输入框')
          Button() {
            SymbolGlyph($r('sys.symbol.plus'))
              .fontSize(20)
              .fontColor([$r('sys.color.ohos_id_color_emphasize')])
          }
          .width(44)
          .height(44)
          .borderRadius(22)
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
          .accessibilityText('添加权限')
          .onClick((): void => { this.addAcl(); })
        }
        .width('100%')
        .padding({ top: 16, bottom: 16 })
      }
      .width('100%')
      .height('100%')
      .padding({ left: $r('sys.float.padding_level6'), right: $r('sys.float.padding_level6') })
    }
    .padding(safeAreaInsets(this.getUIContext(), this.safeTopPx, this.safeBottomPx))
    .title('ACL 权限列表')
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }
}
