# Tasks

> 本轮目录与构建配置的改动已经落地在本地提交中，以下任务按「验证既有改动 + 收尾」组织，逐条给出可执行的核对方式。

## 1. 工具目录收敛

- [x] 1.1 运行 `node .agents/skills/sync-agent-dirs/scripts/sync-agents.mjs status --project .`，确认 `.qoder`、`.trae`、`.workbuddy` 三行状态均为 `linked`
- [x] 1.2 运行 `ls -la | grep -E '\.(qoder|trae|workbuddy) ->'`，确认三者都是指向 `.agents` 的软链而非目录
- [x] 1.3 确认 `.agents/skills/release/SKILL.md` 存在，且该 skill 出现在工具可用 skill 列表中

## 2. 白名单与追踪范围

- [x] 2.1 运行 `git status --short`，确认输出中没有任何 `.xxx` 软链与 `.agents-backup/`
- [x] 2.2 检查 `.gitignore` 标记块：每个白名单目录只占一行，`.agents` 外的手写规则未被改动
- [x] 2.3 运行 `git ls-files .agents`，确认追踪范围只包含 `skills`、`mcp`、`rules`、`commands` 白名单下的内容

## 3. 构建配置与签名隔离

- [x] 3.1 运行 `git show HEAD:build-profile.json5`，确认 `signingConfigs` 为空数组且不含签名相关键
- [x] 3.2 运行 `git log -p -- build-profile.json5 | grep -c 'certpath\|storePassword'`，确认结果为 `0`
- [x] 3.3 运行 `git ls-files -v build-profile.json5`，确认标记为 `S`（skip-worktree），且 `git status` 不提示该文件被修改
- [x] 3.4 确认根目录不存在 `build-profile.json5.example`，且 `.github/workflows/release.yml` 中不再有从模板复制构型的步骤

## 4. 构建验证

- [x] 4.1 执行 `DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon`，确认 `BUILD SUCCESSFUL` 且包含 `SignHap` 任务（本地签名仍然生效）
- [x] 4.2 运行 `git status --short`，确认构建前后工作区保持干净（无新增未忽略产物）

## 5. 收尾

- [x] 5.1 检查 `AGENTS.md` 末尾的目录与签名约定与当前实现一致，不存在对 `.codegenie` 等已删除目录的描述

## Workflow follow-up

- 推送 `main` 到 GitHub 属于对外可见操作，需用户明确同意后单独执行。
- 推送后观察一次 Release CI（`gh run list --repo qinshah/OHB`），确认不再依赖 `build-profile.json5.example` 也能构建成功。
