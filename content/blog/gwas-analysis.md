---
title: "GWAS 全基因组关联分析实战"
summary: "从 SNP 数据下载到 GWAS 关联分析的全流程，涵盖 PLINK 质控、GEMMA/EMMAX 混合线性模型，以及 TWAS 分析的 Python 自动化脚本。"
date: 2024-06-06
draft: false
tags: ["GWAS", "PLINK", "GEMMA", "EMMAX", "TWAS", "全基因组关联分析"]
categories: ["NGS分析"]
author: "Cy257"
---

## 背景

全基因组关联分析（Genome-Wide Association Study, GWAS）是通过扫描全基因组范围内的遗传变异（通常是 SNP），寻找与目标性状（表型）存在统计学关联的位点。其核心思想很简单：如果某个 SNP 的等位基因频率在表型极端个体之间存在显著差异，那么该 SNP 所在的基因组区域可能包含影响该性状的基因。

<!--more-->

GWAS 的基本流程可以概括为：

1. **获取基因型数据** — SNP 芯片或全基因组重测序
2. **准备表型数据** — 连续型（如株高）或分类型（如抗病/感病）
3. **数据质控** — 过滤低质量 SNP 和个体
4. **关联分析** — 用统计模型检验每个 SNP 与表型的关联
5. **结果可视化** — 曼哈顿图、QQ 图等

本文以水稻 3K Rice 和 Rice4k 数据库为例，介绍完整的 GWAS 分析流程。

---

## 1. 获取基因型数据

### 数据库资源

