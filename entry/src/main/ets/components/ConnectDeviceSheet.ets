import { common, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { HapInput } from './HapInput';
import { PillButton } from './PillButton';

@Component
export struct ConnectDeviceSheet {
  @Link ip: string;
  @Link port: string;
  onConfirm: (target: string) => void = (_t: string): void => {};
  onClose: () => void = (): void => {};

  /** 拉起系统「无线调试」页，让用户直接在上面看到本次的 IP 与端口 */
  private openWirelessDebugging(): void {
    const ctx: common.UIAbilityContext =
      this.getUIContext().getHostContext() as common.UIAbilityContext;
    const want: Want = {
      bundleName: 'com.huawei.hmos.settings',
      abilityName: 'com.huawei.hmos.settings.MainAbility',
      uri: 'system_wireless_commissioning'
    };
    ctx.startAbility(want).catch((e: BusinessError): void => {
      this.getUIContext().getPromptAction().showToast({
        message: '打开系统设置失败：' + e.message
      });
    });
  }

  build() {
    Column({ space: 12 }) {
      Flex({ wrap: FlexWrap.Wrap }) {
        Text('手机 设置 > 系统 > 开发人员选项 > ')
          .fontSize(12)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        Text('无线调试')
          .fontSize(12)
          .fontColor($r('sys.color.ohos_id_color_emphasize'))
          .decoration({ type: TextDecorationType.Underline,
            color: $r('sys.color.ohos_id_color_emphasize') })
          .onClick((): void => { this.openWirelessDebugging(); })
      }
      .width('100%')
      Text('打开该页面即可看到本次的 IP 与端口，填到下面两栏')
        .fontSize(12)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .width('100%')

      Row({ space: 8 }) {
        HapInput({ text: $ip, placeholder: '192.168.1.10' }).layoutWeight(2)
        HapInput({ text: $port, placeholder: '端口' }).layoutWeight(1)
        PillButton({ label: '连接', variant: 'primary',
          onClickAction: (): void => { this.onConfirm(this.ip.trim() + ':' + this.port.trim()); } })
          .layoutWeight(1)
      }.width('100%')
    }
    .width('100%')
    .padding({ top: $r('sys.float.padding_level4'),
      left: $r('sys.float.padding_level6'),
      right: $r('sys.float.padding_level6'),
      bottom: $r('sys.float.padding_level6') })
  }
}
