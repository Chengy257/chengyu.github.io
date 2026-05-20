---
title: "Ribo-seq 翻译 ORF 预测工具全攻略"
summary: "汇总 8 种主流 Ribo-seq ORF 预测工具的原理、用法和 Snakemake 集成代码，附工具对比表格和选型建议。"
date: 2024-06-05
draft: false
tags: ["Ribo-seq", "ORF", "翻译预测", "工具对比"]
categories: ["NGS分析"]
author: "Cy257"
showToc: true
TocOpen: false
---

# Ribo-seq 翻译 ORF 预测工具全攻略

## 背景

核糖体 profiling（Ribo-seq）通过捕获正在翻译的核糖体所保护的 mRNA 片段，可以在全基因组范围内揭示翻译事件。除了已知的蛋白编码基因，Ribo-seq 还能发现上游开放阅读框（uORF）、下游开放阅读框（dORF）、长链非编码 RNA 中的翻译事件以及非经典起始密码子介导的翻译。然而，从 Ribo-seq 数据中准确预测活跃翻译的 ORF 并非易事，需要借助专门的生物信息学工具。

本文汇总了目前主流的 Ribo-seq ORF 预测工具，涵盖它们的原理简介、使用方法及 Snakemake 流程集成代码。

> **注意**：本文所有代码块中的 `${}` 均为 Snakemake 模板变量（如 `{input.bam}`、`{wildcards.group}`、`{config[threads]}`），直接嵌入 Snakemake rule 即可运行。Shell 变量转义已使用 `${{var}}` 格式。

---

## 工具对比总览

| 工具 | 语言 | 输入 BAM 类型 | 速度 | 特点 |
|------|------|---------------|------|------|
| **Ribotaper** | Shell + R | Genome | 慢 | 基于三框读取框分布的多重检验，经典方法 |
| **RibORF** | Perl | Genome | 很慢 | 基于读取框一致性和读取密度双检验，严格但计算量大 |
| **RiboCode** | Python | **Transcriptome** | 中等 | 基于转录本坐标的三框周期性检验，需要转录本映射的 BAM |
| **RiboTish** | Python | **Genome** | 快 | 使用负二项分布模型检测翻译，支持差异翻译分析 |
| **Price** | Java (GeLi) | Genome | 中等 | 基于图模型的翻译推断，可检测非经典起始密码子 |
| **Ribotricer** | Python | Genome | 快 | 三帧周期性与读长一致性的严格筛选，输出格式清晰 |
| **Ribowave** | Shell + R | Genome | 中等 | 利用小波分析去噪，支持移码检测和多 ORF 鉴定 |



---

## 各工具详细用法

### Ribotaper

Ribotaper 通过计算每个 ORF 三种读取框中 Ribo-seq reads 的分布，利用统计检验判断是否存在显著的周期性三框信号，从而判定该 ORF 是否被翻译。该方法由 Calviello 等人于 2016 年发表，是经典的 ORF 预测方法之一。

- **语言**：Shell + R
- **输入**：Genome mapped BAM（需要同时提供 Ribo-seq 和 RNA-seq BAM）
- **速度**：较慢

```bash
HOME=`pwd`
if [ ! -d "5.ORF_analysis/RiboTaper/index" ];then 
    create_annotations_files.bash {input.GTF} {input.GENOME} false false 5.ORF_analysis/RiboTaper/index
fi
rlen=`tail -1 5.ORF_predict_old/RiboCode/metaplots/{wildcards.group}_pre_config.txt |awk '{{print $(NF-1)}}'`
pcutoff=`tail -1 5.ORF_predict_old/RiboCode/metaplots/{wildcards.group}_pre_config.txt |awk '{{print $(NF)}}'`
mkdir -p ${{HOME}}/5.ORF_analysis/RiboTaper/{wildcards.group} 
cd 5.ORF_analysis/RiboTaper/{wildcards.group}

Ribotaper.sh ${{HOME}}/3.align/merged/Ribo_{wildcards.group}_toGenome_merged.bam ${{HOME}}/3.align/merged/RNA_{wildcards.group}_toGenome_merged.bam ${{HOME}}/5.ORF_analysis/RiboTaper/index ${{rlen}} ${{pcutoff}} {config[threads]}
```

