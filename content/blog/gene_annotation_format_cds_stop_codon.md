---
title: "基因组注释格式的差异 —— CDS 边界问题"
summary: " 从一个 CDS 边界问题看基因组注释格式的差异：GTF、GFF3、BED 与 genePred 的一些记录"
date: 2026-06-03
draft: false
tags: ["生信分析", "基因组注释", "GTF", "stop-codon"]
categories: ["NGS分析"]
author: "Cy257"

---

> 整理日期：2026-06-03  
>
> 主题：基因组注释格式差异

---

## 1. 问题发现

在个人项目中，需要对多个物种的基因组注释文件进行统一整理。这些注释文件来自不同来源，例如 Ensembl Plants、NCBI RefSeq、JGI/Phytozome，以及一些物种社区数据库。在分析过程中遇到一些报错问题，深入排查发现，问题根源在于不同 `.gtf` 文件中对 `CDS` 的定义不一致。

在一些 GTF 文件中，蛋白编码转录本会出现类似这样的结构：

```text
CDS          100   996
start_codon 100   102
stop_codon  997   999
```

这种情况下，`CDS` 不包含终止密码子，`stop_codon` 被单独写成一行。

但在另外一些来源的注释文件中，同一个概念可能更像下面这样：

```text
CDS          100   999
```

这里 `CDS` 已经覆盖了从起始密码子到终止密码子的完整范围，文件中可能并没有单独的 `stop_codon` 行。

如果只是做 gene-level counting，这个差异可能暂时不明显；但如果需要重建 CDS 序列、计算 CDS 长度、翻译蛋白、提取终止密码子附近区域，或者做 Ribo-seq 终止位点 metagene 分析，这 3 bp 的差异就会直接影响结果。

于是问题就变成了：

> 为什么同样的 GTF 格式参考注释文件，不同物种、不同数据库来源中的 `CDS` 定义会不一致？

---

## 2. 问题原因

### 2.1 标准 GTF 格式是如何规定的？

GTF 的全称通常写作 **Gene Transfer Format**，它和 GFF2 有很深的历史关系。Ensembl 的格式说明中也写到，GTF 与 GFF version 2 基本一致，都是每个 feature 一行、共 9 列的 tab 分隔格式。

一个典型 GTF 行包括 9 列：

| 列号 | 字段 | 含义 |
|---:|---|---|
| 1 | seqname | 染色体、contig 或 scaffold 名称 |
| 2 | source | 注释来源或程序 |
| 3 | feature | feature 类型，例如 `gene`、`transcript`、`exon`、`CDS`、`start_codon`、`stop_codon` |
| 4 | start | feature 起点 |
| 5 | end | feature 终点 |
| 6 | score | 分数，没有则为 `.` |
| 7 | strand | `+`、`-` 或 `.` |
| 8 | frame / phase | CDS 的阅读框信息，通常为 `0`、`1`、`2` 或 `.` |
| 9 | attributes | 属性字段，例如 `gene_id "..."; transcript_id "...";` |

GTF/GFF2 的坐标是 **1-based、闭区间**。也就是说，`start=100, end=102` 表示包含 100、101、102 三个碱基。

真正容易引起误解的是第 3 列中的 `CDS`。在经典 GTF2/GENCODE/Ensembl 风格里：

- `start_codon` 可以单独作为 feature；
- `stop_codon` 可以单独作为 feature；
- `CDS` 表示会被翻译成氨基酸的编码区；
- 因为 stop codon 不编码氨基酸，所以 terminal exon 上的 stop codon 通常不被包含在 `CDS` feature 中。

换句话说，经典 GTF 风格更接近下面这个模型：

```text
ORF genomic span = start_codon + translated CDS body + stop_codon
CDS feature      = translated coding region, usually excluding stop_codon
stop_codon       = separate feature
```

这与很多人的直觉并不完全一致，因为我们常常在口语中说“CDS 从 start codon 到 stop codon”。但在 GTF 的一些历史定义和 Ensembl/GENCODE 生态中，`CDS` 更偏向“真正翻译成蛋白序列的部分”。

这也解释了为什么用 GTF 重建蛋白序列时，拼接 `CDS` 后通常不应该得到末尾的 `*`。如果需要终止密码子的坐标，需要额外读取 `stop_codon` feature。

