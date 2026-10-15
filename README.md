# Han1mePlus 安装源

给 [Han1mePlus](https://github.com/1wc10086/Han1mePlus) 用的 AltStore 格式安装源，
可以直接在 **SideStore / LiveContainer / AltStore Classic** 里添加，一键安装与更新 iOS 版，
不用每次手动去上游 Releases 下载 ipa。

## 源地址

```
https://raw.githubusercontent.com/saki3525/han1meplus-source/main/altstore/source.json
```

国内直连 `raw.githubusercontent.com` 经常不通，可以换成 jsDelivr：

```
https://cdn.jsdelivr.net/gh/saki3525/han1meplus-source@main/altstore/source.json
```

> jsDelivr 有缓存，上游刚发新版时可能要等几分钟到几小时。

### 添加方式

- **SideStore**：`源` → 右上角 `+` → 粘贴上面的地址
- **LiveContainer**：`Sources` → `+` → 粘贴上面的地址
- **AltStore Classic**：`Browse` → 左上角 `+` → 粘贴上面的地址

## 说明

- 上游发布的 ipa **app 主体未签名**（内嵌的 Flutter/App/objective_c framework 保留引擎自带签名），
  SideStore / LiveContainer 会用你自己的证书重新签名后安装。
- 因此需要特殊权限的能力（例如依赖 `associated-domains` 的 Universal Link）在自签环境下不可用。
- 免费 Apple ID 的 7 天有效期限制与本源无关。
- 本源包含上游所有带 `iphone.arm64.ipa` 的版本，可以往下装旧版用于降级。

## 这个仓库是怎么工作的

```
1wc10086/Han1mePlus 的 Releases
        │  只读 API，不拉代码
        ▼
altstore/generate.py  ──►  altstore/source.json  ──►  用户添加的源地址
        ▲
        │  每 6 小时 / 手动触发
.github/workflows/update-source.yml
```

| 文件 | 作用 |
| --- | --- |
| `altstore/source.json` | 生成出来的源本体，就是用户添加的那个文件 |
| `altstore/generate.py` | 生成器，只用 Python 标准库 |
| `.github/workflows/update-source.yml` | 每 6 小时检查一次上游有没有新 Release，有就重新生成并提交 |
| `.github/workflows/sync-upstream.yml` | 可选：把上游 `main` 镜像到本仓库的 `upstream` 分支 |

生成器做三件事，保证 JSON 和真实 ipa 严格一致：

1. 从 Releases API 取每个 Release 的 ipa 地址、字节数、`sha256`；
2. 从**每个 tag 的 `pubspec.yaml`** 读取真实的 `version+build`（不是从 tag 名猜的）；
3. 按 `(version, buildVersion)` 去重、按版本号倒序排列，最新版在最前面。

### 手动触发

Actions → **Update AltStore source** → `Run workflow`，或者本地：

```powershell
python altstore/generate.py
```

可用环境变量：`REPO`、`REF`、`IPA_ASSET`、`OUTPUT`、`GITHUB_TOKEN`、`INCLUDE_PRERELEASE=1`。

### 注意：定时任务会被自动停用

GitHub 的规则是：仓库 **60 天没有任何活动** 就会暂停 `schedule` 触发的 workflow。
本仓库只要有新 Release 进来就会产生一次 bot 提交，通常不会触发这条规则；
万一被停用了（Actions 页面会有提示），点一下 `Enable workflow` 或手动 `Run workflow` 即可恢复。
实在不放心，也可以把定时检查换成别的触发器，或者需要更新时手动跑一次。

## 许可

`altstore/generate.py` 是本仓库自己的代码。被分发的 Han1mePlus 应用本身遵循
[AGPL-3.0](https://github.com/1wc10086/Han1mePlus/blob/main/LICENSE)，本仓库只索引它的发布产物，
不对该应用做任何修改。本应用为非官方第三方客户端，仅供年满 18 周岁的成年人使用。
