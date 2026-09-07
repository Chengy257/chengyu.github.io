---
title: "GLM Conductor：给 ZCode 长程 Coding Agent 加一层路由、保障与连续性控制"
summary: "GLM Conductor 是一个面向 ZCode 和 GLM Coding Plan 的选择性 Agent 编排插件。它利用 ZCode 已有的 Subagent、Hook、Automation 与长程任务能力，在其上增加针对 GLM-5.3 / GLM-5.3-Flash 双模型体系的路由策略、任务状态、证据约束和额度感知连续性。"
date: 2026-09-01
draft: false
tags: ["Agent", "工具开发", "开源", "ZCode", "GLM"]
categories: ["工具开发"]
author: "Cy257"
aliases: ["/blog/glm-conductor-blog-humanized-v3/"]
---


GLM Conductor 是一个运行在 ZCode 之上的轻量 Coding Agent 控制层。

它最早来自个人使用中的两个需求：

> - GLM-5.3 和 GLM-5.3-Flash 逐渐形成了比较自然的分工。GLM-5.3 更适合做仓库理解、问题定位、方案设计和复杂判断；GLM-5.3-Flash 成本更低，又补上了多模态能力，用来处理边界明确的代码实施、测试和视觉任务更合适。
>
> - Coding Agent 一旦开始处理几个小时甚至更长的任务，就会碰到额度窗口、会话暂停和重新恢复的问题。任务本身可能还没结束，当前模型额度已经耗尽；下一次继续时，也不能只靠一句“继续”重新接上，因为仓库状态、验证结果和任务进度可能已经发生变化。



GLM Conductor 主要处理这两类问题，并把当前设计收敛成三部分：

```text
路由 --> 执行保障 --> 连续性
```

ZCode 继续负责 Agent、Subagent、Hook、Automation、工具和权限等基础能力。GLM Conductor 不替代这些功能，而是在上面增加一层针对 Coding 任务的控制逻辑。

## 路由：什么工作该交给谁

GLM Conductor 会先判断当前剩下的工作是否已经适合委派。

如果 root cause 还没找到、关键接口还没定、修改过程中仍需要大量判断，那么任务继续留在 GLM-5.3 主会话。

如果问题已经收敛成明确的实施规格，例如：

```text
修改指定模块
保持公开接口不变
补充指定测试
运行固定验证命令
```

这类工作就可以交给 GLM-5.3-Flash。

项目用两个维度描述这种判断：

- `Delegability`：现在是否适合委派；
- `Assurance`：完成后是否需要独立审查。

对应四种路线：

| | Standard | High Assurance |
|---|---|---|
| Low Delegability | `solo` | `audit` |
| High Delegability | `delegate` | `full` |

`solo` 和 `audit` 由主会话实施，区别在于是否需要独立终审；`delegate` 和 `full` 则把已经明确的实施任务交给子 Agent，其中 `full` 再增加独立审查。

这样做的目的很实际：把旗舰模型额度更多留给需要判断的工作，同时避免为了使用多 Agent 而制造额外协调成本。

Flash 的多模态能力也被放进同一套路由里。需要根据截图判断布局、界面状态或视觉结果时，可以走视觉实施和视觉审查，而不需要把所有任务都交给纯文本主模型处理。

## 执行保障：Agent 说“完成”还不够

Coding Agent 很容易给出这样的结果：

```text
Implementation completed.
All tests passed.
```

问题是，这只是一次报告。

测试可能是在后续修改之前跑的；Reviewer 给出结论以后代码又被改过；实施 Agent 也可能碰了原本没有分配给它的文件。

因此 GLM Conductor 不把自然语言里的“完成”直接等同于任务完成。

它利用 ZCode Hook 和本地 Runtime 维护几类可检查的事实：

- 当前修改是否落在声明的 ownership 范围内；
- 要求的 verification 是否真正执行；
- 需要独立审查时，是否存在有效的 review；
- verification 和 review 是否仍对应当前代码状态；
- 当前任务是否满足进入 `completed` 的条件。

其中比较关键的是 evidence freshness。

验证和审查结果会绑定当时的 repository fingerprint。后面代码继续变化，旧结果不会继续自动生效。

