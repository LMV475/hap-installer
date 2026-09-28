import { PillButton } from './PillButton';

@Component
export struct HomeSettingItem {
  @Prop title: string = '';
  @Prop description: string = '';
  @Prop icon: Resource = $r('sys.symbol.circle');
  @Prop buttonLabel: string = '';
  @Prop isActive: boolean = false;
  @Prop buttonEnabled: boolean = true;
  @Prop show: boolean = true;
  onButtonTap: () => void = (): void => {};

  build() {
    if (this.show) {
      Row({ space: 12 }) {
        SymbolGlyph(this.icon)
          .fontSize(28)
          .fontColor([this.isActive
            ? $r('sys.color.ohos_id_color_emphasize')
            : $r('sys.color.ohos_id_color_text_tertiary')])
          .width(36)
        Column({ space: 2 }) {
          Text(this.description)
            .fontSize(11)
            .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
            .width('100%')
          Text(this.title)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .width('100%')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }.layoutWeight(1)
        PillButton({
          label: this.buttonLabel,
          variant: this.isActive ? 'secondary' : 'primary',
          enabled_: this.buttonEnabled,
          onClickAction: (): void => { this.onButtonTap(); }
        })
      }
      .width('100%')
      .padding({ top: $r('sys.float.padding_level3'), bottom: $r('sys.float.padding_level3') })
    }
  }
}
