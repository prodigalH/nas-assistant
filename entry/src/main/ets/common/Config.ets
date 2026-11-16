import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';
import util from '@ohos.util';

const STORE_NAME: string = 'nas_config';
const KEY: string = 'conn';

export class NasConfig {
  address: string = '';
  user: string = '';
  pass: string = '';
  davPath: string = '/';
}

export async function loadConfig(ctx: common.UIAbilityContext): Promise<NasConfig> {
  const conf = new NasConfig();
  try {
    const store = await preferences.getPreferences(ctx, STORE_NAME);
    const text = await store.get(KEY, '');
    if (typeof text === 'string' && text.length > 0) {
      const obj = JSON.parse(text) as NasConfig;
      conf.address = obj.address ?? '';
      conf.user = obj.user ?? '';
      conf.pass = obj.pass ?? '';
      conf.davPath = obj.davPath ?? '/';
    }
  } catch (e) {
    // 首次启动读不到是正常的
  }
  return conf;
}

export async function saveConfig(ctx: common.UIAbilityContext, conf: NasConfig): Promise<void> {
  const store = await preferences.getPreferences(ctx, STORE_NAME);
  await store.put(KEY, JSON.stringify(conf));
  await store.flush();
}

export async function clearConfig(ctx: common.UIAbilityContext): Promise<void> {
  const store = await preferences.getPreferences(ctx, STORE_NAME);
  await store.delete(KEY);
  await store.flush();
}

/** Basic 认证头：user:pass 做 base64 */
export function basicAuth(user: string, pass: string): string {
  const bytes = new util.TextEncoder().encodeInto(`${user}:${pass}`);
  const helper = new util.Base64Helper();
  return `Basic ${helper.encodeToStringSync(bytes)}`;
}
