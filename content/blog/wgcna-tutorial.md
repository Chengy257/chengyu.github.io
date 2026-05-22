---
title: "WGCNA 加权基因共表达网络分析教程"
summary: "WGCNA 基本概念、适用场景、注意事项，以及完整的 R 代码实现，涵盖数据准备、软阈值选择、模块识别和表型关联。"
date: 2024-07-01
draft: false
tags: ["WGCNA", "R", "共表达网络", "转录组", "加权基因网络"]
categories: ["NGS分析"]
author: "Cy257"
showToc: true
TocOpen: false
---

## 什么是 WGCNA？

**WGCNA**（Weighted Gene Co-Expression Network Analysis），即**加权基因共表达网络分析**，用于寻找高度相关的基因构成的**基因模块（module）**，利用模块特征基因 **eigengene**（模块内第一主成分）或模块内的关键基因 **Hub gene** 来总结这些模块，最终**将基因模块与样本表型进行关联**。

<!--more-->

简单来说，WGCNA 其实相当于是**对多个复杂分组进行的差异分析**，用于找寻不同分组/表型的特征基因模块。其最核心之处就在于能**将基因模块与样本表型进行关联**，从而发现与特定性状相关的基因集合。

---

## 适用场景

WGCNA 并非所有情况都适用，选择合适的场景很重要：

- **适合**：多分组、时间序列、不同浓度梯度等复杂实验设计。样品数量多（≥15），不同基因之间可以计算合理的相关性，根据基因之间的相似性进行分组
- **不适合**：只有两个分组（如正常 vs 对照）的情况，简单的差异分析即可，没必要上 WGCNA。而且两分组样品数通常 <15，官方也不推荐

> 如果一个表达量矩阵中样品是时间序列这样的多分组，比如处理前后以及处理过程的不同时间梯度或者不同浓度，那么就需要每个分组都去跟对照组进行差异分析，上下调的组合非常多，结果也很难精炼出生物学结论，这个时候就可以选择 WGCNA 或者 mfuzz 这样的时间序列分析。

---

## 分析流程总览

WGCNA 的标准分析流程分为以下几步：

| 步骤 | 内容 |
|:---:|------|
| 0 | 输入数据准备 |
| 1 | 判断数据质量，绘制样品的系统聚类树 |
| 2 | 挑选最佳软阈值 power |
| 3 | 构建加权共表达网络，识别基因模块 |
| 4 | 关联基因模块与表型 |
| 5 | 模块相关性热图 |
| 6 | 对感兴趣模块进行 GO 富集分析 |
| 7 | 感兴趣模块绘制热图 |
| 8 | 提取 Hub gene，导出至 VisANT 或 Cytoscape |

---

## 注意事项

