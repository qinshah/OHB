---
name: release
description: OHB 项目发版流程：升级版本号、生成 tag 更新信息、推送触发 GitHub CI。当用户要求"发版/发布新版本/打 tag/更新版本"时使用。
---

# OHB 发版流程

本项目（鸿蒙 ArkTS 应用）的版本发布由 GitHub Actions（Release CI）驱动：**推送 tag 即触发构建发布**。

## 发版步骤

### 1. 确定版本号并更新 AppScope/app.json5

```json5
{
  "app": {
    "versionCode": <版本号 * 1000000>,   // 0.2.0 → 2000000
    "versionName": "<x.y.z>",
  }
}
```

- `versionName`：语义化版本（用户可见）
- `versionCode`：`主版本 * 1000000` 递增（用于升级判定）

先执行 `git tag -l | tail -3` 查看上一个版本号，新版本 = 上一位递增（patch/minor/major 由用户指定或按变更规模判断）。

### 2. 提交版本变更

```bash
git add AppScope/app.json5
git commit -m "chore(release): 发布 vX.Y.Z 版本"
```

### 3. 生成 tag 更新信息（核心：从上一个 tag 总结）

tag 信息 = 从上一个 tag 到当前 HEAD 的变更总结，按以下方法生成：

```bash
git tag -l | tail -3                      # 找到上一个 tag，如 v0.1.0
git log v上一个tag..HEAD --oneline         # 列出区间内全部提交
```

然后将提交按功能模块归类（播放器/首页/我的页/架构规范…），每个模块提炼为条目，格式：

```
vX.Y.Z 更新内容

<模块名>
- <变更点>（合并多个相关 commit 为一条，说明"做了什么"，必要时带关键实现细节）
```

注意：
- 提交信息是细节视角，tag 信息是用户视角（更新日志），要合并同类项
- bug 修复写成"修复了 XX 问题"，而非"修改 XX 代码"

### 4. 创建 annotated tag

```bash
git tag -a vX.Y.Z -m "<第 3 步生成的更新信息>"
```

### 5. 推送并触发 CI

```bash
git push origin main
git push origin vX.Y.Z
```

tag 推送即自动触发 Release CI（构建 HAP 并创建 GitHub Release）。

### 6. 验证 CI

```bash
gh run list --repo qinshah/OHB --limit 3
```

确认新 tag 对应的 workflow 处于 queued/in_progress 状态（等待完成可 `gh run watch <id> --exit-status`）。
失败时用 `gh run view <id> --log-failed` 排查。

### 7. 发布 Release（draft → 正式版）

CI 创建的是 **draft** release，需手动转为正式版对外可见：

```bash
gh release edit vX.Y.Z --repo qinshah/OHB --draft=false --latest
gh release list --repo qinshah/OHB --limit 3   # 校验新版本显示 Latest
```

产物 `entry-default-unsigned.hap` 由 CI 附在 release 上，无需手动上传。

## 注意事项

- 发版前确认工作区干净：`git status`（`LandscapePortraitToggle/`、`PiliPlus/` 为本地参考项目，不提交）
- 版本号更新必须与 tag 同步，否则 CI 产物版本不一致
- tag 信息使用中文（与项目提交信息风格一致）
- 版本号编码规律：`versionCode = minor * 1000000 + patch * 1000`（如 v0.2.0 → 2000000，v0.2.5 → 2005000）
- 改动建议分模块多次提交（如 画质 / 取流 / 播放器 / 文档），不要一次性全提
