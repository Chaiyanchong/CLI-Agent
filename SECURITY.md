# cli-agent 安全说明

本文件说明 cli-agent 的**完整性校验能证明什么、不能证明什么**，捆绑第三方
二进制的信任模型，本地凭据存储，以及安全问题报告渠道。面向进阶用户与安全
评审者；普通用户可只看「下载校验」一节。

## 下载校验：能证明什么 / 不能证明什么

cli-agent 的预构建二进制**未签名**（无 Authenticode / GPG / build attestation）。
这与上游 [reolink-cli](https://github.com/reolink/reolink-cli) 的立场一致——其
SECURITY.md 明确「integrity, not authenticity」（保完整性，不保发布者身份）。

**sha256 对照本仓库默认分支 `checksums/<tag>.sha256` 能防：**

| 威胁 | 能否防住 | 说明 |
|---|---|---|
| 发布后 Release 资产被替换 | ✅ | 校验和落在默认分支（永久历史、经 reviewed PR），资产被换则 sha256 对不上 |
| 下载镜像 / CDN 投毒 | ✅ | 校验和源钉死在默认分支，不随归档下载源变化 |
| 传输损坏 / 截断 | ✅ | 任何字节变化都会改变 sha256 |

**sha256 对照防不住（如实披露）：**

| 威胁 | 能否防住 | 说明 |
|---|---|---|
| 维护者 GitHub 账号被入侵 | ❌ | 攻击者能同时改资产与默认分支校验和 |
| 构建机被入侵 | ❌ | 攻击者能产出「资产 + 校验和」一致但被植入后门的构建 |
| 供应链上游（依赖）被投毒 | ❌ | 见下「捆绑第三方二进制」 |

**缓解（v1 现状）：** 构建在**私有环境**（源码留 SVN、三台构建机、人工触发，
不在公共 CI），降低公共构建机被入侵面；校验和由发布流程提交到默认分支（经
reviewed PR + 永久历史）。**GitHub build attestation 因构建不在 Actions 而
不可用**——这是已记录的未实现缺口。

## 捆绑第三方二进制的信任模型

每个归档捆绑两个第三方二进制（见归档内 `THIRD-PARTY-LICENSES.txt`）：

- **reolink-cli / reolink-gateway**（专有，上游未签名）：版本 + 资产名钉死在
  构建 lock（`packaging/third_party.lock.json`，随源码，不进本仓库）；sha256
  对照 **reolink-cli 仓库默认分支** `checksums/v<ver>.sha256`（**不用** Release
  附带的 SHA256SUMS——能替换资产者能在同一 API 调用里重生成附带校验和）。
- **ffmpeg / ffprobe**（GPL 静态构建）：具体构建 URL + sha256 钉死在 lock。

信任模型与上游完全对齐：sha256 防「发布后替换 / 镜像投毒 / 传输损坏」，防不了
「上游维护者账号或构建机被入侵」。没有更强的验证可做（上游未签名）。

## 本地凭据存储

cli-agent 在**用户目录**存储凭据与配置，**不写系统目录、不需管理员权限**：

| 内容 | 位置 | 权限 |
|---|---|---|
| 模型 API key / Discord token（`.env`） | 安装前缀 `config/.env`（由 `.env.example` 复制） | 0600（Unix）/ 用户 ACL（Windows） |
| reolink-cli 配置（`aliases.toml` 等） | reolink-cli 自身约定（Windows `%APPDATA%\reolink-cli`；Unix `~/.config/reolink-cli`） | 0600（由 `reolink-cli init` 设置） |
| agent 工作区（会话 / 审计 / 媒体） | `~/reolink-agent`（`CLI_AGENT_HOME` 可覆盖） | 用户私有 |

**安装前缀与用户数据完全分离**：`self-update` / 重装只替换安装前缀，客户配置、
摄像头注册表、会话历史零风险。

> 提示：`.env` 含明文 token，请勿提交到任何版本库（本项目 `.env` 已移出 SVN，
> 仅 `.env.example` 模板入库）。

## 与上游 reolink-cli 的差异（如实说明）

- **构建环境**：cli-agent 在私有环境构建（SVN 源码 + 三台构建机 + 人工触发），
  不在公共 GitHub Actions；因此**无 build attestation**。
- **校验和提交**：由发布流程（`publish_release`）提交到本仓库默认分支，经
  reviewed PR + 永久历史。
- **产品名**：`cli-agent`（不含 Reolink 商标字样），捆绑的 reolink-cli 为上游
  专有二进制，按上游条款分发。

## 报告安全问题

发现安全问题请**不要**开公开 Issue，改用以下渠道（择一，附最小复现）：

- 邮件：`security@<maintainer-domain>`（首个版本发布时在此填入实际地址）
- GitHub Security Advisories：本仓库 `Security → Advisories → New draft`（开启后）

我们承诺对有效报告致谢（如你愿意署名）。
