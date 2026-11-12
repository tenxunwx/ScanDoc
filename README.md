# ScanDoc · 纸质文档扫描（iOS / iPadOS）

一个原生 SwiftUI 扫描工具。对着纸拍一张，自动找边、拉正、去阴影，输出清晰的 PDF，需要时还能把文字抠出来。
全部功能跑在设备本地：不联网、不上传、不依赖任何第三方 SDK。

## 功能

- **自动找边 + 透视矫正**：用系统 VisionKit 文档相机，一次可连拍多页，拍歪的纸自动拉正
- **四种出图模式**：原图 / 增强 / 灰度 / 黑白（对应"彩色文档 / 白纸黑字 / 传真件"三类常见场景）
- **相册导入**：已有的照片也能当扫描件处理，一次最多 30 张
- **离线 OCR**：Vision 框架识别中英文，结果可全选复制
- **导出 PDF**：A4 排版、居中缩放，直接走系统分享（存文件 / 发微信 / 打印）
- **本地文档库**：按文档分组、重命名、单页删除、继续追加扫描
- **iPad 友好**：自适应网格，横竖屏都可用

## 目录结构

```
ScanDoc/
├── project.yml                  # XcodeGen 工程描述（不手写 .xcodeproj）
├── ScanDoc/
│   ├── ScanDocApp.swift         # 入口
│   ├── Models.swift             # 数据结构
│   ├── DocumentStore.swift      # 本地文档库 / 文件存储 / 导出
│   ├── ImageTools.swift         # CoreImage 增强管线、缩略图
│   ├── OCRService.swift         # Vision 文字识别
│   ├── PDFBuilder.swift         # A4 PDF 渲染
│   ├── DocumentScannerView.swift# 系统文档相机封装
│   ├── LibraryView.swift        # 文档库首页
│   ├── DocumentDetailView.swift # 文档详情（页列表）
│   ├── PageDetailView.swift     # 单页预览 / 换模式 / OCR
│   └── Support.swift            # 分享面板、纸张样式
└── .github/workflows/build-ipa.yml   # 云端编译：未签名 ipa 或带证书的 ipa
```

`.xcodeproj` 由 `project.yml` 生成，不进版本库，避免合并冲突。

> **为什么不能直接给你一个 ipa**：iOS 二进制必须在 macOS + Xcode 环境下编译，Windows 上没有任何工具能产出可运行的 iOS App 包。所以这里提供的是"云端编译"方案，用 GitHub 免费的 macOS 机器跑一次，你只需要下载结果。

## 出包方式一：云端编译（不需要 Mac）

### 1. 推到 GitHub

新建一个仓库，把 `ScanDoc` 目录里的全部内容传上去。公开或私有都行。
私有仓库每月 2000 分钟免费额度，macOS 按 10 倍折算 ≈ 200 分钟，单次构建约 3~5 分钟，够跑几十次。

### 2. 触发构建

仓库 → **Actions** → 左侧 **Build IPA** → 右上 **Run workflow**：

| 参数 | 填什么 |
|---|---|
| `mode` | **`unsigned`** ← 给全能签用，出的包不带签名，由手机上重签 |
| `bundle_id` | 留空即可；除非你的证书绑定的是别的 Bundle ID |

跑完（绿勾）→ 点进本次运行 → 页面底部 **Artifacts** → 下载 `ScanDoc-unsigned-ipa`，解压得到 `ScanDoc-unsigned.ipa`。

### 3. 导入全能签

1. 把 ipa 传到手机：微信「文件传输助手」、QQ、iCloud Drive、AirDrop 都行
2. 打开全能签 → 导入 ipa（一般是从「文件」App 里选，或者全能签会自动扫描下载目录）
3. 选你的证书签名 → 安装
4. 首次打开如果提示「不受信任的开发者」：设置 → 通用 → VPN 与设备管理 → 信任

**注意**：全能签签出来的有效期取决于你自己的证书。免费 Apple ID 只有 7 天，到期要重签一次；付费开发者证书是 1 年。

### 4. 想直接用证书签好（可选）

如果你不想在手机上签，也可以让云端直接用你的证书签完，出来就是能装的包：

先在仓库 **Settings → Secrets and variables → Actions** 里配好：

| Secret | 必填 | 值 |
|---|---|---|
| `BUILD_CERTIFICATE_BASE64` | 是 | `.p12` 的 base64 |
| `P12_PASSWORD` | 是 | 导出 `.p12` 时的密码 |
| `PROVISIONING_PROFILE_BASE64` | 是 | `.mobileprovision` 的 base64 |
| `KEYCHAIN_PASSWORD` | 否 | 随便一串，CI 临时钥匙串用 |
| `TEAM_ID` | 否 | 十位 Team ID，留空自动从描述文件读 |

转 base64（Mac 上）：

```bash
base64 -i certificate.p12 -o certificate.b64
base64 -i profile.mobileprovision -o profile.b64
```

Windows 上可以用 `certutil -encode 文件名 输出名`，然后手动删掉首尾的 `-----BEGIN/END-----` 行。

然后把 `mode` 选成 `development`（装自己或团队已注册设备）或 `ad-hoc`（装指定 UDID 的设备）。

**这里最容易踩的坑**：`bundle_id` 必须和描述文件里的 App ID 完全一致，否则报 `Provisioning profile doesn't match the bundle identifier`。

## 出包方式二：借一台 Mac 用 Xcode

不需要任何 Secrets，调试也最快：

```bash
brew install xcodegen
cd ScanDoc
xcodegen generate
open ScanDoc.xcodeproj
```

Xcode 里选中 ScanDoc target → Signing & Capabilities → 勾 Automatically manage signing → 选你的 Team → 连上设备直接 Run。

想手动出未签名 ipa（给全能签）：

```bash
cd ScanDoc
xcodegen generate
xcodebuild archive -project ScanDoc.xcodeproj -scheme ScanDoc \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath build/ScanDoc.xcarchive \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""

mkdir -p build/Payload
cp -R build/ScanDoc.xcarchive/Products/Applications/ScanDoc.app build/Payload/
cd build && zip -qry ScanDoc-unsigned.ipa Payload
```

## 证书类型与有效期

| 证书类型 | 有效期 | 说明 |
|---|---|---|
| 免费 Apple ID（Personal Team） | 7 天 | 到期 App 打不开，重签续期；最多 3 个 App、不能推送 |
| 付费个人/公司开发者（$99/年） | 1 年 | 可 TestFlight、可 Ad Hoc 分发到最多 100 台设备 |

## 常见问题

**Actions 报 `xcodebuild: error: Unable to find a destination`**
runner 镜像换了，把 `runs-on: macos-14` 改成 `macos-15` 试一次。

**`No signing certificate "iOS Development" found`**
`.p12` 里没带私钥，或者导出的不是开发证书。重新从「我的证书」导出，确认带私钥。

**`Provisioning profile doesn't include signing certificate`**
描述文件里没勾这张证书。开发者后台编辑 Profile，勾上证书重新下载。

**全能签导入后闪退**
大概率是证书和 Bundle ID 不匹配，或者描述文件过期。先确认证书本身还有效，再试一次。

**编译报错**
代码是在没有 macOS 的环境下写的，第一次跑可能出现 API 可用版本之类的编译错误，把日志贴出来照着修就行。

## 后续可以加的东西

- PDF 加不可见的 OCR 文字层，让导出的 PDF 可搜索
- 裁切后手动微调四个角点
- 拍照时自动去手指遮挡
- iCloud 同步 / PDF 密码加密
- 批量导出、按日期归档

要哪个直接说，我在这份代码上接着改。
