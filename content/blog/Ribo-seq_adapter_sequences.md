---
title: "Ribo-seq 去接头处理常用序列及其来源整理记录"
summary: " Ribo-seq 去接头处理常用序列及其来源整理记录，"
date: 2026-05-28
draft: false
tags: ["Ribo-seq", "生信分析", "Cutadapt"]
categories: ["NGS分析"]
author: "Cy257"
showToc: true
TocOpen: false
---

> 整理日期：2026-05-28  
>
> 主题：Ribo-seq 数据预处理

---

## 1. 背景：为什么 Ribo-seq 数据特别需要去接头

Ribo-seq（ribosome profiling）通过核酸酶消化未被核糖体保护的 RNA，富集核糖体保护片段（ribosome-protected fragments, RPFs），再对这些短片段进行高通量测序，从而在转录组尺度上定位核糖体占据位置和估计翻译状态。常见 RPF 长度通常在约 20–35 nt 范围内，经典真核 elongating ribosome footprint 常见于约 28–30 nt，但具体长度会受到物种、核酸酶、翻译抑制剂、消化强度、片段回收范围和建库方法影响。参考：[McGlincy & Ingolia 2017, Methods / PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC5582988/)、[Ribo-seq review 2024 / PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC11076270/)。

由于 RPF insert 通常明显短于 Illumina SE50、SE75 或更长读长，测序时很容易从 insert 读穿进入 3′ adapter。因此，Ribo-seq 原始 reads 预处理的关键步骤通常包括：

- 1. 3′ adapter trimming；
- 2. 低质量碱基过滤；
- 3. RPF 长度筛选；
- 4. rRNA/tRNA/snRNA/snoRNA 等污染序列去除；
- 5. 基因组或转录组比对；
- 6. P-site/A-site offset 校正；
- 7. CDS 富集和 3-nt periodicity 检查。

