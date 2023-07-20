#' ---
#' title: TypeSeq2 HPV Plugin
#' author: " "
#' date: "`r format(Sys.time(), '%d %B, %Y')`"
#' output:
#'  html_document
#' params:
#'    is_clinical: false
#' ---


#+ load packages, echo=FALSE, include = FALSE
library(tidyverse)
library(stringr)
library(jsonlite)
library(scales)
sessionInfo()


#+ determine run type, echo=FALSE
plugin_json = fromJSON(file("/mnt/startplugin.json"), simplifyDataFrame = TRUE, simplifyMatrix = TRUE)

run_type = plugin_json$runplugin$run_type

#' # {.tabset}

#+ laboratory use, echo=FALSE, results='asis', eval=params$is_clinical
cat("


## Laboratory Use

")

if (run_type!="thumbnail"){

cat('

<a href="./TypeSeq2HPV_laboratory_report.pdf" target="_blank">Laboratory Report</a>

[archive of outputs for laboratory use](./TypeSeq2_outputs.laboratory.zip)


')
}else{
cat('

Thumbnail data insufficient for TypeSeq2 analysis.

Please see full report.

')
}

#+ full report, echo=FALSE, results='asis', eval=TRUE
cat("

## Analysis Output

")

if (run_type!="thumbnail"){
    if (params$is_clinical) {
        cat("

[archive of encrypted outputs](./TypeSeq2_outputs.zip.pgp)


")
    }else{
        cat('

<a href="./TypeSeq2HPV_QC_report.pdf" target="_blank">QC Report</a>

[archive of outputs](./TypeSeq2_outputs.zip)

')

    }
}else{
cat('

Thumbnail data insufficient for TypeSeq2 analysis.

Please see full report.

')
}
