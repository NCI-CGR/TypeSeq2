#!/bin/bash
set -x
# TypeSeq2 HPV
VERSION="2.1.1.2"
#autorundisable
echo Pipeline version $VERSION

ln ../../*.bam ./

mkdir tmp

singularity exec  --bind $(pwd):/mnt --bind $(pwd)/tmp:/tmp --bind /mnt:/user_files /mnt/DCEG/CGF/Sequencing/Analysis/Research/TypeSeq_dev/typeseqhpv2_v1.sif \
        Rscript /TypeSeqHPV2/workflows/TypeSeq2.R \
        --is_torrent_server yes \
        --config_file config_file.csv \
        --barcode_file barcodes.csv \
        --control_definitions control_defs.csv \
        --grouping_defs grouping_defs.csv \
        --cores 22 \
        --manifest manifest.csv \
        --ram 24G \
        --tvc_cores 4

rm *rawlib.bam
