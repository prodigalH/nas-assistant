# NAS 助手（nas-assistant）

[![build](https://github.com/prodigalH/nas-assistant/actions/workflows/build.yml/badge.svg)](https://github.com/prodigalH/nas-assistant/actions/workflows/build.yml)


一个连铁威马（TerraMaster）NAS 的鸿蒙小工具。用 ArkTS + Stage 模型写的，纯本地、无后端、不联网上报。

> 目标很朴素：**在手机上快速确认家里的 NAS 活着没有，并且能翻一下共享目录。**

## 功能

| 功能 | 说明 |
| --- | --- |
| 连接配置 | 填 NAS 地址（`192.168.1.10` 或 `http://192.168.1.10:8181`）、账号、密码，存在本地 `preferences` |
| 状态探测 | 直接走 TCP 发 HTTP 请求，显示「在线 / 连不上」+ 延迟毫秒数 |
| 文件浏览 | 走 **WebDAV**（`PROPFIND`）列目录，支持进入子目录、返回上级、显示大小与修改时间 |
| 本地设置 | 查看已保存配置、一键清除 |

## 为什么自己写 HTTP 客户端

HarmonyOS 的 `@ohos.net.http` 把 `method` 定成了枚举，塞不进 WebDAV 的 `PROPFIND` 这种自定义动词。
所以 `common/RawHttp.ets` 里用 `@ohos.net.socket` 的 TCPSocket 自己拼 HTTP 报文，GET / PROPFIND 都能发。

代价：只支持**明文 HTTP**（内网够用），不支持 HTTPS，不处理 chunked 编码。

## 构建

这台机器上没有 DevEco Studio，下面这套是**命令行闭环**，实测能出 hap。

### 依赖

| 组件 | 版本 | 说明 |
| --- | --- | --- |
| OpenHarmony SDK | 4.1.7.5-Release（API 11） | `repo.huaweicloud.com/openharmony/os/4.1-Release/ohos-sdk-windows_linux-public.tar.gz` |
| hvigor | 4.1.2 | 从华为 npm 源装：`npm i --registry=https://repo.harmonyos.com/npm/ @ohos/hvigor@4.1.2 @ohos/hvigor-ohos-plugin@4.1.2` |
| JDK | 17 | 打包阶段 `spawn java` 要用 |

### 步骤

```sh
# 1) 准备 SDK（解压后目录形如 sdk/11/{ets,toolchains,js,native,previewer}）
export DEVECO_SDK_HOME=/path/to/sdk

# 2) 装 hvigor
npm i --registry=https://repo.harmonyos.com/npm/ @ohos/hvigor@4.1.2 @ohos/hvigor-ohos-plugin@4.1.2

# 3) 编译
export PATH=/path/to/jdk-17/bin:$PATH
./hvigorw assembleHap -p product=default -p buildMode=release --no-daemon

# 产物：entry/build/default/outputs/default/entry-default-unsigned.hap
```

或者直接跑 `./build.sh`（需要先 `export DEVECO_SDK_HOME=/path/to/sdk`）。

### GitHub Actions

推 `main` 会跑 [`.github/workflows/build.yml`](.github/workflows/build.yml)：

1. 装 JDK 17 + Node 22；
2. 从华为镜像拉 SDK（2.3 GB，**有缓存**，key 是 SDK 版本号，之后秒过）；
3. 从华为 npm 源装 hvigor 4.1.2；
4. `assembleHap` 出未签名 hap；
5. 上传到 Actions artifact（`nas-assistant-hap`）；
6. **推 tag（`v*`）时**自动发 Release 并附上 hap。

想在 CI 里顺便签名，就把 `.p12/.cer/.p7b` 存成 repository secrets，
在编译前 restore 出来、在 `build-profile.json5` 里指向它们即可（自行添加，本仓库不含签名材料）。

## ⚠️ 关于签名

**仓库里的 hap 是未签名的**，只能当产物归档，**装不进真机**。

HarmonyOS 要求应用用开发者证书签名后才能安装，证书需要在
[AppGallery Connect](https://developer.huawei.com/consumer/cn/service/josp/agc/index.html) 申请，
拿到 `.p12` / `.cer` / `.p7b` 后：

1. 在 `build-profile.json5` 的 `signingConfigs` 里配好；
2. 重新 `assembleHap`；
3. `hdc install xxx.hap` 安装。

这一步必须用你自己的开发者账号，没法代劳。

## 使用前提

NAS 上要开启 **WebDAV**：控制面板 → 文件服务 → WebDAV，记下端口（默认 5005 或 8080）。
没开的话「浏览文件」会明确告诉你 `WebDAV 没开（HTTP 404/405/501）`。

## 目录

```
AppScope/            应用级配置与图标
entry/
  src/main/
    ets/
      entryability/  入口 Ability
      pages/         Index（连接）/ Browser（文件）/ Settings（设置）
      common/        RawHttp（自写 HTTP）/ Config（本地配置 + Basic Auth）
    resources/       字符串、颜色、图标
build-profile.json5  工程与 SDK 版本
hvigor/              hvigor 配置
```

## License

MIT