### 2.2 现有各大数据库情况

#### 2.2.1 Ensembl / GENCODE 风格：GTF 中常见单独的 stop_codon

在人和小鼠等模式生物中，GENCODE/Ensembl 风格的 GTF 是目前 RNA-seq、Ribo-seq 分析中最常用的注释来源之一。GENCODE 的 GTF 格式说明中，feature type 包括 `gene`、`transcript`、`exon`、`CDS`、`UTR`、`start_codon`、`stop_codon` 等。

这类 GTF 文件通常会把 `stop_codon` 单独列出来，而 `CDS` 本身不包含 stop codon。对于很多基于 GTF 的转录组分析工具来说，这是一种很常见、也很自然的输入。

但需要注意的是：这种习惯是 GTF/GENCODE/Ensembl 生态中的常见约定，并不代表所有以 `.gtf` 结尾的文件都严格遵守这一点。

#### 2.2.2 Ensembl Plants：很多基因模型来自外部导入

Ensembl Plants 的情况更复杂一些。与人、鼠这类高度 curated 的模式生物不同，很多植物基因组的基因模型不是 Ensembl 从头完成全部注释，而是来自 INSDC 记录、物种社区、Phytozome/JGI 或其他公共来源。Ensembl Plants 官方文档也说明，Ensembl Genomes 中的 protein-coding gene models 往往从外部来源导入，GFF 是常用的导入格式。

这意味着 Ensembl Plants 中不同物种虽然最后都可以下载到类似 GTF/GFF 的文件，但底层来源可能并不相同。某些物种的 gene model 可能继承了原始 GFF3 或社区数据库的定义习惯；另一些物种则可能更接近 Ensembl 内部 dump 出来的 GTF 习惯。

因此，在 Ensembl Plants 做多物种分析时，不能简单地认为“来自 Ensembl Plants 的所有 GTF 都有完全一致的语义”。

#### 2.2.3 NCBI RefSeq：更接近 GFF3 / GenBank / INSDC 数据模型

NCBI RefSeq 常用 GFF3 作为基因组注释发布格式。NCBI 文档明确说明，其 GFF3 文件按照 Sequence Ontology 的 GFF3 规范组织，但在部分属性字段和具体实践上有 NCBI 自己的扩展。

在 GFF3 / Sequence Ontology 的语义中，`CDS` 通常包含 start codon 和 stop codon。也就是说，如果起始和终止密码子位置已知，那么 CDS 的前 3 bp 是 start codon，最后 3 bp 是 stop codon。

NCBI 的说明中还有一个很关键的细节：在 GenBank 提交流程中，如果一个 CDS 没有包含、但紧邻一个 stop codon，处理时可能会自动扩展 1–3 bp 来包含 stop codon；同时 `start_codon` 和 `stop_codon` feature 在 GFF3 或 GTF 中并不是必需项。

这就解释了为什么 NCBI/RefSeq 来源的注释经常表现为：

```text
CDS = 包含 stop codon 的完整编码范围
文件中不一定有单独 stop_codon 行
```

如果把这类文件直接转换成 GTF，而转换过程中没有重新调整 CDS/stop_codon 的语义，就会得到一种“扩展名是 GTF，但 CDS 语义更像 GFF3/GenBank”的文件。

#### 2.2.4 JGI / Phytozome 与物种社区数据库：GFF3 生态更常见

JGI/Phytozome 是植物基因组注释中非常常见的来源。很多物种发布时会提供 genome FASTA、transcript FASTA、protein FASTA 和 GFF3 注释文件。对植物、真菌和非模式物种来说，GFF3 往往比 GTF 更常见。

这类数据库的重点通常是提供完整的 gene model、protein sequence、functional annotation 和 comparative genomics 资源。它们的注释文件可能更接近 GFF3 / Sequence Ontology / 数据库内部 schema，而不是 GENCODE 式 GTF。

所以，在使用 JGI/Phytozome 注释时，需要特别注意：

