# itms-services 网页安装

让用户「打开网页 → 点安装 → 桌面出现 App」的那套机制。iOS 弹的「要安装此描述文件吗」就是它。

## 能做什么、不能做什么

| | |
|---|---|
| 能 | 点一个链接直接装 App，不用数据线、不用装签名工具 |
| 不能 | **不能省掉签名**。ipa 必须已用企业证书（In-House）签好 |
| 不能 | 个人证书签的包装到未登记设备上会直接失败 |

用个人证书（Ad Hoc）也能走这个页面，但只有描述文件里登记过 UDID 的设备才装得上，对「给一群人用」没有意义。

## 需要准备

1. **企业证书**（Apple Developer Enterprise Program，$299/年）+ In-House 描述文件
2. 一个 **https** 的静态空间（自己的服务器、对象存储、GitHub Pages 都行）
3. 已签名的 ipa

## 三步

**第一步：出企业签名包**

仓库 Actions → Build IPA → `mode` 选 `enterprise`，拿到 `ScanDoc-enterprise.ipa`。
也可以本地：

```bash
xcodebuild -exportArchive -archivePath X.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath ./out
# ExportOptions.plist 里 method 写 enterprise
```

**第二步：生成 manifest.plist**

```bash
python tools/make_manifest.py \
  --ipa ScanDoc-enterprise.ipa \
  --base-url https://app.example.com/install \
  --icon icon.png
```

脚本会读 ipa 里的 Info.plist，自动填 Bundle ID 和版本，并打印要粘进 `index.html` 的 CONFIG。

**第三步：上传三个文件**

```
https://app.example.com/install/
├── index.html      安装页
├── manifest.plist  上一步生成的
├── ScanDoc-enterprise.ipa
└── icon.png        57×57 或 120×120，可选
```

把 `index.html` 里的 `CONFIG.manifestUrl` 改成 `https://app.example.com/install/manifest.plist`。

## 用户侧流程

1. 用 **Safari** 打开安装页（微信、QQ 内置浏览器会被拦）
2. 点「安装」→ 系统弹「要安装此描述文件吗」→ 允许
3. 回桌面，图标出现
4. 首次打开提示「未受信任的开发者」→ 设置 → 通用 → VPN 与设备管理 → 信任

## 服务器配置要点

- **必须 https**，http 会直接失败
- `manifest.plist` 的 `Content-Type` 建议设成 `text/xml` 或 `application/xml`；有些服务器给 `text/plain` 也能过，但设对更稳
- ipa 文件名**不要用中文和空格**，URL 编码问题很烦
- 大文件确保支持 Range 请求（断点续传），否则慢网下装到一半会失败

## 排查

| 现象 | 原因 |
|---|---|
| 点安装没反应 | manifest 地址错、不是 https、或页面不在 Safari 打开 |
| 提示「无法安装此 App」 | ipa 没签名，或签名证书不被信任 |
| 提示「无法连接服务器」 | manifest 里的 ipa URL 写错，或文件 404 |
| 装完打不开 | 需要去「VPN 与设备管理」信任企业开发者 |
| 突然全都打不开 | **证书被吊销了**，见下 |

## 风险须知

页面一旦公开，ipa 就变成任何人可下载。企业证书被 Apple 判定为对外分发就会吊销，**吊销是账号级即时生效**，所有装了的人当场打不开，没有离线补救。

所以：

- 用内网、或加访问控制（比如临时 token、公司 SSO）再放行
- 不要把这个链接发到公开群、论坛
- 只发给确实需要的人

想公开分发，「TestFlight」或者「上架 App Store」才是正路。