> **提示**：Ribotaper 需要预先通过 `create_annotations_files.bash` 生成注释索引文件。read length 和 p-value cutoff 可从 RiboCode 的 metaplot 结果中自动获取。

---

### RibORF

RibORF 通过两个统计检验来鉴定翻译的 ORF：(1) 三框周期性检验（Ribo-seq reads 是否集中在同一阅读框）；(2) read coverage 的均匀性检验（Ribo-seq reads 是否均匀覆盖整个 ORF 而非集中在一个区域）。两个条件同时满足才判定为翻译。该方法非常严格，但运行速度较慢。

- **语言**：Perl
- **输入**：Genome mapped BAM
- **速度**：很慢

```bash
# RibORF 需要预先准备注释文件，具体参数请参考其官方文档
```

> **注意**：RibORF 由于运行速度较慢，在大规模数据集上建议充分评估运行时间。

---

### RiboCode

RiboCode 首先通过 metaplot 分析确定 Ribo-seq 的 read length 和 P-site offset，然后基于转录本坐标对每个 ORF 的三框周期性进行统计检验。与其他工具不同，RiboCode 要求输入比对到**转录本**（transcriptome）的 BAM 文件。

- **语言**：Python
- **输入**：**Transcriptome** mapped BAM
- **速度**：中等

```bash
## 1. 准备转录本注释索引
mkdir -p 0.index/ribocode/pcGene
if [ ! -f "0.index/ribocode/allGene/transcripts.pickle" ];then
	prepare_transcripts -g {input.GTF} -f {input.GENOME} -o 0.index/ribocode/allGene >> {log} 2>&1
	prepare_transcripts -g {input.pcGene} -f {input.GENOME} -o 0.index/ribocode/pcGene >> {log} 2>&1
fi
## 2. Metaplot 分析，确定 read length 和 P-site offset
metaplots -a 0.index/ribocode/pcGene -r {input.bam} -o 5.ORF_analysis/RiboCode/metaplots/{wildcards.group} -m 20 -M 40 -f0_percent 0.5 -pv1 0.05 -pv2 0.05 >> {log} 2>&1
## 3. ORF 预测
RiboCode -a 0.index/ribocode/allGene -c 5.ORF_analysis/RiboCode/metaplots/{wildcards.group}_pre_config.txt -l no -A GTG,TTG,CTG,ACG -o 5.ORF_analysis/RiboCode/{wildcards.group}  >> {log} 2>&1
```

> **关键参数说明**：
> - `-m 20 -M 40`：指定 read length 范围为 20-40 nt
> - `-f0_percent 0.5`：frame 0 reads 占比阈值
> - `-A GTG,TTG,CTG,ACG`：指定非经典起始密码子
> - 需要先准备两套索引：`allGene`（用于预测）和 `pcGene`（用于 metaplot 参数估计）

---

### RiboTish

RiboTish（Ribo-seq Translation Inference by Smoothing）使用负二项分布模型对 Ribo-seq reads 的三框周期性和覆盖均匀性建模，通过似然比检验判断 ORF 是否翻译。同时支持差异翻译分析（differential translation）。速度较快，是实用性很强的工具。

- **语言**：Python
- **输入**：**Genome** mapped BAM
- **速度**：快

```bash
## 1. 质量评估
ribotish quality -p {config[threads]} -b {input.bam} -g {input.pcGene} -l 20,41 --th 0.5 >> {log} 2>&1

## 2. ORF 预测
ribotish predict -p {config[threads]} --alt --altcodons GTG,TTG,CTG,ACG --framebest  -b {input.bam} -g {input.GTF} -f {input.GENOME} -o {output}  >> {log} 2>&1 
```

> **关键参数说明**：
> - `--alt`：检测非注释的替代 ORF（如 uORF、dORF）
> - `--altcodons`：指定替代起始密码子
> - `--framebest`：使用最优框模式
> - 建议先运行 `ribotish quality` 检查数据质量

---

### Price

