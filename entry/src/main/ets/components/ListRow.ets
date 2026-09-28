@Component
export struct ListRow {
  @Prop title: string = '';
  @Prop subTitle: string = '';
  @Prop tailText: string = '';
  @Prop symbolName: Resource | null = null;
  onRowClick: () => void = (): void => {};

  build() {
    Row({ space: 12 }) {
      if (this.symbolName !== null) {
        SymbolGlyph(this.symbolName as Resource)
          .fontSize(22)
          .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
      }
      Column() {
        Text(this.title)
          .fontSize(15)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .maxLines(1)
        if (this.subTitle.length > 0) {
          Text(this.subTitle)
            .fontSize(12)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .maxLines(2)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      if (this.tailText.length > 0) {
        Text(this.tailText)
          .fontSize(13)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
      }
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor([$r('sys.color.ohos_id_color_text_tertiary')])
    }
    .width('100%')
    .padding({
      top: $r('sys.float.padding_level4'),
      bottom: $r('sys.float.padding_level4'),
      left: $r('sys.float.padding_level2'),
      right: $r('sys.float.padding_level2')
    })
    .onClick((): void => { this.onRowClick(); })
  }
}
