#' ---
#' params:
#'    is_clinical: false
#'    for_batch: false
#'    batch_id: "Batch"
#' title: "TypeSeq2 HPV Report for `r params$batch_id`"
#' author: " "
#' date: "`r format(Sys.time(), '%d %B, %Y')`"
#' output:
#'  pdf_document:
#'     toc: true
#'     toc_depth: 3
#' classoption: landscape
#' html_document:
#'    toc: true
#'    theme: united
#' ---

#' ## Run Metadata

#+  get run metadata, results='asis', echo=FALSE
# startplugin.json
is_clinical <- params$is_clinical

get_run_metadata_safe <- possibly(get_run_metadata, otherwise = data.frame())

startPluginDf = get_run_metadata_safe(args_df, ifelse(!params$for_batch & !is_clinical, get_output_prefix(), NULL))


s2n_caption <- "   
To calculate the signal (green line) for each HPV target, the average read counts was calculated for the 10 samples which had the fewest number of reads for that target but were called positive (read counts above the minimum reads threshold). To calculate the noise (blue line) for each HPV target, the average read counts was calculated for the 10 samples which had the most reads for that target but were called negative (below the minimum reads threshold).   

Occasionally the noise line may cross the red positive call threshold. This may occur if one or more samples in the group of 10 was called negative because it failed one of the other thresholds or QC criteria (for example, the minimum type read percentage) and was called negative. In those cases, the average reads value may be skewed.   

The most desirable result is a large difference between the noise and the signal, which shows decisive differentiation between positive and negative signal strength (which for this assay is sequencing reads).
Note that the y-axis values are on a log10 scale. A gap in the signal line denotes a lack of positive samples."

pie_caption <- '  
The three sections of the pie chart represent the proportions of samples (excluding assay controls) within the project (one chart per project will be generated). The groupings are HPV-negative (“HPV_neg”), positive for low-risk types only (lrHPV_pos), and positive for high risk types (with/without low risk types also; “hrHPV_pos”).  

For this chart, high risk types are considered to be HPV16, 18, 31, 33, 35, 39, 45, 51, 52, 56, 58, 59, and 68.'

#' \newpage
#' ## SAMPLE Results Summary

#+ SAMPLE Results Summary, echo=FALSE, message=FALSE, warning=FALSE, fig.align = "center", results='asis', eval=TRUE
sample_summary_safe <- possibly(sample_summary, otherwise =  data.frame())
#samples_only_matrix_results.csv

temp = sample_summary_safe(samples_only_for_report, ifelse(!params$for_batch & !is_clinical, get_output_prefix(), NULL) )

#' \newpage
#' ## PLATE Results Summary

#+ PLATE Results Summary, echo=FALSE, message=FALSE, warning=FALSE, fig.align = "center", results='asis', eval=TRUE
plate_summary_safe <- possibly(plate_summary, otherwise = data.frame())
#needs controls only and samples only matrix
temp = plate_summary_safe(samples_only_for_report, is_clinical, for_batch=params$for_batch, output_prefix=ifelse(!params$for_batch & !is_clinical, get_output_prefix(), NULL) )


#' \newpage
#' ## Control Summary

#+ Control summary, echo=FALSE, message=FALSE, warning=FALSE, fig.align = "center", results='asis', eval=TRUE
Internal_control_summary_safe <- possibly(Internal_control_summary2,otherwise = data.frame())
temp = Internal_control_summary_safe(detailed_pn_matrix_for_report,manifest,control_for_report,specimen_control_defs, params$for_batch, ifelse(!params$for_batch & !is_clinical, get_output_prefix(), NULL))




#+ Counts and Percent Types Positive by Project, echo=FALSE, message=FALSE, warning=FALSE, out.width = '200%', fig.align = "center", eval=!is_clinical, results='asis'
#samples_only matrix
cat("\n\n\\pagebreak\n")
cat("## Counts and Percentage of Types Positive by Project\n\n") 
percent_positive_histogram_safe <- possibly(TypeSeq2::percent_positive_histogram, otherwise = data.frame())

temp = percent_positive_histogram_safe(samples_only_for_report, ifelse(!params$for_batch & !is_clinical, get_output_prefix(), NULL))

#+ coinfection rate histogram, echo=FALSE, message=FALSE, warning=FALSE, out.width = '200%', fig.align = "center",  eval=!is_clinical, results='asis'
#samples only matrix
# cat("\\newpage\n")
cat("\n\n\\pagebreak\n")
cat("## Coinfection Rate Histogram\n\n")

coinfection_rate_histogram_safe <- possibly(coinfection_rate_histogram,
                                            otherwise = data.frame())

temp = coinfection_rate_histogram_safe(samples_only_for_report, ifelse(!params$for_batch & !is_clinical, get_output_prefix(), NULL))

#' \newpage
#' ## Signal-to-Noise Plot
#+ signal to noise plot, echo=FALSE, message=FALSE, warning=FALSE, fig.width=20, fig.height=9, fig.align = "center", results='asis'
#scaling file and simple pn matrix and read counts matrix
signal_to_noise_plot_safe <- possibly(TypeSeq2::signal_to_noise_plot, otherwise = data.frame())
temp = signal_to_noise_plot_safe(read_count_matrix_report,detailed_pn_matrix_for_report,pn_filters)

cat(s2n_caption)

#+ HPV Status Circle Plot, echo=FALSE, message=FALSE, warning=FALSE, out.width = '200%', fig.align = "center", eval=!is_clinical, results='asis'
# samples only matrix
cat("\n\n\\pagebreak\n")
cat("## Distribution of Sample HPV Positivity by Project\n\n")
hpv_status_circle_plot_safe <- possibly(TypeSeq2::hpv_status_circle_plot, otherwise = data.frame())

temp = hpv_status_circle_plot_safe(samples_only_for_report)

cat(pie_caption)

#+ lineage table plot 1, echo=FALSE, message=FALSE, warning=FALSE, fig.width=16, fig.height=9, fig.align = "center", eval=!is_clinical, results='asis'
cat("\n\n\\pagebreak\n")
cat("## Lineage Plots\n\n")
lineage_plot_safe <- possibly(TypeSeq2::lineage_plot, otherwise = data.frame())
# lineage results .csv
temp = lineage_plot_safe(lineage_for_report, 1)


#+ normalized lineage table plot, echo=FALSE, message=FALSE, warning=FALSE, fig.width=16, fig.height=9, fig.align = "center", eval=!is_clinical, results='asis'
cat("\n\n\\pagebreak\n")
temp = lineage_plot_safe(lineage_for_report, 2)


#' ## Plate map

#+ Plate map, echo=FALSE, message=FALSE, warning=FALSE, fig.width=12, fig.height=9, fig.align = "center"
plate_map_safe <- possibly(plate_map,otherwise = data.frame())
temp = plate_map_safe(manifest,detailed_pn_matrix_for_report,specimen_control_defs,control_for_report)






