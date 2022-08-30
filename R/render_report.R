#'
render_ion_qc_report <- function(variants_final_table,
                                 ion_qc_report,
                                 args_df,
                                 manifest,
                                 control_for_report,
                                 samples_only_for_report,
                                 read_count_matrix_report,
                                 detailed_pn_matrix_for_report,
                                 specimen_control_defs,
                                 pn_filters,
                                 lineage_for_report){

require(dplyr)
require(knitr)
require(rmarkdown)
#require(TypeSeqHPV)
require(scales)
require(ggsci)
library(pander)

template_fn <- "batch_qc_report_template.R"

system(paste0("cp ",
              system.file(
                  "typeseq2", template_fn, package = "TypeSeq2"),
              " ./"))

# system("cp /TypeSeq2/inst/typeseq2/Ion_Torrent_report.R ./")

render(input = template_fn,
       output_dir = "./", output_file = "TypeSeq2HPV_QC_report.pdf", clean = T, params = list(is_clinical = F, for_batch=F))

if("is_clinical" %in% names(args_df) && ! is.na(args_df$is_clinical) ){
    render(input = template_fn,
       output_dir = "./", output_file = "TypeSeq2HPV_laboratory_report.pdf", clean = T, params = list(is_clinical = TRUE, for_batch=F))
}

return(data_frame(path = "Ion_Torrent_report.pdf"))

}
