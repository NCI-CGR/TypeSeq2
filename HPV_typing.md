

# HPV typing in TypeSeq2

## Introduction
The development of the Human Papillomavirus (HPV) typing workflow has spanned several years at NCI-CGR, yet a complete technical record has not been previously compiled. This document aims to establish a foundational understanding by synthesizing existing documentation and elucidating unrecorded aspects through the reverse engineering of the R source code integral to HPV typing.

### Reference
+ https://github.com/NCI-CGR/TypeSeq2
+ 2021-09_TypeSeq2-Technical-Overview_2_Wei[21].pptx
+ https://github.com/NCI-CGR/TypeSeqHPV_issues/issues
+ https://tracker.nci.nih.gov/browse/CGRDOI-536
  + https://tracker.nci.nih.gov/browse/CGRDOI-534

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

***Scaling table (pluginMedia/configs/TypeSeq2_Scaling_v1.csv)***

| min_avg_reads_boundary | max_avg_reads_boundary | scaling_factor |
| ---------------------- | ---------------------- | -------------- |
| 200000                 | 200000000              | 2              |
| 150000                 | 199999                 | 1.75           |
| 125000                 | 149999                 | 1.5            |
| 100000                 | 124999                 | 1.25           |
| 75000                  | 99999                  | 1              |
| 50000                  | 74999                  | 0.85           |
| 25000                  | 49999                  | 0.75           |
| 10000                  | 24999                  | 0.6            |
| 1                      | 9999                   | 0.5            |

---

#### 4. Calculate Per-Sample Positive/Negative (P/N) Cutoff

To establish the matrix of minimum read thresholds for each amplicon (contig) within every sample, two essential vectors are used:

* **Vector A: Sample-Specific Scaling Factor**
    This vector contains the calculated scaling factor unique to each individual sample. For details on how these factors are derived, please refer to the "Run-to-Run Scaling of Minimum Read Thresholds" section (Section 3).

* **Vector B: Baseline Minimum Read Thresholds per Amplicon**
    This vector defines the default minimum read thresholds and percentage cutoffs for each amplicon (contig) type, serving as the foundational values before any sample-specific adjustments. The vector is extracted from the second column of pluginMedia/configs/TypeSeq2_PN-criteria_v1.3.csv.

***pluginMedia/configs/TypeSeq2_PN-criteria_v1.3.csv*** 
<center>

| Contig    | Min\_reads\_per\_type | Min\_perc\_per\_type |
|:-----|------:|-----------:|
| ...       | ...                   | ...                  |
| ASIC-High | 400                   | 0.005                |
| ASIC-Low  | 400                   | 0.01                 |
| ASIC-Med  | 400                   | 0.01                 |
| B2M-S     | 400                   | 0.008                |
| B2M-S2    | 400                   | 0.01                 |
| HPV6      | 500                   | 0.01                 |
| HPV6\_Lin | 500                   | 0.01                 |

</center>

* **Calculation of the Minimum Read Threshold Matrix:**

The final matrix, which represents the per-sample minimum read thresholds for each contig, is computed by taking the outer product of Vector A and Vector B. This ensures that the run-specific scaling factor from Vector A is correctly applied to the baseline thresholds of each amplicon defined in Vector B.

$$\text{Min Read Threshold Matrix} = \text{Vector A} \times \text{Vector B}^{\top}$$

The matrix of min read criteria is exported as the CSV file `Scaled_min-filters.csv` following each TypeSeq2 plugin run.

---


#### 5. Assign P/N status for each amplicon in each sample

##### A. Sample-Level Quality Control: *sequencing_qc* and *HPV_qc*

Before assigning P/N status to individual amplicons within a sample, two critical sample-level quality control metrics are evaluated: *sequencing_qc* and *HPV_qc*. The minimum thresholds for these metrics are specified in `pluginMedia/configs/TS2_config.csv` as `min_reads_per_sample` (for total reads) and `min_hpv_reads_per_sample` (for HPV-specific reads), respectively. A sample's *sequencing_qc* is designated "pass" if its total read count is $\ge$ `min_reads_per_sample`; otherwise, it is designated "fail." Similarly, a sample's *HPV_qc* is designated "pass" if its total HPV read count is $\ge$ `min_hpv_reads_per_sample`; otherwise, it is designated "fail."  

