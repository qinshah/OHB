# build-config Specification

## Purpose

让本地开发与 CI 使用同一份构型文件，把签名材料隔离在版本库之外；既避免两边配置漂移，也避免证书与口令被误提交进仓库。

## Requirements

### Requirement: 构型文件纳入版本管理

项目根目录的 `build-profile.json5` SHALL 被 git 追踪，仓库中该文件的 `signingConfigs` MUST 为空数组。

#### Scenario: 新克隆的仓库

- **WHEN** 任何人克隆项目后查看 `build-profile.json5`
- **THEN** 文件存在，且 `signingConfigs` 为空数组

#### Scenario: 本地写入签名后状态干净

- **WHEN** DevEco 自动签名把签名配置写入该文件，并已启用跳过工作区检查
- **THEN** `git status` 不显示该文件被修改

### Requirement: 签名材料不得入库

签名配置中的证书路径、密钥别名、密钥口令与密钥库口令 MUST NOT 出现在任何提交中。

#### Scenario: 提交内容审计

- **WHEN** 检查已提交版本的 `build-profile.json5`
- **THEN** 其中不包含 `certpath`、`keyPassword`、`storePassword`、`storeFile`、`profile` 等键

#### Scenario: 本地签名改动被隐藏

- **WHEN** 本地 `build-profile.json5` 含有签名配置
- **THEN** 批量暂存不会把该文件内容带入暂存区

### Requirement: CI 构建不依赖本地签名或模板文件

发布流水线 SHALL 直接使用仓库中的 `build-profile.json5` 进行构建，MUST NOT 依赖模板文件或任何本地签名材料。

#### Scenario: 推送 tag 触发发布

- **WHEN** 推送形如 `v*` 的 tag
- **THEN** CI 以仓库内的构型文件构建出未签名 HAP 并上传产物

#### Scenario: 仓库中不存在模板文件

- **WHEN** 查看仓库根目录
- **THEN** 不存在 `build-profile.json5.example`，流水线中也没有从模板生成的步骤
