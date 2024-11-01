
# New TypeSeq2 plugin development for Dual-Barcode Demultiplexed Ion Torrent run

## Introduction
One of the essential components in the original TypeSeq2 plugin is 3`-barcode demultiplexing, which is accomplished using [adam/spark developed by David](https://github.com/NCI-CGR/TypeSeq2/blob/master/inst/methylation/demux_3prime_barcode_adam.scala).  The solution requires lots of memory to process the big data in parallel, causing memory overflow sometimes. Besides, the old library/system also blocks new updates from IonTorrent and R packages. 

Recently, dual-barcode demultiplexing (DBD) becomes available in Ion Torrent *BaseCaller*.  In this study, we explored to apply DBD solution into our TypeSeq2 plugin development so as to make this plugin more efficient.

--- 

## Methods
### The configuration of the 3`-barcode sequence file
The 3`-barcode sequence file is required for DBD.  After some trials, we started to use [TypeSeq2_end-barcodes_v0.1.csv](./data/TypeSeq2_end-barcodes_v0.1.csv) for testing. 

### IonTorrent runs for testing
For the testing, several IonTorrent runs were generated:
+ SBD-TypeSeq2: Single-barcode demultiplexed (SBD) run processed by the TypeSeq2 plugin.
  + http://10.133.136.76/report/256/
+ DBD: DBD run using the duplicated samples.
  + http://10.133.136.76/report/254/
+ SBD-DBD_v0.1: SBD run reanalyzed by DBD with TypeSeq2_end-barcodes_v0.1.csv.
  + http://10.133.136.76/report/266/

### Variant call on the DBD data.
We manually call variants from the DBD data. First, we split the DBD bam files by the ***YK*** tag.  Then, we call variants using *tvc* and save the output in the same way as the TypeSeq plugin using a Perl script.


```bash
cd /results/analysis/output/Home/T00064577_PC_NP0580-TS18_TS2B0000613_DualBCDev_v.02_271/plugin_out/test

### Split bam files
mkdir bam/

