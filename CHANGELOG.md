# CHANGELOG

## 2058 — 基于 `e4e5c96`

### `file-diff` 块整段漏进正文（新）

**现象**（真机截图 2026-10-26 12:33）：正文里直接出现

```
<file-diff path="/mnt/android/sdcard/mod/smali/…/AppAttachHook.smali"
  details="Successfully applied AI code to file: …"><![CDATA[Changes: +42 -2 lines
@@ -51,10 +51,50 @@
…]]></file-diff>
```

**机制**：`CustomXmlRenderer` 解析不出块时，旧代码 `return SelectableText(parsed.body.isEmpty ? xmlContent : parsed.body)`
把原文当普通文本显示。上一版（2056）的修复只认 `tool/tool_result/param/content/…` 白名单，
**不含 `file-diff`**，于是又漏了。

**修法**：判定改成"标签白名单 **或** 带属性的开标签（`<名字 属性="…">`）"，并新增 CDATA 作为可读负载来源。
这样渲染层以后再加语义标签也不会再漏。

- 位置：`apps/flutter/app/lib/ui/features/chat/components/part/ProtocolMarkupRecovery.dart`、`CustomXmlRenderer.dart`
- 测试：`protocol_markup_recovery_test.dart` 8 条（含该 `file-diff` 真实形状），`flutter test` 全过
- 上游 PR：[#362](https://github.com/AAswordman/Operit2/pull/362)

## 2056 — 基于 `e4e5c96`

### `params` 里的字面换行会炸掉整轮（新）

**现象**（真实用户 #335 贴的载荷）：把多行脚本写进 `params` 时，JSON 字符串里是**真换行**而不是 `\n`：

```json
{"command":"python3 - <<'PY'
from pathlib import Path
...
PY
cp /sdcard/a /sdcard/b","timeoutMs":15000}
```

`serde_json` 必然报 `control character (\u0000-\u001F) found while parsing a string at line 2 column 0`，
而这条错误在流处理路径上被包成 `AiServiceError::RequestFailed`，于是**整轮对话消失**。

**修法**：解析前只把**字符串字面量内部**的裸控制字符转义（token 之间的换行保持不动），再解析。

- 位置：`core/crates/tool/services/src/ToolExecutionManager.rs`
- 测试：4 条，含上面这段真实载荷作为回归夹具
- 验证：`cargo test -p operit-tools --lib` → 175 passed / 0 failed

### 协议标记被当正文显示（新）

**现象**：屏幕上直接出现 `<tool_result name="…" status="success"><content>{…}</content></tool_result>`
和 `<tool name="package_proxy" call_id="part-177"><param name="params">…`。

**机制**：实时渲染把 XML 作为 `XmlBlock` 推给 UI（`MarkdownRenderStream` 的测试就是这么断言的），
由 `CustomXmlRenderer` 解析成工具卡片；**解析失败时旧代码把原文当普通文本显示**。
落库路径用的是另一个更严格的解析器（`MessagePartCodec`），所以库里是干净的、只有屏幕脏。

**修法**：降级分支不再显示标记本身 —— 是协议块就只显示 `<content>` 里的可读内容（并解实体），
没有可读内容就什么都不显示；普通文本保持原样。

- 位置：`apps/flutter/app/lib/ui/features/chat/components/part/ProtocolMarkupRecovery.dart`（新增）、`CustomXmlRenderer.dart`
- 测试：`apps/flutter/app/test/protocol_markup_recovery_test.dart`（5 条）

### 延续 2055 的内容

- #336 `terminal_wait` 改轮询（不再往忙的 PTY 写命令）
- #338 参数错误不再终止整轮；`Unknown tool parameter` 报出 accepted/received
- #340 `terminal_jobs` 名字→id
- #341 失败回合记真实 token
- #342 聊天 HTTP 超时（connect 15s / read 120s，共享单例）
- #343 Android PTY 卫生（每命令清屏、CSI 夹取、8 MiB 上限、回收子进程）

---

## Roadmap

1. **把补丁集迁移到上游 main `095c2ee`**（领先 158 个提交）。
   冲突面已摸清：11 个文件上游未动可干净套用，6 个需重新落补丁
   （`AIToolHandler.rs`、`JsToolManager.rs`、`hosts/android/src/terminal.rs`、
   `EnhancedAIService.rs`、`MessageProcessingDelegate.rs`、`llmprovider/mod.rs`）。
2. P6 与"A"补丁提到上游（PR）。
3. 继续跟进上游对 #336 的讨论（维护者认为"没复现"，已回复说明其报错即 bug 本身）。

## 关于证据

每条修复都附了真机证据：反代日志、数据库统计（如 128 个未关闭的终端会话、36/79 条 0 token 消息），
以及可复跑的单测。**没有一条是"看起来像 bug"就改的**；反过来我们也撤回了一条错误结论
（曾以为 `output` 缓冲只写不读，实际 `readPtySession` 会 drain 它）。