> 参考：[WGCNA package: Frequently Asked Questions](https://horvath.genetics.ucla.edu/html/CoexpressionNetwork/Rpackages/WGCNA/faq.html)

- **样本数 ≥ 15**，否则网络不稳定
- **基因过滤**：采用均值、方差、中位数、绝对中位差（MAD）等方法，过滤低表达或样本间变化小的基因。**不建议用差异分析的结果来过滤**
- **输入数据**：如果有批次效应需要先去除；RNA-seq 数据建议使用 DESeq2 的 `varianceStabilizingTransformation` 方法，或将标准化数据（FPKM、CPM 等）进行 `log2(x+1)` 转化
- **经验软阈值 power**：当无向网络在 power < 15（或有向网络 power < 30）内无法达到要求时（即没有一个 power 值可以使无标度网络结构 R² 达到 0.8 且平均连接度降到 100 以下），可采用经验 power 值

---

## R 代码实现

### 1. 数据前处理

```R
library(WGCNA)
library(tidyverse)

# 读取表达矩阵（行为基因，列为样本）
expr_data <- read.table("expression_matrix.txt", header = TRUE, row.names = 1, sep = "\t")

# 过滤低表达和低方差基因
# 保留至少在部分样本中有表达的基因
gene_filter <- function(expr, min_expr = 1, min_samples = 5) {
  keep <- apply(expr, 1, function(x) sum(x > min_expr) >= min_samples)
  expr[keep, ]
}
expr_filtered <- gene_filter(expr_data)

# 过滤低方差基因（保留方差前 5000 或前 75% 的基因）
variances <- apply(expr_filtered, 1, var)
n_keep <- min(5000, ceiling(nrow(expr_filtered) * 0.75))
expr_filtered <- expr_filtered[order(variances, decreasing = TRUE)[1:n_keep], ]

# 如果是 RNA-seq 的 counts 数据，建议先进行 VST 转换
# library(DESeq2)
# dds <- DESeqDataSetFromMatrix(countData = expr_filtered, colData = sample_info, design = ~1)
# vst_expr <- assay(vst(dds))
# dat_expr <- t(vst_expr)  # WGCNA 要求样本为行

# 如果已经是标准化数据（如 FPKM），直接 log2 转换
dat_expr <- t(log2(expr_filtered + 1))

# 检查缺失值
gsg <- goodSamplesGenes(dat_expr, verbose = 3)
if (!gsg$allOK) {
  dat_expr <- dat_expr[gsg$goodSamples, gsg$goodGenes]
}
```

### 2. 样本聚类与异常检测

```R
# 样本层次聚类，检测离群样本
sample_tree <- hclust(dist(dat_expr), method = "average")

# 设置截断高度，去除异常样本（可根据聚类树调整）
cut_height <- 100  # 根据实际情况调整
plot(sample_tree, main = "Sample Clustering", sub = "", xlab = "", cex.lab = 1.5, cex.axis = 1.5, cex.main = 2)

# 标记需要去除的样本
abline(h = cut_height, col = "red")
clust <- cutreeStatic(sample_tree, cutHeight = cut_height, minSize = 10)
keep_samples <- (clust == 1)
dat_expr <- dat_expr[keep_samples, ]
```

### 3. 选择软阈值（Soft Thresholding）

WGCNA 的核心思想是将基因间的相关系数取 β 次幂（即 soft threshold power），使网络接近无标度分布（scale-free topology）。

```R
# 尝试一系列 power 值
powers <- c(1:10, seq(12, 20, 2))
sft <- pickSoftThreshold(dat_expr, powerVector = powers, verbose = 5)

# 可视化：查看哪个 power 能让 R² 达到 0.8 以上
par(mfrow = c(1, 2))
# Scale Free Topology Fit Index
plot(sft$fitIndices[, 1], -sign(sft$fitIndices[, 3]) * sft$fitIndices[, 2],
     xlab = "Soft Threshold (power)",
     ylab = "Scale Free Topology Model Fit, signed R²",
     type = "n", main = "Scale Independence")
text(sft$fitIndices[, 1], -sign(sft$fitIndices[, 3]) * sft$fitIndices[, 2],
     labels = powers, cex = 0.9, col = "red")
abline(h = 0.80, col = "red", lty = 2)

# Mean Connectivity
plot(sft$fitIndices[, 1], sft$fitIndices[, 5],
     xlab = "Soft Threshold (power)", ylab = "Mean Connectivity",
     type = "n", main = "Mean Connectivity")
text(sft$fitIndices[, 1], sft$fitIndices[, 5], labels = powers, cex = 0.9, col = "red")

# 选择最佳 power（一般取 R² > 0.8 的最小 power）
soft_power <- sft$powerEstimate
if (is.na(soft_power)) {
  soft_power <- 6  # 经验值 fallback
  cat("自动选择的 power 为 NA，使用经验值:", soft_power, "\n")
} else {
  cat("自动选择的 power:", soft_power, "\n")
}
```

### 4. 构建共表达网络与模块识别

```R
# 一步法构建网络并识别模块
net <- blockwiseModules(dat_expr, power = soft_power,
                        TOMType = "unsigned", minModuleSize = 30,
                        reassignThreshold = 0, mergeCutHeight = 0.25,
                        numericLabels = TRUE, pamRespectsDendro = FALSE,
                        verbose = 3)

# 获取模块颜色标签
module_labels <- net$colors
module_colors <- labels2colors(module_labels)
table(module_colors)

# 绘制基因树状图和模块颜色
plotDendroAndColors(net$dendrograms[[1]], module_colors[net$blockGenes[[1]]],
                    "Module colors", dendroLabels = FALSE, hang = 0.03,
                    addGuide = TRUE, guideHang = 0.05)
```

### 5. 模块与表型关联

```R
# 计算模块特征基因 (Module Eigengene, ME)
MEs <- moduleEigengenes(dat_expr, module_colors)$eigengenes
MEs <- orderMEs(MEs)

# 读取表型数据
trait_data <- read.table("trait_data.txt", header = TRUE, row.names = 1, sep = "\t")

# 确保样本顺序一致
trait_data <- trait_data[match(rownames(dat_expr), rownames(trait_data)), ]

# 计算模块特征基因与表型的相关系数
module_trait_cor <- cor(MEs, trait_data, use = "p")
module_trait_pvalue <- corPvalueStudent(module_trait_cor, nrow(dat_expr))

# 绘制模块-表型关联热图
text_matrix <- paste(signif(module_trait_cor, 2), "\n(", signif(module_trait_pvalue, 1e-2), ")", sep = "")
dim(text_matrix) <- dim(module_trait_cor)

labeled_heatmap(text_matrix,
                xLabels = colnames(trait_data),
                yLabels = names(MEs),
                ySymbols = names(MEs),
                colorLabels = FALSE,
                colors = blueWhiteRed(50),
                text_matrix = text_matrix,
                setStdMargins = FALSE,
                cex.text = 0.7,
                zlim = c(-1, 1),
                main = "Module-Trait Relationships")
```

### 6. 分类性状处理

不同类型的表型变量需要不同的处理方式：

```R
# 二分类性状：直接用 0/1 编码
# 注意：二分类变量不应该变成两列！
trait_binary <- ifelse(trait_data$group == "treatment", 1, 0)

# 有序多分类：用 1, 2, 3... 编码
trait_ordered <- as.numeric(factor(trait_data$stage, levels = c("early", "mid", "late")))

# 无序多分类：需要用 WGCNA 提供的函数处理
trait_multi <- binarizeCategoricalVariable(trait_data$variety,
                                            includePairwise = TRUE,
                                            includeLevelVsAll = TRUE)
```

> **注意**：如果一个变量只有两个类别（比如 normal 和 tumor），把它变成两列的做法是错误的！虽然很多文章中这样用，但这不符合统计原理。

### 7. 提取 Hub Gene

```R
# 选择感兴趣的模块（如与某表型显著相关的模块）
interested_module <- "turquoise"

# 计算模块内基因的 Module Membership (MM) 和 Gene Significance (GS)
gene_names <- colnames(dat_expr)
MM <- as.data.frame(cor(dat_expr, MEs, use = "p"))
GS <- as.data.frame(cor(dat_expr, trait_data, use = "p"))

# 提取目标模块的 Hub gene（MM 和 GS 都高的基因）
module_genes <- module_colors == interested_module
hub_genes <- gene_names[module_genes & abs(MM[, paste0("ME", interested_module)]) > 0.8]

cat("Hub genes in", interested_module, "module:", length(hub_genes), "\n")
print(head(hub_genes))
```

### 8. 导出至 Cytoscape

```R
# 导出感兴趣的模块网络为 Cytoscape 格式
export_network <- function(module_name, dat_expr, module_colors, soft_power) {
  module_genes <- names(dat_expr)[module_colors == module_name]
  mod_expr <- dat_expr[, module_genes]
  
  # 计算 TOM 矩阵
  adj <- adjacency(mod_expr, power = soft_power)
  TOM <- TOMsimilarity(adj)
  
  # 只保留高权重边（Top 30）
  threshold <- quantile(TOM[TOM > 0], 0.7)
  TOM[TOM < threshold] <- 0
  
  # 导出为 edge/node 文件
  cyt <- exportNetworkToCytoscape(TOM,
                                   edgeFile = paste0("CytoscapeInput-edges-", module_name, ".txt"),
                                   nodeFile = paste0("CytoscapeInput-nodes-", module_name, ".txt"),
                                   weighted = TRUE, threshold = threshold)
}

export_network("turquoise", dat_expr, module_colors, soft_power)
```

---

## 小结

WGCNA 的核心价值在于**将基因表达模式与表型数据直接关联**，找到与特定性状相关的基因模块，而不需要预先指定差异基因列表。分析完成后，可以对感兴趣模块内的基因进行 GO/KEGG 富集分析、PPI 网络分析等下游操作。

| 步骤 | 关键函数 | 输出 |
|:---:|------|------|
| 数据准备 | `goodSamplesGenes()` | 过滤后的表达矩阵 |
| 软阈值选择 | `pickSoftThreshold()` | 最佳 power 值 |
| 模块识别 | `blockwiseModules()` | 基因-模块对应关系 |
| 表型关联 | `cor()` + 热图 | 模块-表型相关性 |
| Hub gene | Module Membership | 核心基因列表 |
| 网络可视化 | `exportNetworkToCytoscape()` | Cytoscape 输入文件 |
