# 校园线索推理与多结局探索 App（`campus-case`）

鸿蒙 + Android **双端同构**的单机推理叙事 App：场景探索 → 线索收集 → 组合验证 → 最终判断 → 多结局，带线索板、HUD、阶段进度、存档与杀进程恢复。

- 平台 A：HarmonyOS NEXT — ArkTS + ArkUI（API 12+），单 HAP，纯离线
- 平台 B：Android 8.0+ — Kotlin + Jetpack Compose，单 Activity，纯离线
- 双端共用**同一份功能规格**与**同一份内容 JSON**，只有平台代码是两份；判定逻辑由 `shared/fixtures` 用例双向校验（见 03 文档 §9）
- 技术栈重点：声明式状态管理、组件动画、领域建模、KV + 关系型双存储、单元测试（Hypium / JUnit5）

---

## 1. 文档与仓库结构

### 1.1 文档索引

| 文档 | 内容 | 状态 |
| --- | --- | --- |
| [01-基础功能需求规格说明](docs/01-基础功能需求规格说明.md) | 软件基础功能 FR-01～FR-17、通用规则、验收标准、测试要求（**平台无关**） | v1.2 定稿 |
| [02-内容与剧情设计规范](docs/02-内容与剧情设计规范.md) | 内容 schema、规模约束、校验规则 | v0.1 骨架，正文待定 |
| [03-Android版实现规格说明](docs/03-Android版实现规格说明.md) | FR → Android 落地映射、状态/存储/动画/恢复对照、双端一致性策略 | v1.0 |
| [04-首轮编译绿检查单](docs/04-首轮编译绿检查单.md) | 在 IDE 里跑通两端编译与单测的步骤、期望输出、报错对照表 | v1.0 |
| [drafts/剧情草案-v0](docs/drafts/剧情草案-v0.md) | 早期含具体剧情的混写版，仅作素材保留 | 草案，不采用 |

**阅读顺序**：先看 01 的「§3 通用规则」和「§4 功能需求」，那是所有实现的判定依据；再看 03 的对照表了解各平台怎么落地；02 只定内容长什么样，具体剧情后续单独写。

### 1.2 仓库结构（双端 monorepo）

```
campus-case/
├─ docs/                 # 规格与设计（两端共用，判定标准只在这里）
├─ shared/               # 两端共用：case/（内容 JSON）+ fixtures/（一致性用例）
│                        #   构建期复制进两端资源目录，副本不入库
├─ harmony/              # DevEco 工程（ArkTS）
└─ android/              # Gradle 工程（Kotlin + Compose）
```

`shared/` 不允许出现任何平台代码；`harmony/`、`android/` 不允许各自复制一份剧情。

---

## 2. 提交规范（**硬规则**）

### 2.1 总则

> **任何一次修改完成后，必须立即提交（commit）。** 不允许把"已完成但未提交"的交付物留在工作区过夜。

| 规则 | 说明 |
| --- | --- |
| R1 修改即提交并推送 | 文档定稿、功能实现、缺陷修复，任务结束时工作区必须干净（`git status` 无输出），且已推到 `origin/main` |
| R2 一次提交一件事 | 不把"改需求 + 改代码 + 调样式"塞进同一个 commit；能一句话说清才提交 |
| R3 可回滚粒度 | 每个提交单独能通过构建/测试；不允许提交"半截功能导致跑不起来"的状态 |
| R4 文档与实现同步 | 改判定逻辑 → 同步改 01 文档对应 FR；改内容格式 → 同步改 02；两者不一致时以文档为准并补齐文档 |
| R5 提交前自检 | 跑完 §2.5 清单再提交，不靠"先提交再说" |

**允许不提交的中间态**：仅限编辑器自动保存、临时草稿（放在 `scratch/`，已被 `.gitignore` 忽略）。一旦进入 `docs/`、`entry/` 等交付目录，就必须提交。

### 2.2 提交信息格式

```
<type>(<scope>): <中文摘要，≤ 50 字，不加句号>

<可选正文：为什么改、影响哪些 FR / AC，每行 ≤ 72 字>

<可选脚注：Refs: FR-04 / AC-05>
```

**type**

| type | 用途 | 示例 |
| --- | --- | --- |
| `feat` | 新增功能 | `feat(clueboard): 实现线索两两连线与规则校验` |
| `fix` | 修缺陷 | `fix(save): 修复读档后 seq 与流水冲突` |
| `docs` | 只改文档 | `docs(requirements): 补充 FR-14 恢复流程` |
| `refactor` | 不改行为的重构 | `refactor(domain): 抽出 Condition 统一求值器` |
| `test` | 只加/改测试 | `test(domain): 补 TC-15 双链成立用例` |
| `style` | 格式/命名/注释 | `style: 统一热点状态命名` |
| `chore` | 构建、依赖、配置 | `chore: 加入 DevEco 构建忽略规则` |
| `content` | 只改内容 JSON | `content(case): 补 N05 节点与对应线索` |
| `revert` | 回滚 | `revert: feat(clueboard) 连线重绘抖动` |

