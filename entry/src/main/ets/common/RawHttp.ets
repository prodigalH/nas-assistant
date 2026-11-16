import socket from '@ohos.net.socket';
import util from '@ohos.util';

/**
 * 极简 HTTP 客户端（走 TCPSocket 自己拼请求）。
 *
 * 为什么不用 @ohos.net.http：它的 RequestMethod 是枚举，塞不进 WebDAV 的
 * PROPFIND（列目录）这种自定义方法。自己拼一个，GET/PROPFIND 都能用。
 * 只支持明文 HTTP —— NAS 在内网，够用；HTTPS 以后再说。
 */
export class HttpResult {
  ok: boolean = false;
  status: number = 0;
  statusText: string = '';
  headers: string = '';
  body: string = '';
  error: string = '';
  elapsedMs: number = 0;
}

function decode(buf: ArrayBuffer): string {
  const decoder = util.TextDecoder.create('utf-8');
  return decoder.decodeWithStream(new Uint8Array(buf), { stream: false });
}

export async function request(
  host: string,
  port: number,
  method: string,
  path: string,
  headers: Map<string, string>,
  body: string,
  timeoutMs: number = 8000,
): Promise<HttpResult> {
  const result = new HttpResult();
  const started = Date.now();
  const tcp = socket.constructTCPSocketInstance();

  let raw = '';
  let settled = false;

  const finish = (ok: boolean, error: string): void => {
    if (settled) {
      return;
    }
    settled = true;
    result.elapsedMs = Date.now() - started;
    result.ok = ok;
    result.error = error;
    try {
      tcp.close();
    } catch (e) {
      // 忽略关闭异常
    }
  };

  const parse = (): boolean => {
    const idx = raw.indexOf('\r\n\r\n');
    if (idx < 0) {
      return false;
    }
    const head = raw.substring(0, idx);
    const lines: string[] = head.split('\r\n');
    const first: string = lines.length > 0 ? lines[0] : '';
    const m: RegExpMatchArray | null = first.match(/^HTTP\/\d\.\d\s+(\d{3})\s*(.*)$/);
    if (m !== null) {
      result.status = Number(m[1]);
      result.statusText = m[2];
    }
    result.headers = head;
    const bodyText: string = raw.substring(idx + 4);
    let length = -1;
    for (let i = 1; i < lines.length; i++) {
      const lower: string = lines[i].toLowerCase();
      if (lower.startsWith('content-length:')) {
        length = Number(lines[i].substring(15).trim());
      }
    }
    if (length >= 0) {
      const bytes = new util.TextEncoder().encodeInto(bodyText);
      if (bytes.length < length) {
        return false; // 还没收全
      }
    }
    result.body = bodyText;
    return true;
  };

  const done = new Promise<void>((resolve) => {
    const timer = setTimeout(() => {
      finish(false, `超时（${timeoutMs}ms）`);
      resolve();
    }, timeoutMs + 500);

    tcp.on('message', (value: socket.SocketMessageInfo) => {
      raw += decode(value.message);
      if (parse()) {
        clearTimeout(timer);
        finish(true, '');
        resolve();
      }
    });

    tcp.on('close', () => {
      clearTimeout(timer);
      if (!settled) {
        parse();
        finish(raw.length > 0, raw.length > 0 ? '' : '连接被关闭且没有收到数据');
      }
      resolve();
    });

    tcp.on('error', (err: Object) => {
      clearTimeout(timer);
      finish(false, `socket 错误: ${JSON.stringify(err)}`);
      resolve();
    });
  });

  try {
    await tcp.connect({ address: { address: host, port: port, family: 1 }, timeout: timeoutMs });
  } catch (e) {
    finish(false, `连接失败: ${JSON.stringify(e)}`);
    return result;
  }

  let head = `${method} ${path} HTTP/1.1\r\nHost: ${host}\r\nConnection: close\r\n`;
  headers.forEach((v: string, k: string) => {
    head += `${k}: ${v}\r\n`;
  });
  head += '\r\n';
  const payload = head + body;

  try {
    await tcp.send({ data: payload });
  } catch (e) {
    finish(false, `发送失败: ${JSON.stringify(e)}`);
    return result;
  }

  await done;
  return result;
}

/** 把 http://ip:port 拆成 host/port；不带协议时默认 http。 */
export class Endpoint {
  host: string = '';
  port: number = 80;
  basePath: string = '';
  valid: boolean = false;
  error: string = '';
}

export function parseEndpoint(input: string): Endpoint {
  const ep = new Endpoint();
  let s = input.trim();
  if (s.length === 0) {
    ep.error = '地址为空';
    return ep;
  }
  if (s.startsWith('https://')) {
    ep.error = '暂只支持 http://（内网明文）';
    return ep;
  }
  if (s.startsWith('http://')) {
    s = s.substring(7);
  }
  const slash = s.indexOf('/');
  if (slash >= 0) {
    ep.basePath = s.substring(slash);
    s = s.substring(0, slash);
  }
  const colon = s.indexOf(':');
  if (colon >= 0) {
    ep.host = s.substring(0, colon);
    const p = Number(s.substring(colon + 1));
    ep.port = p > 0 ? p : 80;
  } else {
    ep.host = s;
    ep.port = 80;
  }
  ep.valid = ep.host.length > 0;
  if (!ep.valid) {
    ep.error = '缺少主机';
  }
  return ep;
}
