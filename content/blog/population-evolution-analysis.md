---
title: "群体进化分析：π、Fst、Tajima's D 计算与可视化"
summary: "使用 vcftools/plink 计算群体遗传多样性指标（π、Fst、Tajima's D），并结合 R 进行基因组区域可视化。"
date: 2025-01-13
draft: false
tags: ["群体遗传", "vcftools", "plink", "Tajima's D", "Fst", "π"]
categories: ["NGS分析"]
author: "Cy257"
---

群体进化分析中，核苷酸多样性（π）、群体分化系数（Fst）和中性检验（Tajima's D）是三个最常用的遗传多样性指标。本文以水稻 Rice4K SNP 数据为例，记录如何使用 vcftools 和 plink 计算这些指标，并利用 ggplot2 进行基因组区域的可视化。

<!--more-->

## 原理概念

### 核苷酸多样性 π（Nucleotide Diversity）

π 衡量的是群体内任意两条序列之间核苷酸差异的平均比例。计算时将群体中所有序列两两比较，累加差异位点数后除以总比较对数。π 值越高，说明群体内的遗传多样性越丰富；π 值越低，则说明该区域的多样性被"压缩"了，可能经历了选择性消除（Selective Sweep）。

### 群体分化系数 Fst（Fixation Index）

Fst 衡量的是两个群体之间的遗传分化程度，取值范围 0\~1。Fst 越接近 1，说明两个群体在该位点的等位基因频率差异越大，群体间分化越强；接近 0 则说明群体间几乎没有分化。在实际分析中，Fst 常被用于筛选受选择区分不同群体的关键位点。

### 中性检验 Tajima's D

Tajima's D 由日本遗传学家 Fumio Tajima 提出，用于检验 DNA 序列是否符合中性进化模型。其核心思想是比较两种遗传多样性的估计方式：

```
Tajima's D = θπ − θs
```

- **θπ**：基于成对序列差异的多样性估计（pairwise differences）
- **θs**：基于分离位点数的多样性估计（segregating sites）

在中性进化、群体大小恒定的假设下，这两个估计值应当相等，即 D ≈ 0。当 D 显著偏离 0 时，意味着可能存在自然选择或群体历史事件：

| Tajima's D | 含义 |
|:---:|:---|
| **D ≈ 0** | 符合中性进化模型，群体处于平衡状态 |
| **D < 0**（显著） | 稀有等位基因过多，可能经历了定向选择（Positive Selection）或群体规模扩张 |
| **D > 0**（显著） | 稀有等位基因过少，可能经历了平衡选择（Balancing Selection）或瓶颈效应 |

简单来说：**只要 D 值显著背离 0，就可能是自然选择的结果**；不显著背离 0 时，则不能排除中性假说。

> Tajima’s D 值检验的目的是鉴定目标DNA序列在进化过程中是否遵循中性进化模型。当Tajima’s D显著大于0时，可用于推断瓶颈效应和平衡选择，当Tajima’s D显著小于0时，可用于推断群体规模放大和定向选择。由于平衡选择和定向选择均属于正选择的范畴，因此只要D值显著背离0，就可能是自然选择的结果，当D值不显著背离0时，中性假说则不能被排除。
>
> 平衡选择：位点呈现多态性，且一直保持着平衡，人类的ABO血型系统就是典型的平衡选择；
>
> 选择性消除(Selective sweep)是由于某一位点受到强选择后，其周围的位点的多态性因受该位点牵连而发生多态性降低的现象。也可以认为某个位点发生突变，突变后的位点因对物种在特定的情况下有利或者受到了人为选择，那么该突变位点在群体中的频率必然提高，但是其附近和它处在同一单体型或者block的其它位点同样跟着受到了选择，频率发生了提高，也就是单体型内的其它多态位点的某一多态形式比率大大提高，从而降低了整个周围区域的多态性。
>
> 原文：https://taoyan.netlify.app/post/2017-12-24.%E7%94%9F%E7%89%A9%E4%BF%A1%E6%81%AF%E5%AD%A6%E5%AD%A6%E4%B9%A0%E7%AC%94%E8%AE%B0%E5%85%AD/

