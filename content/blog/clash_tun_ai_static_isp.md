---
title: "从 Codex stream 断连到 Clash Verge TUN 分流：一次 AI 专用静态 ISP 代理配置记录"
date: 2026-06-11
tags: [Clash Verge, TUN, Codex, OpenAI, Static ISP, SOCKS5, GitHub, Bing]
---

# 从 Codex stream 断连到 Clash Verge TUN 分流：AI 专用静态 ISP 代理配置记录

本文记录了一次典型的网络代理排查过程。最初的问题并非"要配置一套复杂的 Clash 规则"，而是 **Codex 在使用的过程中反复出现 stream 断连、TLS 握手中断、响应流中途 EOF 等问题**。为了让 Codex / ChatGPT / OpenAI API 这类 AI 服务更稳定地运行，我尝试在 Clash Verge 的 TUN 模式下，为 AI 服务单独建立了一条静态 ISP 代理通道。之后又遇到了 Bing、GitHub 在 TUN 模式下访问异常的情况，最终形成了一套相对保守、便于维护的配置方案。

本文不是一份"一键复制即可适配所有网络环境"的模板，而是一次从问题发现、方案尝试、异常排查到最终收敛的完整配置复盘。

---

## 1. 问题起点：Codex compact stream 最近总是断

最初的现象是 Codex 使用不够稳定，常见报错如下：

```text
stream disconnected before completion: tls handshake eof
```

这类错误表面上看像是模型接口的超时问题，或者是客户端的 TLS 握手问题。我一开始也尝试从 Codex 自身的配置入手，比如增大 `stream_idle_timeout_ms`、提高重试次数，甚至希望通过环境变量给 Codex 单独指定代理。但在实际排查中发现，这些手段只能缓解部分症状，无法从根本上解决问题。

真正的症结在于以下几点：

- 通过 Windows 应用商店安装的 Codex App，不像普通 CLI 工具那样可以方便地通过启动脚本注入代理环境变量。
- Clash Verge 同时开启系统代理和 TUN 代理后，应用流量的实际走向并不直观。
- 普通订阅节点会受到订阅规则、分组策略、`MATCH` 规则的影响，不一定能稳定命中预期节点。
- AI 服务对出口网络质量、IP 类型、TLS 稳定性以及长连接的表现都比较敏感。

因此，后续的目标逐渐清晰：**不把所有流量都交给同一个全局代理，也要依赖订阅分组的默认规则，而是为 AI 服务单独指定一个稳定的静态 ISP 出口。**

---

## 2. 为什么需要静态 ISP 代理？

普通代理订阅更适合日常访问场景——节点多、切换快、价格低，但同时也存在一些潜在问题：

1. 出口 IP 变动频繁。
2. 部分节点共享人数较多，出口质量不稳定。
3. 各节点的 TLS 稳定性、长连接表现参差不齐。
4. 订阅规则可能将不同 AI 域名分配到不同分组，导致请求链路不一致。

静态 ISP 代理的核心价值在于：**出口 IP 相对固定，网络画像更接近普通住宅或 ISP 用户，适合对稳定性、登录状态保持和风控敏感的服务。**



---

## 3. 先确认代理本身是否可用

先独立测试 SOCKS5 入口是否可用。

最直接的测试方式如下：

```powershell
curl.exe -x socks5h://用户名:密码@IP:端口 https://api.ipify.org
```

如果返回结果为：

```text
IP
```

就说明该 SOCKS5 代理本身可以正常连通，且出口 IP 符合预期。

之后可能还需要测试 SOCKS5 入口是否支持 UDP relay，最终节点配置中可以使用：

```javascript
udp: true
```

如果代理服务商不支持 UDP，则保守设置为 `udp: false`。这一步因代理不同而异，需要实际测试验证。

---

## 4. 方案核心：订阅配置 + 全局扩展脚本