**scope 取值**（统一用，便于按模块查历史）
`requirements` `content` `engine` `ui` `state` `storage` `recovery` `test` `build` `docs`

### 2.3 提交粒度示例

| 场景 | 拆法 |
| --- | --- |
| 实现"线索板连线" | ① `feat(engine): checkCombine 规则校验` ② `feat(ui): 线索板卡槽与选中态` ③ `feat(ui): 连线曲线动画与持久重绘` ④ `test(engine): 补 TC-09~TC-12` |
| 修"杀进程丢档" | ① `fix(storage): 节点应用后改为事务立即落盘` ② `fix(recovery): seq 对账不一致时回放流水` ③ `test(recovery): 补 TC-24/TC-25` |
| 需求调整 | ① `docs(requirements): FR-09 改为选项灰显可见` ② 代码跟改 `feat(judge): 选项可见性按链计算` |

**禁止**：`update`、`fix bug`、`修改一下`、`提交`、`1`、`asdf` 这类无信息量的信息。

### 2.4 分支与标记

| 项 | 约定 |
| --- | --- |
| 主干 | `main`（远程已设同名主干，`git branch -m main` 已完成） |
| 远程 | `origin` = `https://github.com/NaCl1Yan/campus-case.git`（**私有**，交作业如需对外可见要改公开或加协作者） |
| 特性分支 | `feat/<scope>-<简述>`，如 `feat/clueboard-link`；单人开发可直接在 `main` 上小步提交，超过 1 天的改动开分支 |
| 里程碑标记 | 每个里程碑验收通过后打 tag：`m1-skeleton` `m2-engine` `m3-ui` `m4-persistence` `m5-release` |
| 版本标记 | 可交付版本打语义化 tag：`v0.1.0`（M3 可玩）、`v1.0.0`（验收通过） |
| 回滚 | 优先 `git revert <sha>`（保留历史）；禁止对已推送历史 `reset --hard` |

> **网络提示**：本机到 GitHub 的 443 时通时断（会被重置），本地 Clash（`127.0.0.1:7890`）对 `github.com` 也会偶发握手失败。仓库**不设**代理配置，push 失败时两种都试：
> - 直连：`git push`
> - 临时代理：`git -c http.proxy=http://127.0.0.1:7890 push`
>
> 先用 `curl.exe -s -o NUL -w "%{http_code}" https://github.com` 判断：返回 `200` 就走直连，`000` 就换代理。

### 2.5 提交前检查清单

```
[ ] git status 里没有不该提交的东西（见 .gitignore）
[ ] 文档：新增链接可达、表格未错位、TBD 只出现在确实待定的位置
[ ] 需求变更是否已同步到 01/02 文档（R4）
[ ] 代码：hvigorw assembleHap 通过；hvigorw test 通过
[ ] 新增逻辑是否补了对应 TC 用例（对照 01 文档 §10.2）
[ ] commit 信息符合 §2.2，摘要能独立看懂
[ ] 本次提交只做了一件事（R2）
```

### 2.6 每轮任务的收尾动作（固定流程）

1. 完成修改 → 跑检查清单
2. `git add <path>`（按文件加，别一把 `-A` 兜底，能防止误提交）
3. `git commit -m "<type>(<scope>): <摘要>"`
4. 用 `git log --oneline -1` 确认提交成功
5. `git push`（首次已 `-u`，之后直接 push）
6. 若本轮涉及需求判定变化，在回复里点明"改了哪个 FR、影响哪个 AC"

> 提交记录本身是验收证据：AC-05（分支真实生效）、AC-12（杀进程恢复）、AC-17（单测）都能通过对应 commit 的 diff 与测试结果追溯。远程仓库则保证换机、误删后进度可恢复。

---

## 3. 忽略规则速览

`.gitignore` 已覆盖：DevEco 构建产物（`build/`、`.hvigor/`、`.preview/`）、Gradle 产物（`android/**/build/`、`.gradle/`）、依赖（`oh_modules/`、`node_modules/`）、签名与本地配置（`local.properties`、`*.p12`、`*.cer`、`*.p7b`、`*.keystore`、`keystore.properties`）、两端**构建期复制的内容副本**（`harmony/**/rawfile/case/`、`android/**/assets/case/`）、系统与编辑器垃圾文件、临时草稿（`scratch/`）。

---

## 4. 当前进度

