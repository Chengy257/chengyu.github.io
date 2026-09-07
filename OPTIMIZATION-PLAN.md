# OPTIMIZATION-PLAN.md — 站点优化计划（2026-09-03 制定；2026-09-07 第二轮审查增补第五阶段）

> 依据 2026-09-03 全面审查（配置/内容/布局盘点 + 本地构建 + 浏览器截图审查：首页/博客列表/文章/简历/暗色/移动端）制定。
> 本文件是优化工作的唯一任务清单；完成后勾选并在「状态」列记录日期。涉及构建与回归的验证统一按 `AGENTS.md` §2/§4 执行。

## 0. 范围与约束（已与站点所有者确认）

1. **博客不使用真实个人照片**：照片仅用于简历页（`static/images/myphoto.jpg` + `layouts/_default/cv.html`）。博客侧的视觉锚点（hero、头像、og:image 等）一律采用非照片方案（图标 / 首字母 monogram / 抽象插画 / 自动生成图）。
2. **简历页现有设计必须保留为可切换版本**：当前 `layouts/_default/cv.html`（蓝色系、内嵌 CSS）已复制为 `layouts/_default/cv-classic.html` 原样封存。后续对简历页的任何优化只改 `cv.html`（或新建 `cv-v2`），通过 `content/about.md` 的 `layout:` 字段一键切换回 `cv-classic`。
3. 其余按 2026-09-03 审查报告执行；主题目录内文件仍禁止直接修改（AGENTS.md §1）。
4. 每个阶段完成后：WSL 内 `hugo --minify --gc --cleanDestinationDir` 须 0 error/0 warn；`git status`（父仓库+子模块）全绿后由所有者按惯常流程提交。

## 1. 第一阶段：快速修复（bug 与失效配置）—— ✅ 2026-09-03 全部完成并通过验证

| # | 任务 | 涉及文件 | 验收标准 | 状态 |
|---|------|----------|----------|------|
| 1.1 | 修复 GLM Conductor 文章 tags 的 YAML 引号缺失（渲染出 `开源"` 脏标签） | `content/blog/glm-conductor-blog-humanized-v3.md` | 首页/列表/文章页标签为 `开源`，无引号残留；`hugo` 构建 0 warn | ✅ 2026-09-03 |
| 1.2 | 页脚版权修复：Hextra 页脚读 i18n 键 `copyright`（zh-cn.yaml:31），config 的 `params.footer.copyright` 不生效 | 新建 `i18n/zh-cn.yaml`（项目级覆盖） | 页脚显示「© 2024–2026 程宇 (Cy257)」；年份更新规则记入 §5 | ✅ 2026-09-03 |
| 1.3 | 文章页作者署名：文章用单数 `author`，模板消费 `.Params.authors`（复数）导致不渲染 | `layouts/blog/single.html`（项目覆盖文件，允许改） | 文章页标题下方显示「日期 · Cy257」 | ✅ 2026-09-03 |
| 1.4 | 导航栏加主题切换按钮（Hextra 支持 `theme-toggle` 菜单项，当前只有页脚一处且不可点） | `config.yml`（main 菜单追加） | 导航栏出现切换图标，亮/暗切换即时生效且刷新后保持 | ✅ 2026-09-03 |
| 1.5 | Hero 排版清理：移除 `<br> </br>` 伪空行（无效 HTML） | `layouts/hextra-home.html` | 欢迎语与简介间距正常，无空段落 | ✅ 2026-09-03 |
| 1.6 | 简历页版本封存：现有 cv 设计复制为独立布局，保证随时可切回 | `layouts/_default/cv-classic.html`（新增，`cv.html` 原样拷贝） | `layout: cv` 与 `layout: cv-classic` 均可正常渲染 | ✅ 2026-09-03 |
| 1.7 | 内容约定补充：博客不放真实照片、cv-classic 封存说明写入 AGENTS.md §5 | `AGENTS.md` | 约定可查，后续 agent 遵守 | ✅ 2026-09-03 |

> 验证记录（2026-09-03）：dev server 重启后 curl 断言全部通过（脏标签 0 处、页脚新版权 1 处、导航栏+页脚切换按钮 3 处、文章 meta 行 `2024-07-01 · Cy257`）；生产构建 0 error/0 warn（170 页）；子模块 status 干净。

## 2. 第二阶段：视觉与体验升级（1–2 天）—— ✅ 2026-09-03 全部完成