Cutadapt 官方文档说明：当待测片段短于 read length 时，read 会包含 adapter；`-a ADAPTER` 用于识别并去除 3′ adapter 及其后续序列。参考：[Cutadapt user guide](https://cutadapt.readthedocs.io/en/stable/guide.html)。

需要特别注意：**Ribo-seq 没有唯一标准 adapter 序列**。去接头序列主要由文库构建方案决定。常见来源包括：

- Ingolia-style Ribo-seq 协议；
- NEB Universal miRNA Cloning Linker；
- Illumina TruSeq Small RNA；
- NEBNext Small RNA / NEBNext Multiplex Small RNA；
- NEXTflex、CleanTag、TailorMix、Lexogen 等 small RNA kit；
- QIAseq miRNA Library Kit；
- SMARTer smRNA-seq / poly(A)-tailing 类流程；
- Ribo-ITP 等低输入或单细胞改造流程；
- 项目或实验室自定义 adapter。

---

## 2. 常见文库构建试剂盒 / 论文协议与 adapter 来源

### 2.1 Ingolia-style Ribo-seq / NEB Universal miRNA Cloning Linker

经典 Ribo-seq 协议常把 RPF 当作短 RNA 片段进行建库。RPF 经过末端修复后，在 3′ 端连接一个预腺苷化、3′ 阻断的 linker，然后进行反转录、环化或 PCR 扩增、测序。

NEB Universal miRNA Cloning Linker 的官方序列为：

```text
5′ rAppCTGTAGGCACCATCAAT–NH2 3′
```

其中真正会作为 reads 3′ 端 adapter 被 trim 的 DNA 序列是：

```text
CTGTAGGCACCATCAAT
```

参考来源：

- [NEB Universal miRNA Cloning Linker, S1315S](https://www.neb.com/en-us/products/s1315-universal-mirna-cloning-linker)
- [RiboGalaxy Ribo-seq preprocessing tutorial](https://riboseq.org/tutorials/RiboGalaxy/RiboGalaxy_HandsOnTurorial_PART1_preprocessing_RiboSeq_and_RNASeq_20Feb23.pdf)

该序列是 Ribo-seq 中最常见的 adapter 之一。若在 FastQC overrepresented sequences 中看到 `CTGTAGGCACCATCAAT`、`TGTAGGCACCATCAAT` 或相关截短片段，通常可以优先怀疑是 NEB/Ingolia-style linker。

---

### 2.2 Illumina TruSeq Small RNA / NEXTflex / CleanTag / TailorMix 类 small RNA kit

Ribo-seq 文库的 insert 很短，因此很多实验室直接借用 small RNA library kit。Illumina TruSeq Small RNA 的官方 adapter trimming 序列为：

```text
TGGAATTCTCGGGTGCCAAGG
```

参考来源：

- [Illumina TruSeq Small RNA adapter sequences](https://support-docs.illumina.com/SHARE/AdapterSequences/Content/TruSeq-SmallRNA.htm)
- [adapter4srna：small RNA kit adapter 汇总](https://github.com/joey0214/adapter4srna)

NEXTflex、CleanTag、TailorMix 等 small RNA 建库体系也常见同一 `TGGA...` 系列 adapter。部分 NEXTflex Small RNA 文库还会在 insert 两侧引入 random bases，因此在去除 3′ adapter 后，还可能需要额外裁剪 reads 两端的 4 nt random bases。例如 GEO 样本 GSM4403966 的 Ribo-seq 数据处理记录中，先使用 `-a TGGAATTCTCGGGTGCCAAGG --minimum-length 23` 去接头，再使用 `cutadapt -u 4 -u -4` 去除两侧 4 nt random bases。参考：[GSM4403966 GEO processing record](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSM4403966)。

---

### 2.3 NEBNext Small RNA / NEBNext Multiplex Small RNA

NEBNext Small RNA Library Prep 的官方 FAQ 给出 single-end Read 1 trimming 序列：

```text
AGATCGGAAGAGCACACGTCTGAACTCCAGTCAC
```

paired-end 数据中，Read 2 可使用：

```text
GATCGTCGGACTGTAGAACTCTGAACGTGTAGATCTCGGTGGTCGCCGTATCATT
```

参考来源：[NEB FAQ: How should my NEBNext Small RNA library be trimmed?](https://www.neb.com/en-us/faqs/how-should-my-nebnext-small-rna-library-be-trimmed)

实际分析中，还常见使用较短的 Illumina/NEBNext adapter core：

```text
AGATCGGAAGAGCACACGTCT
```

该 core 序列可提高对截短 adapter 的识别，但也更容易与 insert 内部序列发生偶然匹配。因此，未知数据初筛时可以使用，最终流程中建议结合 cutadapt report 和 FastQC 结果决定。

---

### 2.4 QIAseq miRNA Library Kit

QIAseq miRNA Library Kit 也可能用于 Ribo-seq 或类似短 RNA 文库。QIAGEN 官方 FAQ 给出的 QIAseq miRNA NGS 3′ adapter 为：

```text
AACTGTAGGCACCATCAAT
```

QIAseq miRNA 5′ adapter 的 DNA trimming 序列为：

```text
GTTCAGAGTTCTACAGTCCGACGATC
```

参考来源：

- [QIAGEN FAQ-3671: QIAseq miRNA NGS 3′ Adapter](https://www.qiagen.com/us/resources/faq/3671)
- [QIAseq miRNA Library Kit product FAQ](https://www.qiagen.com/us/products/discovery-and-translational-research/next-generation-sequencing/rna-sequencing/mirna-small-rnaseq/qiaseq-mirna-ngs)

注意：`AACTGTAGGCACCATCAAT` 与 NEB/Ingolia-style `CTGTAGGCACCATCAAT` 高度相似。如果在 reads 中观察到 `ACTGTAGGCACCA` 这类片段，既可能是 QIAseq adapter 的截短片段，也可能是 NEB/Ingolia linker 附近多读入或截断造成的相似片段。建议同时测试完整的 `AACTGTAGGCACCATCAAT` 与 `CTGTAGGCACCATCAAT`。

---

### 2.5 Lexogen、CATS、SMARTer 等其他 small RNA 建库体系

一些 Ribo-seq 或短 RPF 类数据可能使用其他 small RNA kit。adapter4srna 汇总了多种商业 small RNA kit 的 3′ adapter，例如：

| Kit / 技术体系 | 3′ adapter 序列 |
|---|---|
| Lexogen Small RNA-Seq Library Prep Kit | `TGGAATTCTCGGGTGCCAAGGAACTCCAGTCAC` |
| Diagenode CATS small RNA-seq Kit | `GATCGGAAGAGCACACGTCTG` |
| CATS / Illumina 短残留片段 | `AGAGCACACGTCTG` |
| Takara SMARTer smRNA-Seq Kit for Illumina | `AAAAAAAAAA` |

参考来源：[adapter4srna GitHub repository](https://github.com/joey0214/adapter4srna)

这类序列在 Ribo-seq 中不是最经典方案，但由于 Ribo-seq insert 很短、建库逻辑与 small RNA-seq 相似，因此在未知数据中仍值得检查。

---

### 2.6 Ribo-ITP / poly(A)-like adapter / ligation-free 或低输入改造流程

Ribo-ITP（ribosome profiling via isotachophoresis）是低输入或单细胞场景下的改造 Ribo-seq 方法。Ozadam et al. 的 Nature 文章方法部分说明，Ribo-ITP 数据中使用 cutadapt 去除 3′ adapter：

```text
AAAAAAAAAACAAAAAAAAAA
```

而 conventional ribosome profiling 数据中去除 poly(A) tail 的参数为：

```bash
cutadapt -u 3 -a AAAAAAAAAA --overlap=4 --trimmed-only
```

参考来源：

- [Ozadam et al. 2023, Nature: Single-cell quantification of ribosome occupancy in early mouse development](https://www.nature.com/articles/s41586-023-06228-9)
- [Ribo-ITP protocol page](https://ceniklab.github.io/ribo_itp/)

这类 poly(A)-like 序列低复杂度较高，最终分析时应谨慎使用，避免对真实 insert 中的 A-rich 区域造成过度修剪。

---

### 2.7 较老或项目特异 adapter

部分较早 Ribo-seq 数据或实验室自定义建库方案使用不同 adapter。例如 GEO 样本 GSM1446833 明确标注 ribosome profiling 3′ adapter 为：

```text
TCGTATGCCGTCTTCTGCTTG
```

参考来源：[GSM1446833 GEO processing record](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSM1446833)

还有一些项目会直接把 NEB/Ingolia linker 与下游 Illumina adapter 拼接后作为完整 trim 序列，例如 GEO 样本 GSM5610138 的 Ribo-seq trimming 参数为：

```text
CTGTAGGCACCATCAATAGATCGGAAGAGCACACGTCTGAACTCCAGTCAC
```

参考来源：[GSM5610138 GEO processing record](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSM5610138)

这类序列更应视为“项目实例来源”，不宜直接当作所有 Ribo-seq 数据的通用 adapter。

---

## 3. Ribo-seq 去接头常用序列汇总表

| 序列，5′→3′                                               | 推荐 FASTA header                                        | 来源 / 适用场景                                              | 来源链接                                                     |
| --------------------------------------------------------- | -------------------------------------------------------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| `CTGTAGGCACCATCAAT`                                       | `NEB_Universal_miRNA_Cloning_Linker_Ingolia_RiboSeq`     | NEB Universal miRNA Cloning Linker；Ingolia-style Ribo-seq 常见 3′ linker | [NEB S1315S](https://www.neb.com/en-us/products/s1315-universal-mirna-cloning-linker) |
| `AACTGTAGGCACCATCAAT`                                     | `QIAseq_miRNA_Library_Kit_3prime_adapter`                | QIAseq miRNA Library Kit 3′ adapter                          | [QIAGEN FAQ-3671](https://www.qiagen.com/us/resources/faq/3671) |
| `TGGAATTCTCGGGTGCCAAGG`                                   | `Illumina_TruSeq_Small_RNA_NEXTflex_CleanTag_TailorMix`  | Illumina TruSeq Small RNA；NEXTflex、CleanTag、TailorMix 等 small RNA kit 常见 adapter | [Illumina TruSeq Small RNA](https://support-docs.illumina.com/SHARE/AdapterSequences/Content/TruSeq-SmallRNA.htm), [adapter4srna](https://github.com/joey0214/adapter4srna), [GSM4403966](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSM4403966) |
| `TGGAATTCTCGGGTGCCAAGGAACTCCAGTCAC`                       | `Lexogen_Small_RNA_Seq_3prime_adapter`                   | Lexogen Small RNA-Seq Library Prep Kit 3′ adapter            | [adapter4srna](https://github.com/joey0214/adapter4srna)     |
| `AGATCGGAAGAGCACACGTCTGAACTCCAGTCAC`                      | `NEBNext_Small_RNA_Read1_adapter`                        | NEBNext Small RNA single-end Read 1 trimming 序列            | [NEB FAQ](https://www.neb.com/en-us/faqs/how-should-my-nebnext-small-rna-library-be-trimmed) |
| `AGATCGGAAGAGCACACGTCTGAACTCCAGTCA`                       | `Illumina_TruSeq_or_NEBNext_LowBias_Read1_adapter`       | Illumina TruSeq / NEBNext Low-bias Read 1 adapter 常见写法   | [Illumina adapter trimming reference](https://knowledge.illumina.com/library-preparation/general/library-preparation-general-reference_material-list/000001314) |
| `AGATCGGAAGAGCACACGTCT`                                   | `NEBNext_Small_RNA_3prime_adapter_core`                  | NEBNext / Illumina 类 adapter core；适合初筛，但最终使用需谨慎 | [adapter4srna](https://github.com/joey0214/adapter4srna)     |
| `GATCGGAAGAGCACACGTCTG`                                   | `Diagenode_CATS_small_RNA_Seq_3prime_adapter`            | Diagenode CATS small RNA-seq Kit 3′ adapter                  | [adapter4srna](https://github.com/joey0214/adapter4srna)     |
| `AGAGCACACGTCTG`                                          | `CATS_Illumina_short_adapter_residual`                   | CATS / Illumina adapter 残留短片段                           | [adapter4srna](https://github.com/joey0214/adapter4srna)     |
| `TCGTATGCCGTCTTCTGCTTG`                                   | `Old_Illumina_small_RNA_DpnII_gene_expression_adapter`   | 较老或项目特异 Ribo-seq adapter                              | [GSM1446833](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSM1446833) |
| `CTGTAGGCACCATCAATAGATCGGAAGAGCACACGTCTGAACTCCAGTCAC`     | `Ingolia_RiboSeq_linker_plus_Illumina_adapter_composite` | NEB/Ingolia linker + Illumina adapter 拼接型序列；项目实例   | [GSM5610138](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSM5610138) |
| `AAAAAAAAAA`                                              | `PolyA_tailing_SMARTer_smRNA_ligation_free_RiboSeq`      | poly(A)-tailing / SMARTer smRNA-seq / conventional Ribo-seq poly(A) trimming | [adapter4srna](https://github.com/joey0214/adapter4srna), [Ozadam et al. 2023](https://www.nature.com/articles/s41586-023-06228-9) |
| `AAAAAAAAAACAAAAAAAAAA`                                   | `Ribo_ITP_3prime_adapter`                                | Ribo-ITP 3′ adapter                                          | [Ozadam et al. 2023](https://www.nature.com/articles/s41586-023-06228-9) |
| `GTTCAGAGTTCTACAGTCCGACGATC`                              | `Illumina_TruSeq_QIAseq_small_RNA_5prime_adapter`        | Illumina TruSeq / QIAseq small RNA 5′ adapter；通常不是 SE Ribo-seq 主要 3′ trim 目标 | [Illumina TruSeq Small RNA](https://support-docs.illumina.com/SHARE/AdapterSequences/Content/TruSeq-SmallRNA.htm), [QIAseq miRNA product FAQ](https://www.qiagen.com/us/products/discovery-and-translational-research/next-generation-sequencing/rna-sequencing/mirna-small-rnaseq/qiaseq-mirna-ngs) |
| `GATCGTCGGACTGTAGAACTCTGAACGTGTAGATCTCGGTGGTCGCCGTATCATT` | `NEBNext_Small_RNA_paired_end_Read2_adapter`             | NEBNext Small RNA paired-end Read 2 adapter                  | [NEB FAQ](https://www.neb.com/en-us/faqs/how-should-my-nebnext-small-rna-library-be-trimmed) |
| `AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT`                       | `Illumina_TruSeq_paired_end_Read2_adapter`               | Illumina TruSeq / NEBNext Low-bias Read 2 adapter 常见序列   | [Illumina adapter trimming reference](https://knowledge.illumina.com/library-preparation/general/library-preparation-general-reference_material-list/000001314) |

---

## 4. FASTA 格式 adapter 序列

可将以下内容保存为 `ribo_adapters.fa`，用于 cutadapt 初筛。

```fasta
>NEB_Universal_miRNA_Cloning_Linker_Ingolia_RiboSeq
CTGTAGGCACCATCAAT
>QIAseq_miRNA_Library_Kit_3prime_adapter
AACTGTAGGCACCATCAAT
>Illumina_TruSeq_Small_RNA_NEXTflex_CleanTag_TailorMix
TGGAATTCTCGGGTGCCAAGG
>Lexogen_Small_RNA_Seq_3prime_adapter
TGGAATTCTCGGGTGCCAAGGAACTCCAGTCAC
>NEBNext_Small_RNA_Read1_adapter
AGATCGGAAGAGCACACGTCTGAACTCCAGTCAC
>Illumina_TruSeq_or_NEBNext_LowBias_Read1_adapter
AGATCGGAAGAGCACACGTCTGAACTCCAGTCA
>NEBNext_Small_RNA_3prime_adapter_core
AGATCGGAAGAGCACACGTCT
>Diagenode_CATS_small_RNA_Seq_3prime_adapter
GATCGGAAGAGCACACGTCTG
>CATS_Illumina_short_adapter_residual
AGAGCACACGTCTG
>Old_Illumina_small_RNA_DpnII_gene_expression_adapter
TCGTATGCCGTCTTCTGCTTG
>Ingolia_RiboSeq_linker_plus_Illumina_adapter_composite
CTGTAGGCACCATCAATAGATCGGAAGAGCACACGTCTGAACTCCAGTCAC
>PolyA_tailing_SMARTer_smRNA_ligation_free_RiboSeq
AAAAAAAAAA
>Ribo_ITP_3prime_adapter
AAAAAAAAAACAAAAAAAAAA
>Illumina_TruSeq_QIAseq_small_RNA_5prime_adapter
GTTCAGAGTTCTACAGTCCGACGATC
>NEBNext_Small_RNA_paired_end_Read2_adapter
GATCGTCGGACTGTAGAACTCTGAACGTGTAGATCTCGGTGGTCGCCGTATCATT
>Illumina_TruSeq_paired_end_Read2_adapter
AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT
```

---

## 5. 未知 Ribo-seq 数据的 cutadapt 操作建议

### 5.1 优先确认 adapter 来源

对于未知 Ribo-seq 数据，不建议直接固定使用某一个 adapter。推荐按以下顺序确认：

1. 查看原始论文 Methods 中的 library preparation / data processing；
2. 查看 GEO/SRA/ENA 样本页面的 `Data processing` 或 `Library construction` 字段；
3. 运行 FastQC 或 fastp，查看 `Overrepresented sequences`；
4. 将 overrepresented sequences 与上方 adapter FASTA 比对；
5. 使用多个候选 adapter 做 cutadapt 初筛；
6. 根据 cutadapt report 选择主 adapter，再进行正式 trimming。

---

### 5.2 使用多个候选 adapter 做初筛

将上方 FASTA 保存为：

```bash
ribo_adapters.fa
```

对未知样本做初筛：

```bash
cutadapt \
  -j 8 \
  -a file:ribo_adapters.fa \
  -m 15 \
  -o sample.adapter_screen.fq.gz \
  sample.raw.fq.gz \
  > sample.adapter_screen.cutadapt.log
```

查看每个 adapter 的命中情况：

```bash
grep -A 8 "=== Adapter" sample.adapter_screen.cutadapt.log
```

如果某个 adapter 的 trimmed reads 占比显著高于其他 adapter，说明它更可能是真实建库 adapter。正式分析时建议只使用该 adapter 或同一建库体系的一组 adapter，避免过度修剪。

---

### 5.3 常规 single-end Ribo-seq 去接头示例

#### NEB / Ingolia-style linker

```bash
cutadapt \
  -j 8 \
  -a CTGTAGGCACCATCAAT \
  -m 20 \
  -M 35 \
  -q 20 \
  -o sample.trimmed.fq.gz \
  sample.raw.fq.gz \
  > sample.cutadapt.log
```

#### Illumina TruSeq / NEXTflex small RNA adapter

```bash
cutadapt \
  -j 8 \
  -a TGGAATTCTCGGGTGCCAAGG \
  -m 20 \
  -M 40 \
  -q 20 \
  -o sample.trimmed.fq.gz \
  sample.raw.fq.gz \
  > sample.cutadapt.log
```

#### NEBNext Small RNA adapter

```bash
cutadapt \
  -j 8 \
  -a AGATCGGAAGAGCACACGTCTGAACTCCAGTCAC \
  -m 20 \
  -M 40 \
  -q 20 \
  -o sample.trimmed.fq.gz \
  sample.raw.fq.gz \
  > sample.cutadapt.log
```

---

### 5.4 NEXTflex random bases 处理示例

如果确认文库为 NEXTflex Small RNA，并且建库设计包含两端 4 nt random bases，可先去 3′ adapter，再去两端 random bases：

```bash
# Step 1: 去除 3′ adapter
cutadapt \
  -j 8 \
  -a TGGAATTCTCGGGTGCCAAGG \
  -m 23 \
  -o sample.no_adapter.fq.gz \
  sample.raw.fq.gz \
  > sample.adapter.log

# Step 2: 去除两端 4 nt random bases
cutadapt \
  -j 8 \
  -u 4 \
  -u -4 \
  -m 20 \
  -M 40 \
  -o sample.trimmed.fq.gz \
  sample.no_adapter.fq.gz \
  > sample.random_base_trim.log
```

参考：[GSM4403966 GEO processing record](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSM4403966)。

---

### 5.5 Poly(A)-like adapter 的处理建议

对于 `AAAAAAAAAA` 或 `AAAAAAAAAACAAAAAAAAAA` 这类 poly(A)-like adapter，应特别谨慎：

```bash
cutadapt \
  -j 8 \
  -a AAAAAAAAAA \
  --overlap 4 \
  --trimmed-only \
  -m 20 \
  -o sample.trimmed.fq.gz \
  sample.raw.fq.gz \
  > sample.polyA_trim.log
```

Ribo-ITP 示例：

```bash
cutadapt \
  -j 8 \
  -a AAAAAAAAAACAAAAAAAAAA \
  --overlap 4 \
  --trimmed-only \
  -m 20 \
  -o sample.trimmed.fq.gz \
  sample.raw.fq.gz \
  > sample.ribo_itp_trim.log
```

低复杂度 adapter 容易与真实 insert 中的 A-rich 区域偶然匹配。建议只有在文献、GEO/SRA 记录或 FastQC 明确支持时，才把它作为最终 trimming adapter。

---

### 5.6 不建议盲目把所有 adapter 用于最终 trimming

多 adapter trimming 适合做初筛，但不一定适合作为最终流程。特别需要谨慎的序列包括：

```text
AAAAAAAAAA
AGAGCACACGTCTG
AGATCGGAAGAGCACACGTCT
```

这些序列较短或低复杂度，可能在真实 RPF insert 中偶然出现。最终 trimming 方案应结合以下 QC 指标判断：

- adapter trim rate 是否合理；
- trim 后 reads 长度峰是否符合实验预期，例如常见 20–35 nt；
- rRNA/tRNA 污染是否下降；
- CDS 区域 reads 是否富集；
- 是否存在明显 3-nt periodicity；
- P-site/A-site offset 是否稳定；
- 生物学重复之间长度分布和周期性是否一致。

---

## 6. 推荐的未知 Ribo-seq 数据处理流程

```bash
# Step 1: 原始数据 QC
fastqc sample.raw.fq.gz -o fastqc_raw/

# Step 2: 使用候选 adapter FASTA 做初筛
cutadapt \
  -j 8 \
  -a file:ribo_adapters.fa \
  -m 15 \
  -o sample.adapter_screen.fq.gz \
  sample.raw.fq.gz \
  > sample.adapter_screen.cutadapt.log

# Step 3: 查看 adapter 命中情况
grep -A 8 "=== Adapter" sample.adapter_screen.cutadapt.log

# Step 4: 根据主 adapter 正式 trimming
cutadapt \
  -j 8 \
  -a CTGTAGGCACCATCAAT \
  -m 20 \
  -M 35 \
  -q 20 \
  -o sample.trimmed.fq.gz \
  sample.raw.fq.gz \
  > sample.final.cutadapt.log

# Step 5: trim 后 QC
fastqc sample.trimmed.fq.gz -o fastqc_trimmed/
```

---

## 7. 总结

Ribo-seq 去接头序列应由建库方案决定，而不是由 “Ribo-seq” 这个实验类型唯一决定。最常见的 Ribo-seq 3′ adapter 是 NEB/Ingolia-style `CTGTAGGCACCATCAAT`；small RNA kit 文库中常见 `TGGAATTCTCGGGTGCCAAGG`；NEBNext/Illumina 系文库中常见 `AGATCGGAAGAGCACACGTCT...`；QIAseq 文库中可能出现 `AACTGTAGGCACCATCAAT`；Ribo-ITP 或 poly(A)-tailing 类流程中可能出现 `AAAAAAAAAA` 或 `AAAAAAAAAACAAAAAAAAAA`。

对于未知来源 Ribo-seq 数据，推荐先结合论文 Methods、GEO/SRA 记录、FastQC overrepresented sequence 和 cutadapt 初筛结果确定真实 adapter，再进行正式 trimming。不要直接把所有候选 adapter 同时用于最终分析，尤其要谨慎处理短序列和低复杂度序列。

---

## 8. 参考来源

1. [NEB Universal miRNA Cloning Linker, S1315S](https://www.neb.com/en-us/products/s1315-universal-mirna-cloning-linker)
2. [Illumina TruSeq Small RNA adapter sequences](https://support-docs.illumina.com/SHARE/AdapterSequences/Content/TruSeq-SmallRNA.htm)
3. [NEB FAQ: How should my NEBNext Small RNA library be trimmed?](https://www.neb.com/en-us/faqs/how-should-my-nebnext-small-rna-library-be-trimmed)
4. [QIAGEN FAQ-3671: QIAseq miRNA NGS 3′ Adapter](https://www.qiagen.com/us/resources/faq/3671)
5. [QIAseq miRNA Library Kit product FAQ](https://www.qiagen.com/us/products/discovery-and-translational-research/next-generation-sequencing/rna-sequencing/mirna-small-rnaseq/qiaseq-mirna-ngs)
6. [adapter4srna: 3′ adapter in small RNA sequencing](https://github.com/joey0214/adapter4srna)
7. [GSM4403966 GEO record: NEXTflex / TGGA adapter and 4-nt random-base trimming](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSM4403966)
8. [GSM1446833 GEO record: TCGTATGCCGTCTTCTGCTTG Ribo-seq adapter](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSM1446833)
9. [GSM5610138 GEO record: composite Ribo-seq adapter](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSM5610138)
10. [Ozadam et al. 2023, Nature: Single-cell quantification of ribosome occupancy in early mouse development](https://www.nature.com/articles/s41586-023-06228-9)
11. [Ribo-ITP protocol page](https://ceniklab.github.io/ribo_itp/)
12. [Cutadapt user guide](https://cutadapt.readthedocs.io/en/stable/guide.html)
13. [RiboGalaxy Ribo-seq preprocessing tutorial](https://riboseq.org/tutorials/RiboGalaxy/RiboGalaxy_HandsOnTurorial_PART1_preprocessing_RiboSeq_and_RNASeq_20Feb23.pdf)
14. [Illumina adapter trimming reference](https://knowledge.illumina.com/library-preparation/general/library-preparation-general-reference_material-list/000001314)
15. [McGlincy & Ingolia 2017: Transcriptome-wide measurement of translation by ribosome profiling](https://pmc.ncbi.nlm.nih.gov/articles/PMC5582988/)
16. [A review of ribosome profiling and tools used in Ribo-seq data analysis, 2024](https://pmc.ncbi.nlm.nih.gov/articles/PMC11076270/)





---
<br>

> **贡献者**
>
> 数据整理与撰写：ChatGPT-5.5
>
> 审校与发布：Cy257
>
> *本文由 AI 辅助生成，经作者审校后发布。*