```text
Code A
├─ verification: pass
└─ review: ship
        │
        │ 又发生修改
        ▼
Code B

A 的验证和审查不能继续证明 B
```

因此一次任务真正结束前，大致会经过：

```text
implementation
      ↓
ownership
      ↓
verification
      ↓
review（按需）
      ↓
evidence freshness
      ↓
completion gate
```

这套机制主要针对多文件、长时间和多 Agent 参与的任务。简单修改没有必要强行套完整流程。

这里的重点也不是“多加一个 Reviewer”，而是让任务完成尽量对应当前仓库里的真实状态，而不是只依赖 Agent 对自己的判断。

## 连续性：任务被打断以后还能接着做

长任务的另一个问题是中断。

GLM Coding Plan 的额度窗口只是其中最直接的一种情况。任务可能还没有完成，但当前额度已经不可用。等到下一窗口，再让 Agent 继续时，需要恢复的不只是聊天内容，还包括真实任务状态。

GLM Conductor 为长任务保存 Work Unit、task state、journal、checkpoint 和 resume manifest。

其中一个基本原则是：

> checkpoint 用来找回执行位置，repository 用来判断真实状态。

恢复时不会简单读取“上次做到哪里”，然后直接往下跑，而是重新检查当前仓库、Work Unit 和已有验证结果。

例如，一个子任务可能在记录里已经写成 completed，但用户后来又手动改了相关文件，那么恢复时就不能继续把旧验证当成有效事实。

### Quota 也被当成运行状态，而不是定时器

如果只处理额度问题，最简单的办法是“五小时以后再唤醒一次”。

但 scheduler fire 和 quota 真正可用不是同一件事。

所以当前设计里，任务关注的是 Quota Epoch，而不是某个固定时间点。

```text
Quota Observation
       ↓
   Quota Epoch
       ↓
  Subscription
       ↓
Resume Eligibility
       ↓
     Resume
```

Watcher 可以在会话休眠期间观察额度状态，但它不调用模型，也不直接给休眠会话塞一个新回合。

当前稳定的激活方式是 `recurring_bridge`。ZCode Scheduled Task 周期性提供一次唤醒机会，Runtime 再判断当前是不是新的 executable epoch，以及任务是否真的具备恢复资格。

这样可以把几件事分开：

```text
定时器触发
≠
额度恢复
≠
任务恢复
≠
额度窗口被消费
```

同一个窗口重复触发，也不会因此把同一任务重复恢复多次。

连续性控制还会保留用户授权边界。任务可以配置成只通知、单次自动恢复或持续执行，并限制允许跨越的额度窗口数量。长任务可以自动继续，但不会默认无限运行。

## GLM Conductor 在 ZCode 里处于哪一层

当前项目结构可以简单理解成：

```text
GLM-5.3 / GLM-5.3-Flash
            ↓
          ZCode
Agent / Tools / Subagent / Hook / Automation
            ↓
      GLM Conductor
      ├─ 路由
      ├─ 执行保障
      └─ 连续性
```

其中：

**路由**决定当前任务该由主模型处理，还是适合交给实施 Agent，以及是否需要额外审查。

**执行保障**负责确认修改范围、验证结果和审查证据仍然对应当前仓库，避免“Agent 已经说完成”直接变成任务完成。

**连续性**负责保存长任务状态，并在额度或会话中断以后，根据当前真实状态重新接续执行。

这也是项目目前比较明确的边界。

它不是新的通用 Agent Harness，也没有准备和 ZCode、Codex、Claude Code 之类的平台竞争 Subagent、工具系统或者 Agent 数量。底层 Harness 越完善，GLM Conductor 反而可以越轻，只保留和任务控制有关的部分。

## 后续方向

Coding Agent 能处理的任务越来越长以后，过程控制会变得更重要。

额度窗口只是一个很具体的例子。类似的等待条件还可能来自 CI、API 限流、外部任务、计算资源或者人工确认。

后续更值得继续处理的，是同一类问题：任务暂停以后怎样保留真实进度，外部条件变化以后怎样安全恢复，以及怎样避免重复执行和状态漂移。

GLM Conductor 会继续沿着路由、执行保障和连续性这三条线收敛，而不是继续增加 Agent 角色。

项目地址：[github.com/Chengy257/glm-conductor](https://github.com/Chengy257/glm-conductor)