***pluginMedia/configs/TS2_config.csv***
  
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

##### C. Sample-Level Internal Control Metrics: Assay_SIC, human_control, and overall_qc

Our HPV typing assay incorporates two distinct types of internal controls: a human endogenous control and an assay spiked-in control, both critical for assessing sample quality and assay performance.

###### Human Control (human_control)
Beta-2-microglobulin (B2M) serves as our human housekeeping gene control, with its amplicons, B2M-S and B2M-S2, expected to be consistently positive in all human specimens. The human_control status for each sample is assigned based on the Positive/Negative (P/N) statuses of B2M-S and B2M-S2, as defined within the TypeSeq2_Internal-Controls_v1.1.csv configuration table. For instance, if B2M-S is "pos" but B2M-S2 is "neg," the human_control status will be "pass_low-concentration."

###### Assay Spiked-in Control (Assay_SIC)
We also include a set of assay spiked-in controls (ASICs): ASIC-Low, ASIC-Med, and ASIC-High. These are designed to mimic varying target abundances, with ASIC-Low at 1X abundance, ASIC-Med at 2.5X, and ASIC-High at 10X. The Assay_SIC status is determined by the P/N calls of these three ASICs, also based on the TypeSeq2_Internal-Controls_v1.1.csv table. As an example, Assay_SIC will be assigned "pass_flag-high" if both ASIC-Low and ASIC-Med are "pos" while ASIC-High is "neg."


***The detailed criteria for assigning these internal control statuses are provided in the following table:***
  
| internal_control_code | qc_name       | qc_print               | ASIC-Low | ASIC-Med | ASIC-High | B2M-S | B2M-S2 |
| --------------------- | ------------- | ---------------------- | -------- | -------- | --------- | ----- | ------ |
| Assay_SIC             | Assay_SIC     | pass                   | pos      | pos      | pos       |       |        |
| Assay_SIC             | Assay_SIC     | pass_flag-low          | neg      | pos      | pos       |       |        |
| Assay_SIC             | Assay_SIC     | pass_flag-med          | pos      | neg      | pos       |       |        |
| Assay_SIC             | Assay_SIC     | pass_flag-high         | pos      | pos      | neg       |       |        |
| Assay_SIC             | Assay_SIC     | failed_med-high        | pos      | neg      | neg       |       |        |
| Assay_SIC             | Assay_SIC     | failed_low-high        | neg      | pos      | neg       |       |        |
| Assay_SIC             | Assay_SIC     | failed_low-med         | neg      | neg      | pos       |       |        |
| Assay_SIC             | Assay_SIC     | failed_all             | neg      | neg      | neg       |       |        |
| specimens             | human_control | pass                   |          |          |           | pos   | pos    |
| specimens             | human_control | pass                   |          |          |           | pos   | neg    |
| specimens             | human_control | pass_low-concentration |          |          |           | neg   | pos    |
| specimens             | human_control | failed_to_amplify      |          |          |           | neg   | neg    |


###### Overall QC status: *overall_qc*

The ultimate overall_qc status for each sample is derived from a comprehensive evaluation that integrates the human_control and Assay_SIC metrics. This integrated assessment follows the specific criteria outlined in the TypeSeq2_Overall-qc-defs_v1.1.csv configuration table:

| OVERALL_QC | sequencing_qc | human_control | total_HPV_reads | Assay_SIC |
| ---------- | ------------- | ------------- | --------------- | --------- |
| pass       | pass          | pass          | fail            | pass      |
| pass       | pass          | pass          | pass            | pass      |
| pass       | pass          | fail          | pass            | pass      |

If the overall_qc status for a sample is determined to be "failed," the P/N (Positive/Negative) statuses for all HPV amplicons within that specific sample will be re-assigned to "NA" (Not Applicable).