| 阶段 | 鸿蒙版 | Android 版 |
| --- | --- | --- |
| 需求文档（基础功能，FR-01～17） | ✅ v1.4 | ✅ 沿用同一套（03 文档为映射） |
| 内容设计（schema + 占位案件 + 42 条用例） | ✅ 已落地 `shared/` | ✅ 同一份，不复制 |
| `domain/` 判定引擎 | ✅ 代码完成（待 DevEco 编译 + 跑 Hypium） | ✅ 代码完成（待 Gradle 跑 JUnit5） |
| 工程骨架（DevEco / Gradle app 模块） | ✅ 骨架就绪（未编译验证） | ✅ 骨架就绪（未编译验证） |
| UI 与动画（6 类） | ⬜ 未开始 | ⬜ 未开始 |
| 持久化与恢复（Preferences+RDB / DataStore+Room） | ⬜ 未开始 | ⬜ 未开始 |
| 双端一致性（fixtures 双向校验） | ✅ 用例就绪 | ✅ runner 就绪 |

## 5. 如何验证（M2 现状）

```powershell
# 1) 离线预检：配置/资源/符号/Gradle 目录（现在就能跑，只需 Python）
python tools/preflight.py            # 期望：PASS 9 / FAIL 0

# 2) 内容校验 + 规格自检（现在就能跑，只需 Python）
python tools/validate.py            # 期望：内容通过 + 42/42 用例通过

# 3) Android 引擎单测（需要一个 Gradle，或用 Android Studio 打开 android/）
cd android; ./gradlew :domain:test

# 4) 鸿蒙引擎单测（需要 DevEco Studio + hvigor）
cd harmony; hvigorw test
```

首次在 IDE 里跑编译的完整步骤、期望输出与报错对照表见 [首轮编译绿检查单](docs/04-首轮编译绿检查单.md)。

`tools/validate.py` 是开发期参照实现：它跑通只代表"用例与 01 §5.3 语义一致"，**不代表两端代码已跑**。两端要各自跑通同一批 fixtures 才算 AC-18 成立。

## 6. 工程骨架（M1）

### 6.1 内容同步（两端共用一份）

```powershell
powershell -File tools/sync-case.ps1          # shared/case → rawfile/case + assets/case
powershell -File tools/sync-case.ps1 -Check   # 只比对，不一致退出码 1（AC-19 用）
```

副本目录已在 `.gitignore` 里，仓库只保留 `shared/case` 这一份源。

### 6.2 鸿蒙侧（`harmony/`）

DevEco Studio 直接 **File → Open → `harmony/`**：

| 文件 | 作用 |
| --- | --- |
| `AppScope/app.json5` | bundleName `com.nacl1yan.campuscase`、版本、图标 |
| `build-profile.json5` | 产品 `default`，`compatibleSdkVersion 5.0.0(12)`，无签名配置（本地调试自动签名） |
| `entry/src/main/module.json5` | 入口 Ability；**没有任何权限声明**（离线约束） |
| `entry/src/main/ets/entryability/EntryAbility.ets` | 生命周期；注释标出 M4 会接恢复流程的位置 |
| `entry/src/main/ets/pages/Index.ets` | 骨架页：读 rawfile 内容 → 跑 `Engine` → 显示阶段/目标/进度/线索数 |
| `entry/src/ohosTest/` | Hypium 测试模块，入口 `List.test.ets` → `Domain.test.ets` |

构建与测试：`hvigorw assembleHap`、`hvigorw test`（或 DevEco 里右键 `ohosTest` → Run）。

### 6.3 Android 侧（`android/`）

Android Studio 直接 **Open → `android/`**：

| 模块 | 作用 |
| --- | --- |
| `:domain` | 纯 JVM：引擎 + 内容校验 + 42 条 fixture runner（无 Android 依赖，`./gradlew :domain:test` 秒级） |
| `:app` | Compose 壳：`MainActivity` + `LaunchScreen`（同样读 assets 内容 → 跑 `Engine` → 显示状态） |

`app/build.gradle.kts` 里有 `syncCaseContent` 复制任务，挂在 `pre*Build` 上，所以构建时自动同步内容；命令行也可先用 6.1 的脚本。

测试：`./gradlew :domain:test`；打包：`./gradlew :app:assembleDebug`。

### 6.4 已知状态

两个工程**骨架都还没在本机编译过**（这台机器只有 JDK 17 + Python，无 Gradle / Kotlin 编译器 / DevEco / Android SDK）。首次在 IDE 打开时可能需要：

- Gradle：IDE 会按 `gradle-wrapper.properties` 下载 8.11.1，然后补 `./gradlew` 脚本与 `gradle-wrapper.jar`（AS 自动生成）；
- DevEco：按提示配 SDK 路径与自动签名（`build-profile.json5` 的 `signingConfigs` 目前为空）；
- ArkTS 侧 JSON 解析与 `TextDecoder` 的 API 名称若有出入，编译一次即可定位，不影响引擎逻辑。

下一步：M3 做 UI 与 6 类动画（先鸿蒙后 Android，共用 `domain/`），M4 接持久化与杀进程恢复。
