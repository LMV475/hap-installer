import { buttonMaterial, useSystemChrome } from '../common/MaterialPolicy';

export type PillButtonVariant = 'primary' | 'secondary' | 'danger';

@Component
export struct PillButton {
  @Prop label: string = '';
  @Prop variant: PillButtonVariant = 'secondary';
  @Prop enabled_: boolean = true;
  onClickAction: () => void = (): void => {};

  private usesMaterial(): boolean {
    return this.variant === 'secondary' && useSystemChrome();
  }

  private bgColor(): ResourceColor {
    if (this.variant === 'primary') {
      return $r('sys.color.ohos_id_color_emphasize');
    }
    if (this.variant === 'danger') {
      return $r('sys.color.ohos_id_color_warning');
    }
    // 中性档保留语义底色：模拟器实测（同图 y=520 亮度剖面）材质单独下发时底色与幕布逐像素相同
    // （235 vs 236，即胶囊消失）；材质 + 语义底色同时下发时胶囊恢复（幕布 234 / 按钮 222，落差 12 级，
    // 与未上材质前的 11 级同量级）。SDK 文档说 systemMaterial 会接管 backgroundColor，实测本档并未接管。
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
      .systemMaterial(this.usesMaterial() ? buttonMaterial() : undefined)
      .onClick((): void => { this.onClickAction(); })
  }
}