Price（Protein-seq Ribo-seq Inference by Computational Enrichment）基于图模型（graph model）来推断翻译事件，能够有效区分真实翻译信号与背景噪音。Price 是 GeLi 软件套件的一部分，可以检测非经典起始密码子起始的翻译。

- **语言**：Java（GeLi 平台）
- **输入**：Genome mapped BAM
- **速度**：中等

```bash
## 1. 构建基因组索引
if [ ! -f 0.index/price/IndexGenome ];then
	mkdir -p 0.index/price/
	/home/chengyu/soft/Gedi_1.0.6/gedi -e IndexGenome -s {input.GENOME} -a {input.GTF} -p -nokallisto -nobowtie -nostar -o 0.index/price/IndexGenome >> {log} 2>&1
fi

## 2. BAM 转 CIT 格式
/home/chengyu/soft/Gedi_1.0.6/gedi -e Bam2CIT {output.cit} {input.bam} >> {log} 2>&1

## 3. 运行 Price 预测
/home/chengyu/soft/Gedi_1.0.6/gedi -e Price -fdr 0.1 -reads {output.cit} -genomic 0.index/price/IndexGenome -prefix 5.ORF_analysis/Price/{wildcards.group} -progress -plot -nthreads {config[threads]} >> {log} 2>&1
```

> **提示**：Price 需要 GeLi/GeDi 平台支持，BAM 文件需先转换为 CIT 格式。

---

### Ribotricer

Ribotricer 通过严格筛选三帧周期性和 read length 一致性来鉴定活跃翻译的 ORF。它提供了一个从数据中经验学习 cutoff 的功能（`learn-cutoff`），可以自动确定最佳的筛选阈值，提高预测准确性。

- **语言**：Python
- **输入**：**Genome** mapped BAM
- **速度**：快

```bash
## 1. 准备 ORF 注释索引
ribotricer prepare-orfs --gtf {input.GTF} --fasta {input.GENOME} --prefix 0.index/ribotricer/ --min_orf_length 60 --start_codons ATG,GTG,TTG,CTG,ACG >> {log} 2>&1

## 2. 检测翻译的 ORF
ribotricer detect-orfs --bam {input.bam} \
 --ribotricer_index 0.index/ribotricer/_candidate_orfs.tsv \
 --prefix 5.ORF_predict/Ribotricer/{wildcards.group} >> {log} 2>&1

## 3. 从数据中经验学习 cutoff（可选，需要同时提供 Ribo-seq 和 RNA-seq BAM）
ribotricer learn-cutoff --ribo_bams ribo_bam1.bam,ribo_bam2.bam \
--rna_bams rna_1.bam \
--prefix ribo_rna_prefix \
--ribotricer_index {RIBOTRICER_ANNOTATION}
```

> **关键参数说明**：
> - `--min_orf_length 60`：最小 ORF 长度为 60 nt（即 20 个氨基酸）
> - `--start_codons`：支持的起始密码子列表
> - `learn-cutoff` 步骤需要同时有 Ribo-seq 和 RNA-seq 数据

---

### Ribowave

Ribowave 利用小波分析（wavelet analysis）对 Ribo-seq P-site 信号进行去噪处理，然后基于去噪后的信号鉴定翻译的 ORF。其独特优势在于可以检测翻译过程中的**核糖体移帧**（ribosomal frameshift）事件，这是其他工具较少涉及的功能。

- **语言**：Shell + R
- **输入**：Genome mapped BAM
- **速度**：中等

