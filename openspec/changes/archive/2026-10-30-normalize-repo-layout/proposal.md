# Proposal

## Why

各家 AI 工具的项目级目录（`.qoder`、`.trae`、`.workbuddy` 等）此前各自为政：同一份 skill 只要换一个工具就要复制一遍，git 也无法判断哪些内容该入库。同时 `build-profile.json5` 被 `.gitignore` 忽略、CI 靠 `.example` 兜底，本地与 CI 的构建输入长期漂移，而签名材料（`certpath`、`keyPassword`、`storePassword`）随时有被误提交的风险。

## What Changes

- 所有 AI 工具专有目录收敛为指向 `.agents` 的相对软链；两侧内容不一致时按 git 合并冲突处理，逐项征询后再落定。
- git 只追踪 `.agents` 下的 `skills`、`mcp`、`rules`、`commands` 白名单，其余内容（含软链本身与备份目录）一律忽略。
- `build-profile.json5` 纳入版本管理，入库版本的 `signingConfigs` 为空数组；本地签名由 DevEco 写入后通过 `git update-index --skip-worktree` 隐藏，**签名材料永不提交**。
- 删除 `build-profile.json5.example`，CI 直接使用仓库内的 `build-profile.json5`。
- `release` skill 从 `skills/` 迁入 `.agents/skills/release`，成为可被工具发现的 skill。
- 清理无用点文件（`.codegenie`、`.cache`、`.clangd`、`.clang-tidy`）与失效的 `.gitignore` 条目。
- **BREAKING**：新克隆的仓库需要先在 DevEco 配置自动签名，再执行一次 `skip-worktree`；否则 `build-profile.json5` 会显示为已修改。

## Capabilities

### New Capabilities

- `agent-workspace`: AI 工具目录的单一真源、软链规则、冲突处理方式，以及 git 白名单追踪的边界。
- `build-config`: 构建配置文件（`build-profile.json5`）的版本管理方式、签名材料隔离要求，以及 CI 构建的输入来源。

### Modified Capabilities

- 无。

## Impact

- 受影响的文件：`.gitignore`、`.agents/`（含子模块 `qinshah/sync-agent-dirs`）、`build-profile.json5`、`.github/workflows/release.yml`、`AGENTS.md`，以及 `.qoder`/`.trae`/`.workbuddy` 三个软链。
- 受影响的流程：本地 DevEco 签名、`hvigorw` 构建、Release CI。
- 业务代码（`entry/` 下的 ArkTS）不做任何改动。
