---
title: "cv-a4-generator：从 Markdown 生成 A4 打印简历"
summary: "一个纯 Python 工具，只需一个 Markdown 文件和一张照片，即可生成排版精美的 A4 双页个人简历 HTML。无需 Hugo、Node.js 或任何站点构建工具。"
date: 2025-07-28
draft: false
tags: ["Python", "工具开发", "简历", "开源"]
categories: ["工具开发"]
author: "Cy257"
showToc: true
TocOpen: false
---

## 背景

之前我在做个人主页时，用 Hugo + Hextra 搭建了一个在线简历页面。但当需要打印或导出 PDF 时，流程很繁琐：Hugo 构建 → 从生成的 HTML 中提取内容 → 清理框架注入的标签 → 嵌入照片 → 包装 A4 CSS → 输出。

整个流程强依赖 Hugo 和完整的站点目录，只为生成一个 HTML 文件，太重了。

于是我把这个生成逻辑剥离出来，做了一个独立工具：**cv-a4-generator**。

<!--more-->

## 它能做什么

给定一个 Markdown 文件和一张照片，一行命令生成自包含的 A4 简历 HTML：

```bash
python generate.py cv.md photo.jpg -o resume.html
```

输出效果：

- **A4 双页排版**：内容自动压缩至刚好 2 页
- **自包含**：照片以 base64 内嵌，无外部依赖
- **打印即用**：浏览器打开后 `Ctrl+P` 直接打印
- **视觉风格**：蓝色主题（`#2a7ae2`），论文编号 CSS counter 自动连续编号

## 技术细节

### 只有一个外部依赖

```bash
pip install markdown
```

用 [python-markdown](https://python-markdown.github.io/) 做 Markdown → HTML 渲染，其余全部标准库。

### Markdown Frontmatter

在 Markdown 文件头部用 `---` 包裹的 frontmatter 提供元信息：

```yaml
---
name: 程 宇
header_name: 程&nbsp;&nbsp;宇
intro: 第一段简介。 | 第二段简介。 | 第三段简介。
---
```

`intro` 字段用 ` | `（空格竖线空格）分隔多段，支持 HTML 标签。

### 模板系统

使用 `template.html` 作为 HTML 模板，占位符用 `{{ }}` 标记：

| 占位符 | 替换内容 |
|--------|----------|
| `{{ photo_data_uri }}` | base64 照片 |
| `{{ intro_html }}` | 简介段落 |
| `{{ body_html }}` | Markdown 渲染内容 |
| `{{ header_name }}` | 头部姓名 |

不依赖 Jinja2，用 Python 字符串替换即可。

### 论文连续编号

关键技巧：CSS counter。不管论文按多少个年份 `<h3>` 分组，`<ol>` 被 Hugo/Hextra 的 markdown 渲染器在每个 `###` 后重置，但 CSS counter 在 `.cv-page` 层面 `counter-reset`，每个 `<li>` 自动递增，实现跨年份连续编号 1-9：

```css
.cv-page { counter-reset: pub-counter; }
.cv-page ol li {
  counter-increment: pub-counter;
  position: relative;
  padding-left: 1.8rem;
}
.cv-page ol li::before {
  content: counter(pub-counter) ".";
  position: absolute;
  left: 0;
  font-weight: 700;
  color: #2a7ae2;
}
```

### A4 尺寸控制

通过 CSS `@page` 和 `!important` override 精确控制：

```css
@page { size: A4; margin: 12mm 15mm; }
body { font-size: 9.5pt; line-height: 1.55; width: 210mm; }
.cv-page { padding: 10mm 14mm; margin: 0; box-shadow: none; }
```

照片从 130px 缩到 90px，所有间距压缩，确保内容刚好落在 2 页 A4。

## 项目结构

```
cv-a4-generator/
├── generate.py          # 主脚本 (~170 行)
├── template.html        # A4 HTML 模板 (CSS 全内嵌)
├── requirements.txt     # markdown>=3.5
├── README.md            # 英文主文档 + 中文折叠说明
└── test/
    └── test_cv.md       # 测试用 Markdown
```

## 仓库地址

[https://github.com/Chengy257/cv-a4-generator](https://github.com/Chengy257/cv-a4-generator)

欢迎 star / fork / issue。