## 计算方法

下面以水稻 Rice4K 数据（来自 RiceVarMap v2.0 数据库）为例，演示如何从原始 SNP 数据出发，计算指定基因组区域的 π、Tajima's D 等指标。

### 1. 准备群体样本 ID 文件

首先从样本信息文件中提取不同亚群体（Aus、Indica、Japonica）的样本 ID：

```bash
for group in Aus Indica Japonica
do
cat ~/data/SNP/RiceVarMapv2.0/RiceVarMap2_Cultivar_Information.csv \
  |sed 's/"//g'|sed 's/,/\t/g'|sed 's/ /_/g'|cut -f2,3 \
  |fgrep $group|cut -f1|sed -e 's/_/ /g' -e 's/-/./g' \
  |awk '{if($2==""){$2=$1} print $1,$2}' > sampleIDs.$group
done
cat sampleIDs.*|sort -u > sampleIDs.all
```

### 2. 提取指定基因组区间的 SNP 数据

使用 plink 根据样本 ID 和基因组区间提取各群体的 SNP 数据（以 VCF 格式输出）：

```bash
bfilePath="/home/chengyu/data/SNP/RiceVarMapv2.0/plink_format/rice4k_geno_no_del"
## 以基因 lncRNA VIVIpary 为例，上下游延伸 2Mb
chr=12
start=8804334
end=12805254

# 提取目标区间内的 SNP ID
cat ~/data/SNP/RiceVarMapv2.0/plink_format/rice4k_geno_no_del.bim \
  |awk -v start="${start}" -v end="${end}" -v chr="${chr}" \
  '$1==chr && $4 > start && $4 < end {print $2}' > SNP_IDs.17440_extend10k

# 按群体分别提取
for group in Aus Indica Japonica all
do
plink --threads 30 --memory 200000 \
  --bfile $bfilePath \
  --double-id --allow-extra-chr \
  --keep sampleIDs.$group \
  --extract SNP_IDs.17440_extend10k \
  --recode vcf-iid \
  --out subPop.${group}.vcf
done
```

### 3. 使用 vcftools 计算 π 和 Tajima's D

```bash
for group in Aus Indica Japonica all
do
# 计算窗口化 π（窗口 50kb，步长 5kb）
vcftools --vcf ./subPop.${group}.vcf.vcf \
  --window-pi 50000 --window-pi-step 5000 \
  --out subPop.${group}.vcf.pi

# 计算 Tajima's D（窗口 20kb）
vcftools --vcf ./subPop.${group}.vcf.vcf \
  --TajimaD 20000 \
  --out subPop.${group}.vcf.TajimaD

# 计算 Fst（窗口 5kb，步长 500）
vcftools --vcf ./subPop.${group}.vcf.vcf \
	--fst-window-size 5000 --fst-window-step 500 \
	--out subPop.${group}.vcf.fst
done
```

### 4. 整理绘图数据

将 π 和 Tajima's D 的输出结果合并为统一的绘图数据格式：

```bash
rm -rf dat.plot
for group in Aus Indica Japonica all
do
# 整理 π 数据：取窗口中点作为 x 坐标
cat subPop.${group}.vcf.pi.windowed.pi \
  |sed '1d' \
  |awk -v OFS="\t" -v g="${group}" '{print $1,($2+$3-1)/2,$5,"pi",g}' >> dat.plot

# 整理 Tajima's D 数据：取窗口中点，过滤 nan 值
cat subPop.${group}.vcf.TajimaD.Tajima.D \
  |sed '1d' \
  |awk -v OFS="\t" -v g="${group}" '{print $1,$2+20000/2,$4,"Tajima.D",g}' \
  |fgrep -v nan >> dat.plot
done
```

## 可视化

