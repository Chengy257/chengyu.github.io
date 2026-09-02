---
title: "GLM Conductor：面向 GLM 双模型/ZCode 的选择性 Agent 编排插件"
summary: "GLM Conductor 是一个面向 ZCode 和 GLM Coding Plan 的选择性 Agent 编排插件。它利用 ZCode 已有的 Subagent、Hook、Automation 与长程任务能力，在其上增加针对 GLM-5.3 / GLM-5.3-Flash 双模型体系的路由策略、任务状态、证据约束和额度感知连续性。"
date: 2026-09-01
draft: false
tags: ["Agent", "工具开发", 开源","ZCode","GLM"]
categories: ["工具开发"]
author: "Cy257"
---

# GLM Conductor：面向 ZCode 的 GLM 双模型选择性 Agent 编排插件

>GLM Conductor 是一个面向 ZCode 和 GLM Coding Plan 的选择性 Agent 编排插件。它利用 ZCode 已有的 Subagent、Hook、Automation 与长程任务能力，在其上增加针对 GLM-5.3 / GLM-5.3-Flash 双模型体系的路由策略、任务状态、证据约束和额度感知连续性。

项目地址：[Chengy257/glm-conductor](https://github.com/Chengy257/glm-conductor)

## 项目起源：

随着国产大模型逐步进入真实的 Coding Agent 场景，模型之间的差异已经不再只是 benchmark 分数，而开始体现在复杂推理、长程执行、多模态能力、推理成本以及 Agent 运行环境等不同维度。

2026 年 8 月发布的 GLM-5.3 进一步强化了复杂 Coding 与 Long-Horizon Tasks 能力，并与 ZCode 深度集成。与此同时，ZCode 已经发展为较完整的 Agent Harness，提供长程任务上下文、Plan / Full Access 执行模式、Subagent、Goal Mode、Review、Automation、Plugin 与 Hook 等能力，使一个开发任务能够在统一环境中持续完成规划、修改、验证与审查。

GLM-5.3-Flash 的推出，则让模型之间的分工协作具备了更明确的现实基础。该模型在正式发布前曾以 Ox Alpha 的身份进行匿名真实流量测试，随后进入 GLM 与 ZCode 生态。其稀疏 MoE 架构、原生多模态能力以及更低的计算与 KV-cache 开销，使其尤其适合承担边界清晰的代码实施、批量修改、测试补充，以及需要视觉理解的前端任务。

ZCode 本身已经提供了较完整的 Agent 运行环境，包括任务规划、持续执行、子智能体、审查、自动化以及插件等基础能力，GLM Conductor 在 ZCode 已有能力之上，  将不同模型显式化为稳定的编排方式：

- GLM-5.3 主要负责需求理解、仓库探索、root cause 定位、架构决策以及最终验收；
- GLM-5.3-Flash 主要负责已经规格化、边界明确的实施任务，并可承担视觉执行与辅助审查；
- GLM Conductor 则负责在二者之间建立更明确的任务路由、编排规则与运行时契约。

项目的另一个直接动机来自 GLM Coding Plan 的额度机制。Coding Plan 同时受到 5 小时 prompt 池和周额度限制。对于持续数小时乃至跨天执行的复杂任务，真正中断任务的因素有时并不是代码错误或 Agent 失败，而只是当前额度窗口已经耗尽。

这使长程任务产生了一个传统单轮 Agent 流程并不擅长处理的问题：如果任务状态主要依赖当前聊天上下文，在下一额度窗口恢复执行时，很容易出现重复实施、验证结果丢失、子任务边界模糊以及仓库实际状态与上下文记录不一致等情况。

因此，GLM Conductor 从设计之初便将“跨额度窗口持续执行”作为核心目标之一。系统在额度耗尽或任务暂停时保存可恢复的执行状态，在下一窗口恢复后重新核对仓库状态、任务 ledger 与既有验证结果，再在用户授权范围内继续执行。由此，额度窗口不再被视为一次任务的生命周期边界，而只是长程任务执行过程中的一个运行时约束。

## 项目特点

- **GLM 双模型选择性编排**：让 GLM-5.3 保留判断密集型工作，把规格明确的实施交给 GLM-5.3-Flash。
- **Delegability × Assurance 双轴路由**：分别判断“是否适合委派”和“是否需要独立终审”，而不是简单按任务难度切换模型。
- **结构化任务交接**：通过目标、ownership、接口、约束和验证要求，把主会话的复杂上下文压缩成可执行规格。
- **基于 ZCode Hook 的运行时契约**：利用宿主已有的 PreToolUse、PostToolUse、SessionStart 和 Stop 等 Hook，把部分编排要求从提示词约定变成机器检查。
- **Work Unit 与有界并行**：对长任务建立依赖和 ownership 明确的执行单元，在安全范围内并行，而不是无条件增加 Agent 数量。
- **文本与视觉双通道**：利用 GLM-5.3-Flash 的多模态能力，为需要截图判断的 UI 任务建立独立实施和审查路径。
- **Quota-Aware Continuity**：把 Coding Plan 额度状态纳入调度，在额度耗尽时保留任务状态，并支持授权后的跨窗口恢复。
- **证据与仓库状态绑定**：验证和独立审查记录绑定 repository fingerprint，代码继续变化后旧证据不再被当作当前状态的证明。
- **本地任务 ledger 与恢复**：checkpoint 负责导航，repository 负责事实，避免把模型记忆或旧会话摘要当成仓库真相。

## 安装使用

GLM Conductor 是一个 ZCode 插件。使用前需要：

- ZCode；
- GLM Coding Plan 或对应的 Z.ai / BigModel 账号；
- Python 3.8+。

### 从 GitHub 插件市场安装

在 ZCode 中打开：

```text
Settings
→ 插件
→ 创建
→ 添加插件市场
```

添加仓库：

```text
https://github.com/Chengy257/glm-conductor
```

校验通过后安装 `glm-conductor`。

安装或更新插件后需要新建会话，因为 Subagent、Skill 和 Hook 都在会话启动时加载。

### 本地安装

开发和测试时也可以直接克隆仓库：

```bash
git clone https://github.com/Chengy257/glm-conductor.git
```

随后在 ZCode 插件市场中添加本地目录，选择包含 `marketplace.json` 的仓库根目录。

### 开始使用

新建会话后，可以直接调用编排 Skill：

```text
用 glm-conductor:orchestration 规划并实现这个功能，声明路由并完成验证
```

主要入口包括：

| 命令 / Skill           | 用途                                   |
| ---------------------- | -------------------------------------- |
| `/orchestration`       | 路由、任务拆分、委派和独立审查         |
| `/continuity`          | checkpoint、任务恢复和跨额度窗口连续性 |
| `/glm-conductor:quota` | Coding Plan 用量与 quota 状态诊断      |
| `enforcement`          | 查看运行时策略、完成门和拦截原因       |

对于简单任务，GLM Conductor 不要求强行进入多 Agent 流程。主会话能够直接完成时，仍然可以走单 Agent 路径。

## 项目定位： ZCode 专用的控制策略

ZCode 本身已经支持隔离上下文的 Subagent、Goal Mode、Automation、执行权限，以及可以在工具调用和 Stop 阶段执行策略检查的 Hook。类似地，Codex 等现代 Agent Harness 也已经在做持久线程、并行 Agent、sandbox / approval、运行日志、自动验证和 agent-to-agent review。

因此，GLM Conductor 的定位是：

> **在 ZCode 已有 Harness 原语之上，为 GLM 双模型和 Coding Plan 配额场景建立一套更具体、更确定性的 编排策略与任务控制层。**

它的特色主要体现在如何组合这些基础能力，例如什么时候委派给 Flash、什么时候要求独立 reviewer、如何把 Work Unit 与 ownership 绑定、如何让验证证据失效、如何根据 quota 收缩并发，以及如何在跨额度窗口恢复时重新对账仓库状态。

## 1. 双轴选择性路由：决定谁实施，以及需要多强的验收

GLM Conductor 不直接把任务划分为“简单 / 困难”或“低风险 / 高风险”，而是分别考虑两个维度。

第一个维度是 **Delegability**，表示当前剩余工作是否已经适合委派。

如果 root cause 还没有找到、架构仍未确定、关键接口存在歧义，或者实施本身还需要大量判断，那么任务更适合留在 GLM-5.3 主会话。

反过来，一个规模很大的重构，只要已经拆成目标明确、ownership 清晰、接口固定、验证方式确定的 Work Unit，也可以进入委派路径。

第二个维度是 **Assurance**，表示实施完成以后是否值得增加一次独立终审。

局部、影响范围有限的修改，可以由主会话验证后完成；影响核心架构、大范围行为或重要 UI 的任务，则可以要求新的 reviewer 上下文重新检查。

两个维度组合形成四种路由：

| Delegability | Assurance | Route      | 实施方式       | 独立审查 |
| ------------ | --------- | ---------- | -------------- | -------- |
| low          | standard  | `solo`     | GLM-5.3 主会话 | 否       |
| high         | standard  | `delegate` | 实施子智能体   | 否       |
| low          | high      | `audit`    | GLM-5.3 主会话 | 是       |
| high         | high      | `full`     | 实施子智能体   | 是       |

这种路由不是永久标签。随着新证据出现，任务可以重新评估。

例如一个 bug 在最初只有错误现象时可能保持 `solo`；当 root cause 和修复边界确定以后，剩余实施可以切换为 `delegate`。如果子智能体在实施过程中发现原有接口假设不成立，则可以重新把判断交回主会话。

这里的重点不是多用一个 Agent，而是尽量让旗舰模型处理需要判断的部分，让高效模型接手已经收敛的部分。

## 2. 结构化委派：把主会话上下文压缩成执行规格

ZCode Subagent 已经提供隔离上下文和并行执行能力，但隔离上下文本身也意味着：主会话中已经讨论过的隐含条件，不会天然变成子智能体的完整任务规格。

因此 GLM Conductor 对实施型委派增加了结构化约定：

```text
OBJECTIVE
FILES AND OWNERSHIP
INTERFACES
CONSTRAINTS
VERIFICATION
```

视觉任务再增加：

```text
VISUAL ACCEPTANCE
```

这套结构的目的不是创造新的 Agent 通信机制，而是约束主会话在派发前先完成“上下文压缩”。

GLM-5.3 可以读取更多仓库内容、比较不同方案、解决歧义；真正交给 Flash 的内容则尽量只包含已经确定的事实、修改范围和验收条件。

子智能体完成后返回 Implementation Report，但它仍然只是实施者的报告。主会话和 runtime 会根据真实 diff 和验证结果决定任务是否满足后续条件。

## 3. Runtime Contract：把部分编排要求落实到 ZCode Hook

ZCode 已经提供 PreToolUse、PostToolUse、PostToolUseFailure、SessionStart 和 Stop 等 Hook，并允许插件在工具调用前执行 allow / ask / deny，在 Agent 准备结束时继续阻止完成。

GLM Conductor 利用这套宿主能力实现自己的运行时契约。

重点不是“拥有 Hook”，而是 Hook 具体检查什么。例如：

- 实施型子智能体是否经过合法的 dispatch 流程；
- 实际修改是否超出声明 ownership；
- required verification 是否已经存在对应记录；
- high-assurance 任务是否具有独立 review；
- review 或 verification 是否仍然对应当前 repository fingerprint；
- 任务是否真的满足进入完成状态的条件。

因此，项目所谓的 Completion Gate 更准确地说，是**建立在 ZCode Stop Hook 之上的项目级完成协议**。

类似地，dispatch permit 也是一种项目级授权事实，用于把“这个实施者应该被派发”从 prompt 中的一句话变成 runtime 能够检查的状态。

这类机制不会取代 ZCode 自身的权限系统。ZCode 的 Ask before changes、Full access 等模式控制 Agent 在宿主中的操作权限；GLM Conductor 的 policy 则关注当前任务流程中某个动作是否符合既定编排状态。

两层解决的是不同问题。

## 4. Work Unit 与有界并行：在同一任务内明确依赖和 ownership

ZCode 已经能够启动并行 Subagent，其他 Harness 也普遍支持并行 Agent。GLM Conductor 在此基础上更关注同一个长任务内部的执行单元关系。

一个任务可以被拆成多个 Work Unit：

```text
WU-01  Repository reconnaissance
   |
   v
WU-02  Runtime API
   |
   +----------+
   v          v
WU-03       WU-04
Tests       Docs
   |          |
   +----+-----+
        v
WU-05  Integration verification
```

每个 Work Unit 可以记录 dependency、ownership、verification、状态和对应 Agent run。

这样做主要解决两个问题。

第一是恢复。任务被打断后，不需要只依赖聊天摘要判断“做到哪里了”，而可以逐个核对哪些 Work Unit 已经拥有足够证据。

第二是并行边界。只有依赖满足且 ownership 不冲突的 Work Unit 才适合进入同一 dispatch wave。

GLM Conductor 的并行策略因此是有界的。它不会把“多开 Agent”本身视为优化目标，而是根据任务依赖、文件 lease、执行策略和 quota 状态决定实际 worker budget。

需要注意的是，这不是 Codex worktree 那类完整仓库级隔离方案。GLM Conductor 当前的 lease 更接近同一主编排会话下的 ownership 协议，用来减少多个实施者对同一文件范围的竞争。

## 5. 文本与视觉通道：利用 Flash 的原生多模态能力

GLM-5.3-Flash 的原生多模态能力使它除了作为低成本实施者，还可以承担视觉任务。

GLM Conductor 因此为需要截图反馈的任务定义了独立角色：

```text
GLM-5.3 主会话
        |
        v
visual-implementer
        |
   修改代码并请求截图
        |
        v
主会话采集视觉证据
        |
        v
visual-implementer 读取截图并修正
        |
        v
visual-reviewer 独立视觉终审
```

ZCode 本身提供视觉输入和相关工具，GLM Conductor 的工作是把这些能力纳入一个明确的实施与验收流程。

主会话负责规划、驱动和证据采集；视觉判断交给具备多模态能力的角色。如果任务声明需要视觉验收，而实际没有得到所需截图，则不会用纯文本代码检查替代视觉结论。

## 6. Quota-Aware Continuity：把 5 小时额度窗口纳入调度

跨额度窗口连续性是 GLM Conductor 相对更专门的一部分。

ZCode 已经具备 Goal Mode、Automation 和长期任务能力，但 Coding Plan 的额度窗口仍然是模型资源层面的现实约束。任务可能尚未完成，当前 5 小时 prompt 池却已经耗尽。

GLM Conductor 将 quota 抽象为调度状态：

```text
AVAILABLE
PRESSURE
EXHAUSTED
UNKNOWN
```

runtime 在准备新的实施派发时读取当前 quota 状态，并据此调整 worker budget。

例如：

- `AVAILABLE`：按当前策略正常派发；
- `PRESSURE`：收缩并发，避免继续快速消耗；
- `EXHAUSTED`：停止新的实施派发，任务进入等待；
- `UNKNOWN`：采用保守策略，不假定额度一定可用。

进入 resumable 模式的任务会保存必要的任务状态。额度恢复后，流程不会简单重新发送原始 prompt，而是先重新核对 repository、Work Unit 和当前 quota，再继续执行。

自动恢复同时受到用户授权限制。项目区分手动、通知、单次自动恢复和持续恢复等策略，并允许限制可跨越的 quota window 数量。

目标不是让 Agent 无限制后台运行，而是让一个已授权的长任务能够在 5 小时窗口之间保持连续性。

## 7. 跨会话恢复：checkpoint 负责导航，repository 负责事实

ZCode 自身具有长期任务上下文、Project Memory 和任务管理能力。GLM Conductor 额外维护的是其编排协议所需要的本地任务状态。

可恢复任务会拥有独立 `TASK_ID`，并保存 state、event ledger 和 checkpoint。

其中 checkpoint 只用于描述恢复入口，例如当前目标、已完成单元和下一步动作；它不是仓库副本，也不会覆盖用户后来对代码做出的修改。

恢复时，repository 优先于 checkpoint。

系统会重新检查实际 diff、Work Unit 状态和验证证据，再决定是复用结果、继续未完成工作、重新派发，还是要求主会话处理冲突。

这一设计主要服务于 GLM Conductor 自己的 orchestration state，而不是试图替代 ZCode 的通用任务持久化。

## 8. Verification 与 Review Provenance：让证据对应具体代码状态

ZCode 和 Codex 等 Harness 本身都已经重视测试结果、Review 和执行日志。GLM Conductor 在此基础上进一步约束自己的完成协议：任务引用的验证和 reviewer 结论，需要能够对应到具体 repository state。

例如，代码在状态 A 通过验证并获得 `ship`，之后继续修改为状态 B：

```text
Code state A
  ├─ verification: pass
  └─ review: ship
          |
       code changed
          |
Code state B
  ├─ old verification: stale
  └─ old review: stale
```

项目通过 repository fingerprint 和 receipt 记录这种关系。

因此它并不是声称“只有 GLM Conductor 才会验证代码”，而是对自己定义的路由和完成条件增加更严格的 evidence freshness 约束。

对于 high-assurance 路由，独立 review 也不是普通的自我检查，而是由新的 reviewer 上下文给出裁决。后续如果代码发生变化，原有 review 不再自动代表当前状态。

## 适用范围和边界

GLM Conductor 并不适合所有 Coding 任务。

一个只改几行代码、验证非常简单的问题，直接让 ZCode 主会话完成通常更快。项目更适合：

- 中大型多文件修改；
- 模块重构和迁移；
- 可以拆成多个 Work Unit 的任务；
- 实现、测试和文档存在明确并行边界的工作；
- 希望针对高风险修改加入独立终审的任务；
- 需要截图或视觉反馈的前端任务；
- 容易跨越 Coding Plan 5 小时额度窗口的长任务；
- 希望把旗舰模型额度更多留给架构和判断，而减少机械实施消耗的工作流。

它不是新的通用 Agent Runtime，也不替代 ZCode 自身的 Goal、Review、权限、Automation 和 Subagent。

更准确地说，它是一层专门面向 **GLM 双模型 + ZCode + Coding Plan** 的 orchestration policy：把已有 Harness 能力组合成一条更明确的任务路由、验证和恢复路径。

## 参考资料

- GLM-5.3：[Z.ai 官方发布](https://z.ai/blog/glm-5.3)
- GLM-5.3-Flash / Ox Alpha：[GLM-5.3-Flash 官方介绍](https://autoclaw.z.ai/blog/model/glm-5.3-flash/)
- ZCode：[ZCode 官网](https://zcode.z.ai/)
- ZCode Agent：[ZCode Agent 文档](https://zcode.z.ai/en/docs/agent-framework)
- ZCode Subagents：[Subagents 文档](https://zcode.z.ai/en/docs/subagents)
- ZCode Hooks：[Hooks 文档](https://zcode.z.ai/en/docs/hooks)
- ZCode Goal Mode：[Goal Mode 文档](https://zcode.z.ai/en/docs/goal)
- ZCode Automations：[Automations 文档](https://zcode.z.ai/en/docs/automations)

## 参考项目

- **sol-advisor** · MIT   https://github.com/DannyMac180/sol-advisor  
  选择性模型路由与 architect / implementer / reviewer 分工的主要早期设计参考。

- **zai-org/zai-coding-plugins** · Apache-2.0   https://github.com/zai-org/zai-coding-plugins  
  Z.ai 官方 Coding 插件集合。主要参考 GLM Coding Plan 用量查询、鉴权形式与 quota 行为。

- **zai-org/zcode-plugins** · Apache-2.0   https://github.com/zai-org/zcode-plugins  
  ZCode 官方插件市场与示例实现，用于参考 ZCode Plugin、Skill、Subagent 和 Hook 的原生组织方式。

  

