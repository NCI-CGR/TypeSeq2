 # New Dual-Barcode Demultiplexing (DBD) in TypeSeq2

## Introduction

The original **TypeSeq2-SBD** (Single-Barcode Demultiplexing) plugin performed 3' barcode demultiplexing using **Spark/Adam**, which is now outdated. This dependency on outdated code created two major issues:

  * **System Resource Strain:** The use of Spark required a significant amount of RAM, which could cause the plugin to crash due to memory overflow. This issue was reported in [NCI-CGR/TypeSeqHPV\_issues\#84](https://github.com/NCI-CGR/TypeSeqHPV_issues/issues/84).
  * **Maintenance Challenges:** The outdated software dependencies forced the use of old versions of Ubuntu (v16.04), R packages, and TVC (v5.10.1) within the Docker container, making the plugin difficult to maintain.

These issues have been resolved in the new **TypeSeq2-DBD** version by replacing the outdated demultiplexing method with a new feature available in recent Ion Torrent BaseCaller releases. 

-----

## Major Steps in TypeSeq2-DBD

### Ion Torrent Run with DBD Configuration

The Ion Torrent run is configured for dual-barcode demultiplexing (DBD) using specific parameters in the **BaseCaller** command. This configuration ensures that both 5' and 3' barcodes are processed correctly.

```bash
BaseCaller --barcode-filter-minreads 10 --phasing-residual-filter=2.0 --max-phasing-levels 2 --num-unfiltered 1000 --barcode-filter-postpone 1 --wells-normalization on --barcode-auto-config true --end-barcode-list=/results/plugins/scratch/TypeSeq2_end-barcodes_v1.0.csv --end-barcode-separation 1
```

-----

### Generating DBD bam files

The Ion Torrent run still generates BAM files (e.g., `IonXpress_050_rawlib.bam`) demultiplexed by the 5' barcode. However, each alignment in these files now contains a **YK tag** derived from the 3' barcode demultiplexing. The DBD BAM files can be obtained by splitting the original files using this YK tag.

```bash
ls ./*_rawlib.bam | parallel -j 10 'singularity exec --pwd /mnt --bind $(pwd):/mnt docker://biocontainers/bamtools:v2.4.0_cv4 /bin/bash -c "bamtools filter -isMapped true -isPrimaryAlignment true -mapQuality '"'"'>=5'"'"' -in {} | bamtools split -stub bams/{/.} -tag YK"'
```

-----

### Variant Calling

**TVC** (Torrent Variant Caller), which is installed on the Ion Torrent server, is used to call variants from the DBD BAM files. The `parallel` command is utilized to run multiple TVC jobs concurrently, improving processing efficiency.

```bash
parallel  -j 10 --colsep '\t' "samtools index {1}; tvc --output-vcf vcf/{2}.vcf --input-bam {1} --force-sample-name  {2} --input-vcf ${CONFIG}/TypeSeq2_Hotspot_v1.2.vcf --reference ${CONFIG}/TypeSeq2_Ion_Ref_v1.3.fasta --target-file ${CONFIG}/TypeSeq2_BED_v1.1.bed --parameters-file ${CONFIG}/TypeSeq2_Parameters_v1.1.json  --trim-ampliseq-primers  --num-threads 2" :::: bc2_mapping.tsv 2>&1 | tee call_tvc.logs
```

-----

### HPV Typing

The HPV typing workflow, which was originally a **drake** workflow, was rewritten with **R targets**. The updated code is available at [https://github.com/NCI-CGR/TypeSeq2/tree/dual\_barcode](https://github.com/NCI-CGR/TypeSeq2/tree/dual_barcode) and is containerized as `docker://cgrlab/typeseq_dbd:v1.0`.

```bash
singularity exec  --pwd /mnt --bind $(pwd):/mnt --bind $(pwd)/tmp:/tmp --bind ${DIRNAME}/pluginMedia:/user_files --bind ${OFFLOAD_DIR}:/CGF docker://cgrlab/typeseq_dbd:v1.0 /bin/bash -c \
        "cp -r /TypeSeq2/workflow/inst tmp/ && Rscript /TypeSeq2/workflow/TypeSeq2.R --debug no --user_files /user_files/ --offload /CGF/Laboratory/LIMS/drop-box-prod/typeseq2,/CGF/Sequencing/IonTorrent/Offload_Results_Data "
```

-----

### Cleaning Intermediate Files

Finally, all intermediate files are removed from the plugin's run folder to maintain a clean workspace.

```bash
rm -f ./*_rawlib.bam
rm -fr bams
```