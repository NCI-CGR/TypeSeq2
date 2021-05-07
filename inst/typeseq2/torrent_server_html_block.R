#' ---
#' title: TypeSeq2 HPV Plugin
#' author: " "
#' date: "`r format(Sys.time(), '%d %B, %Y')`"
#' output:
#'  html_document
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
#' ## Analysis Output

#+ full run, echo=FALSE, results='asis', eval=run_type!="thumbnail"

cat('

<a href="./TypeSeqHPV_QC_report.pdf" target="_blank">QC Report</a>

[archive of outputs](./TypeSeq2_outputs.zip)


')

#+ thumbnail run, echo=FALSE, results='asis', eval=run_type=="thumbnail"
cat('

Thumbnail data insufficient for methylation analysis.

Please see full report.

')
