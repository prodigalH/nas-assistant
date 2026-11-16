import router from '@ohos.router';
import common from '@ohos.app.ability.common';
import { request, parseEndpoint, Endpoint, HttpResult } from '../common/RawHttp';
import { loadConfig, NasConfig, basicAuth } from '../common/Config';

class DavEntry {
  href: string = '';
  name: string = '';
  isDir: boolean = false;
  sizeText: string = '';
  modified: string = '';
}

const PROPFIND_BODY: string =
  '<?xml version="1.0" encoding="utf-8" ?>' +
  '<d:propfind xmlns:d="DAV:"><d:prop>' +
  '<d:displayname/><d:getcontentlength/><d:getlastmodified/><d:resourcetype/>' +
  '</d:prop></d:propfind>';

function prettySize(bytes: number): string {
  if (bytes <= 0) {
    return '';
  }
  if (bytes >= 1073741824) {
    return `${(bytes / 1073741824).toFixed(1)} GB`;
  }
  if (bytes >= 1048576) {
    return `${(bytes / 1048576).toFixed(1)} MB`;
  }
  if (bytes >= 1024) {
    return `${Math.round(bytes / 1024)} KB`;
  }
  return `${bytes} B`;
}

function tagText(block: string, tag: string): string {
  const re = new RegExp(`<[a-zA-Z0-9]*:?${tag}[^>]*>([\\s\\S]*?)</[a-zA-Z0-9]*:?${tag}>`, 'i');
  const m = block.match(re);
  return m !== null && m.length > 1 ? m[1] : '';
}

function parseDav(xml: string): DavEntry[] {
  const out: DavEntry[] = [];
  const parts: string[] = xml.split(/<[a-zA-Z0-9]*:?response[\s>]/i);
  for (let i = 1; i < parts.length; i++) {
    const block = parts[i];
    const hrefRaw = tagText(block, 'href').trim();
    if (hrefRaw.length === 0) {
      continue;
    }
    let href = hrefRaw;
    try {
      href = decodeURIComponent(hrefRaw);
    } catch (e) {
      // 保留原样
    }
    if (href.endsWith('/') && out.length === 0 && i === 1) {
      continue; // 第一项通常是目录自身
    }
    const e = new DavEntry();
    e.href = href;
    const segs = href.split('/');
    let last = segs.length > 0 ? segs[segs.length - 1] : href;
    if (last.length === 0 && segs.length > 1) {
      last = segs[segs.length - 2];
    }
    const display = tagText(block, 'displayname').trim();
    e.name = display.length > 0 ? display : last;
    e.isDir = /collection/i.test(block);
    const len = Number(tagText(block, 'getcontentlength').trim());
    e.sizeText = e.isDir ? '' : prettySize(len);
    const mod = tagText(block, 'getlastmodified').trim();
    e.modified = mod.length > 10 ? mod.substring(5, 16) : mod;
    out.push(e);
  }
  return out;
}

@Entry
@Component
struct Browser {
  @State entries: DavEntry[] = [];
  @State currentPath: string = '/';
  @State message: string = '加载中…';
  @State loading: boolean = false;
  private conf: NasConfig = new NasConfig();

  aboutToAppear(): void {
    loadConfig(getContext(this) as common.UIAbilityContext).then((c: NasConfig) => {
      this.conf = c;
      this.list(this.currentPath);
    });
  }

  async list(path: string): Promise<void> {
    if (this.loading) {
      return;
    }
    this.loading = true;
    this.message = '加载中…';
    const ep: Endpoint = parseEndpoint(this.conf.address);
    if (!ep.valid) {
      this.message = '还没配置 NAS 地址，回首页填一下';
      this.loading = false;
      return;
    }
    const h: Map<string, string> = new Map<string, string>();
    h.set('Depth', '1');
    h.set('Content-Type', 'application/xml; charset=utf-8');
    if (this.conf.user.length > 0) {
      h.set('Authorization', basicAuth(this.conf.user, this.conf.pass));
    }
    const r: HttpResult = await request(ep.host, ep.port, 'PROPFIND', path, h, PROPFIND_BODY, 8000);
    if (r.status === 207 || (r.status >= 200 && r.status < 300)) {
      const items = parseDav(r.body);
      items.sort((a: DavEntry, b: DavEntry) => {
        if (a.isDir !== b.isDir) {
          return a.isDir ? -1 : 1;
        }
        return a.name.localeCompare(b.name);
      });
      this.entries = items;
      this.currentPath = path;
      this.message = items.length === 0 ? '这个目录是空的' : '';
    } else if (r.status === 401) {
      this.message = '401 需要认证：回首页填账号密码';
    } else if (r.status === 404 || r.status === 405 || r.status === 501) {
      this.message = `WebDAV 没开（HTTP ${r.status}）。到 NAS 控制面板 → 文件服务里开启。`;
    } else if (!r.ok) {
      this.message = `请求失败：${r.error}`;
    } else {
      this.message = `HTTP ${r.status}`;
    }
    this.loading = false;
  }

  goUp(): void {
    if (this.currentPath === '/' || this.currentPath.length === 0) {
      return;
    }
    const segs = this.currentPath.replace(/\/$/, '').split('/');
    segs.pop();
    const up = segs.length <= 1 ? '/' : `${segs.join('/')}/`;
    this.list(up);
  }

  build() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Button('← 返回')
          .height(34)
          .backgroundColor('#1B2430')
          .onClick(() => { router.back(); })
        Button('↑ 上级')
          .height(34)
          .backgroundColor('#1B2430')
          .onClick(() => { this.goUp(); })
        Blank()
        Button('刷新')
          .height(34)
          .backgroundColor('#1B2430')
          .onClick(() => { this.list(this.currentPath); })
      }
      .width('100%')

      Text(this.currentPath)
        .fontSize(12)
        .fontColor('#8A8F98')
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (this.message.length > 0) {
        Text(this.message)
          .fontSize(13)
          .fontColor('#E5A54B')
          .width('100%')
          .padding(10)
      }

      List({ space: 6 }) {
        ForEach(this.entries, (item: DavEntry) => {
          ListItem() {
            Row({ space: 10 }) {
              Text(item.isDir ? '📁' : '📄').fontSize(18)
              Column({ space: 2 }) {
                Text(item.name)
                  .fontSize(15)
                  .fontColor('#E6E8EB')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(`${item.sizeText}  ${item.modified}`)
                  .fontSize(11)
                  .fontColor('#5A626E')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .padding(10)
            .backgroundColor('#10161F')
            .borderRadius(8)
            .onClick(() => {
              if (item.isDir) {
                const base = item.href.endsWith('/') ? item.href : `${item.href}/`;
                this.list(base);
              }
            })
          }
        }, (item: DavEntry) => item.href)
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .backgroundColor('#0B1220')
  }
}