- 原始文件是 GFF3 还是转换后的 GTF；
- `CDS` 是否包含 stop codon；
- 是否提供 protein FASTA，可用于反向验证 CDS 翻译结果；
- 是否存在 `phase`、`protein_id`、`Parent` 等关键信息；
- 不同物种 release 之间是否来自不同 annotation pipeline。

#### 2.2.5 UCSC / BED / genePred：更适合浏览器显示和区间操作，不适合作为 stop 语义的最终依据

UCSC 生态中常见格式包括 BED、BED12、genePred、refFlat、bigBed、bigGenePred 等。这些格式非常适合 genome browser 显示和大规模区间检索，但并不一定适合作为判断 `CDS` 是否包含 stop codon 的最终依据。

BED 的坐标是 **0-based、half-open**。例如：

```text
chromStart = 0
chromEnd   = 100
```

表示长度为 100 bp 的区间，对应 0–99，而不是 0–100。

BED12 中的 `thickStart` 和 `thickEnd` 通常用于表示 coding region 在浏览器中画粗的范围。但 BED12 没有独立的 `CDS`、`start_codon`、`stop_codon` feature 行，也没有保存 CDS phase。因此它可以用于展示“哪里是编码区”，但不能可靠回答“stop codon 是否包含在 CDS 中”。

genePred/refFlat 比 BED12 更结构化，可以按 transcript 一行保存 exonStarts、exonEnds、cdsStart、cdsEnd、exonFrames 等字段。但它依然没有单独的 `stop_codon` feature。也就是说，它很适合表示 transcript/CDS 骨架，却不适合追溯 stop codon 的原始注释语义。

### 2.3 已有社区讨论情况

这个问题并不是个例。UCSC 早期 FAQ 中就曾经提到，不同 gene annotation sets 对 stop codon 的处理历史上并不一致：GTF2 格式不把 stop codon 包含在 terminal exon 的 CDS 中，而 GenBank 格式会包含 stop codon；GFF 本身过去又没有把这个问题规定得足够清楚。

<img src="https://raw.githubusercontent.com/Chengy257/img-file-bed/main/test/image-20260603015959699.png" alt="image-20260603015959699" style="zoom: 40%;" />

AGAT 文档也专门整理过 GFF/GTF 的历史和各种格式“flavor”。它提到，GTF/GFF 格式变体很多，许多工具会因为对格式有特定预期而解析失败。这一点和实际项目中遇到的情况高度一致：文件扩展名看起来一样，但第 9 列属性、feature 层级、CDS/stop codon 定义、phase 字段都可能有细微差别。

Biostars 等社区论坛中也能看到类似问题。例如有人讨论 GFF/GTF 中如何根据 CDS 坐标翻译序列，也有人明确提到 GTF 与 GFF3 的差异之一就是 GTF 的 stop codon 不属于 CDS，而 GFF3 的 CDS 可能包含 stop codon。

AgBioData GFF3 工作组也从更宏观的角度指出：GFF3 是一个常见、灵活的 tab-delimited 注释格式，但随着注释数据复用越来越多，这种灵活性也变成了下游标准化处理的障碍。不同软件和数据库会用不同 notation 表达相似的数据模型，最终解释成本往往转移到使用者身上。

---

## 3. 基因组注释格式的发展变迁历史

从历史上看，基因组注释格式的发展大致经历了几个阶段。

### 3.1 从简单区间到 GFF 时代 （1997-2000 左右）

最早的需求通常很简单：在一条 DNA 序列上标记某个 feature 的位置，例如基因、外显子、motif、repeat、splice site 等。GFF，也就是 General Feature Format，最初就是为这种“一行表示一个 feature”的需求设计的。

GFF 的基本思想很朴素：

```text
sequence + source + feature type + start + end + strand + attributes
```

它比简单的 BED 区间更丰富，因为它可以保存 feature 类型、strand、score、phase 和属性字段；但早期 GFF/GFF2 对复杂层级关系的表达并不够严格。

### 3.2 GTF：为了基因预测和转录本注释而更具体化 （2000 左右）

2000 年左右，GTF 从 GFF2 分支出来，可以看作 GFF2 的一个更具体的分支。它更强调 gene/transcript/exon/CDS 这类基因模型注释，并且要求第 9 列中有稳定的 `gene_id` 和 `transcript_id`。

