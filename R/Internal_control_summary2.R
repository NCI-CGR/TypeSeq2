#'
#'control_summary

#Using detailed_pn_matrix, manifest and control results

Internal_control_summary2 <- function(detailed_pn_matrix_for_report,manifest,control_for_report,specimen_control_defs, for_batch=F){
    requre(pander)
    # use the code developed for collect_metrics
    # Add project for Batch level 
    t4 <- .internal_control_summary(detailed_pn_matrix_for_report,manifest, specimen_control_defs, for_batch)
    
    t4 %>% pandoc.table(caption = "Internal Control Summary")
    
    #table5 
    t5 <- .control_sumamry(control_for_report, specimen_control_defs, for_batch)
    
    # Introduce spaces to enable multiple lines
    t5 %>% rename_all(~ gsub("_", " ", .)) %>% pandoc.table(caption = "Control Summary", split.table=100, split.cells=12, style="multiline")
}



