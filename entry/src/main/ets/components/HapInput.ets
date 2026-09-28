@Component
export struct HapInput {
  @Link text: string;
  @Prop placeholder: string = '';
  @Prop isPassword: boolean = false;

  build() {
    TextInput({ text: this.text, placeholder: this.placeholder })
      .type(this.isPassword ? InputType.Password : InputType.Normal)
      .onChange((v: string): void => { this.text = v; })
      .height(40)
      .borderRadius($r('sys.float.corner_radius_level6'))
      .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
      .border({
        width: 1,
        color: $r('sys.color.ohos_id_color_list_separator')
      })
      .padding({ left: $r('sys.float.padding_level4'), right: $r('sys.float.padding_level4') })
  }
}
