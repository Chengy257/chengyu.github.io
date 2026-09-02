---
title: "生信数据格式详解：Peak 文件 (narrowPeak / broadPeak / gappedPeak)"
summary: "详解 ChIP-seq/ATAC-seq 等 Peak calling 结果的三种标准格式，包括每列含义、0-based 坐标系及 MACS2 输出解读。"
date: 2024-06-05
draft: false
tags: ["Peak", "BED", "ChIP-seq", "ATAC-seq", "数据格式"]
categories: ["生信基础"]
author: "Cy257"
---

## 背景

在 ChIP-seq、ATAC-seq、CUT&Tag 等表观基因组学分析中，Peak calling 是核心步骤。MACS2 等工具会在基因组上鉴定出 reads 富集的区域（即 Peak），并输出标准化格式文件。

<!--more-->

为了统一不同 peak calling 软件的输出结果，ENCODE 项目制定了三种标准格式：

- **narrowPeak** — 窄峰，适用于转录因子结合位点等尖锐信号
- **broadPeak** — 宽峰，适用于组蛋白修饰等弥漫性信号
- **gappedPeak** — 间隙峰，适用于包含多个离散区域的峰（如 RNA 水平的 m6A peak）

> 💡 这三种格式本质上都是 BED 格式的扩展，区别在于附加列的数量和含义。

**重要：BED 格式采用 0-based 半开区间坐标系统**，即起始位置从 0 开始计数，区间为 `[start, end)`。

---

## narrowPeak (BED 6+4)

**10 列**，适用于窄峰（如转录因子 ChIP-seq）。

| 列号 | 字段 | 说明 |
|:---:|---|---|
| 1 | `chrom` | 染色体名称 |
| 2 | `chromStart` | 起始位置（0-based） |
| 3 | `chromEnd` | 终止位置 |
| 4 | `name` | Peak 名称/描述 |
| 5 | `score` | MACS2 中为 `int(-10 * log10(qvalue))`，用于 UCSC Genome Browser 显示 |
| 6 | `strand` | 链方向，MACS2 输出中通常为 `.` |
| 7 | `signalValue` | 富集强度，通常使用 `fold_enrichment` |
| 8 | `pValue` | 统计显著性，MACS2 输出为 `-log10(pvalue)` |
| 9 | `qValue` | 校正后显著性，MACS2 输出为 `-log10(qvalue)` |
| 10 | `peak` | Summit 位置，即 peak 最高点距离 `chromStart` 的偏移量 |

### 示例

```
chr1  10045  10250  MACS_peak_1  185  .  12.53  28.45  18.52  98
chr1  23015  23280  MACS_peak_2  142  .   9.87  22.31  14.25  130
```

> 最后一列 `peak=98` 表示 summit 位于 `10045 + 98 = 10143`。

---

## broadPeak (BED 6+3)

**9 列**，在 narrowPeak 基础上去掉了最后一列（summit 位置）。

| 列号 | 字段 | 说明 |
|:---:|---|---|
| 1-6 | 同 narrowPeak | 染色体、起始终止、名称、score、链 |
| 7 | `signalValue` | 富集强度 |
| 8 | `pValue` | `-log10(pvalue)` |
| 9 | `qValue` | `-log10(qvalue)` |

**适用场景：** H3K27me3、H3K9me3 等形成宽泛富集区域的组蛋白修饰。这类信号没有明确的峰顶，因此不需要 summit 信息。

---

## gappedPeak (BED 12+3)

**15 列**，用于描述非连续的 Peak 区域，即一个 Peak 区间内包含多个离散的子区间（类似转录本中包含多个 exon）。

### 前 6 列

与 narrowPeak / broadPeak 完全相同。

### 第 7-9 列

| 列号 | 字段 | 说明 |
|:---:|---|---|
| 7 | `signalValue` | 富集强度 |
| 8 | `pValue` | 统计显著性 |
| 9 | `qValue` | 校正后显著性 |

### 第 10-15 列（BED12 扩展列）

| 列号 | 字段 | 说明 |
|:---:|---|---|
| 10 | `thickStart` | 通常设为与 `chromStart` 相同 |
| 11 | `thickEnd` | 通常设为与 `chromEnd` 相同 |
| 12 | `itemRgb` | RGB 颜色值（如 `255,0,0`），无颜色信息时为 `0` |
| 13 | `blockCount` | Peak 区间内包含的子区间（block）数量 |
| 14 | `blockSizes` | 每个子区间的长度，逗号分隔 |
| 15 | `blockStarts` | 每个子区间相对于 `chromStart` 的偏移量，逗号分隔 |

**适用场景：** m6A-seq 鉴定的 RNA 修饰位点（跨多个 exon 的 Peak），或其他非连续富集区域。

---

## 格式对比总结

| 格式 | 列数 | 类型 | 典型应用 |
|---|:---:|---|---|
| narrowPeak | 10 | 窄峰 | 转录因子 ChIP-seq, ATAC-seq |
| broadPeak | 9 | 宽峰 | 组蛋白修饰 (H3K27me3 等) |
| gappedPeak | 15 | 间隙峰 | m6A-seq, RNA 水平富集 |

## 实用技巧

### 用 bedtools 处理 Peak 文件

```bash
# 查看两个 Peak 文件的交集
bedtools intersect -a peaks.narrowPeak -b regions.bed > overlap.bed

# 合并相邻 Peak
bedtools merge -i peaks.narrowPeak > merged.bed

# 计算Peak在基因组特征上的分布
bedtools intersect -a peaks.narrowPeak -b genes.bed -wa -wb > peak_annotation.txt
```

### 用 IGV 可视化

narrowPeak 和 broadPeak 文件可以直接加载到 IGV 中浏览。建议同时加载对应的 BAM 文件，查看 reads 覆盖情况。

### 坐标系转换

BED 格式是 **0-based**，而 GFF/GTF 格式是 **1-based**。互相转换时注意：

```
BED:  [100, 200)    → 长度 100
GFF:  101..200      → 长度 100
```

> 参考：[BED Format Specification](https://genome.ucsc.edu/FAQ/FAQformat.html)
