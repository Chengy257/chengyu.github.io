# AGENTS.md — chengyu.github.io 项目约束（对本仓库所有 agent 生效）

> 本文件描述的是**站点仓库**（根级）的约束，优先级高于 `themes/hextra/AGENTS.md`
> （后者只约束 Hextra 主题目录内的开发）。改动本仓库任何文件前先读本文件。

## 1. 项目概览

个人技术博客/简历站（生物信息学方向），技术栈：

- **Hugo**（extended **0.165.0**，版本与 CI 严格一致，见 `deploy.yml` 的 `HUGO_VERSION`；升级走 §4 流程）
- **主题**：Hextra，以 **git submodule** 方式固定于 `themes/hextra`（当前 pin `v0.12.3-17-g38d18a5`，即上游 main；检出 release tag 或其后提交即可升级，禁止在主题目录内直接改文件）
- **站点形态**：GitHub Pages 项目站（Actions 部署，`baseURL` 带 `/chengyu.github.io/` 子路径，勿改回根路径）

## 2. 开发环境（硬约束）

> **注意**：本节正文记录的是 **DSH 远程会话机**（另一台机器）的环境；当前维护所用机器的环境见本节末尾
> 「**本机环境（Windows + WSL Ubuntu-24.04）**」小节，两套记录不可混用（仓库路径、发行版、认证方式均不同）。

所有 git / hugo / gh 命令必须在**本机 WSL** 内执行，Windows 侧仅作文件宿主：

- 仓库路径：`/mnt/f/MyBlog/chengyu.github.io`；发行版：`Ubuntu-18.04`（WSL2，glibc 实测 2.35——曾就地升级，新版 Hugo 可运行）
- Hugo 二进制：`/home/chengyu/.local/bin/hugo`（0.165.0；旧版保留为 `hugo-0.147.4` 供回滚）；hugo 缓存：`/home/chengyu/.cache/hugo_cache`
- git 2.34.1（身份已配置）；gh 已登录 `chengy257`（repo/workflow 权限，可改远端设置）
- 本会话（DSH）执行方式：`wsl -- bash -lc '<命令>'`；Windows 侧 git 有 dubious ownership 问题，禁止使用
- WSL 内网络可直连 github.com；代理类环境变量（HTTP_PROXY 等）可能干扰 git，失败时先 unset 重试
- 换行：仓库统一 LF（`.gitattributes` 已约束）；shell 脚本由 DSH 重写后需 `chmod +x` 恢复可执行位

### 常用命令

```bash
# 生产构建（与 CI 等效；--cleanDestinationDir 避免 public/ 积存孤儿文件）
cd /mnt/f/MyBlog/chengyu.github.io
HUGO_ENVIRONMENT=production hugo --minify --gc --cleanDestinationDir

# 本地预览（WSL 后台运行，Windows 浏览器访问 http://localhost:1313）
hugo server -D --bind 0.0.0.0

# 同步发布（自动 fetch→stash→pull→commit→push，见 git_sync.sh）
./git_sync.sh "commit message"
```

### 本机环境（Windows + WSL Ubuntu-24.04，2026-09-03 实测记录）