```bash
script_dir="/opt/biosoft/Ribowave/scripts"

## 0. 创建注释文件
if [ ! -f "0.index/ribowave/start_codon.bed" ]; then 
    mkdir -p 0.index/ribowave/
    ${{script_dir}}/create_annotation.sh -G {input.GTF} -f {input.GENOME} -o 0.index/ribowave/ -s ${{script_dir}} >> {log} 2>&1
fi

## 1. P-site 确定
${{script_dir}}/P-site_determination.sh -i {input.bam} -S 0.index/ribowave/start_codon.bed -o 5.ORF_analysis/Ribowave/{wildcards.group}/ -n {wildcards.group} -s ${{script_dir}}  >> {log} 2>&1

## 2. 生成 P-site track
if [ ! -f "{input.GENOME}.fai" ]; then samtools faidx {input.GENOME}; fi
${{script_dir}}/create_track_Ribo.sh -i {input.bam} -G 0.index/ribowave/exons.gtf -g {input.GENOME}.fai -P 5.ORF_analysis/Ribowave/{wildcards.group}/P-site/{wildcards.group}.psite1nt.txt -o 5.ORF_analysis/Ribowave/{wildcards.group}/ -n {wildcards.group} -s ${{script_dir}} >> {log} 2>&1 

## 3. Ribowave 预测翻译 ORF
${{script_dir}}/Ribowave -P -a 5.ORF_analysis/Ribowave/{wildcards.group}/bedgraph/{wildcards.group}/final.psite -b 0.index/ribowave/final.ORFs -o 5.ORF_analysis/Ribowave/{wildcards.group}/ -n {wildcards.group} -s ${{script_dir}} -p {config[threads]} >> {log} 2>&1

## 4. 计算移帧潜力（可选）
awk -F '\t' '$3=="anno"'  0.index/ribowave/final.ORFs  >  0.index/ribowave/aORF.ORFs;
${{script_dir}}/Ribowave -F -a 5.ORF_analysis/Ribowave/{wildcards.group}/bedgraph/{wildcards.group}/final.psite -b 0.index/ribowave/aORF.ORFs -o 5.ORF_analysis/Ribowave/{wildcards.group}/ -n {wildcards.group}_frameshift -s ${{script_dir}} -p {config[threads]}  >> {log} 2>&1 
```

> **关键步骤说明**：
> - 步骤 1-2 是 P-site 校准，必须先完成
> - 步骤 3 是核心 ORF 预测
> - 步骤 4 可选，专门用于检测已知注释 ORF 的移帧潜力
> - Ribowave 流程步骤较多，建议仔细检查每一步的中间输出

---

### RiboTIE

RiboTIE（Ribo-seq Translation Inference Engine）采用机器学习方法（SVM 分类器），综合三框周期性、read coverage、ORF 长度等多个特征来预测翻译 ORF。相比单一统计检验，机器学习方法能更好地整合多维度信息。

- **语言**：Python
- **输入**：Genome mapped BAM
- **速度**：中等

```bash
# RiboTIE 的具体参数配置请参考其官方文档
```

> **注意**：RiboTIE 需要训练好的模型或参考数据集来构建分类器，初次使用建议参考官方教程。

---

## 实用建议

### 1. 数据预处理

- **P-site 校准**是 Ribo-seq 分析的关键步骤，大部分工具都会自动或半自动完成这一步，建议在运行前检查 metaplot 结果确认 P-site offset 是否合理。
- **Read length 过滤**：通常选择 25-35 nt 范围的 reads，具体范围应根据实验实际情况通过 metaplot 确定。

### 2. 起始密码子设置

- 大多数工具默认仅检测以 ATG 起始的 ORF。如果需要检测非经典起始密码子（如 GTG、TTG、CTG 等），需要通过参数显式指定。
- 建议至少包含 `GTG, TTG, CTG` 作为非经典起始密码子。

### 3. 多工具联合分析

- 不同工具的算法原理和灵敏度存在差异，建议使用 **2-3 种工具**取交集，以提高预测结果的可靠性。
- 常见的组合策略：**RiboTish + Ribotricer**（快速筛选） + **RiboCode**（转录本级别验证）。

### 4. 结果验证

- 预测到的新 ORF 建议结合蛋白质组学数据（Mass Spec）进行验证。
- 对于 uORF 的功能研究，可以结合报告基因实验（reporter assay）进行验证。
- 利用保守性分析（如 PhyloCSF）提供额外的翻译证据。

### 5. Snakemake 集成

- 本文代码中的路径结构（如 `0.index/`、`3.align/`、`5.ORF_analysis/`）是一种推荐的目录组织方式，可根据实际项目调整。
- 所有代码可直接嵌入 Snakemake rule 的 `shell:` 指令中，`{}` 变量会自动被 Snakemake 解析。