| # | 任务 | 说明 / 方案 | 验收标准 | 状态 |
|---|------|-------------|----------|------|
| 2.1 | 站点标识三件套 | monogram 素材（`static/favicon.svg`、`static/images/logo.svg`）+ 位图（favicon 16/32/ico、apple-touch 180，PIL 缩放）+ og 分享卡（`static/images/og-image.png` 1200×630，由 `og-card.svg` 渲染）；config 开 `displayLogo` + `params.images` | 页签图标/导航 logo/og:image 均生效（curl 200 + meta 确认） | ✅ 2026-09-03 |
| 2.2 | Hero 重构（**不含真实照片**） | 左对齐体系；CY monogram 渐变徽标替代 👋 emoji（`.cy-hero-id/.cy-hero-avatar`）；徽章贴左 | 亮/暗色桌面+移动端截图通过；无布局抖动 | ✅ 2026-09-03 |
| 2.3 | 主题色统一 | Hextra primary 为 hue 驱动（`--primary-hue/saturation`），custom.css 覆盖为绿（152deg/48%，暗色 54%），博客侧（导航/代码块底色/高亮行）生效。~~cv.html 蓝转绿~~ **已回退**：所有者反馈简历页绿色太艳太亮，`cv.html` 从 `cv-classic.html` 恢复**原深蓝主题**。最终定案：**博客绿 / 简历蓝**双配色共存（AGENTS.md §5 已记录，勿再强行统一） | 博客侧绿色统一；简历页恢复原深蓝 | ✅ 2026-09-03 |
| 2.4 | 代码块亮色适配 | **核实为误报**：亮色模式代码块本就是浅色自适应（chroma light/dark 双套规则正常加载，pre 底色为 primary-700 的 5% 混色）；早前审查把暗色截图误记为亮色问题。另发现 dev 分支多发的 `variables.css`/`custom.css` 冗余链接会 404（生产为拼接单文件，不受影响），属上游 dev-only 现象，不处理 | 亮/暗两套截图复核通过 | ✅ 2026-09-03 |
| 2.5 | 暗色对比度 | `.dark` 下 mint 绿文字系（#5bd6a2/#7ce3bb）用于 tag/徽章/链接/年份标题等，`--cy-text-muted/secondary` 提亮 | 截图复核，正文对比 ≥ AA | ✅ 2026-09-03 |
| 2.6 | 卡片交互反馈 | 仓库卡 hover 补 `translateY(-2px)`（与文章卡一致）；补 `:focus-visible` 外框；未新增 `!important` | hover/键盘焦点有反馈 | ✅ 2026-09-03 |
| 2.7 | 移动端回归 | 375px 实测发现长仓库名致 53px 横向溢出 → `.cy-repo-card` 限宽 + `.cy-repo-name` `overflow-wrap:anywhere` + header 允许换行 | 复测 `scrollWidth-innerWidth = -15px`（无溢出） | ✅ 2026-09-03 |
| 2.8 | Hero 视觉精修（所有者反馈迭代 ×3） | 迭代轨迹：全左对齐 → 深绿实色卡（太绿，否决）→ 白底弱辉光（太散，否决）→ **最终版：浅绿渐变大圆角面板**——`#f2f9f5→#d9eee2` 浅渐变 + 描边 + 柔投影，与白底自然融合；内容居中，头像+标题并排（72px monogram 白圈），角落装饰圆 + 渐隐点阵；暗色模式换深绿黑面板（`#12291e→#1b3f2f`）；入场动画保留，640px 降档 | 亮暗截图验收通过 | ✅ 2026-09-03 |

## 3. 第三阶段：内容与 SEO（持续项）—— ✅ 2026-09-03 全部完成

