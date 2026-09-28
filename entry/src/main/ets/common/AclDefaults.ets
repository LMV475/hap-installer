import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

/** 默认 ACL 权限列表（与 Flutter EcoServices.dart defaultAcl 一致） */
export const DEFAULT_ACL: string[] = [
  'ohos.permission.SYSTEM_FLOAT_WINDOW',
  'ohos.permission.READ_CONTACTS',
  'ohos.permission.WRITE_CONTACTS',
  'ohos.permission.READ_AUDIO',
  'ohos.permission.WRITE_AUDIO',
  'ohos.permission.READ_IMAGEVIDEO',
  'ohos.permission.WRITE_IMAGEVIDEO',
  'ohos.permission.READ_WRITE_DESKTOP_DIRECTORY',
  'ohos.permission.ACCESS_DDK_USB',
  'ohos.permission.ACCESS_DDK_HID',
  'ohos.permission.READ_PASTEBOARD',
  'ohos.permission.FILE_ACCESS_PERSIST',
  'ohos.permission.INTERCEPT_INPUT_EVENT',
  'ohos.permission.INPUT_MONITORING',
  'ohos.permission.SHORT_TERM_WRITE_IMAGEVIDEO',
  'ohos.permission.READ_WRITE_USER_FILE',
  'ohos.permission.READ_WRITE_USB_DEV',
  'ohos.permission.GET_WIFI_PEERS_MAC',
  'ohos.permission.SET_TELEPHONY_ESIM_STATE_OPEN',
  'ohos.permission.kernel.DISABLE_CODE_MEMORY_PROTECTION',
  'ohos.permission.kernel.ALLOW_WRITABLE_CODE_MEMORY',
  'ohos.permission.kernel.ALLOW_EXECUTABLE_FORT_MEMORY',
  'ohos.permission.MANAGE_PASTEBOARD_APP_SHARE_OPTION',
  'ohos.permission.MANAGE_UDMF_APP_SHARE_OPTION',
  'ohos.permission.ACCESS_DISK_PHY_INFO',
  'ohos.permission.PRELOAD_FILE',
  'ohos.permission.SET_PAC_URL',
  'ohos.permission.PERSONAL_MANAGE_RESTRICTIONS',
  'ohos.permission.START_PROVISIONING_MESSAGE',
  'ohos.permission.USE_FRAUD_CALL_LOG_PICKER',
  'ohos.permission.USE_FRAUD_MESSAGES_PICKER',
  'ohos.permission.PERSISTENT_BLUETOOTH_PEERS_MAC',
  'ohos.permission.ACCESS_VIRTUAL_SCREEN',
  'ohos.permission.MANAGE_APN_SETTING',
  'ohos.permission.GET_WIFI_LOCAL_MAC',
  'ohos.permission.kernel.ALLOW_USE_JITFORT_INTERFACE',
  'ohos.permission.GET_ETHERNET_LOCAL_MAC',
  'ohos.permission.kernel.DISABLE_GOTPLT_RO_PROTECTION',
  'ohos.permission.USE_FRAUD_APP_PICKER',
  'ohos.permission.ACCESS_DDK_DRIVERS',
  'ohos.permission.ACCESS_DDK_SCSI_PERIPHERAL',
  'ohos.permission.kernel.SUPPORT_PLUGIN',
  'ohos.permission.CUSTOM_SANDBOX',
  'ohos.permission.MANAGE_SCREEN_TIME_GUARD',
  'ohos.permission.CUSTOMIZE_SAVE_BUTTON',
  'ohos.permission.GET_ABILITY_INFO',
  'ohos.permission.ACCESS_FIDO2_ONLINEAUTH',
  'ohos.permission.USE_FLOAT_BALL',
  'ohos.permission.DLP_GET_HIDE_STATUS',
  'ohos.permission.READ_LOCAL_DEVICE_NAME',
  'ohos.permission.KEEP_BACKGROUND_RUNNING_SYSTEM',
  'ohos.permission.LINKTURBO',
  'ohos.permission.ACCESS_NET_TRACE_INFO',
  'ohos.permission.READ_WHOLE_CALENDAR',
  'ohos.permission.WRITE_WHOLE_CALENDAR',
  'ohos.permission.SET_SYSTEMSHARE_APPLAUNCHTRUSTLIST',
  'ohos.permission.HOOK_KEY_EVENT',
  'ohos.permission.WEB_NATIVE_MESSAGING',
  'ohos.permission.SUBSCRIBE_NOTIFICATION',
  'ohos.permission.CUSTOM_SCREEN_RECORDING',
  'ohos.permission.GET_IP_MAC_INFO',
  'ohos.permission.ACCESS_USER_FULL_DISK',
  'ohos.permission.kernel.LOAD_INDEPENDENT_LIBRARY',
  'ohos.permission.CRYPTO_EXTENSION_REGISTER'
];

const ACL_KEY: string = 'aclList';

/** 读取持久化 ACL 列表，未设置时返回默认列表副本 */
export async function loadAclList(ctx: common.UIAbilityContext): Promise<string[]> {
  try {
    const store = await preferences.getPreferences(ctx, 'hapinstaller');
    const raw: string = await store.get(ACL_KEY, '') as string;
    if (raw.length === 0) {
      return DEFAULT_ACL.slice();
    }
    return JSON.parse(raw) as string[];
  } catch (e) {
    return DEFAULT_ACL.slice();
  }
}

/** 持久化 ACL 列表 */
export async function saveAclList(ctx: common.UIAbilityContext, list: string[]): Promise<void> {
  try {
    const store = await preferences.getPreferences(ctx, 'hapinstaller');
    await store.put(ACL_KEY, JSON.stringify(list));
    await store.flush();
  } catch (e) {
    // 忽略写入失败，与页面上的即时状态不冲突
  }
}