time ls ../../*.bam | parallel -j 10 ' samtools view -b -q 4 {} | bamtools split -in - -stub bam/{/.} -tag "YK" '

real    11m57.738s
user    136m4.567s
sys     1m52.537s

ls -al bam | head 
total 32881580
drwxr-xr-x 2 ionadmin docker     69632 Nov  1 11:50 .
drwxr-xr-x 8 ionadmin docker      4096 Nov  1 11:33 ..
-rw-r--r-- 1 ionadmin docker 102178478 Nov  1 11:45 IonXpress_049_rawlib.TAG_YK_AACTGACGAC.bam
-rw-r--r-- 1 ionadmin docker 108212213 Nov  1 11:45 IonXpress_049_rawlib.TAG_YK_ACGTGAGTGTTC.bam
-rw-r--r-- 1 ionadmin docker  97201131 Nov  1 11:45 IonXpress_049_rawlib.TAG_YK_ACTCTAACGAC.bam
-rw-r--r-- 1 ionadmin docker    339838 Nov  1 11:45 IonXpress_049_rawlib.TAG_YK_ACTCTAGATGAAC.bam
-rw-r--r-- 1 ionadmin docker 156497354 Nov  1 11:45 IonXpress_049_rawlib.TAG_YK_ACTCTGTAAC.bam
-rw-r--r-- 1 ionadmin docker    352220 Nov  1 11:45 IonXpress_049_rawlib.TAG_YK_ACTGAGTATC.bam
-rw-r--r-- 1 ionadmin docker  42552842 Nov  1 11:45 IonXpress_049_rawlib.TAG_YK_ACTTGTAGTC.bam


### Map the bam files to the target VCF file
perl /results/analysis/output/Home/Auto_user_Bender-122-DualBCDev_T00064577_NP0580-TS18_TS2B0000613_288_254/plugin_out/test/scripts/call_TVC.pl bam /results/analysis/output/Home/Auto_user_Bender-123-T00064577_PC_NP0580-TS18_TS2B0000613_287_256/plugin_out/TypeSeq2_out.307/manifest.csv /results/plugins/scratch/TypeSeq2_end-barcodes_v0.2.csv  > YK2barcode_hq.tab

head -n 3 YK2barcode_hq.tab
bam_hq/IonXpress_049_rawlib.TAG_YK_AACTGACGAC.bam       A49P10
bam_hq/IonXpress_049_rawlib.TAG_YK_ACGTGAGTGTTC.bam     A49P14
bam_hq/IonXpress_049_rawlib.TAG_YK_ACTCTAACGAC.bam      A49P13

### Call Variants and save to vcf/
mkdir vcf/

time parallel -j 5 --colsep '\t' 'samtools index {1}; tvc --output-vcf vcf/{2}.vcf --input-bam {1} --force-sample-name  {2} --input-vcf /results/plugins/TypeSeq2/pluginMedia/configs/TypeSeq2_Hotspot_v1.2.vcf --reference TypeSeq2_Ion_Ref_v1.3.fasta --target-file /results/plugins/TypeSeq2/pluginMedia/configs/TypeSeq2_BED_v1.1.bed --parameters-file /results/plugins/TypeSeq2/pluginMedia/configs/TypeSeq2_Parameters_v1.1.json  --trim-ampliseq-primers  --num-threads 2' :::: YK2barcode_hq.tab 

real    16m45.384s
user    100m17.426s
sys     15m13.956s

ls -al vcf/ | head
total 31964
drwxr-xr-x 2 ionadmin docker 36864 Oct 29 10:09 .
drwxr-xr-x 8 ionadmin docker  4096 Nov  1 11:33 ..
-rw-r--r-- 1 ionadmin docker 13740 Nov  1 13:49 A49P01_filtered.vcf
-rw-r--r-- 1 ionadmin docker 68124 Nov  1 13:50 A49P01.vcf
-rw-r--r-- 1 ionadmin docker 13740 Nov  1 13:49 A49P02_filtered.vcf
-rw-r--r-- 1 ionadmin docker 68630 Nov  1 13:49 A49P02.vcf
-rw-r--r-- 1 ionadmin docker 13740 Nov  1 13:49 A49P03_filtered.vcf
-rw-r--r-- 1 ionadmin docker 70043 Nov  1 13:49 A49P03.vcf
-rw-r--r-- 1 ionadmin docker 13740 Nov  1 13:49 A49P04_filtered.vcf
```

### Read supports from DBD are much lower than those from SBD-TypeSeq2
Ideally, HPV variant call results should be identical with comparable read support between the runs *DBD* and *SBD-TypeSeq2*. We noticed that variant genotypes are similar but read supports from DBD is much lower compared to SBD-TypeSeq2.  The lower read support was also detected in the run SBD-DBD_v0.1, which cannot be accounted by system errors.

### Adapter sequences and reference sequences
We reviewed the barcoded primer sequences for IonTorrent sequencing: [TypeSeq2_Barcoded-Primers-Order-List_v0.2.3.xlsx](data/TypeSeq2_Barcoded-Primers-Order-List_v0.2.3.xlsx).  We found that the correct 3\`-adapter sequence is *TTAGTAAGATAATA*, not *GAT* as specified in TypeSeq2_end-barcodes_v0.1.csv.  Besides, it is also noticed that the references sequences used by TypeSeq2 are modified: the actual references are flanked by 5\`-/3\`- adapter sequences.  In another word, there is no need to remove adapter sequences during 3\`-barcode demultiplexing.  

Accordingly, we dropped adapter sequences from TypeSeq2_end-barcodes_v0.1.csv and generated a new configuration file: [TypeSeq2_end-barcodes_v0.2.csv](data/TypeSeq2_end-barcodes_v0.2.csv).

+ Example of the reference sequences.
```bash
>ASIC-Low
ATAAATACAAGTTACTCTAA-CCCTAGCATACAAGCATACTCAGTCCCTTATGTTATTCCGGATAAATTCATTTCCCTCATTCACAAGTGCGAAGTCTATACTGATATATGAATGCAATCATACTTTAGATTCCATTAGAGTATCGTAGGATCACAGGCTCATAGAT-TAGTAAGATAATA
```

### New IonTorrent run *SBD-DBD_v0.2*
We also made a new IonTorrent run *SBD-DBD_v0.2*: 
+ SBD-DBD_v0.2: SBD run reanalyzed by DBD with TypeSeq2_end-barcodes_v0.2.csv.
  + http://bender2/report/271/

We compiled two variant tables in CSV files: 
+ [SBD-TypeSeq2](data/PRD.variant_table.csv)
+ [SBD-DBD_v0.2](data/variant_table.csv)
  
Comparing the two variant tables, we found that most variants have slightly higher DP in SBD-DBD_v0.2 than SBD-TypeSeq2 (see the [plot](data/R01.DP_scatter.pdf)).  So the use of TypeSeq2_end-barcodes_v0.2.csv did remediate the previous issue.

However, there are still about 8.3% of the variants with DP ratio > 3/2 or < 2/3 between the two runs.  Those outliers are not enriched with any particular 5\`- or 3\`-barcodes, neither with any particular reference sequences. Therefore, the cause of this discrepancy is not certain yet.  



We may continue the downstream data analysis and hopefully that the reduced discrepancy may not affect HPV typing results.