| # | 任务 | 说明 | 验收标准 | 状态 |
|---|------|------|----------|------|
| 3.1 | summary 质量线 | 重写 Ribo-seq adapter 一文的占位式 summary；质量规则写入 AGENTS.md §5（不得与标题雷同/标点悬空结尾） | 全部文章 summary 为完整表述 | ✅ 2026-09-03 |
| 3.2 | 图床本地化 | 5 张外链图（jsDelivr×4 + raw.githubusercontent×1）下载至 `static/images/posts/`（其中 `640` 实为 WebP 已正名）；新建 `img` shortcode（relURL + lazy + 宽高）；AGENTS.md §5 记录用法 | 构建 HTML 0 外链图片引用；图片 200 | ✅ 2026-09-03 |
| 3.3 | URL 规范统一 | 3 篇下划线/大写文章加 `slug`（小写连字符），旧 URL 全部写入 `aliases`（meta-refresh 跳转页已生成） | 新旧 URL 均 200；sitemap 更新 | ✅ 2026-09-03 |
| 3.4 | 旧测试文处理 | `my-first-blog.md` 置 `draft: true`（2022 PaperMod 时代测试文，生产不再渲染/列表不再出现） | 生产无该页 | ✅ 2026-09-03 |
| 3.5 | 评论系统 | ✅ **已启用并实测可用**（2026-09-03）：Discussions 已开启、giscus App 已由所有者安装、repoId/categoryId（Announcements）填入、评论区加载正常（0 评论 + GitHub 登录按钮，暗色自适应） | ✅ 2026-09-03 |
| 3.6 | 文章元信息 | 文章头新增「约 N 分钟读完」（`.ReadingTime`）；lastmod 经排查**本来就在文章底部渲染**（「最后更新于」，早前审查未截到），无需修复 | 截图/curl 确认 | ✅ 2026-09-03 |
| 3.7 | SEO 杂项 | og:description 已消费 summary（抽查正常）；robots.txt + sitemap.xml 均在构建产物中；线上最终验证待下次部署后冒烟 | 构建产物齐备 | ✅ 2026-09-03 |

## 4. 第四阶段：进阶

| # | 任务 | 说明 | 验收标准 | 状态 |
|---|------|------|----------|------|
| 4.1 | 域名策略 | **决策（2026-09-03，所有者确认）：维持现状**——继续使用 GitHub Pages 项目站 + 子路径 `https://chengy257.github.io/chengyu.github.io/`。零风险零成本；后续如需切换（改名升用户站 / 绑自定义域名）再重开此项，届时旧链接用 GitHub 仓库重定向 + 全站 aliases 兜底 | 决策已记录 | ✅ 维持现状 |
| 4.2 | 相关文章 | Hugo Related Content：config `related`（tags 80 / categories 40，threshold 50，includeNewer）+ single.html 底部「相关文章」3 卡区块（复用 post-card 样式，响应式 3/2/1 列）。WGCNA 页实测推荐 R 绘图/基因组注释/Ribo-seq 三篇，相关度合理。`series` 分类法留待真有连载内容时再启用 | 文章页底部出现 3 张相关卡片 | ✅ 2026-09-03 |
| 4.3 | CI 防线 | 新增 `.github/workflows/audit.yml`：每周一自动 + 手动触发。①lychee 死链检查（构建后扫全部 HTML；`lychee.toml` 排除学术出版社 403 误报域；报告传 artifact，断链即红）；②Lighthouse 巡检线上首页/列表/简历页（treosh action，报告传 artifact） | 首次推送后 Actions 出现 Site audit 工作流 | ✅ 2026-09-03（待推送后首跑） |
| 4.4 | custom.css 渐进重构 | 23 处 `!important` 中大部分服务于文章页标题/边距覆盖与布局兜底，单独摘除有回归风险。**定位为持续项**：每次主题升级回归时顺手把当日触及的规则迁移到 CSS 变量/`hx:` 工具类，不在本专项内一次性处理 | `!important` 数量随升级逐步下降 | 🔁 持续项 |

## 5. 第五阶段：导航与分类/标签体系优化（2026-09-07 审查后制定）—— ✅ 2026-09-07 全部完成并通过验证

> 依据 2026-09-07 审查（导航信息架构 + 分类/标签数据盘点 + Hextra 默认 `taxonomy.html`/`term.html` 模板核对）制定。**导航采用收敛方案**：主菜单只保留主动线；分类作为博客列表的筛选维度；标签降级为页内横向元素（文章底部/卡片/相关文章处已有）；分类/标签归档页保留 URL（SEO 与外链不受影响）但页面重设计。
> **对 09-07 审查初稿的两项更正**：① `my-first-blog.md` 已是 draft（3.4），「测试」标签与「杂记」分类不进生产，无需治理；② 页脚版权由 i18n 控制（1.2），已是 2024–2026 并非写死，无需修复。

### 数据基线（2026-09-07 实测）

- 生产 15 篇（另有 1 篇 draft）；**分类 5 个**：NGS分析(8)、工具开发(3)、生信基础(1)、工具使用(1)、R绘图(1)；clash 一文未分类。
- **标签 ~57 个**，仅 6 个出现 ≥2 次 → 绝大多数词条页只有一篇文章，作为导航级入口价值低。
- 移动端主导航文字链接被主题隐藏（navbar-link `hidden md:inline-flex`），汉堡抽屉是唯一移动导航；**分类目前移动端不可达**（menu.sidebar 仅 简历/标签）。

