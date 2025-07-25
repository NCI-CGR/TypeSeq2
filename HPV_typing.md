

# HPV typing in TypeSeq2

## Introduction
The development of the Human Papillomavirus (HPV) typing workflow has spanned several years at NCI-CGR, yet a complete technical record has not been previously compiled. This document aims to establish a foundational understanding by synthesizing existing documentation and elucidating unrecorded aspects through the reverse engineering of the R source code integral to HPV typing.

### Reference
+ 2021-09_TypeSeq2-Technical-Overview_2_Wei[21].pptx

### Something about controls
+ Control samples: batch controls
+ Internal controls 
  + Human B2M
    + B2M-S1
    + B2M-S2
  + Assay spike-in controls
    + ASIC-Low
    + ASIC-Med
    + ASIC-High

---

## Methods
### Variant calling using Torrent Variant Caller (*tvc*)
on Torrent Variant Caller (TVC) is a genetic variant caller for Ion Torrent sequencing platforms, and is specially optimized to exploit the underlying flow signal information in the statistical model to evaluate variants. Torrent Variant Caller is designed to call single-nucleotide polymorphisms (SNPs), multi-nucleotide polymorphisms (MNPs), insertions, deletions, and block substitutions (see https://github.com/domibel/IonTorrent-VariantCaller).

+ The command below is to call HPV variants from the bam input files.
```bash
tvc --output-vcf {OutputVcf} --input-bam {InputBam} --force-sample-name  {SampleName} --input-vcf ${CONFIG}/TypeSeq2_Hotspot_v1.2.vcf --reference ${CONFIG}/TypeSeq2_Ion_Ref_v1.3.fasta --target-file ${CONFIG}/TypeSeq2_BED_v1.1.bed --parameters-file ${CONFIG}/TypeSeq2_Parameters_v1.1.json  --trim-ampliseq-primers  --num-threads 2
```

+ -o,--output-vcf                       FILE        vcf file with small variant calling results [small_variants.vcf]
+ -b,--input-bam                        FILE        bam file with mapped reads [required]
+ --force-sample-name                STRING      force all read groups to have this sample name [off]
+ -c,--input-vcf                        FILE        vcf.gz file (+.tbi) with additional candidate variant locations and alleles [optional]
+ -r,--reference                        FILE        reference fasta file [required]
+ -t,--target-file                      FILE        only process targets in this bed file [optional]
+ --parameters-file                  FILE        json file with algorithm control parameters [optional]
+ --trim-ampliseq-primers            on/off      match reads to targets and trim the ends that reach outside them [off]
+ -n,--num-threads                      INT         number of worker threads [2]

The reference file consists customized sequences of HPV strains, internal controls (i.e., B2M-S1/2 and ASIC-Low/Med/High) and decoys. To eliminate reference variant calling bias, the reference sequence was deliberately modified to contain mismatches with all known variants, including those within the A/A1 lineage. This ensures that all sublineages and lineages are assessed for changes relative to the established reference, preventing any inherent preference in variant detection. For instance, if lineage A exhibits the sequence AGTT***G***CCTG and lineage B exhibits AGTT***C***CCTG, the reference sequence was set to AGTT***A***CCTG, thereby neutralizing any bias in variant calling. Besides, 5\`-adapter sequence (ATAAATACAAGTTA-) and 3\`-adapter sequences (-TTAGTAAGATAATA) have been appended to each sequence in the reference file.  Therefore, there is no need to trim the adapter sequences in the upstream NGS read processing.  The variant positions are adjusted accordingly.  

The decoy contig sequences are designed to reduce the bias of read alignment in identical or similar regions among HPV strains.  

---

### HPV typing using the *R* workflow
#### 1. Parse VCF and get read counts
The input VCF file is parsed using *vcfR::vcfR2tidy*.  In this step, the multiallelic variants are split to into multiple bi-allelic variants.  Results from all samples are complied into one big table, with columns "barcode", "CHROM", "ALT", "AO", "SAF", "SAR", "FAO", "AF", "FSAF", "FSAR", "TYPE", "LEN", "HRUN", "MLLD", "FWDB", "REVB", "REFB", "VARB", "STB", "STBP", "RBI", "FR", "SSSB", "SSEN", "SSEP", "PB", "PBP", "FDVR".  The table is exported as the CSV file *variant_table.csv*.

---

#### 2. Build read count table
The variant table is converted into a read count matrix. In this matrix, rows represent individual samples, and columns correspond to contigs, which include both HPV strains and internal controls. Additional columns, named total_reads and hpv_reads, are included to report the total reads for all contigs and for the HPV strains, respectively.

---

#### 3. Run-to-run scaling of Minimum Read Thresholds
Objective: To ensure consistent and accurate data filtering across different sequencing runs, TypeSeq v2 requires dynamic scaling of minimum read thresholds. This adjustment accounts for variations in sequencing depth and associated noise levels between runs.

##### Why Scaling is Necessary:

Optimal data analysis relies on adjusting filtering parameters to match the unique characteristics of each sequencing run. Scaling of minimum read thresholds is crucial because:
+ Variable Usable Reads: Each sequencing run generates a different total number of usable reads.
+ Sample Load Impact: The number of samples sequenced on a run, relative to the recommended amount, directly affects the average reads per sample. Higher or lower sample counts necessitate corresponding threshold adjustments.
+ Reads Per Sample and Noise Correlation:
  + Higher reads per sample generally correlate with increased background noise levels, requiring higher minimum read thresholds to maintain specificity.
  + Shallower sequencing (lower reads per sample) results in reduced noise, allowing for a reduction in minimum read thresholds without compromising data quality.

##### How to Apply Scaling:

To implement run-to-run scaling for your TypeSeq v2 analysis:
1. Determine Average Reads Per Sample: Calculate the average usable reads per sample for your current sequencing run.
2. Select Scaling Factor: Refer to the "scaling table" (presumably provided elsewhere in your documentation) and identify the appropriate scaling factor based on the calculated average reads per sample.
3. Adjust Minimum Read Thresholds:
  + Locate the min_reads_per_type values within your "pos-neg matrix filtering criteria table."
  + Multiply each min_reads_per_type value by the selected scaling factor.
  + The resulting scaled values will serve as the new minimum read thresholds for each amplicon type in your analysis.

Example:

If your run's average reads per sample was 60,000, and the scaling table indicates a scaling factor of 0.85 for this read depth, then all min_reads_per_type values in your filtering criteria table would be multiplied by 0.85 to set the adjusted minimum read thresholds for each type.

+ Scaling table (pluginMedia/configs/TypeSeq2_Scaling_v1.csv)
```csv
min_avg_reads_boundary,max_avg_reads_boundary,scaling_factor
200000,200000000,2
150000,199999,1.75
125000,149999,1.5
100000,124999,1.25
75000,99999,1
50000,74999,0.85
25000,49999,0.75
10000,24999,0.6
1,9999,0.5
```

---

#### 4. Calculate Per-Sample Positive/Negative (P/N) Cutoff

To establish the matrix of minimum read thresholds for each amplicon (contig) within every sample, two essential vectors are used:

* **Vector A: Sample-Specific Scaling Factor**
    This vector contains the calculated scaling factor unique to each individual sample. For details on how these factors are derived, please refer to the "Run-to-Run Scaling of Minimum Read Thresholds" section (Section 3).

* **Vector B: Baseline Minimum Read Thresholds per Amplicon**
    This vector defines the default minimum read thresholds and percentage cutoffs for each amplicon (contig) type, serving as the foundational values before any sample-specific adjustments. The vector is extracted from the second column of pluginMedia/configs/TypeSeq2_PN-criteria_v1.3.csv.

  + pluginMedia/configs/TypeSeq2_PN-criteria_v1.3.csv   

<center>

| Contig    | Min\_reads\_per\_type | Min\_perc\_per\_type |
|:-----|------:|-----------:|
| ASIC-Low  | 400                   | 0.01                 |
| ASIC-Med  | 400                   | 0.01                 |
| B2M-S2    | 400                   | 0.01                 |
| HPV6      | 500                   | 0.01                 |
| HPV6\_Lin | 500                   | 0.01                 |
| B2M-S     | 400                   | 0.008                |
| ASIC-High | 400                   | 0.005                |
| ...       | ...                   | ...                  |

</center>

* **Calculation of the Minimum Read Threshold Matrix:**

The final matrix, which represents the per-sample minimum read thresholds for each contig, is computed by taking the outer product of Vector A and Vector B. This ensures that the run-specific scaling factor from Vector A is correctly applied to the baseline thresholds of each amplicon defined in Vector B.

$$\text{Min Read Threshold Matrix} = \text{Vector A} \times \text{Vector B}^{\top}$$

The matrix of min read criteria is exported as the CSV file `Scaled_min-filters.csv` following each TypeSeq2 plugin run.

---


#### 5. Assign P/N status for each amplicon in each sample

##### A. Sample-Level Quality Control: *sequencing_qc* and *HPV_qc*

Before assigning P/N status to individual amplicons within a sample, two critical sample-level quality control metrics are evaluated: *sequencing_qc* and *HPV_qc*. The minimum thresholds for these metrics are specified in `pluginMedia/configs/TS2_config.csv` as `min_reads_per_sample` (for total reads) and `min_hpv_reads_per_sample` (for HPV-specific reads), respectively. A sample's *sequencing_qc* is designated "pass" if its total read count is $\ge$ `min_reads_per_sample`; otherwise, it is designated "fail." Similarly, a sample's *HPV_qc* is designated "pass" if its total HPV read count is $\ge$ `min_hpv_reads_per_sample`; otherwise, it is designated "fail."  

+ pluginMedia/configs/TS2_config.csv
  
| hotspot_vcf              | configs/TypeSeq2_Hotspot_v1.2.vcf           |
| ------------------------ | ------------------------------------------- |
| tvc_parameters           | configs/TypeSeq2_Parameters_v1.1.json       |
| reference                | configs/TypeSeq2_Ion_Ref_v1.3.fasta         |
| region_bed               | configs/TypeSeq2_BED_v1.1.bed               |
| lineage_defs             | configs/TypeSeq2_Lineage-defs_v1.2.csv      |
| pn_filters               | configs/TypeSeq2_PN-criteria_v1.3.csv       |
| scaling_table            | configs/TypeSeq2_Scaling_v1.csv             |
| internal_control_defs    | configs/TypeSeq2_Internal-Controls_v1.1.csv |
| barcode_file             | configs/TypeSeq2_plugin-barcodes_v1.csv     |
| grouping_defs            | configs/TypeSeq2_Grouping-defs_v1.csv       |
| control_definitions      | configs/TypeSeq2_Batch-controls_v1.3.csv    |
| overall_qc_defs          | configs/TypeSeq2_Overall-qc-defs_v1.1.csv   |
| min_reads_per_sample     | 5000                                        |
| min_hpv_reads_per_sample | 5000                                        |

If a sample's *sequencing_qc* is "fail," the read counts for all HPV amplicons within that sample are set to 0. Consequently, all HPV types for that sample are assigned a negative status.

##### B. Amplicon-level P/N status

The assignment of a "positive" or "negative" status for each amplicon within a sample is determined by a stringent, dual-criterion filtering process. An amplicon is designated as "positive" only if it simultaneously satisfies two conditions: its absolute read count (depth) must meet or exceed a calculated minimum read threshold specific to that amplicon and sample (as defined in *Scaled_min-filters.csv*), and its relative abundance (read depth divided by total sample reads) must also meet or exceed a defined minimum percentage threshold (as specified in the 3rd column of *TypeSeq2_PN-criteria_v1.3.csv*). If either of these two criteria is not fulfilled, the amplicon is then classified as "negative," indicating it did not pass the quality control measures for confident detection within that sample.

```r
status = ifelse(depth >= min_reads & depth / total_reads >= Min_perc_per_type, "pos", "neg")
```


#### 6. Identify HPV types

#### 7. Refine HPV typing with the internal controls

#### 8. Generate reports