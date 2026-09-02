# Cy257's Blog

生物信息学 | NGS 数据分析 | Python/R 脚本 | 学习笔记 — 基于 **Hugo + Hextra** 的个人博客与简历站。

- 站点：<https://chengy257.github.io/chengyu.github.io/>
- GitHub：<https://github.com/Chengy257>

## 技术栈与结构

| 组成 | 说明 |
|---|---|
| Hugo | extended，版本与 `deploy.yml` 的 `HUGO_VERSION` 严格一致 |
| 主题 | [Hextra](https://github.com/imfing/hextra)（git submodule，固定于 `themes/hextra`） |
| 部署 | GitHub Pages + Actions（监听 `source` 分支 push） |
| 数据 | `data/publications.yml`（论文）、`data/profile.yml`（经历/技能）、`data/repos.yml`（开源项目）——首页与简历页共享的单一数据源 |

```
content/        Markdown 内容（blog/ 文章、about.md 简历、_index.md 首页）
layouts/        自定义模板（覆盖 Hextra：首页/博客列表/文章页/cv）
assets/css/     custom.css 自定义样式
data/           结构化数据（单一数据源）
static/images/  静态图片
```

## 开发（WSL）

所有命令在本机 WSL（Ubuntu-18.04）内执行，详细约束见 **[AGENTS.md](AGENTS.md)**。

```bash
# 生产构建（与 CI 等效）
cd /mnt/f/MyBlog/chengyu.github.io
HUGO_ENVIRONMENT=production /home/chengyu/.local/bin/hugo --minify --gc --cleanDestinationDir

# 本地预览 → http://localhost:1313
hugo server -D --bind 0.0.0.0

# 拉取远端并提交推送（唯一开发分支 source）
./git_sync.sh "commit message"
```

## 发布流程

1. 在 `source` 分支上提交改动（构建产物永不提交）；
2. push 后 GitHub Actions（`.github/workflows/deploy.yml`）自动构建并部署；
3. 到 Actions 页面确认绿色，并冒烟检查线上页面。

## 约定速览

- 新文章：`hugo new blog/<slug>.md`，front matter 必含 `summary`；不引入 PaperMod 遗留字段。
- 发新论文/改经历：只改 `data/` 下对应 YAML，首页与简历页自动同步。
- 升级主题/版本：先读 [AGENTS.md](AGENTS.md) 第 4 节「版本纪律」。