### 5.1 数据治理（P0，半小时级）

| # | 任务 | 涉及文件 | 验收标准 | 状态 |
|---|------|----------|----------|------|
| 5.1.1 | 标签大小写统一：`plink` → `PLINK`（官方写法；gwas-analysis 已用 PLINK） | `content/blog/population-evolution-analysis.md` | 生产构建 public/tags/ 下只有 `plink/`（PLINK）一个词条；`grep -rn '"plink"' content/` 无残留 | ✅ 2026-09-07 |
| 5.1.2 | 唯一未归类文章补分类：`categories: ["工具使用"]` | `content/blog/clash_tun_ai_static_isp.md` | /categories/ 五词条覆盖全部 15 篇，工具使用=2 | ✅ 2026-09-07 |
| 5.1.3 | 命名约定写入 AGENTS.md §5：软件名用官方大小写；新增 tag 前先 grep 全站已有；一文一 category | `AGENTS.md` | 约定可查 | ✅ 2026-09-07 |

### 5.2 分类/标签归档页重设计（P1，约半天）

视觉沿用现有 cy-* 设计语言（浅色绿系、卡片化），不引入新配色；按所有者偏好小步迭代 + 截图裁决。

| # | 任务 | 说明 / 方案 | 验收标准 | 状态 |
|---|------|-------------|----------|------|
| 5.2.1 | 覆盖 taxonomy 落地页 | 新建 `layouts/taxonomy.html`（项目根，覆盖主题默认；未来 series 启用时同模板生效）：标题区（N 个分类 · M 篇）；**categories** = 卡片网格（复用 cy-post-card 语言：分类名 + 篇数徽章 + 中文描述 + hover 反馈），`.Data.Terms.ByCount` 降序；**tags** = tag cloud（count 决定字号/明度梯度，≥2 篇强调）；模板以 `.Data.Plural` 区分两类 | /categories/ 与 /tags/ 亮暗 × 375/1440 截图通过；57 标签无横向溢出；构建 0 warn | ✅ 2026-09-07 |
| 5.2.2 | 覆盖词条页 | 新建 `layouts/term.html`：头部（← 全部分类/标签 返回链接、标题、共 N 篇、分类描述）；条目复用博客列表 cy-blog-item 结构（日期/标题/summary/≤3 标签）按年份分组；保留主题 wrapper（sidebar 禁用、无 TOC） | /categories/ngs分析/（8 篇分年）与单篇词条页（如 /tags/r/）截图通过；返回链接可达 | ✅ 2026-09-07 |
| 5.2.3 | 分类描述单一数据源 | 新建 `data/categories.yml`（key 用小写；模板 `index site.Data.categories (lower $term)` 查询，缺失时降级不显示描述）；记入 AGENTS.md §5 数据源清单 | 5 个分类卡片描述渲染正常；未知分类不报错不显示 | ✅ 2026-09-07 |
| 5.2.4 | 配套 CSS | custom.css 新增 `cy-tax-*`：卡片响应式网格（3/2/1 列）、云图字号梯度、返回链接、`:focus-visible`；`.dark` 变体；**不新增 `!important`** | 亮暗两档截图；`grep -c '!important'` 数量不增 | ✅ 2026-09-07 |
| 5.2.5 | （实施中发现）Hugo 默认 `capitalizeListTitles` 把词条标题改写为 Title Case（argparse→Argparse、ggplot2→Ggplot2、vcftools→Vcftools），与文章页标签 chips 不一致且违背软件官方大小写 | `config.yml` 关闭该默认项 | 词条页 `<title>`/h1/云图显示与 front matter 完全一致（复测 argparse/ggplot2/vcftools 均原样） | ✅ 2026-09-07 |
| 5.2.6 | （实施中发现）沿用主题默认的 sidebar 占位 + 空 toc 调用会在 xl 桌面产生两个空列，归档内容被挤到 ~715px | 两个模板移除 `displayPlaceholder` 与 `toc.html` 调用（同博客列表做法） | 1440 桌面内容宽 ~76rem，3 列卡片舒展（截图复测） | ✅ 2026-09-07 |

### 5.3 导航收敛（P2，1 小时级）

