#'
#'control_summary

#Using detailed_pn_matrix, manifest and control results

### Note that specimen_control_defs is not needed any more

Internal_control_summary2 <- function(detailed_pn_matrix_for_report,manifest,control_for_report,specimen_control_defs, for_batch=F, output_prefix=NULL){
    require(pander)
    # use the code developed for collect_metrics
    # Add project for Batch level 
    
    # t4 <- .internal_control_summary(detailed_pn_matrix_for_report, manifest, control_for_report, for_batch)
    
    
    #table5 
    t5 <- .control_summary(control_for_report, for_batch) %>% rename_all(~ gsub("_", " ", .))
    
    # Introduce spaces to enable multiple lines
    t5  %>% pandoc.table(caption = "Batch Control Summary", split.table=100, split.cells=12, style="multiline")

    if(!is.null(output_prefix)){
        write_csv(t5, sprintf("%s.Table5.csv", output_prefix))
    }

    return(t5)
}




