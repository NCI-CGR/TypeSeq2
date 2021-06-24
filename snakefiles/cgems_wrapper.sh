#/bin/bash

mkdir -p /CGF/Sequencing/Analysis/Research/TypeSeq_dev/mks_dev/TypeSeqHPV2/snakefiles/logs

snakemake \
    --cluster "qsub -pe by_node {threads} \
    -q all.q,research.q -V -j y \
    -o /CGF/Sequencing/Analysis/Research/TypeSeq_dev/mks_dev/TypeSeqHPV2/snakefiles/logs" \
    --jobs 500 --latency-wait 120 \
    --keep-going \
    #--rerun-incomplete \