---

#### 6. Identify P/N statues of HPV types
Human Papillomaviruses (HPVs) are categorized into a hierarchical system: types, genetically distinct variants with >10% L1 gene sequence difference, which are classified as high-risk (e.g., HPV16, HPV18) or low-risk (e.g., HPV6, HPV11) based on their association with cancer or benign conditions. Within a type, lineages (1.0-10.0% L1 difference; e.g., HPV16-A and HPV16-B) represent further genetic diversity, sometimes linked to geographical distribution or subtle clinical variations. The finest classification level, sublineages (<1.0% L1 difference within a lineage; e.g., HPV16-A1), provide even higher resolution for epidemiological and evolutionary studies. For more detailed information, you can refer to [resources from the Centers for Disease Control and Prevention (CDC)](https://www.cdc.gov/hpv/index.html) or the International HPV Reference Center.

In our analysis, an HPV type is assigned as "positive" in a sample if at least one corresponding amplicon associated with that type is found to be "positive" (as per the P/N cutoff calculation). An important exception applies to HPV16 and HPV18: for these specific high-risk types, a "positive" assignment requires the detection of at least two "positive" amplicons in the sample.

The P/N (Positive/Negative) matrix, along with manifest details and sample QC metrics, are comprehensively exported to the CSV file named *pn_matrix_for_groupings*.

---

#### 7. Identify P/N statues of HPV lineages/sublineages

The identification of specific HPV lineages and sublineages in a sample involves a rigorous evaluation of individual genetic variants (markers). This process begins by assigning a quality flag, *qc_reason*, to each HPV variant based on predefined criteria in the *TypeSeq2_Lineage-defs_v1.2.csv* table.


**Assigning the qc_reason Flag:**
For each candidate variant that could define a lineage or sublineage, the *qc_reason* flag records its status during a series of quality control checks. An empty *qc_reason* string initially indicates no issues, but if a check fails, a specific reason is appended.

+ Individual quality criteria:
  + *min_coverage_pos*: SRF >= min_coverage_pos
  + *min_coverage_neg*: SRR >= min_coverage_neg
  + *min_allele_coverage_pos*: SAF >= min_allele_coverage_pos
  + *min_allele_coverage_neg*: SAR >= min_allele_coverage_neg
  + *min_qual*: QUAL >= min_qual
  + *max_alt_strand_bias*: STB <= max_alt_strand_bias
  + *min_freq*: AF >= min_freq
  + *max_freq:: AF <= max_freq
+ *Pass* status:
    + Meaning: his is the ideal status. It signifies that the genetic marker successfully passed all internal quality control criteria. This means the reads covering the marker were sufficient and balanced, the variant call quality was high, its allele frequency was within the acceptable range, and there were no indications of technical artifacts. A marker with a "Pass" status is considered reliable evidence for the presence of its associated lineage. 

***The criteria for these flags are sourced from *TypeSeq2_Lineage-defs_v1.2.csv*:***

| Chr        | classification | Lineage_ID | Base_num | Base_ID | vcf_variant | allele | min_coverage_pos | min_coverage_neg | min_allele_coverage_pos | min_allele_coverage_neg | min_qual | min_freq | max_freq | max_alt_strand_bias |
|------------|----------------|------------|----------|---------|-------------|--------|------------------|------------------|-------------------------|-------------------------|----------|----------|----------|---------------------|
| HPV6_Lin   | lineage        | HPV6_A     | 62       | T       | C           | alt1   | 0                | 0                | 10                      | 0                       | 4        | 0.05     | 1        | 1                   |
| HPV6_Lin   | lineage        | HPV6_B     | 62       | T       | G           | alt1   | 0                | 0                | 10                      | 0                       | 4        | 0.05     | 1        | 1                   |
| HPV16      | lineage        | HPV16_A    | 112      | G       | C           | alt1   | 0                | 0                | 10                      | 0                       | 4        | 0.05     | 1        | 1                   |
| HPV16_Lin4 | lineage        | HPV16_B    | 57       | T       | C           | alt1   | 0                | 0                | 10                      | 0                       | 4        | 0.05     | 1        | 1                   |
| HPV16_Lin4 | lineage        | HPV16_B    | 117      | C       | A           | alt1   | 0                | 0                | 10                      | 0                       | 4        | 0.05     | 1        | 1                   |
| HPV16_Lin4 | lineage        | HPV16_B    | 152      | C       | T           | alt1   | 0                | 0                | 10                      | 0                       | 4        | 0.05     | 1        | 1                   |
| HPV16_Lin2 | lineage        | HPV16_C    | 72       | A       | C           | alt1   | 0                | 0                | 10                      | 0                       | 4        | 0.05     | 1        | 1                   |
| HPV11_Lin  | sublineage     | HPV11_A1   | 47       | A       | G           | alt1   | 0                | 0                | 10                      | 0                       | 4        | 0.05     | 1        | 1                   |
| HPV11_Lin  | sublineage     | HPV11_A2   | 47       | A       | T           | alt1   | 0                | 0                | 10                      | 0                       | 4        | 0.05     | 1        | 1                   |

**Final Lineage/Sublineage P/N Assignment:**

An HPV lineage or sublineage is ultimately assigned a "positive" status only if two conditions are met:
1.  All related genetic variants (markers) that define that specific lineage or sublineage, as listed in `TypeSeq2_Lineage-defs_v1.2.csv`, must have a "Pass" status for their `qc_reason`.
2.  The corresponding overarching HPV type (e.g., HPV16 for HPV16-A lineage) must also have been assigned a "positive" P/N status in that sample during earlier filtering steps.

This multi-layered filtering ensures that reported lineage and sublineage calls are highly reliable, based on both the precise genetic markers and the overall quality of the HPV type detection in the sample.

The allele frequency (AF) assigned to a detected HPV lineage or sublineage is determined by the minimum allele frequency observed across all the genetic variants (markers) that collectively provide evidence for its presence. If a lineage or sublineage is not detected or fails to meet the stringent quality control criteria, its assigned AF will be 0. This calculated AF, reflecting the lowest supporting variant frequency and indicating the overall confidence of detection for each lineage/sublineage, is then meticulously exported to the *lineage_for_report* file.

---

#### 8. Quality control by batch control samples

To ensure the integrity and reliability of every assay plate, a set of batch control samples with known HPV typing statuses are included. These controls provide vital batch-level performance information, monitoring critical aspects of the assay process.

**Batch-Level Performance Monitoring:**
These controls are placed in independent wells, separate from the patient samples, and are designed to assess the overall performance of the assay at a batch level. They primarily control for the quality of **reagents**, the efficacy of **master mixes**, and the proper functioning of **equipment** (with the exception of individual well pipetting). It's important to note that these controls generally **do not control for** pipetting errors (e.g., missed or inaccurate transfers in individual wells) or the inherent quality of individual patient specimens.

**EXTRACTION/LYSIS BATCH CONTROLS**

These controls are specifically designed to monitor the efficiency and cleanliness of the nucleic acid extraction and lysis processes for the entire batch.

* **Positive Control (HPV16/18+ cell lines):** These controls consist of cell lines known to contain HPV16 and/or HPV18. They confirm that the DNA extraction, lysis, and subsequent steps are successfully recovering and preparing target DNA.
* **Negative Extraction Control (clean media):** This control utilizes clean media as its input material for the entire extraction process. Its purpose is to detect any contamination introduced during the DNA extraction and handling phases, ensuring no exogenous DNA is present from the start.
* **Empty (for Negative Assay Control):** This typically refers to an empty well or a well containing only buffer, acting as a negative control for the entire assay process to detect any carry-over contamination within the assay itself, outside of extraction.

**ASSAY BATCH CONTROLS**

These controls focus on verifying the performance of the downstream assay steps, including amplification (PCR) and detection.

* **Positive Assay Controls (plasmids and synthetic DNA fragments):** These controls are engineered DNA constructs (plasmids or synthetic fragments) containing specific HPV sequences. They are introduced at various stages of the assay to verify the amplification and detection efficiency of particular HPV targets.
* **Negative Assay Controls (no-template and human+ HPV-):**
    * **No-template assay control (PCR negative):** This control contains all reagents required for PCR but no DNA template. It monitors for contamination within the PCR reagents or the amplification setup, ensuring no non-specific amplification occurs.
    * **Human+ HPV- (human positive, HPV negative) control:** This control contains human DNA that has been confirmed to be negative for all targeted HPV types. It serves to check for the specificity of the HPV detection, ensuring that the presence of human DNA does not lead to false-positive HPV signals.

In the quality control process for batch control samples, their expected amplicon statuses are defined in the TypeSeq2_Batch-controls_v1.3.csv table. This table specifies whether an amplicon is anticipated to be "pos" (positive), "neg" (negative), or "either." The "either" status acts as a wildcard, meaning the amplicon's P/N call can be either positive or negative without impacting the control's pass/fail determination, and is consequently ignored in the subsequent analysis of that specific control's performance.

To evaluate these controls, the actual assay results are fuzzy matched with the *TypeSeq2_Batch-controls_v1.3.csv* table. This matching uses a flexible approach where the Owner_Sample_ID from your assay results is considered a match for a Control_Code in the definition table if the Owner_Sample_ID contains the Control_Code string, and this comparison is case-insensitive. For example, an Owner_Sample_ID like "SampleA_ntc" would successfully match a Control_Code of "NTC".  Overall, there are two types of controls defined in *TypeSeq2_Batch-controls_v1.3.csv*: "pos" and "neg".   The observed results for each control sample's amplicons are compared against predefined expectations (allowing for "pos," "neg," or "either" outcomes) and then consolidates these individual checks into an overall "pass" or "fail" verdict for each control, along with specific reasons for any failures. This ensures the reliability of the entire assay batch.

***TypeSeq2_Batch-controls_v1.3.csv***
| Control_Code                        | Control_type | qc_name        | B2M-S  | B2M-S2 | HPV6 | HPV11 | HPV13 | HPV16 | HPV18 | HPV26 | … |
| ----------------------------------- | ------------ | -------------- | ------ | ------ | ---- | ----- | ----- | ----- | ----- | ----- | - |
| SiHa-HeLa                           | pos          | control_result | either | either | neg  | neg   | neg   | pos   | pos   | neg   | … |
| C0112                               | pos          | control_result | either | either | neg  | neg   | neg   | pos   | pos   | neg   | … |
| Lysis-NTC                           | neg          | control_result | neg    | neg    | neg  | neg   | neg   | neg   | neg   | neg   | … |
| PCR-NTC                             | neg          | control_result | neg    | neg    | neg  | neg   | neg   | neg   | neg   | neg   | … |
| NTC                                 | neg          | control_result | neg    | neg    | neg  | neg   | neg   | neg   | neg   | neg   | … |
| hg19                                | pos          | control_result | either | pos    | neg  | neg   | neg   | neg   | neg   | neg   | … |
| LOW_6_30_33_39_43_83_84_90_HIGH_69  | pos          | control_result | either | either | pos  | neg   | neg   | neg   | neg   | neg   | … |
| LOW_26_32_42_45_51_67_72_82_HIGH_30 | pos          | control_result | either | either | neg  | neg   | neg   | neg   | neg   | pos   | … |
| LOW_16_44_52_53_69_71_87_89_HIGH_32 | pos          | control_result | either | either | neg  | neg   | neg   | pos   | neg   | neg   | … |
| …                                   | …            | …              | …      | …      | …    | …     | …     | …     | …     | …     | … |


The `Control_type`, `control_result`, and `control_fail_code` for each batch control sample are consolidated and exported to individual CSV files, named `{AssayBatch}-control_results.csv`, providing a clear and concise summary of the quality control outcomes for each assay batch.

---


#### 9. Generate reports

##### {AnalysisName}.full.csv
Based on the R code provided, the `{AnalysisName}.full.csv` file is a comprehensive output that combines various pieces of information about each sample, including manifest details, read counts, and the P/N (Positive/Negative) statuses for HPV types and internal controls.

Here's an explanation of each column you would find in the `{AnalysisName}.full.csv` file:

* **Project**: The overall project identifier to which the sample belongs, typically from your manifest.
* **Assay\_Batch\_Code**: A code identifying the specific batch in which the assay was processed.
* **Assay\_Plate\_Code**: A code identifying the specific assay plate on which the sample was run.
* **Assay\_Well\_ID**: The specific well identifier on the assay plate where the sample was located.
* **[any\_of(SAMPLE\_ID)]**: This represents a column (or columns) from your manifest that serves as the primary sample identifier. The exact column name will depend on your `SAMPLE_ID` variable, but it's typically a unique ID for the biological sample.
* **Owner\_Sample\_ID**: Another identifier for the sample, likely originating from the sample owner or submission.
* **barcode**: The unique barcode sequence used to identify the sample during sequencing.
* **total\_reads**: The total number of raw sequencing reads obtained for that sample.
* **HPV reads**: The total number of reads that successfully mapped to any HPV amplicon.
* **Control**: A logical indicator (TRUE/FALSE) specifying whether the sample is identified as an assay control (e.g., positive or negative controls defined in your pipeline).
* **Num\_Types\_Pos**: The count of HPV types that were assigned a "positive" P/N status in that sample.
* **Overall\_qc**: The final quality control status for the entire sample (e.g., "pass" or "failed"), which is a combined evaluation of internal control metrics.
* **Sequencing\_qc**: The quality control status related specifically to the sequencing performance for that sample.
* **Human\_Control**: The P/N status of the human internal control (e.g., B2M), indicating the quality of the human DNA in the sample.
* **Assay\_SIC**: The P/N status of the assay spiked-in control, assessing the overall assay performance.
* **Type**: This column dynamically lists each individual HPV type (e.g., HPV16, HPV18, HPV6) or internal control amplicon (e.g., B2M-S, ASIC-Low) for which data is reported. Because this file combines different types into long format, you'll see multiple rows for each `barcode`, one for each `Type`.
* **Call**: The P/N (Positive/Negative) status assigned to the specific `Type` in that row for that sample.
* **Reads**: The raw read count (`depth`) specifically for the `Type` (HPV amplicon or internal control amplicon) in that row.
* **% of Total Reads**: The percentage of `Reads` for that specific `Type` relative to the `total_reads` for the sample (Reads / Total Reads \* 100).
* **% of Total HPV Reads**: The percentage of `Reads` for that specific `Type` relative to the `HPV reads` for the sample (Reads / HPV Reads \* 100). This column will be `NA` for internal control amplicons (`CTRL_CONTIGS`) as they are not considered HPV types.
* **LIMS\_Sample\_ID**: This column is initialized as `NA` in this code, suggesting it might be a placeholder for future integration with a Laboratory Information Management System (LIMS) ID, or is not populated by this specific analysis step.

In summary, the `*.full.csv` file provides a detailed, row-by-row breakdown for each sample and each specific HPV type/amplicon, integrating metadata, read counts, and all relevant quality control and P/N statuses to offer a complete picture of the assay results.

##### {AnalysisName}.laboratory.csv

The **`{AnalysisName}.laboratory.csv`** file is a specialized report designed for clinical settings, serving as a focused subset of the more comprehensive `{AnalysisName}.full.csv` output.

Specifically, this file contains **only the rows corresponding to control samples**. This means it excludes all patient samples and exclusively presents the data for internal controls (such as positive controls, negative controls, human controls, and assay spiked-in controls) that were run alongside the patient samples. All the columns present in the `{AnalysisName}.full.csv` (e.g., manifest details, read counts, P/N statuses for HPV types and internal controls, and various QC metrics) are retained in this subset, providing a complete picture of the performance of the controls within the specific assay run. This focused report is crucial for laboratories to quickly review and verify the quality and validity of their experimental run by checking the expected performance of the control samples.