这种设计非常适合 RNA-seq 软件生态。很多常用工具，例如 STAR、HISAT2/StringTie、featureCounts、HTSeq、RSEM、Salmon/tximport 相关流程，都很容易使用 GTF 构建转录本或 gene-level 注释。

但 GTF 的缺点也来自这里：它对通用 feature 层级的表达能力不如 GFF3，很多复杂类型只能通过约定俗成的字段来表示。不同数据库为了适应自己的需求，又逐渐形成了不同 GTF “方言”。

### 3.3 GFF3：引入 Sequence Ontology 和 ID/Parent 层级（2004- ） 

GFF3 试图解决 GFF/GTF 层级表达不清的问题。它引入了更明确的 `ID` / `Parent` 关系：

```text
gene
  └── mRNA / transcript
        ├── exon
        ├── CDS
        ├── five_prime_UTR
        └── three_prime_UTR
```

GFF3 还更强调使用 Sequence Ontology 中定义的 feature type。因此从理论上说，GFF3 比 GTF 更适合作为跨物种、跨数据库、跨 feature 类型的通用交换格式。

但是，GFF3 的问题也很现实：它太灵活了。不同数据库在 attributes、Parent 关系、多转录本建模、UTR 表达、functional annotation、partial feature、exception 等方面都可能有自己的写法。结果就是，GFF3 在理论上更强，但在实际工具兼容性上未必总是更省心。

### 3.4 BED / genePred / bigBed：浏览器与区间计算需求推动的格式

UCSC 生态推动了另一类格式的发展：BED、genePred、bigBed、bigGenePred。

这类格式更关注：

- 快速显示；
- 快速区间检索；
- 远程加载；
- genome browser track 的性能；
- transcript model 的紧凑表示。

BED 非常适合 bedtools 这类区间操作；genePred 很适合 UCSC 内部数据库和 transcript model 表示；bigBed/bigGenePred 适合大规模浏览器 track。

但这些格式的定位与 GTF/GFF3 不完全一样。它们通常不是为了保存所有生物学语义细节，而是为了高效查询和展示。因此在 `CDS`、`stop_codon`、`phase`、partial transcript、translation exception 等问题上，需要回到原始 GTF/GFF3/GenBank 记录中确认。

---

## 4. 不同格式的特征和优缺点总结

| 格式 | 坐标体系 | 层级表达 | CDS/stop codon 语义 | 优点 | 缺点 | 适合用途 |
|---|---|---|---|---|---|---|
| GTF / GTF2.x | 1-based, closed | 中等，依赖 `gene_id` / `transcript_id` | 经典 GTF 中 `CDS` 通常不含 stop codon，`stop_codon` 单独表示 | RNA-seq/Ribo-seq 工具支持好；Ensembl/GENCODE 生态成熟；人工可读 | 方言多；层级不如 GFF3 清晰；不同来源的 `.gtf` 语义可能不一致 | 转录组分析、Ribo-seq、Ensembl/GENCODE 注释 |
| GFF3 | 1-based, closed | 强，使用 `ID` / `Parent` | Sequence Ontology 语义中 `CDS` 包含 start/stop codon | 语义丰富；适合复杂 feature；适合多物种数据库交换 | 灵活性过强；不同数据库 attributes 差异大；软件兼容性不稳定 | 跨物种注释交换、非模式物种、数据库发布 |
| BED3/6 | 0-based, half-open | 弱 | 不表达 CDS/stop codon | 极简；bedtools 友好；计算快 | 不能表达 gene model 细节 | peak、interval、region 操作 |
| BED12 | 0-based, half-open | 弱到中等，可表达 exon blocks | 通过 `thickStart/thickEnd` 表示 coding display region，但不可靠表达 stop 语义 | 浏览器显示友好；可表达 transcript block | 无 phase；无独立 stop_codon；属性少 | transcript 可视化、简单区间运算 |
| genePred / refFlat | 0-based, half-open | 中等，每个 transcript 一行 | 有 `cdsStart/cdsEnd`，但不单独表达 stop_codon | 结构紧凑；适合 UCSC 工具链；可保存 exon frame | 坐标系统易混；语义依赖来源；属性信息有限 | UCSC 注释表、格式转换中间层 |
| bigBed | 0-based, half-open | 取决于 schema | 取决于原始 BED schema | 二进制索引；远程加载快；适合大数据 track | 不适合人工编辑；不是通用交换母格式 | genome browser track hub |
| bigGenePred | 0-based, half-open | genePred 扩展 | 可用于显示更复杂 gene model，但仍偏浏览器生态 | 显示性能好；适合大型注释 track | UCSC 生态绑定；不适合通用文本处理 | 大规模基因注释可视化 |
| GenBank / EMBL / DDBJ flatfile | 通常为 feature table 语义 | 强，但格式复杂 | CDS 更接近 INSDC/GenBank 语义，通常期望包含完整翻译区和终止信息 | 信息丰富；适合归档；包含 qualifiers、translation、文献、taxonomy | 不适合大规模区间计算；解析复杂 | 原始记录归档、人工审阅、提交 |
| SAF | 1-based, closed | 弱 | 不表达 CDS/stop | 简单；featureCounts 友好 | 只能表达简单 feature | gene-level read counting |
| TxDb / EnsDb / SQLite 注释库 | 取决于构建来源 | 强，结构化数据库 | 取决于导入来源和构建规则 | 查询快；适合 R/Bioconductor | 不是通用交换文本；依赖软件生态 | 本地重复查询、下游统计分析 |

