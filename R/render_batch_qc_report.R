#'
render_batch_qc_report <- function(variants_final_table,
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
                    "typeseq2", template_fn, package = "TypeSeqHPV2"),
                " ./"))


    for(batch in unique(manifest$Assay_Batch_Code)){
        batch_env <- new.env()

        batch_env$manifest <- subset_by_batch(manifest, batch)
        
        barcodes <- batch_env$manifest %>% unite("barcode", BC1, BC2, sep="") %>% pull(barcode)

        batch_env$control_for_report <- subset_by_batch(control_for_report, batch)
        batch_env$samples_only_for_report <- subset_by_batch(samples_only_for_report, batch)

        batch_env$read_count_matrix_report <- subset_by_batch(read_count_matrix_report, barcodes, is.batch_id=F)
        batch_env$detailed_pn_matrix_for_report <- subset_by_batch(detailed_pn_matrix_for_report, barcodes, is.batch_id=F)


        batch_env$lineage_for_report <- subset_by_batch(lineage_for_report, batch)
       


        render(input = template_fn,
            output_dir = "./", output_file = sprintf("%s_TypeSeq2HPV_QC_report.pdf", batch), clean = T, envir=batch_env, params=list(batch_id=batch, is_clinical = FALSE, for_batch=TRUE))
    }

### Assume there is no need for the batch report for laboratory

## if("is_clinical" %in% names(args_df) && args_df$is_clinical == "yes"){
##     render(input = "Ion_Torrent_report.R",
##        output_dir = "./", output_file = "TypeSeq2HPV_laboratory_report.pdf", clean = FALSE, params = list(is_clinical = TRUE))
## }

    return(data_frame(path = "Batch_Ion_Torrent_report.pdf"))

}