- 仓库路径：Windows 侧 `C:\Lab\chengyu.github.io`，WSL 内为 `/mnt/c/Lab/chengyu.github.io`；本机**不存在** `/mnt/f`（上文 `/mnt/f/MyBlog` 为 DSH 机器专属路径）
- 发行版：`Ubuntu-24.04`（WSL2，默认发行版，用户 `chengyu`）。Hugo 已升级至 **0.165.0** extended（`~/.local/bin/hugo`，与 CI 一致；原 0.147.4 已被覆盖）。构建命令同 §2，`cd /mnt/c/Lab/chengyu.github.io` 后执行
- git 认证：本机 `~/.ssh/id_ed25519` **未被 GitHub 接受**（SSH 拉取/推送均失败）；`origin` 已改用 **HTTPS**，fetch/push 走 gh CLI 凭据助手（gh v2.98.0，账号 `Chengy257`，keyring 存储）。认证失效时用 `gh auth login --web` 重新登录，勿改回 SSH
- Windows 侧 Git Bash 对本仓库**可用**（无 §2 所述 dubious ownership 问题，该约束仅针对 DSH 机器）；但 **Hugo 构建仍在 WSL 内执行**，保证与 CI 同版本
- **CRLF 陷阱（本机已踩过）**：Windows git `core.autocrlf=true` 会把 hextra 子模块检出为 CRLF（其 `.gitattributes` 无 eol 规则），Hugo 0.165 解析含 `{{/* … */}}` 注释的模板会直接报 `comment ends before closing delimiter`。已修复：子模块本地设置 `core.autocrlf=false` + `core.eol=lf` 并归一化行尾。本机重装/更新子模块后若构建再报此错，按同样方式处理
- 子模块内 `CLAUDE.md` 是**上游 hextra 跟踪的符号链接**（→ AGENTS.md），由 WSL 侧工具创建，Windows git 无法读取而恒报 modified：已用本地 `git -C themes/hextra update-index --assume-unchanged CLAUDE.md` 屏蔽（仅本地索引标志，不改上游内容）；索引重建（`read-tree`/`reset`）后若 M 复现，重新执行该命令即可，**勿删除或改写该链接**
- 与远端无关的本地散落文件（文章草稿、简历 txt 等）不放仓库根目录：已移至仓库外 `C:\Lab\blog-local-archive\` 归档，新同类文件照此办理
- 日常检查基线：`git status`（父仓库与子模块）应保持全绿

## 3. 分支与发布纪律

- **唯一开发/部署分支：`source`**。远端默认分支已是 `source`；`main` 已删除，禁止重建。
- CI（`.github/workflows/deploy.yml`）只监听 push 到 `source`，用 GitHub Pages Actions 部署。
- `public/`、`resources/_gen/`、`.hugo_build.lock` 为构建产物：**永不提交**（已 gitignore + gitattributes）。
- 每次改动推送后确认 GitHub Actions 绿色，并对线上 URL 冒烟（首页/博客/cv/robots）。

## 4. 版本纪律（升级前必读）

- **WSL 的 hugo 与 CI 的 `HUGO_VERSION` 必须保持同一版本**（当前 **0.165.0**+extended）。升级流程：WSL 实测新版本能运行（glibc 2.35 已过验证）→ 替换 WSL 二进制（旧版改名保留）→ 同步改 `deploy.yml` → 全量回归（构建须 0 warn/error）。
- 新 Hugo 迁移注意：`site.Data` → `hugo.Data`（v0.156+ 弃用）、`languageCode` → `locale`（v0.158+ 弃用）；主题自带 `_partials/utils/hugo-compat/` 兼容层，勿绕开。
- Hextra 升级：`git -C themes/hextra fetch origin` → 检出选定提交（一般取上游 main，须 >= 最新 release tag 且含其后修复）→ 提交 submodule 指针。**升级前通读目标版 release notes 中破坏性变更清单**。
- 主题升级必须回归以下**覆盖文件**（Hextra 布局变更最可能影响它们）：
  - `layouts/hextra-home.html`（首页自定义大改）
  - `layouts/blog/list.html`、`layouts/blog/single.html`（覆盖主题同名列）
  - `layouts/_default/cv.html`、`layouts/_partials/custom/`（自建 partial）
  - `assets/css/custom.css`（大量 `!important` 对抗 Tailwind，主题类名前缀 `hx:` 变更会静默失效）
  - 回归项：首页各区块、博客列表年份锚点/分页、文章页 TOC/标签/上下篇、cv 页论文编号、搜索、亮/暗色、移动端。

## 5. 内容约定（写文章/改简历必读）

- front matter 标准字段：`title / summary / date / draft / tags / categories`。**summary 必填**（首页卡片展示）；新文章默认经 `hugo new`（archetype 含 draft:true）。**summary 质量线**：须概括文章方法与产出，不得与标题雷同、不得以逗号等标点悬空结尾，占位式 summary 视同缺失。
- 标签/分类命名约定（2026-09-07 起）：软件名用官方大小写（如 PLINK、DESeq2、Ribo-seq）；新增 tag 前先 grep 全站已有标签，避免重复词或大小写变体把同一词条页拆成两个（Hugo taxonomy 区分大小写）；一文一 category，漏写会使文章从全部分类动线消失。
- 内容图片引用统一用 `img` shortcode：`{{< img src="images/posts/x.png" alt="说明" width="1630" height="482" >}}`（自动 relURL + lazy + 响应式），源图存 `static/images/posts/`；改文件名时同步 `slug`/`aliases` 规则（URL 一律小写连字符，旧 URL 写入 aliases）。
- 禁止引入 PaperMod 遗留字段（`showToc`、`TocOpen` 等，Hextra 不识别）；文章目录控制用页面参数 `toc: false/true`。
- **单一数据源**（双处展示的内容只改数据文件，禁止双份硬编码）：
  - 论文 → `data/publications.yml`（首页「发表论文」与简历页共用）
  - 教育/工作经历、专业技能、研究兴趣 → `data/profile.yml`
  - 首页「开源项目」卡片 → `data/repos.yml`（描述为中文定制文案；star/语言构建时由 GitHub API 填充，失败自动降级为 0/yml 默认值）
  - 分类描述（分类落地页卡片与分类词条页）→ `data/categories.yml`（key 用小写，模板按 `lower(分类名)` 查询；新增分类时同步补一行，缺失时页面自动降级不显示描述）
- 自由文本例外：`content/about.md` 的「基本信息」「专业技能」段落与首页顶部欢迎语/技能卡片为各自语境定制文本，允许表述不同（改动时注意两处同步）。
- 时区陷阱：`timeZone: Asia/Shanghai`，给文章配未来日期会导致 `buildFuture: false` 下不渲染。
- 图片放 `static/images/`，引用走 `relURL`。
- **博客侧不使用真实人物照片**（所有者 2026-09 明确要求）：照片仅用于简历页；博客 hero/头像/og 图一律用图标、monogram 或插画。
- **简历页保持原深蓝主题**（所有者 2026-09-03 反馈绿色太艳，已从绿回退蓝）：站点为「博客绿 / 简历蓝」双配色，这是有意为之，勿再强行统一。`layouts/_default/cv-classic.html` 为原样封存副本（当前与 cv.html 同源），改简历页只动 `cv.html`，经 `content/about.md` 的 `layout:` 可切回。站点优化总清单见根目录 `OPTIMIZATION-PLAN.md`。

## 6. 首页 GitHub 卡片（hextra-home.html）行为说明

- 构建时以 1 次请求 `GET users/{owner}/repos`（`owner` 与仓库清单在 `data/repos.yml`），`try` 包裹、失败降级（语言/描述用 yml，star=0），**不得移除降级逻辑**。
- `HUGO_GITHUB_TOKEN`（CI 注入 `secrets.GITHUB_TOKEN`）命名带 `HUGO_` 前缀以匹配 Hugo `security.funcs.getenv` 白名单（`^HUGO_`），本地自定义环境变量沿用该前缀。
- 本地离线构建时该区块数据会降级，属预期，不算构建失败。

## 7. 已知坑清单

- 搜索：生产使用**本地 min 版** flexsearch（`assets/js/flexsearch.bundle.min.js`，配置 `params.search.flexsearch.js`），不要改回 debug 版或 CDN 引用（大陆网络不稳）。
- `config.yml` 里只有主题真实读取的键才保留；新增键先查 `themes/hextra/layouts` 是否消费，避免死配置。
- `series` 分类法已配置但暂未启用（预留）。
- 论文条目含 `<u>/<strong>/<sup>` 等 HTML 标记，YAML 字符串经 `safeHTML` 输出；cv 页编号依赖 `<ol>` 结构与 `p:nth-child(1..3)` 顺序，重构时不得改序。
- Hugo 不清理旧产物：本地/CI 构建都加 `--cleanDestinationDir`（见 §2/§3），避免 public/ 积存孤儿 JS。