最终没有选择直接修改 Clash 订阅文件，而是通过 Clash Verge 的"全局扩展脚本"以补丁的方式进行配置。

这样做有几个好处：

- 订阅更新后，自定义配置不会被覆盖。
- 静态 ISP 节点可以自动注入到当前配置中。
- AI 相关域名规则可以统一前置，优先级高于订阅内置规则。
- 后续新增或删除 AI 域名，只需维护一个数组即可。
- 可以在同一个脚本中统一处理 TUN、fake-ip、route-exclude-address 等设置。

从整体策略上看，最终并不是"全局都走静态 ISP"，而是：

```text
AI 服务          → Static-ISP-SOCKS5
静态代理入口 IP   → DIRECT
GitHub / Bing 等异常目标 → 按需绕开 TUN 或使用真实 DNS
其它流量          → 保持订阅原有规则
```

这既避免了静态 ISP 被大量无关流量占用，也能减少因全局代理而引发的访问异常。

---

## 5. AI 域名应该如何维护？

本次配置主要覆盖以下服务类别：

- OpenAI / ChatGPT / Codex
- Claude / Anthropic
- Gemini / Google AI Studio / Google Generative Language API
- Cursor / Anysphere
- Google 登录、OAuth、API 相关依赖
- 少量 AI 服务常见的静态资源、统计、客服或风控域名

原则是：**只把明确与 AI 服务相关的域名加入静态 ISP，避免范围扩得过大。**

例如可以加入：

```text
openai.com
chatgpt.com
oaistatic.com
oaiusercontent.com
anthropic.com
claude.ai
generativelanguage.googleapis.com
aistudio.google.com
cursor.sh
anysphere.co
```

不建议加入：

```text
cloudflare.com
*.cloudflare.com
```

因为 Cloudflare 覆盖范围太广，一旦把整个 Cloudflare 都导入静态 ISP，大量与 AI 无关的网站也会被错误分流，导致速度下降、规则污染，甚至引入新的访问问题。

相对稳妥的做法是：如果确实观察到某个 AI 服务依赖了特定的 Cloudflare 上报域名，只加入类似：

```text
a.nel.cloudflare.com
```

而不是泛化到整个 `cloudflare.com`。

---

## 6. TUN 模式下如何判断规则是否生效？

Clash Verge 开启 TUN 后，连接面板中会出现一些看起来比较"奇怪"的地址，例如：

```text
源地址: 198.18.0.1:54601
类型: Tun(tcp)
```

这通常不是异常。`198.18.0.0/15` 网段常见于 TUN / fake-ip 场景，是 Clash/Mihomo 用来接管连接和映射域名的虚拟地址段。

更关键的是观察连接记录中的以下信息：

```text
主机: chatgpt.com:443
链路: Static-ISP-SOCKS5
规则: DomainSuffix(chatgpt.com)
类型: Tun(tcp)
```

如果能看到 `chatgpt.com` 命中了 `DomainSuffix(chatgpt.com)`，且链路显示为 `Static-ISP-SOCKS5`，基本就可以确认 AI 域名规则已经生效。

此时再结合出口 IP 测试，即可完成以下验证：

1. SOCKS5 节点本身可用。
2. Clash 规则命中了静态 ISP 节点。
3. TUN 模式下相关应用流量已被正确接管。

---

## 7. 关键配置片段：全局扩展脚本骨架

下面是经过精简的核心结构。

