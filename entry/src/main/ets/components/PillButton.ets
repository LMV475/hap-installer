export type PillButtonVariant = 'primary' | 'secondary' | 'danger';

@Component
export struct PillButton {
  @Prop label: string = '';
  @Prop variant: PillButtonVariant = 'secondary';
  @Prop enabled_: boolean = true;
  onClickAction: () => void = (): void => {};

  private bgColor(): ResourceColor {
    if (this.variant === 'primary') {
      return $r('sys.color.ohos_id_color_emphasize');
    }
    if (this.variant === 'danger') {
      return $r('sys.color.ohos_id_color_warning');
    }
    return $r('sys.color.ohos_id_color_button_normal');
  }

  private fgColor(): ResourceColor {
    if (this.variant === 'secondary') {
      return $r('sys.color.ohos_id_color_text_primary');
    }
    return Color.White;
  }

  build() {
    Button(this.label)
      .fontSize(14)
      .height(40)
      .backgroundColor(this.bgColor())
      .fontColor(this.fgColor())
      .borderRadius($r('sys.float.corner_radius_level8'))
      .enabled(this.enabled_)
      .onClick((): void => { this.onClickAction(); })
  }
}
