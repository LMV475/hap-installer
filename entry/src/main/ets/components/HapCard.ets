@Component
export struct HapCard {
  @Prop title: string = '';
  @Prop actionText: string = '';
  onAction: () => void = (): void => {};
  @BuilderParam content: () => void;

  build() {
    Column() {
      if (this.title.length > 0 || this.actionText.length > 0) {
        Row() {
          Text(this.title)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
          Blank()
          if (this.actionText.length > 0) {
            Text(this.actionText)
              .fontSize(13)
              .fontColor($r('sys.color.ohos_id_color_emphasize'))
              .accessibilityText(this.actionText)
              .onClick((): void => { this.onAction(); })
          }
        }
        .width('100%')
        .margin({ bottom: $r('sys.float.padding_level3') })
      }
      this.content()
    }
    .width('100%')
    .padding($r('sys.float.padding_level5'))
    .borderRadius($r('sys.float.corner_radius_level6'))
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }
}