```javascript
function main(config) {
  var proxyName = "Static-ISP-SOCKS5";

  var staticProxy = {
    name: proxyName,
    type: "socks5",
    server: "替换IP",
    port: 替换端口,
    username: "用户名",
    password: "密码",
    udp: true
  };

  // 注入 / 覆盖静态 ISP 节点
  if (!config.proxies) config.proxies = [];
  config.proxies = config.proxies.filter(function (p) {
    return p.name !== proxyName;
  });
  config.proxies.unshift(staticProxy);

  // TUN 模式下增强进程识别，便于 Codex.exe 等进程规则生效
  config["find-process-mode"] = "always";

  // AI 相关域名，统一强制走静态 ISP
  var staticDomains = [
    "openai.com",
    "chatgpt.com",
    "oaistatic.com",
    "oaiusercontent.com",
    "featuregates.org",
    "featureassets.org",
    "statsig.com",
    "statsigapi.net",

    "anthropic.com",
    "claude.ai",

    "aistudio.google.com",
    "generativelanguage.googleapis.com",
    "ai.google.dev",
    "gemini.google.com",

    "cursor.sh",
    "anysphere.co",
    "anysphere.cursor-retrieval.com",

    "accounts.google.com",
    "oauth2.googleapis.com",
    "www.googleapis.com"
  ];

  var aiRules = [];

  // 静态代理入口必须直连，避免代理回环
  aiRules.push("IP-CIDR,替换静态ISP代理IP,DIRECT,no-resolve");

  // Codex 相关进程可优先指定到静态 ISP
  aiRules.push("PROCESS-NAME,Codex.exe," + proxyName);

  for (var i = 0; i < staticDomains.length; i++) {
    aiRules.push("DOMAIN-SUFFIX," + staticDomains[i] + "," + proxyName);
  }

  if (!config.rules) config.rules = [];
  config.rules = aiRules.concat(config.rules);

  return config;
}
```

后面发现某个 AI 相关域名没有走静态 ISP，往 `staticDomains` 中追加即可。

---

## 8. 后续问题：GitHub 和 Bing 访问异常

AI 分流稳定后，又遇到了新的问题：开启 TUN 后，GitHub 和 Bing 访问出现异常。例如测试 GitHub 时：

```powershell
curl.exe -Iv https://github.com --connect-timeout 10
```

结果卡在某个 GitHub IP 上并超时：

```text
Trying 20.205.243.166...
Connection timed out after 10016 milliseconds
```

类似地：

```powershell
curl.exe -Iv https://api.github.com --connect-timeout 10
```

也可能卡在：

```text
Trying 20.205.243.168...
Connection timed out after 10016 milliseconds
```



---

## 9. 最终处理：route-exclude-address + fake-ip-filter

针对 GitHub / Bing 这类在 TUN + fake-ip 场景下容易出现问题的目标，最终从两个方向进行了修正。

### 9.1 排除特定网段，避免 TUN 接管

在 Clash Verge 的 TUN 设置中，可以找到类似"排除自定义网段"的配置项，加入以下内容：

```yaml
tun:
  route-exclude-address:
    - 静态 ISP 代理入口 
    - 20.205.243.0/24
    - 185.199.108.0/22
```

各项含义如下：

- 静态 ISP 代理入口自身必须直连，防止代理回环。
- `20.205.243.0/24`：GitHub 某些解析结果所在的网段。
- `185.199.108.0/22`：GitHub Pages / raw.githubusercontent.com 等常见 GitHub 静态资源网段。

如果 Clash Verge 图形界面提供了"TUN 设置 → 排除自定义网段"，可以直接在界面中添加这些 CIDR；如果没有，也可以通过全局扩展脚本合并到 `config.tun["route-exclude-address"]`。

需要强调的是，这些网段并非永远固定不变的"GitHub 完整 IP 列表"，只是在本次排查中观察到并用于解决当前环境问题的保守例外。以后如果 GitHub 解析到新的异常 IP，仍需根据实际情况补充。

### 9.2 对 GitHub / Bing 使用真实 DNS 解析

另一个方向是减少 fake-ip 对这些站点的影响。可以在 `fake-ip-filter` 中加入：

```yaml
dns:
  fake-ip-filter:
    - "*.github.com"
    - "github.com"
    - "*.githubusercontent.com"
    - "githubusercontent.com"
    - "*.githubassets.com"
    - "githubassets.com"
    - "*.bing.com"
    - "bing.com"
    - "*.bingapis.com"
    - "bingapis.com"
```

