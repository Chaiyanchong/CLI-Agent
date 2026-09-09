# checksums

本目录存放每个发布版本的 sha256 校验和文件：`checksums/<tag>.sha256`（每行 `<sha256>  <归档文件名>`，覆盖全部平台归档）。

- 一行安装器（`install.sh` / `install.ps1`）与 `cli-agent self-update` 从本仓库**默认分支**读取校验和，**fail-closed**（缺失或不匹配即中止）。
- **不要**使用 Release 附带的 `SHA256SUMS`——能替换 Release 资产的人可以在同一 API 调用里重生成附带校验和；默认分支文件在 reviewed 提交与永久历史之后。
