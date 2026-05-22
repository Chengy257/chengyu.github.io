---
title: "JCVI 基因组共线性分析与可视化"
summary: "使用 JCVI (MCscan Python 版) 进行基因组间共线性分析，包括数据准备、pairwise synteny 检测和多物种共线性图绘制的完整流程。"
date: 2024-06-26
draft: false
tags: ["JCVI", "MCscan", "共线性", "比较基因组学", "基因组进化"]
categories: ["NGS分析"]
author: "Cy257"
showToc: true
TocOpen: false
---

## 背景

基因组共线性（Synteny）分析是比较基因组学中的重要手段。通过比较不同物种或同一物种不同品种之间的基因组区域，可以发现保守的基因排列顺序、基因组重排事件以及物种间的进化关系。

<!--more-->

[JCVI](https://github.com/tanghaibao/jcvi) 是由 Haibao Tang 开发的 Python 工具集，其中的 MCscan（Python 版）模块可以高效地进行共线性分析和可视化。本文以水稻属多个物种为例，介绍完整的分析流程。

> 参考：[JCVI MCscan (Python version) Wiki](https://github.com/tanghaibao/jcvi/wiki/MCscan-(Python-version)#microsynteny-getting-fancy)

---

## 1. 准备基因组与注释文件

从 Ensembl Plant 等数据库下载目标物种的基因组序列（FASTA）和注释文件（GFF3）。

需要准备的材料：
- 基因组 FASTA 文件：`Oryza_sativa.fa`, `Oryza_rufipogon.fa` 等
- 基因注释 GFF3 文件：`Oryza_sativa.gff3`, `Oryza_rufipogon.gff3` 等

---

## 2. 数据格式化

JCVI 需要 BED 格式的基因位置文件和 CDS 序列文件。下面的函数自动从 GFF3 生成这些文件：

```bash
GENOME_PATH=/path/to/genome/fasta

function formated() {
    name=$(basename ${1%%.*})  ## 输入 gff3 文件，提取物种名
    mkdir -p temp_dir

    # GFF3 转 BED 格式
    # --primary_only 只保留每个基因的一个转录本（去除冗余 isoform）
    python -m jcvi.formats.gff bed --type=mRNA --key=ID --primary_only $1 -o ${name}.bed

    # 提取 CDS 序列
    gffread -g ${GENOME_PATH}/${name}.fa -x ./temp_dir/${name}.cds $1

    # 去重：基于 BED 文件去除重复基因
    python -m jcvi.formats.bed uniq ${name}.bed
    mv ${name}* ./temp_dir

    # 根据去重后的 BED 提取对应的 CDS 序列
    seqkit grep -f <(cut -f 4 ./temp_dir/${name}.uniq.bed) ./temp_dir/${name}.cds \
      | seqkit seq -i > ./temp_dir/${name}.uniq.cds

    # 创建符号链接（JCVI 默认在当前目录查找）
    ln -s ./temp_dir/${name}.uniq.cds ./${name}.cds
    ln -s ./temp_dir/${name}.uniq.bed ./${name}.bed
}
```

> **为什么要去重？** 一个基因可能有多个转录本（isoform），如果不去重会导致同一位点出现多次，干扰共线性检测。`--primary_only` 只保留主转录本。

---

## 3. Pairwise 共线性检测

两两物种之间进行共线性分析，寻找同源基因块：

```bash
function pairwiseSynteny() {
    query=${1}
    target=${2}
    if [ "${query}" != "${target}" ]; then
        # 计算正交同源基因（Ortholog）
        python -m jcvi.compara.catalog ortholog ${query} ${target} --full --no_strip_names

        # 过滤 anchors，保留最小跨度 ≥ 30 的共线性区块
        python -m jcvi.compara.synteny screen --minspan=30 --simple \
            ${query}.${target}.anchors ${query}.${target}.anchors.new
    fi
}

# 批量运行：从 compares 文件中读取物种对
cat ./compares | while read a b
do
    pairwiseSynteny $a $b
    echo "Finish $a & $b!"
done
```

`compares` 文件格式示例（每行一对）：

```
Oryza_sativa Oryza_rufipogon
Oryza_sativa Oryza_indica
Oryza_sativa Oryza_barthii
Oryza_sativa Oryza_nivara
Oryza_sativa Oryza_glaberrima
```

> **`--full`** 参数表示使用全模式（包括不包含 CDS 的比对），**`--no_strip_names`** 保留原始基因名。

---

## 4. 多物种合并绘图

将多个 pairwise 共线性结果合并，绘制多物种共线性图。

### 4.1 合并 BED 文件

```bash
# 合并所有物种的 BED 文件
python -m jcvi.formats.bed merge \
    Oryza_sativa.bed Oryza_rufipogon.bed Oryza_indica.bed \
    Oryza_barthii.bed Oryza_nivara.bed Oryza_glaberrima.bed \
    -o all.bed
```

### 4.2 合并共线性区块

```bash
# 将各 pairwise 的 RBH（Reciprocal Best Hit）结果合并
python -m jcvi.formats.base join \
    Oryza_rufipogon.Oryza_sativa.rbh.simple \
    Oryza_indica.Oryza_sativa.rbh.simple \
    Oryza_barthii.Oryza_sativa.rbh.simple \
    Oryza_nivara.Oryza_sativa.rbh.simple \
    Oryza_glaberrima.Oryza_sativa.rbh.simple \
    --column=1,1,1,1,1 \
    -o merged.rbh

# 重排列顺序（将参考物种放在第一列）
cat merged.rbh | awk -v OFS="\t" '{print $2,$1,$3,$5,$7,$9}' > all.blocks
```

### 4.3 绘制共线性图

```bash
python -m jcvi.graphics.synteny \
    all.blocks all.bed all.layout \
    --glyphcolor=orthogroup --glyphstyle=arrow
```

其中 `all.layout` 是布局文件，定义每个物种在图中的位置：

```
# y, xstart, xend, species, ., options
0.6, 0.1, 0.9, Oryza_sativa, .
0.4, 0.1, 0.9, Oryza_rufipogon, .
0.2, 0.1, 0.9, Oryza_indica, .
```

---

## 小结

| 步骤 | 命令 | 说明 |
|:---:|------|------|
| 格式化 | `jcvi.formats.gff bed` | GFF3 → BED + CDS |
| 去重 | `jcvi.formats.bed uniq` | 去除冗余 isoform |
| 共线性检测 | `jcvi.compara.catalog ortholog` | Pairwise ortholog |
| 过滤 | `jcvi.compara.synteny screen` | 保留高质量区块 |
| 合并 | `jcvi.formats.base join` | 多物种结果合并 |
| 绘图 | `jcvi.graphics.synteny` | 可视化共线性 |

JCVI 的优势在于它提供了从数据准备到可视化的一站式流程，特别是多物种共线性图的绘制非常灵活。对于大规模比较基因组分析（如植物基因组加倍事件研究），JCVI 是非常实用的工具。
