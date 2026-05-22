---
title: "RNA-seq 差异表达分析流程：从 fastq 到 DEG"
summary: "完整记录 RNA-seq 数据分析的标准流程，包括质控、比对、定量和差异表达分析。"
date: 2024-06-15
draft: false
tags: ["RNA-seq", "DESeq2", "NGS", "差异表达"]
categories: ["NGS分析"]
author: "Cy257"
showToc: true
TocOpen: false
cover:
  image: ""
  alt: ""
---

## 前言

RNA-seq（转录组测序）是研究基因表达最常用的技术之一。本文记录从原始 fastq 文件到获得差异表达基因（DEG）的完整流程。

<!--more-->

## 1. 数据质控

使用 FastQC + MultiQC 进行质量评估：

```bash
# FastQC 质控
fastqc -t 8 -o qc/ *.fastq.gz

# MultiQC 汇总
multiqc qc/ -o multiqc_report/
```

### Trim Galore 去接头

```bash
trim_galore --paired \
  --quality 20 \
  --length 35 \
  --max_n 0 \
  --trim-n \
  -o trimmed/ \
  sample_R1.fastq.gz sample_R2.fastq.gz
```

## 2. 序列比对

以 HISAT2 为例：

```bash
hisat2 -p 8 \
  -x genome_index/genome \
  -1 trimmed/sample_R1_val_1.fq.gz \
  -2 trimmed/sample_R2_val_2.fq.gz \
  -S align/sample.sam \
  2> align/sample_hisat2.log
```

SAM 转 BAM 并排序：

```bash
samtools view -bS align/sample.sam | \
  samtools sort -@ 8 -o align/sample.sorted.bam
samtools index align/sample.sorted.bam
```

## 3. 基因定量

使用 featureCounts：

```bash
featureCounts -T 8 \
  -p -B -C \
  -a annotation.gtf \
  -o counts.txt \
  *.sorted.bam
```

## 4. 差异表达分析 (DESeq2)

```r
library(DESeq2)
library(clusterProfiler)

# 读取计数矩阵
countData <- read.table("counts.txt", header = TRUE, row.names = 1)
colData <- data.frame(
  condition = factor(c(rep("Control", 3), rep("Treatment", 3)))
)

# 创建 DESeq2 对象
dds <- DESeqDataSetFromMatrix(
  countData = countData,
  colData = colData,
  design = ~ condition
)

# 运行差异分析
dds <- DESeq(dds)
res <- results(dds, alpha = 0.05)

# 筛选显著差异基因
sig_genes <- subset(res, padj < 0.05 & abs(log2FoldChange) > 1)
```

## 5. GO/KEGG 富集分析

```r
# 基因 ID 转换
gene_list <- sig_genes$log2FoldChange
names(gene_list) <- rownames(sig_genes)

# GO 富集
go_enrich <- enrichGO(
  gene = names(gene_list),
  OrgDb = org.Hs.eg.db,
  keyType = "ENSEMBL",
  ont = "BP",
  pAdjustMethod = "BH",
  pvalueCutoff = 0.05
)
```

## 总结

| 步骤 | 工具 | 输出 |
|---|---|---|
| 质控 | FastQC + MultiQC | 质量报告 |
| 去接头 | Trim Galore | clean reads |
| 比对 | HISAT2/STAR | BAM 文件 |
| 定量 | featureCounts | 计数矩阵 |
| 差异分析 | DESeq2 | DEG 列表 |
| 富集分析 | clusterProfiler | GO/KEGG 结果 |

> 💡 完整的 Snakemake 流程模板可在我的 [GitHub](https://github.com/Chengy257) 找到。
