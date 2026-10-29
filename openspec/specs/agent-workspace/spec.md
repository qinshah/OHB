# agent-workspace Specification

## Purpose

让项目里所有 AI 工具共用同一份配置真源，并让 git 只追踪其中被明确指定的内容类型，避免同一份 skill 与规则在多处复制、漂移。

## Requirements

### Requirement: AI 工具目录必须指向单一真源

项目根下用于 AI 工具的项目级配置目录（如 `.qoder`、`.trae`、`.workbuddy`）SHALL 是指向 `.agents` 的相对软链，MUST NOT 保存独立副本。

#### Scenario: 已有目录首次收敛

- **WHEN** 某个工具目录存在独立内容且 `.agents` 中没有同名路径
- **THEN** 该内容被并入 `.agents`，原目录转为指向 `.agents` 的软链

#### Scenario: 新工具目录接入

- **WHEN** 项目根下出现一个此前未管理的候选工具目录
- **THEN** 侦察结果将其标记为待链接，执行链接后该目录指向 `.agents`

#### Scenario: 两侧内容冲突

- **WHEN** 工具目录与 `.agents` 存在同名但内容或类型不同的路径，且冲突项尚未逐项决定
- **THEN** 执行过程不做任何改动，并列出待决定的冲突项及其两侧内容

#### Scenario: 禁止链接的目录

- **WHEN** 候选列表中包含 `.git`、`.github`、`.agents` 或备份目录
- **THEN** 这些目录保持原样，永远不会被链接

### Requirement: git 只追踪白名单内容

`.agents` 下只有 `skills`、`mcp`、`rules`、`commands` 四个目录的内容进入版本管理；其余内容、各工具软链与备份目录 MUST 被忽略。

#### Scenario: 新增共享 skill

- **WHEN** 在 `.agents/skills/<name>/` 下新增 skill 文件
- **THEN** 该文件出现在待提交列表中

#### Scenario: 工具软链不入库

- **WHEN** 执行 `git status`
- **THEN** `.qoder`、`.trae`、`.workbuddy` 等软链不会出现在待提交列表中

#### Scenario: 白名单块自动维护

- **WHEN** 重新执行目录同步
- **THEN** 只重写 `.gitignore` 中带标记的块，块外规则保持不变，且块内每个目录只占一行

### Requirement: 项目级 skill 必须位于工具可发现的位置

声明为项目级 skill 的目录 SHALL 位于 `.agents/skills/<name>/SKILL.md`，且目录名与 frontmatter 的 `name` 一致。

#### Scenario: skill 迁入共享目录

- **WHEN** 一个 skill 从 `.agents/skills/` 之外的路径迁入
- **THEN** 该 skill 出现在可用的 skill 列表中
