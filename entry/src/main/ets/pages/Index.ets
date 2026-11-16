import router from '@ohos.router';
import common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import { request, parseEndpoint, Endpoint, HttpResult } from '../common/RawHttp';
import { NasConfig, loadConfig, saveConfig, basicAuth } from '../common/Config';

@Entry
@Component
struct Index {
  @State address: string = '';
  @State user: string = '';
  @State pass: string = '';
  @State statusText: string = '未连接';
  @State statusColor: string = '#8A8F98';
  @State latency: string = '';
  @State busy: boolean = false;

  private ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  aboutToAppear(): void {
    loadConfig(this.ctx).then((c: NasConfig) => {
      this.address = c.address;
      this.user = c.user;
      this.pass = c.pass;
    });
  }

  async probe(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.statusText = '连接中…';
    this.statusColor = '#8A8F98';
    this.latency = '';
    const ep: Endpoint = parseEndpoint(this.address);
    if (!ep.valid) {
      this.statusText = `地址无效：${ep.error}`;
      this.statusColor = '#E5484D';
      this.busy = false;
      return;
    }
    const h: Map<string, string> = new Map<string, string>();
    if (this.user.length > 0) {
      h.set('Authorization', basicAuth(this.user, this.pass));
    }
    const r: HttpResult = await request(ep.host, ep.port, 'GET', ep.basePath.length > 0 ? ep.basePath : '/', h, '', 6000);
    if (r.ok) {
      this.statusText = `在线 · HTTP ${r.status}`;
      this.statusColor = '#2ECC71';
    } else {
      this.statusText = `连不上：${r.error}`;
      this.statusColor = '#E5484D';
    }
    this.latency = `${r.elapsedMs} ms`;
    this.busy = false;
    const conf = new NasConfig();
    conf.address = this.address;
    conf.user = this.user;
    conf.pass = this.pass;
    await saveConfig(this.ctx, conf);
  }

  build() {
    Column({ space: 12 }) {
      Text('NAS 助手')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor('#E6E8EB')
        .alignSelf(ItemAlign.Start)

      Text('连接你的铁威马 NAS：先填地址，再测试连接')
        .fontSize(13)
        .fontColor('#8A8F98')
        .alignSelf(ItemAlign.Start)

      TextInput({ text: this.address, placeholder: '192.168.1.10 或 http://192.168.1.10:8181' })
        .onChange((v: string) => { this.address = v; })
        .style(TextInputStyle.Inline)
        .backgroundColor('#141A24')
        .fontColor('#E6E8EB')
        .placeholderColor('#5A626E')

      TextInput({ text: this.user, placeholder: '账号（可留空）' })
        .onChange((v: string) => { this.user = v; })
        .backgroundColor('#141A24')
        .fontColor('#E6E8EB')
        .placeholderColor('#5A626E')

      TextInput({ text: this.pass, placeholder: '密码（可留空）' })
        .type(InputType.Password)
        .onChange((v: string) => { this.pass = v; })
        .backgroundColor('#141A24')
        .fontColor('#E6E8EB')
        .placeholderColor('#5A626E')

      Button(this.busy ? '正在连接…' : '测试连接')
        .width('100%')
        .height(44)
        .enabled(!this.busy)
        .backgroundColor('#2F81F7')
        .onClick(() => { this.probe(); })

      Row({ space: 8 }) {
        Circle({ width: 8, height: 8 }).fill(this.statusColor)
        Text(this.statusText).fontColor(this.statusColor).fontSize(14)
        Blank()
        Text(this.latency).fontColor('#8A8F98').fontSize(12)
      }
      .width('100%')
      .padding(12)
      .backgroundColor('#10161F')
      .borderRadius(10)

      Row({ space: 10 }) {
        Button('浏览文件')
          .layoutWeight(1)
          .height(42)
          .backgroundColor('#1B2430')
          .onClick(() => {
            router.pushUrl({ url: 'pages/Browser' });
          })
        Button('设置')
          .layoutWeight(1)
          .height(42)
          .backgroundColor('#1B2430')
          .onClick(() => {
            router.pushUrl({ url: 'pages/Settings' });
          })
      }
      .width('100%')

      Blank()

      Text('用法：在 NAS 的「控制面板 → 文件服务」里开启 WebDAV，\n然后这里的「浏览文件」就能列目录。')
        .fontSize(11)
        .fontColor('#5A626E')
        .alignSelf(ItemAlign.Start)
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .backgroundColor('#0B1220')
  }
}
