# cli-agent

cli-agent 的**公开发布仓库**——下载页即本仓库的 [Releases](../../releases) 页。

- **产品**：在 Discord 里用一句话控制你的 Reolink 摄像头——拍照、看直播、查事件、布防报警、远程 PTZ，还能"看图说话"。
- **平台**：Windows 10/11 x64 / macOS 13+（arm64）/ Linux x86_64。
- **许可**：预构建二进制为**专有软件**（源码不公开；归档不附 EULA）。
- **隐私**：归档不含遥测（无 LangSmith）、不含 Discord token 或账号信息；权限设置（白名单/角色）由用户自行配置。
- **完整性校验**：每个归档的 sha256 提交在本仓库默认分支 [`checksums/`](checksums/README.md)，一行安装器与 `cli-agent self-update` 对照校验、**fail-closed**（详见 `SECURITY.md`，随首个版本发布）。

> 首个版本发布中。发布后，Releases 页置顶一行安装命令（Windows / macOS / Linux 各一条），无需管理员权限、装到用户目录。
