# Design

## Context

- 仓库是 HarmonyOS ArkTS 应用，`entry/` 为唯一模块，构建入口为 `build-profile.json5` + `hvigorw`。
- 各家 AI 工具的规则是「项目根下的 `.xxx` 目录」，没有共享机制；Qoder 与多数工具都能发现 `.agents/skills/<name>/SKILL.md`。
- `build-profile.json5` 里的签名配置由 DevEco 自动签名写入，含绝对路径与加密口令，`git update-index --skip-worktree` 是 git 原生的「追踪但忽略本地改动」手段。
- 动机见 `proposal.md`，行为契约见 `specs/agent-workspace/spec.md` 与 `specs/build-config/spec.md`。

## Goals / Non-Goals

**Goals:**

- 工具目录只有一份内容，接入新工具零复制。
- 冲突以「逐项征询」的方式解决，脚本不做任何自动取舍。
- 签名材料在版本库中出现概率为零，同时本地开发无需额外手工步骤。
- CI 的构建输入与仓库内容完全一致。

**Non-Goals:**

- 不处理 Windows 上的软链权限差异。
- 不接管各工具的运行时状态（登录态、缓存、日志）。
- 不改造业务代码与构建产物结构。

## Decisions

**1. 用软链而不是复制或生成**

复制会产生多份真源，生成需要模板与构建步骤。软链让 `<.xxx>/skills` 与 `.agents/skills` 是同一份 inode，工具读写都落在同一处。备选方案（`npx skills` 只链接 skills 子目录）覆盖不到 `rules`、`commands`、`mcp`。

**2. 目录同步能力做成独立 skill 仓，以子模块引入**

能力本身可复用到其他项目，因此独立成 `qinshah/sync-agent-dirs` 仓库，用 submodule 挂在 `.agents/skills/sync-agent-dirs`。备选方案（脚本内嵌在本项目 `scripts/`）会让这份能力无法被别的仓库复用。

**3. `.gitignore` 用「先全忽略 + 白名单放行」的标记块**

`.agents/*` 一条忽略掉全部直接子项，再逐条 `!.agents/<name>/` 放行整棵子树（一条即可，不需要再补 `**`）。标记块由脚本整体重写，块外手写规则不受影响；块内目录名会被继承，分批执行不会把先前的目录挤掉。

**4. 签名配置走 `skip-worktree` 而不是 git filter**

备选方案是 `.gitattributes` + clean/smudge 过滤器：更自动化，但需要每个克隆者执行 `git config filter...`，漏配时会静默失败。`skip-worktree` 只需一条命令，行为可预期；代价是 git 不再提示该文件的本地改动，改为在 `AGENTS.md` 中固定记录。

**5. CI 直接读仓库内的 `build-profile.json5`**

`signingConfigs: []` 的构型足以产出未签名 HAP（过往 CI 用 `.example` 做的就是这件事），因此模板文件多余，删除后 CI 与本地输入同源。

## Risks / Trade-offs

- [skip-worktree 掩盖本地改动] → 在 `AGENTS.md` 写明用法与检查方式；提交前用 `git show HEAD:build-profile.json5` 审计。
- [skip-worktree 与上游改动冲突时拉取可能失败] → 单人维护主干，且该文件极少变更；真发生时先备份本地签名再 `--no-skip-worktree` 比对。
- [DevEco 可能在打开工程时重新生成 `.cache`、`.clangd`、`.clang-tidy`] → 本次已删除并移除对应忽略项；若重新出现，补回一行忽略即可，属可接受的噪音。
- [软链在未开启开发者模式的 Windows 上不可用] → 项目当前只在 macOS 开发，Windows 支持列为非目标。
- [子模块需要额外初始化] → `AGENTS.md` 与 README 中的克隆步骤需包含 `git submodule update --init`。

## Migration Plan

1. 已有本地仓库：脚本自动把工具目录内容并入 `.agents` 并建立软链，原目录备份到 `.agents-backup/<时间戳>/`（已忽略）。
2. `build-profile.json5` 入库后，本地立刻执行一次 `git update-index --skip-worktree build-profile.json5`。
3. 新克隆：`git submodule update --init` → DevEco 配置自动签名 → 执行第 2 步。
4. 回滚：删除软链并从 `.agents-backup/` 还原原目录，`git rm --cached` 解除对 `build-profile.json5` 的追踪。
