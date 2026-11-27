
# cmux 主线程文本布局重入崩溃分析

- **发生时间**：2026-11-27 10:24:28 (+08:00)
- **软件版本**：`cmux` 0.65.2 (build 113)
- **运行环境**：macOS 15.6.1 (24G90) / Apple M4 Pro (ARM-64)
- **异常类型**：`EXC_BREAKPOINT (SIGTRAP)` — 主线程未捕获 Objective-C 异常

## 1. 崩溃原因

主线程在更新文本内容时触发了 **布局重入（Layout Re-entrancy）**，破坏了 `NSLayoutManager` 的内部字形索引一致性，导致 UIFoundation 抛出异常并使应用闪退：

1. **SwiftUI 刷新文本视图**：调用 `[NSTextView replaceCharactersInRange:withString:]` 替换文本，进入 `-[NSTextStorage endEditing]` -> `processEditing` 事务。
2. **通知中同步修改标尺宽度**：`cmux` 监听文本变更通知，在 `processEditing` 尚未完成时同步调用 `-[NSRulerView setRuleThickness:]`（如行号栏宽度随行数变化调整）。
3. **重入触发字形计算崩溃**：修改标尺厚度立即引起 `NSScrollView tile` -> `NSClipView setContentInsets:` -> `-[NSLayoutManager numberOfGlyphs]` -> `_fillGlyphHoleForCharacterRange...`。此时文本存储仍处于编辑事务中间态，状态不一致触发 `NSException`，被 AppKit 主循环拦截终止。

## 2. 临时规避措施

- **关闭行号或自动换行**：若 `cmux` 设置支持隐藏行号栏（Line Numbers / Ruler）或关闭自动换行（Soft Wrap），关闭后可避免触发布局重入路径。
- **减少高频边界触发**：避免在内置输入框/编辑器中单次粘贴超大文本，或在输出刷屏时高频拖拽调整分屏大小。

## 3. 修复建议（上游 Issue 参考）

- **根因**：在 `NSTextStorage` 的 `processEditing` / `textDidChange` 回调链中同步修改了 `NSRulerView.ruleThickness`。
- **解法**：使用 `DispatchQueue.main.async` 将标尺厚度更新推迟到当前 RunLoop 布局周期结束后执行。
