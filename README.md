# cli-agent

**用一句话控制你的 Reolink 摄像头**——拍照、看直播、查事件、布防报警、远程 PTZ、"看图说话"。
两个通道，同一个 AI 大脑：

- 💬 **Discord bot**：在 Discord 频道里 @ 它或发消息，带白名单 / 角色权限 / 操作审计，适合家庭与团队多设备共享。
- 🖥️ **本地网页**：PC 上打开一个本地网页对话页，无登录、无 Discord 依赖，模型与 API 直接在网页里配置，适合单人自用与快速体验。

---

## 能力集

cli-agent 通过 [reolink-cli](https://github.com/reolink/reolink-cli) 的 gateway 访问摄像头，把 ~100 条 CLI 命令封装成一个听得懂人话的 AI agent。

### 摄像头控制

| 能力 | 说明 |
|---|---|
| 📷 快照 | 拍照并回传图片（Discord 附图 / 网页内联显示） |
| 🎮 PTZ 云台 | 上下左右转动、变焦、聚焦、预置位调用 |
| 💡 灯光 | 红外灯 / 探照灯 / LED 开关与亮度 |
| 🔍 检测 | 运动 / AI 检测（人 / 车 / 包裹）配置与时间表 |
| 📼 录像 | 历史录像（VOD）查询与下载 |
| 🔧 系统 | 重启、固件升级、用户管理、WiFi |
| 🌐 流媒体 | 获取 RTSP / RTMP 流地址 |
| 🔊 音频 | 双向通话、TTS 语音播放、音量 / 静音 |
| 📡 事件 | 事件查询、监控规则、事件时间线 |
| 🛡️ 布防 | 报警闭环（一键把某摄像头报警推到指定频道）、警号 |
| 🎬 场景 | 场景 / 日程自动化 |
| 🩺 诊断 | 健康检查、状态、基准测试 |

### Agent 智能（v3.17.0 起）

- **看图说话**：对快照做视觉问答（"门口那个人在干什么？"）。
- **偏好学习**：记住你的常用设置（未经确认不保存）。
- **事件去重 / 聚类**：同一事件不重复打扰。
- **自然语言 → 规则**：说人话即可生成可编辑的监控规则。
- **授权内自动处置**：在授权范围内自动响应，未授权不执行。
- **持续健康推送**：只在状态翻转时推送，不刷屏。

### 实时画面（v3.18.0 起）

- **快照面板**：一键抓取当前画面。
- **直播流面板**：网页内 WebCodecs 实时解码 H.264 / HEVC 直播流（与 Discord `/live` 同源）。

### 安全与治理（Discord 通道）

- **per-user 权限**：`owner` / `member` / `viewer` 三角色，高危操作按角色分级确认。
- **操作审计**：SQLite 记录每次高危操作。
- **HITL 确认**：高危操作（重启 / 升级 / 删用户）弹确认按钮，120 秒未确认自动取消。

> 本地网页通道**不含**权限 / 审计 / 角色模块（无登录，单用户自用），但同样带 HITL 高危确认。

---

## 平台 / 许可 / 隐私 / 完整性

- **平台**：Windows 10/11 x64 / macOS 13+（arm64）/ Linux x86_64。
- **许可**：预构建二进制为**专有软件**（源码不公开；归档不附 EULA）。
- **隐私**：归档不含遥测、不含 Discord token 或账号信息；权限设置（白名单 / 角色）由用户自行配置。
- **完整性**：每个归档的 sha256 提交在本仓库默认分支 [`checksums/`](checksums/README.md)，一行安装器与 `cli-agent self-update` 对照校验、**fail-closed**（详见 [`SECURITY.md`](SECURITY.md)）。

---

## 快速开始

无需管理员权限，装到用户目录。

**Windows（PowerShell）**

```powershell
powershell -NoProfile -Command "iwr https://raw.githubusercontent.com/Chaiyanchong/CLI-Agent/main/install.ps1 -UseBasicParsing | iex"
```

**macOS / Linux**

```sh
curl -fsSL https://raw.githubusercontent.com/Chaiyanchong/CLI-Agent/main/install.sh | sh
```

安装后验证：

```sh
cli-agent --version
```

### 前置：reolink-cli + gateway

cli-agent 依赖 [reolink-cli](https://github.com/reolink/reolink-cli) 的 gateway 访问摄像头。若尚未安装：

```sh
# 1. 安装 reolink-cli（见其仓库 README）
curl -fsSL https://raw.githubusercontent.com/reolink/reolink-cli/main/install.sh | sh

# 2. 启动 gateway（agent 运行必需，常驻）
reolink-cli gateway start --addr 127.0.0.1:9000

# 3. 添加摄像头（口令交互输入，勿写进命令行）
reolink-cli device add front-door --host 192.168.1.41 --user admin
```

---

## 通道一：Discord bot

### 1. 创建 Discord 应用

1. 打开 [Discord Developer Portal](https://discord.com/developers/applications) → **New Application**。
2. **Bot** 页 → **Reset Token**，复制 token（只显示一次）。
3. **Privileged Gateway Intents** 开启 `SERVER MEMBERS INTENT`（白名单需要）。
4. **OAuth2 → URL Generator**：勾选 `bot` + `applications.commands`，Scope 选 `bot`，Permission 给 `Send Messages` / `Embed Links` / `Attach Files` / `Read Message History`，用生成的 URL 把 bot 拉进你的服务器。

### 2. 配置

配置分两部分：**bot token 走环境变量**（不写进文件），**其余走 `bot_config.json`**。

**① 设置 bot token 环境变量**（值不落地，安全）：

```sh
# macOS / Linux
export DISCORD_BOT_TOKEN="你的 bot token"
# Windows PowerShell
$env:DISCORD_BOT_TOKEN="你的 bot token"
```

**② 编辑 `bot_config.json`**（默认在 `~/reolink-agent/`，首次运行生成）。关键项：

```jsonc
{
  "discord_token_env": "DISCORD_BOT_TOKEN",  // token 的环境变量名（缺省即此）
  "model": "gpt-4o",                          // 模型 key，见下方"模型配置"
  "agent_home": "~/reolink-agent",
  "allowed_user_ids": [1234567890],           // 白名单（必填，为空拒绝启动）
  "user_roles": { "1234567890": "owner" },    // 角色：owner / member / viewer
  "default_role": "viewer"                    // 未列明用户的缺省角色
}
```

> `allowed_user_ids` 是**硬门槛**：为空时 bot 拒绝启动。你的 Discord user_id 可在
> Discord 设置 → 高级 → 打开"开发者模式"，然后右键自己头像 → 复制 ID 获得。

**③ API Key** 放环境变量（或 `agent_home/.env`）：`OPENAI_API_KEY` / `ANTHROPIC_API_KEY` / `GOOGLE_API_KEY` 等。

### 3. 运行

```sh
cli-agent            # 缺省即 Discord bot
```

### 4. 使用

在频道里直接发消息即可，例如：

- "front-door 健康吗？"
- "拍张快照"
- "把摄像头往左转"
- "重启摄像头"（高危，会弹确认按钮）

**Slash 命令**

| 命令 | 作用 |
|---|---|
| `/new` | 本频道重开会话 |
| `/model list` | 列出可用模型（含 API Key 状态） |
| `/model use <key>` | 运行时切换模型（保留历史） |
| `/live <alias>` | 本频道开直播片段循环（约 5s 一段自动播放，回 `stop` 结束） |
| `/alarms enable <device> [trigger]` | 一键把该摄像头报警（快照 + 消息）推到本频道 |
| `/alarms disable <device>` | 移除该摄像头报警规则 |
| `/alarms status` | 报警闭环状态 |
| `/perms list` | 列出白名单用户与角色（仅 owner） |
| `/perms add <user_id> [role]` | 加白名单（仅 owner） |
| `/perms role <user_id> <role>` | 改角色（仅 owner） |
| `/perms remove <user_id>` | 移除白名单（仅 owner） |
| `/status` | bot / gateway 状态 |
| `/help` | 帮助 |

> 长回复自动分段；快照等图片自动附图；高危操作 120 秒未确认自动取消。

---

## 通道二：本地网页（PC）

无登录、无 Discord 依赖。模型 / API / gateway 地址**全部在网页界面里配置**，改完即生效（无需改文件、无需重启）。

### 1. 运行

```sh
cli-agent --web          # 启动本地网页，自动打开浏览器
```

默认监听 `http://127.0.0.1:8787`（仅本机可访问）。可选参数：

```sh
cli-agent --web --port 9000 --no-browser   # 改端口、不自动开浏览器
```

### 2. 配置（网页内完成）

打开网页后点右上角 **⚙ 设置**：

- **模型**：下拉选择预设模型（云端 / 本地）。
- **API Key**：为所选模型填 Key（存本机 `web_config.json`，0600 权限，不上传）。
- **自定义模型**：填 `key` / 显示名 / `base_url` / `api_key`，即可接入任意 OpenAI 兼容端点（vLLM / llama.cpp / LM Studio / 自建网关）。
- **gateway 地址**：缺省 `http://127.0.0.1:9000`，gateway 不在默认端口时改这里。

保存后即时热切换模型（有进行中的对话时拒绝切换，避免串话）。

### 3. 使用

- **对话**：左侧新建会话，直接发消息（自然语言，能力集与 Discord 一致）。
- **实时画面**：点顶栏 **📺 直播** 选摄像头，开直播流面板（WebCodecs 实时解码）或抓快照。
- **高危确认**：agent 触发高危操作时，聊天区出现审批卡片，点 **批准 / 拒绝**（支持单条与全部）。
- **回放**：会话历史可回看，工具调用与结果按时间线还原。

> 本地网页与 Discord bot **可并存**（各自独立进程、独立 agent 实例，共享同一 `agent_home`）。

---

## 模型配置（云端 + 本地）

cli-agent 复用统一模型注册表，支持多厂商云端 API 与本地部署模型，**换模型不改代码**。

### 预设模型

| Key | 模型 | 需要 |
|---|---|---|
| `gpt-4o` / `gpt-4o-mini` | OpenAI GPT-4o 系列 | `OPENAI_API_KEY` |
| `o1-mini` / `o1-preview` | OpenAI o1 系列 | `OPENAI_API_KEY` |
| `claude-3-5-sonnet` / `claude-3-opus` / `claude-3-haiku` | Anthropic Claude 3 系列 | `ANTHROPIC_API_KEY` |
| `gemini-1.5-pro` / `gemini-1.5-flash` | Google Gemini 1.5 | `GOOGLE_API_KEY` |
| `deepseek-coder` | DeepSeek Coder | `DEEPSEEK_API_KEY` |
| `ollama-<name>` | 任意 Ollama 本地模型 | 本地 Ollama（`localhost:11434`） |

### 本地 / 自建端点

- **Ollama**：模型 key 用 `ollama-<模型名>`（如 `ollama-llama3`），无需 API Key。
- **OpenAI 兼容端点**（vLLM / llama.cpp / LM Studio 等）：在网页 **设置 → 自定义模型** 填 `base_url` + `api_key` 即可，无需改代码。
- **逃生通道**：`provider:model` 形式（如 `openai:gpt-4o`）走通用路径。

> 本地端点（`localhost` / 内网 IP）直连、不走系统代理，避免被代理拦截。

---

## 详细指南

安装目录的 `docs/` 内随包附带完整指南（本仓库不重复存放）：

- **`docs/WEB_使用指南.md`** — 本地网页通道：界面逐区讲解、模型 / 自定义端点配置、直播面板、审批、回放、排障。
- **`docs/DISCORD_使用指南.md`** — Discord 通道：应用创建、白名单 / 角色、审计、报警闭环、直播、排障。
- **`docs/REOLINK_AGENT_使用说明书.md`** — 能力全集与 reolink-cli 依赖说明。

> 安装后路径：Windows `%USERPROFILE%\.local\bin\cli-agent\docs\`；macOS / Linux `~/.local/bin/cli-agent/docs/`。

---

## 升级

```sh
cli-agent self-update        # macOS / Linux 原地替换；Windows 给出下载指引
```

或重跑一行安装器（幂等，覆盖两个二进制）。

## 卸载

```sh
cli-agent setup --uninstall --no-interactive --agents none
# 加 --purge 连配置 / 别名 / 缓存 / 规则一并清除（删除摄像头注册，不可逆，先确认）
```

---

## 故障速查

| 症状 | 处理 |
|---|---|
| `cli-agent: command not found` | 安装前缀不在 PATH：`export PATH="$HOME/.local/bin:$PATH"`（Windows：`$env:PATH += ";$HOME\.local\bin"`） |
| `gateway connect failed: Connection refused` | gateway 没起：`reolink-cli gateway start --addr 127.0.0.1:9000` |
| 网页打不开 / 端口占用 | 换端口：`cli-agent --web --port 9000` |
| 模型调用 401 / 403 | API Key 错或额度不足；网页设置里重填 |
| 直播黑屏 | 浏览器需支持 WebCodecs（Chrome / Edge 新版）；确认 gateway 在跑、摄像头在线 |
| 校验失败 `checksum mismatch` | 多为下载被截断 / 代理篡改，重试一次；仍失败请到仓库安全公告页报告，**勿**绕过校验 |

更多见 [`SECURITY.md`](SECURITY.md) 与安装目录 `docs/`。