---

## 5. 小结

1. **经典 GTF/GENCODE/Ensembl 风格中，`CDS` 通常不包含 stop codon，`stop_codon` 单独表示。**
2. **GFF3/Sequence Ontology/NCBI RefSeq 风格中，`CDS` 通常包含 start codon 和 stop codon。**
3. **BED12/genePred 更适合浏览器显示和区间操作，不适合作为判断 stop codon 语义的最终依据。**
4. **不同数据库、不同物种、不同 release 的注释文件即使扩展名相同，也可能有不同的语义习惯。**
5. **多物种项目中最可靠的做法不是相信文件扩展名，而是建立自己的内部 canonical gene model，并用 genome FASTA / transcript FASTA / protein FASTA 做校验。**

---

## 6. 参考文献与资料

1. GENCODE. **Data format: GENCODE GTF/GFF3 format description**.  https://www.gencodegenes.org/pages/data_format.html
   
2. Ensembl. **GFF/GTF File Format - Definition and supported options**.  https://www.ensembl.org/info/website/upload/gff.html
   
3. Ensembl Plants. **Genome Annotation / GFF annotation import**.  https://plants.ensembl.org/info/genome/annotation/index.html , https://plants.ensembl.org/info/genome/annotation/gff_annotation.html
   
4. The Sequence Ontology. **GFF3 specification**. https://github.com/The-Sequence-Ontology/Specifications/blob/master/gff3.md
   
5. NCBI Datasets. **GFF3 format - NCBI annotation files**.  https://www.ncbi.nlm.nih.gov/datasets/docs/v2/reference-docs/file-formats/annotation-files/about-ncbi-gff3/
   
6. NCBI GenBank. **Annotating Genomes with GFF3 or GTF files**.  https://www.ncbi.nlm.nih.gov/genbank/genomes_gff/
   
7. UCSC Genome Browser. **Frequently Asked Questions: Data File Formats**.  https://genome.ucsc.edu/FAQ/FAQformat.html
   
8. UCSC Genome Browser. **Genome Browser FAQ / gene track notes on stop codon handling**.  https://ucsc.crg.eu/FAQ/FAQtracks.html
   
9. AGAT documentation. **The GTF/GFF formats**. https://agat.readthedocs.io/en/latest/gxf.html
   
10. Saha S. et al. **Recommendations for extending the GFF3 specification for improved interoperability of genomic data**. 
    arXiv:2202.07782.  https://arxiv.org/abs/2202.07782
    
11. Goodstein D.M. et al. **Phytozome: a comparative platform for green plant genomics**. *Nucleic Acids Research*, 2012.  https://pmc.ncbi.nlm.nih.gov/articles/PMC3245001/
    
12. Biostars discussion. **GFF/GTF: how to translate CDS genomic coordinates**. https://www.biostars.org/p/9481226/