| 数据库 | 下载地址 | 说明 |
|--------|---------|------|
| [SNP-Seek](https://brs-snpseek.duckdns.org/3kRG) | https://brs-snpseek.duckdns.org/3kRG | 3K Rice SNP 数据（IRRI 主站暂停服务，CIMMYT 镜像提供在线查询） |
| [RiceVarMap v2.0](https://ricevarmap.ncpgr.cn/) | https://ricevarmap.ncpgr.cn/download/ | Rice4k SNP 数据 |

### VCF 预处理与格式转换

下载的 VCF 文件通常需要先过滤再转换为 PLINK 格式，因为大多数 GWAS 工具都基于 PLINK 的 BED/BIM/FAM 格式工作。

```bash
# VCF filter
## 过滤掉 indels 和多等位基因位点，只保留双等位 SNP
bcftools view --max-alleles 2 --exclude-types indels input.vcf.gz
## 另一种写法：只保留双等位 SNP
bcftools view -m2 -M2 -v snps input.vcf.gz > output.vcf

# VCF to PLINK
## 转换为 BED 格式 (.bim, .bed, .fam)，不支持多等位基因
plink2 --threads 20 --vcf ${OUT}.vcf --double-id --allow-extra-chr --make-bed --out ${OUT}
## 转换为 BGEN 格式（可选）
plink2 --make-pgen
```

> **为什么要过滤多等位基因？** PLINK 的 BED 格式不支持多等位基因位点（multiallelic），而大多数 GWAS 模型也只针对双等位基因设计。所以在转换前需要先用 bcftools 过滤。

---

## 2. 准备表型数据

准备表型信息文件（`.phe` 格式），至少包含三列：家系 ID（FID）、个体 ID（IID）和表型值。表型值可以是连续型数值（如产量、株高）或二分类（0/1）。

---

## 3. 数据质控

质控是 GWAS 中非常关键的一步，低质量的数据会导致假阳性或假阴性结果。

### 质控参数说明

| 参数 | 含义 | 建议阈值 |
|------|------|---------|
| `--geno` | 过滤缺失率过高的 SNP | 0.2（缺失率 >20% 的 SNP 删除） |
| `--mind` | 过滤缺失率过高的个体 | 0.2（缺失率 >20% 的个体删除） |
| `--maf` | 次等位基因频率（Minor Allele Frequency） | 0.05（删除 MAF <5% 的罕见变异） |
| `--hwe` | Hardy-Weinberg 平衡检验 | 1e-6 ~ 1e-10（删除不符合 HWE 的 SNP） |
| `--prune` | 基于表型数据过滤样本 | — |

```bash
# 根据表型数据过滤样本
plink2 --threads 20 --memory 16000 \
  --bfile ${OUT}_filter \
  --pheno ${Pheno_DIR}/${Pheno_type}.phe \
  --prune --make-bed --allow-no-sex --out ${OUT}_pheno_filter

# 完整质控命令
plink2 --threads 20 --memory 16000 \
  --bfile ${OUT}_pheno_filter \
  --make-bed --allow-no-sex \
  --pheno ${Pheno_DIR}/${Pheno_type}.phe \
  --geno 0.2 --mind 0.2 --maf 0.05 \
  --out ${OUT}_QC
```

> **MAF 过滤的理由：** 罕见变异（MAF <5%）的统计检验效力较低，容易产生假阳性，且样本量不足时难以可靠估计效应大小。

---

## 4. GWAS 关联分析

GWAS 分析有多种统计模型可选，从简单的线性回归到复杂的混合线性模型（MLM）。混合线性模型通过引入亲缘关系矩阵（kinship matrix）作为随机效应来校正群体结构，是目前最常用的方法。

### 4.1 PLINK（简单模型）

PLINK 提供了几种基础关联分析方法，适用于初步筛选。但它们不校正群体结构，假阳性率可能较高。

```bash
## PLINK v2 的 glm（广义线性模型）
plink2 --threads 24 --memory 16000 \
      --bfile ${OUT}_filter \
      --glm --allow-no-sex --adjust \
      --out ${OUT}_plink2_glm

## PLINK v1.90 的 linear（线性回归）
plink --threads 24 --memory 16000 \
    --bfile ${OUT}_filter \
    --linear --allow-no-sex --adjust \
    --out ${OUT}_plink_linear

## PLINK v1.90 的 assoc（适用于二分类表型）
plink --threads 24 --memory 16000 \
    --bfile ${OUT}_filter \
    --assoc --allow-no-sex --adjust \
    --out ${OUT}_plink_assoc
```

> **`--adjust`** 参数会在输出中添加多重检验校正结果（Bonferroni、FDR 等）。

### 4.2 GEMMA（混合线性模型）

GEMMA 实现了混合线性模型（MLM），通过计算亲缘关系矩阵来校正群体结构和个体间相关性，是目前 GWAS 分析的主流选择。

```bash
# Step 1: 计算亲缘关系矩阵（kinship matrix）
# -gk 2 表示使用标准化方法
gemma -bfile HT5.2 -gk 2 -o kinship -p p.txt

# Step 2: 运行 MLM 关联分析
# -lmm 1 使用 Wald 检验
gemma -bfile HT5.2 -lmm 1 \
  -k ./output/kinship.sXX.txt \
  -p p.txt -c c.txt \
  -o HT5.2.gemma
```

> **`-p`** 指定表型文件，**`-c`** 指定协变量文件（如 PCA 结果，用于进一步校正群体结构）。

### 4.3 EMMAX（混合线性模型）

EMMAX（Efficient Mixed-Model Association eXpedited）是另一个流行的 MLM 工具，计算速度较快。

```bash
# Step 1: 将 PLINK 格式转为 EMMAX 所需的 TPED 格式
plink --bfile 3kRice_filtered \
  --recode 12 --transpose \
  --out emmax_input --threads 24 --memory 100000

# Step 2: 计算亲缘关系矩阵 (GRM)
emmax-kin -v -d 10 -o kinship_matrix emmax_input

# Step 3: 准备表型文件（从 .tfam 提取）
cat emmax_input.tfam | cut -d" " -f1,2,6 > phenotype.txt

# Step 4: 运行关联分析
emmax -v -d 10 \
  -t emmax_input \
  -p phenotype.txt \
  -k kinship_matrix \
  -o emmax_output
```



---

## 总结

| 方法 | 模型 | 群体结构校正 | 适用场景 |
|------|------|-------------|---------|
| PLINK `--assoc` | 卡方/逻辑回归 | 无 | 初步筛选、二分类表型 |
| PLINK `--glm` | 广义线性模型 | 可加协变量 | 快速分析 |
| GEMMA | MLM (Wald/LRT) | 有（kinship） | 精细关联分析 |
| EMMAX | MLM (REML) | 有（kinship） | 大规模数据、TWAS |

实际分析中，建议先用 PLINK 做快速筛选，再用 GEMMA/EMMAX 的混合线性模型做精细关联分析，以降低假阳性率。