这样 GitHub / Bing 相关域名会尽量使用真实 DNS 解析结果，而不是被 fake-ip 映射到虚拟地址后再由 TUN 处理。

---

## 10. 最终策略总结

整套配置最终收敛为一个层次清晰的分流策略：

| 流量类型 | 处理方式 |
|---|---|
| OpenAI / ChatGPT / Codex | 强制走 `Static-ISP-SOCKS5` |
| Claude / Anthropic | 强制走 `Static-ISP-SOCKS5` |
| Gemini / Google AI | 强制走 `Static-ISP-SOCKS5` |
| Cursor / Anysphere | 强制走 `Static-ISP-SOCKS5` |
| 静态 ISP 入口 IP | `DIRECT`，避免代理回环 |
| GitHub / Bing 异常域名 | 按需加入 `fake-ip-filter` |
| GitHub 异常 IP 网段 | 按需加入 `route-exclude-address` |
| 其它普通流量 | 保持订阅原有规则 |



---

## 11. 排查体会

### 11.1 不要一开始就怀疑客户端

Codex stream 断连看上去很像客户端或模型服务的问题，但在网络不稳定、代理链路复杂、TUN 接管不够透明的情况下，真正的原因往往出在路由层和出口层。

### 11.2 AI 服务适合单独分流

AI 登录、网页、API、客户端长连接最好保持出口一致。尤其是 ChatGPT、Codex、Claude、Gemini 这类服务，不建议让不同域名随机落到不同的订阅节点上。

### 11.3 静态 ISP 不适合全局滥用

静态 ISP 的价值在于稳定和出口固定，不是用来承载所有下载、网页浏览和开发流量的。把 GitHub、Bing、Cloudflare 全部塞进去，短期来看省事，长期会让规则越来越不可控。

### 11.4 TUN + fake-ip 的问题要分开看

TUN 负责接管流量，fake-ip 负责 DNS 映射。遇到访问异常时，需要分别判断：

- 是域名规则没有命中？
- 是 fake-ip 映射导致目标异常？
- 是某个 IP 网段被 TUN 接管后不可达？
- 是代理入口自身被错误代理导致了回环？

不同原因对应不同的解法，不能一律用"加入代理规则"来应付。

### 11.5 保守配置比大而全更容易维护

AI 域名列表不需要一开始就写成"互联网大全"。更推荐的做法是从核心域名开始，观察 Clash 连接面板，缺什么补什么。

---

## 12. 一个更稳妥的维护流程

后续如果继续维护这套配置，可以按照以下流程操作：

1. 打开 Clash Verge 连接面板。
2. 正常使用 Codex / ChatGPT / Claude / Gemini / Cursor。
3. 观察相关域名是否命中 `Static-ISP-SOCKS5`。
4. 如果某个 AI 域名没有命中，将其加入 `staticDomains`。
5. 如果 GitHub / Bing 出现异常，不要直接加入静态 ISP，先判断是否是 TUN / fake-ip / IP 网段问题。
6. 新增任何 `route-exclude-address` 之前，先用 `curl -Iv` 或浏览器测试确认异常目标。
7. 每次修改后重载 Clash 配置，并再次观察连接面板。

---

## 13. 结语

这次配置的出发点仅仅是 Codex stream 断连，但最终解决的，实际上是一整套"AI 服务如何在 TUN 模式下稳定分流"的问题。

最终方案可以概括为：

> 在保留订阅规则的基础上，通过全局扩展脚本注入静态 ISP 节点，并将 OpenAI、Claude、Gemini、Cursor 等 AI 服务的域名规则前置；同时对静态代理入口、GitHub、Bing 这类容易在 TUN / fake-ip 下出问题的目标做保守排除或真实解析处理。

相比全局代理，这种方式更加克制，也更容易排查。不把所有网络问题都强行推给同一个代理节点，而是把不同类型的流量放回各自合适的位置。