| # | 任务 | 涉及文件 | 验收标准 | 状态 |
|---|------|----------|----------|------|
| 5.3.1 | 主菜单收敛为 5 项：首页 / 博客 / 个人简历 / 搜索 / 切换主题（移除 分类、标签） | `config.yml` menu.main | 桌面导航 5 项、当前页高亮正确；归档页仍从博客列表/文章标签可达 | ✅ 2026-09-07 |
| 5.3.2 | 移动抽屉菜单重组：移除与主菜单重复的「个人简历」，换成「分类」「标签」（修复分类移动端不可达） | `config.yml` menu.sidebar | 375px 实测抽屉：无重复项、分类/标签可达 | ✅ 2026-09-07 |
| 5.3.3 | 博客列表左栏「按年份」下新增「按分类」区块（5 分类 + 篇数，链至词条页） | `layouts/blog/list.html` | 桌面/移动截图；链接 200；不破坏现有年份锚点 | ✅ 2026-09-07 |

### 5.4 分页 × 年份锚点隐患（P3，随 5.3 顺手做）

| # | 任务 | 涉及文件 | 验收标准 | 状态 |
|---|------|----------|----------|------|
| 5.4.1 | `params.blog.list.pagerSize: 999`（现状取模板默认 20；超过 20 篇后年份组按当前分页计算，**跨页锚点静默失效**；999 等效单页使锚点永全，pager UI 条件渲染自动隐藏。「跨页锚点跳转」方案评估后不做：实现复杂收益低，记录备查） | `config.yml` | 列表单页渲染、年份锚点全部有效 | ✅ 2026-09-07 |
| 5.4.2 | 移除顶层 `pagination.pagerSize: 10`（无消费方：现有全部 `.Paginate` 均显式传 size；符合 AGENTS §7 死配置纪律） | `config.yml` | 构建 0 warn；分页行为不变 | ✅ 2026-09-07 |

### 5.5 回归与发布 —— ✅ 2026-09-07

> 验证记录（2026-09-07）：生产构建 0 error/0 warn（163 页；首版误用 `site.Data` 触发弃用 WARN，已按 AGENTS §4 迁移为 `hugo.Data`）。本地 dev server 截图验收通过：/categories/ 与 /tags/ 亮/暗 × 1440/375、/categories/ngs分析/（8 篇按 2026/2025/2024 分组、返回链接、分类描述）、/tags/plink/（合并后 2 篇）、/blog/ 左栏「按分类」桌面+移动 chips、移动抽屉（分类/标签经「更多」可达、个人简历不再与主菜单重复）、首页与文章页回归正常。统计口径修正：标签页 meta 行为「共 62 个标签 · 全站 70 次引用」（70 = 标签引用次数，非文章数；分类页 1:1 为「收录 15 篇文章」）。
> 遗留观察（不处理）：移动抽屉中站点树的「个人简介」（about.md 页面标题）与主菜单「个人简历」指向同一 /about/ 页、文案不同，为主题树+菜单并存的自然结果，属既有多语言文案现象。

- 全量回归按 AGENTS.md §4 清单：首页各区块、博客列表年份锚点、文章页 TOC/标签/上下篇/相关文章/评论、简历页论文编号、搜索、亮/暗、移动端；`HUGO_ENVIRONMENT=production hugo --minify --gc --cleanDestinationDir` 0 error/0 warn。
- 提交拆分 4 个 commit：数据治理 / 归档页重设计 / 导航收敛+分页配置 / 文档记录；`git_sync.sh` 推送后确认 Actions 绿，冒烟首页、/blog/、/categories/、/categories/ngs分析/、/tags/。

## 6. 长期维护约定（实施中沉淀）

- 页脚版权年份：每年 1 月检查 `i18n/zh-cn.yaml` 的 `copyright`（当前静态 2024–2026）。
- 新文章图片一律本地 `static/images/`；博客侧永不使用真实人物照片（约束 0.1）。
- 简历页优化永远在 `cv.html`/`cv-v2` 上进行，`cv-classic.html` 只读封存（约束 0.2）。
- **og 图 / favicon 再生成**：位图由 `static/images/og-card.svg`（1200×630 截图）与 `static/favicon.svg`（320×320 截图 → PIL 缩放出 16/32/180/ico）生成；改动这两个 SVG 后需重新渲染覆盖同名 PNG/ICO。
- 每阶段完成当天在本文件勾选并记状态日期；跨阶段的公共回归项：构建 0 warn、亮/暗色、375px/1440px 两档、`git status` 全绿。