使用 ggplot2 绑定分面图展示 π 和 Tajima's D 在基因组区域上的分布：

```R
library(ggplot2)
library(ggsci)

dat <- read.delim("dat.plot", header = FALSE)
colnames(dat) <- c("Chr", "Pos", "Value", "Metric", "Subpopulation")

ggplot(dat) +
  geom_line(aes(x = Pos, y = Value, group = Subpopulation, color = Subpopulation)) +
  facet_wrap(~Metric, scales = "free", ncol = 1) +
  geom_vline(xintercept = 10804334, lty = 2, lwd = 0.5, color = "red") +
  scale_color_npg() +
  theme_bw() +
  coord_cartesian(xlim = c(9804334, 11905254)) +
  scale_x_continuous(
    breaks = seq(10000000, 12000000, by = 500000),
    labels = paste0(seq(10, 12, by = 0.5), " Mb")
  ) +
  labs(x = "Chr12", y = NULL)
```

![群体进化分析：π 与 Tajima's D 分布](https://cdn.jsdelivr.net/gh/Chengy257/img-file-bed@main/img2/image-20260520135532210.png)

### 结果解读示例

以 lncRNA *VIVIpary* 基因组区域（[Yang L, Cheng Y, Yuan C...The long noncoding RNA VIVIpary promotes seed dormancy release and pre-harvest sprouting through chromatin remodeling in rice. Molecular Plant, 2025; 18, 978-994](https://linkinghub.elsevier.com/retrieve/pii/S1674205225001364)）为例：

图中红色虚线标记目标基因的位置，上方面板展示 Tajima's D 的变化，下方面板展示 π 的分布趋势。通过比较不同亚群体在这些指标上的差异，可以初步判断该区域是否受到选择作用。

- **Tajima's D**：该区域在不同群体稻种间均显著偏离 0（绝对值 > 1），说明该位点在水稻驯化过程中受到了选择作用。粳稻和籼稻亚群之间呈现相反趋势的 Tajima's D 值，提示该位点在两个亚群的驯化过程中可能经历了不同的选择压力。
- **π**：VIVIpary 基因组位点区域在粳稻中有一个显著的下降趋势（选择性消除），而在籼稻和 Aus 稻种中核苷酸多样性反而呈现上升趋势，可能受到平衡选择作用。

综合来看，Tajima's D 和 π 的结果可以相互印证，帮助我们理解基因组特定区域在不同群体中的进化历史。

## 附录：批量计算基因区间 π

如果需要对大量基因区间批量计算 π，可以借助 plink 的 range 模式和 vcftools 的 `--bed` 参数：

```bash
# 1. 准备 bed 格式的基因区间文件（前四列）
cat ncORF.tr.f6.bed | cut -f1-4 > range.txt

# 2. 使用 plink 提取所有区间内的 SNP
plink --threads 30 --memory 200000 \
  --bfile /home/chengyu/data/SNP/RiceVarMapv2.0/plink_format/rice4k_geno_no_del \
  --extract 'range' range.txt \
  --recode vcf-iid \
  --out ncORF.tr.f4.bed.vcf

# 3. 使用 vcftools 按 bed 区间逐位点计算 π
vcftools --vcf ncORF.tr.f4.bed.vcf.vcf \
  --bed ncORF.tr.f4.bed \
  --site-pi \
  --out test.pi.site
```

## 小结

| 指标 | 工具 | 关键参数 | 用途 |
|:---|:---|:---|:---|
| π | vcftools `--window-pi` | 窗口大小、步长 | 衡量群体内遗传多样性 |
| Tajima's D | vcftools `--TajimaD` | 窗口大小 | 中性检验，检测选择信号 |
| Fst | vcftools `--fst-window-size` | 窗口大小、步长 | 衡量群体间分化程度 |

这三个指标是群体进化分析中不可或缺的工具。实际操作中，建议根据基因组大小和 SNP 密度合理设置窗口大小和步长，并综合多个指标进行判断。
