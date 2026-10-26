# operit-wrm

**Operit2 的非官方补丁版**：上游 `AAswordman/Operit2` 的源码 + 一组针对真实故障的修复，自己构建、自己签名、自己发布。

> ⚠️ **签名不同，不能覆盖安装。**
> 本仓库的 APK 用本地 key 签名（`SHA-256 c15a0e57c2a54463026ee6479dad86a9bef6985d4ee4b063390daa261b5bbe41`），
> 和官方包**不是同一个证书**。装之前必须先卸载官方版 —— 而卸载会**清掉 App 数据（对话、配置、身份）**。
> 想保留数据就别装这个包；想用就先自己做好备份。

---

## 为什么会有这个仓库

上游的 PR 长期无人合并（我们提了 6 个，最长挂了 4 天，0 回复、0 label），但问题是真的：

- 工具参数格式一错，**整轮对话直接消失**；
- 聊天 HTTP 请求**没有任何超时**，provider 不响应就一直挂着；
- 终端会话**从不关闭**，两天泄漏 128 个；
- 协议标记**漏进正文**，用户看到的是 `<tool_result …><content>…`。

所以这里的做法是：**补丁照提 PR，同时自己出可用构建**。PR 留着（万一有人接手），构建不等它们。

## 当前版本

| 版本 | 基于上游 | 说明 |
|---|---|---|
| `2056` | `e4e5c96`（2026-10-22） | 含下方全部补丁 |

> ⚠️ **落后上游 158 个提交**（上游 main 已到 `095c2ee`，2026-10-25）。
> 这是刻意先止血：先把已知故障修掉并出包，再把补丁集迁移到最新上游（见 `CHANGELOG.md` 的 roadmap）。

## 补丁清单

| 补丁 | 解决什么 | 对应 PR |
|---|---|---|
| 参数错误不再终止整轮 | `Proxy tool_name must be text` / 信封残缺 → 以前整轮死，现在是一条失败的工具结果 | [#338](https://github.com/AAswordman/Operit2/pull/338) |
| `Unknown tool parameter` 报出可用参数名 | 模型老发 OpenAI 风格的 `arguments`，被逐轮拒绝；现在错误里带 accepted/received | #338 |
| `terminal_wait` 改为轮询 | 以前往忙着的 PTY 里再写命令，必然报 `already has a command in progress` | [#336](https://github.com/AAswordman/Operit2/pull/336) |
| `terminal_jobs` 名字→id | 传会话名给只认 id 的 host，永远返回"会话不存在" | [#340](https://github.com/AAswordman/Operit2/pull/340) |
| 失败回合记真实 token | 失败/取消时消息记 0 token，而请求级用量已产生（79 条里 36 条为 0） | [#341](https://github.com/AAswordman/Operit2/pull/341) |
| 聊天 HTTP 补超时 | `reqwest::Client::new()` 15 处、0 处带超时；provider 不回就永久挂起 | [#342](https://github.com/AAswordman/Operit2/pull/342) |
| Android PTY 卫生 | 每条命令清屏、CSI 行列夹取、单命令 8 MiB 上限、回收子进程 | [#343](https://github.com/AAswordman/Operit2/pull/343) |
| `params` 里的字面换行 | 多行脚本写进 JSON 字符串 → `control character (\u0000-\u001F)` → 整轮消失 | 待提 |
| 协议标记不上屏 | 显示层认不出标签时把原始 XML 当正文显示 | 待提 |

更详细的证据（真机日志、复现步骤、A/B 结果）见 [`CHANGELOG.md`](CHANGELOG.md)。

## 怎么用

1. 从 **Releases** 下载对应版本的 `arm64-v8a` APK；
2. **先卸载官方版**（会丢数据，自己权衡）；
3. `adb install -r operit2-<版本>-*.apk` 或直接点安装。

> 资产上传说明：构建机上 `uploads.github.com` 不可达（`api.github.com` 正常），
> 所以 APK 可能需要在**能访问 GitHub 上传端点的网络**下、在 Release 页面手动拖拽上传。

## 怎么自己构建

和上游一致，只是先把补丁放上去：

```bash
# 1. 取上游源码（版本见上表"基于上游"）
git clone https://github.com/AAswordman/Operit2.git && cd Operit2
git checkout e4e5c96

# 2. 应用本仓库 patched-files/ 下的文件（覆盖同名文件）
#    每个文件顶部都有注释说明改了什么、为什么

# 3. 构建
cd tools/build_scripts
python build_flutter_android.py --build-name 2.0.0 --build-number 56
# versionCode = 2000 + build-number = 2056
```

Windows 上的工具链坑（Flutter OHOS fork、NDK libclang、pnpm/corepack 等）见上游 `build-notes` 类文档；
我们踩过的记录在 `BUILD-NOTES-WINDOWS.md`。

## 已知限制

- **没有做代码签名之外的任何加固**，这是给自用/尝鲜的构建，不建议装在有重要数据的设备上；
- 每个补丁都在 PR 里，但**上游可能用完全不同的方式修**，届时以官方为准；
- 终端/proxy 相关的诊断日志比官方版多，长期使用会略增日志体积。

## 与 `dsx-proxy` 的关系

`dsx-proxy`（自建的反向代理）是**独立项目**，不包含在本仓库的 APK 里。本仓库只涉及 Operit2 本体。
