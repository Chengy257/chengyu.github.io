---
title: "Git 常用操作速查指南"
summary: "Git 仓库初始化、推送、分支合并、冲突解决等常用操作的命令速查，以及 master 到 main 分支迁移的完整流程。"
date: 2025-11-18
draft: false
tags: ["Git", "GitHub", "版本控制"]
categories: ["工具使用"]
author: "Cy257"
---

Git 是日常开发中最常用的版本控制工具。本文整理了从仓库初始化到分支管理、远程同步的常用命令，方便随时查阅。

<!--more-->

---

## 一、初始化并推送到 GitHub

### 从零开始

```bash
# 进入项目目录
cd /path/to/your/project

# 初始化 git
git init

# 添加远程仓库
git remote add origin https://github.com/<USERNAME>/<REPO>.git

# 添加所有文件并提交
git add .
git commit -m "Initial commit"

# 推送到 main 分支（新仓库通常默认 main）
git branch -M main
git push -u origin main
```

### 一键上传

适合已有的本地项目快速上传到 GitHub：

```bash
cd /path/to/project
git init
git add .
git commit -m "update"
git branch -M main
git remote add origin https://github.com/<USERNAME>/<REPO>.git
git push -u origin main
```

### 远端有内容时的处理

```bash
# 先 pull 合并远端内容，再 push
git pull origin main --allow-unrelated-histories
git push origin main

# 如果确认本地版本是正确的，可以强制覆盖远端
git push origin main --force
```

---

## 二、日常推送流程

```bash
# 查看改动状态
git status

# 添加指定文件
git add file1.txt file2.txt

# 或添加所有改动
git add .

# 提交（附带说明）
git commit -m "fix: 修复了某个问题"

# 推送到远程
git push origin main
```

---

## 三、常见问题处理

### 推送被拒绝

```bash
# 远端有新提交，先拉取再推送
git pull origin main --rebase
# 解决冲突后再推送
git push origin main
```

### 撤销操作

```bash
# 撤销 git add（取消暂存）
git restore --staged <file>

# 撤销工作区的修改
git restore <file>

# 修改最后一次 commit 信息
git commit --amend -m "新的提交信息"

# 回退到上一个版本（保留工作区修改）
git reset --soft HEAD~1

# 彻底回退（丢弃所有修改，慎用！）
git reset --hard HEAD~1
```

### 查看历史

```bash
# 查看提交历史
git log --oneline --graph --all

# 查看某个文件的修改历史
git log -p <file>

# 查看某次提交的详细内容
git show <commit-hash>
```

---

## 四、分支管理：master 合并到 main

GitHub 在 2020 年将默认分支从 `master` 改为 `main`。如果你的旧仓库还在用 `master`，可以通过以下方式迁移。

### 本地有 master 分支

```bash
# 查看所有分支（本地 + 远程）
git fetch --all
git branch -a

# 切换到 main 分支（如不存在会自动创建）
git checkout main

# 合并本地 master 的内容到 main
git merge master

# 如果有冲突，解决后提交
git add .
git commit -m "resolve merge conflicts between master and main"

# 推送 main 到远程
git push origin main
```

### 仅远程有 master，本地没有

```bash
# 拉取远程 master 分支
git fetch origin master

# 切换到 main 分支
git checkout main

# 合并远程 master 的内容
git merge origin/master

# 推送到远程
git push origin main
```

### 清理旧分支（可选）

确认 main 分支已经包含所有内容后，可以删除旧的 master 分支：

```bash
# 删除本地 master
git branch -d master
# 如果未合并，需要强制删除
git branch -D master

# 删除远程 master
git push origin --delete master
```

---

## 五、远程仓库管理

```bash
# 查看远程仓库
git remote -v

# 修改远程仓库地址
git remote set-url origin https://github.com/<USERNAME>/<NEW_REPO>.git

# 添加多个远程仓库
git remote add upstream https://github.com/ORIGINAL/<REPO>.git

# 从上游仓库拉取更新
git fetch upstream
git merge upstream/main
```

---

## 小结

| 场景 | 命令 |
|------|------|
| 初始化并推送 | `git init` → `add` → `commit` → `push` |
| 日常更新 | `git add .` → `commit -m "msg"` → `push` |
| 推送被拒 | `git pull --rebase` → 解决冲突 → `push` |
| 分支合并 | `git merge <branch>` |
| 撤销暂存 | `git restore --staged <file>` |
| 回退版本 | `git reset --soft HEAD~1` |
| 查看历史 | `git log --oneline --graph` |

Git 的操作看起来很多，但日常高频使用的就那么几个：`add`、`commit`、`push`、`pull`、`merge`。遇到问题时再查对应的解决方案即可。
