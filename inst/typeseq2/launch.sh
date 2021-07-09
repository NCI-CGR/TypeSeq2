#!/bin/bash
set -x
# TypeSeq2 HPV
VERSION="2.2107.0906"
#autorundisable
echo Pipeline version $VERSION

cp ../../*.bam ./
cp ../../raw_peak_signal ./
cp ../../sigproc_results/analysis.bfmask.stats ./
cp ../../basecaller_results/BaseCaller.json ./
cp ../../basecaller_results/datasets_basecaller.json ./
cp ../../basecaller_results/ionstats_tf.json ./
cp ../../ionstats_alignment.json ./


singularity exec --bind --bind $(pwd):/mnt --bind /mnt:/user_files  /home/ionadmin/test_singularity_Amulya/amulya.sif \
        Rscript /TypeSeqHPV2/workflows/TypeSeq2.R \
        --is_torrent_server yes \
        --config_file config_file.csv \
        --barcode_file barcodes.csv \
        --control_definitions control_defs.csv \
        --grouping_defs grouping_defs.csv \
        --cores 22 \
        --manifest manifest.csv \
        --ram 80G \
        --tvc_cores 4

rm *rawlib.bam
