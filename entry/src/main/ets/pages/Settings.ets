import router from '@ohos.router';
import common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import { NasConfig, loadConfig, clearConfig, saveConfig } from '../common/Config';

@Entry
@Component
struct Settings {
  @State address: string = '';
  @State user: string = '';
  @State davPath: string = '/';
  @State savedCount: number = 0;

  private ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  aboutToAppear(): void {
    loadConfig(this.ctx).then((c: NasConfig) => {
      this.address = c.address;
      this.user = c.user;
      this.davPath = c.davPath;
      this.savedCount = c.address.length > 0 ? 1 : 0;
    });
  }

  async clear(): Promise<void> {
    await clearConfig(this.ctx);
    this.savedCount = 0;
    promptAction.showToast({ message: '配置已清除' });
  }

  build() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Button('← 返回').height(34).backgroundColor('#1B2430')
          .onClick(() => { router.back(); })
        Text('设置').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#E6E8EB')
        Blank()
      }.width('100%')

      Column({ space: 6 }) {
        Text('已保存的配置').fontSize(13).fontColor('#8A8F98')
        Text(this.savedCount > 0 ? this.address : '（还没有）')
          .fontSize(15).fontColor('#E6E8EB')
        Text(this.user.length > 0 ? `账号：${this.user}` : '账号：未设置')
          .fontSize(12).fontColor('#5A626E')
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding(12)
      .backgroundColor('#10161F')
      .borderRadius(10)

      Button('清除配置').width('100%').height(42).backgroundColor('#7A2E2E')
        .onClick(() => { this.clear(); })

      Blank()

      Column({ space: 4 }) {
        Text('关于').fontSize(13).fontColor('#8A8F98')
        Text('NAS 助手 v1.0.0').fontSize(14).fontColor('#E6E8EB')
        Text('连接铁威马 NAS：状态探测走 HTTP，文件浏览走 WebDAV。')
          .fontSize(12).fontColor('#5A626E')
        Text('MIT License · 源码：github.com/prodigalH/nas-assistant')
          .fontSize(11).fontColor('#5A626E')
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .backgroundColor('#0B1220')
  }
}
