#' parse an ini likely file without section
#' @param fn input file name
#' @NoRd
parse_key_value <- function(fn){
    read.delim(fn, header=F)  %>% separate(V1, into=c("key", "value"), sep=" *= *", fill="right") %$% setNames(value, key) 
    
}

#' a wrapper to parse the json file under raw_metrics by default
#' @param fn the josn file name under raw_metrics
#' @NoRd
parse_json <- function(fn, metrics_source_dir="./raw_metrics"){
    fromJSON(file.path(metrics_source_dir, fn), simplifyDataFrame = TRUE, simplifyMatrix = TRUE)
}

#' Convert the decimal to percentaage 
#' @param x a float number between 0 and 1
#' @NoRd
fmt_perc <- function(x, digits=2){
    ifelse(x != 0,paste0(round(x * 100, digits=digits), "%"),"0")
}

#' take subset by batch
#' @param x a float number between 0 and 1
#' @NoRd
subset_by_batch <- function(df, ids, is.batch_id=T){
    if(is.batch_id){
        rv <- subset(df, Assay_Batch_Code %in% ids)
    }else{
        # use barcode otherwise
        rv <- subset(df, barcode %in% ids)
    }
}

#' Make internal contrl summary (Table 4)
#' @param detailed_pn_matrix_for_report
#' @param manifest
#' @param specimen_control_defs
#' @NoRd

.internal_control_summary <- function(detailed_pn_matrix_for_report,manifest, specimen_control_defs, for_batch=F){
    # when the data is for each batch, data is straitified by Project
    v <- ifelse(!for_batch, "Assay_Batch_Code", "Project")
    
    vv <- v %>% rlang::sym()
    # vn <- v %>% rlang::quo_name()

    rv <- detailed_pn_matrix_for_report %>% dplyr::mutate_if(is.factor, ~ as.character(.) ) %>% inner_join(manifest %>% unite("barcode", BC1, BC2, sep="")) %>% left_join( specimen_control_defs %>% dplyr::select(Owner_Sample_ID=Control_Code,Control_type) %>% unique ) %>% bind_rows(dplyr::mutate(., !!vv :="", Assay_Plate_Code = "All_plates")) %>% group_by(!!vv, Assay_Plate_Code) %>% summarise( total = n(), sample_n = sum(is.na(Control_type)), B2M_perc = fmt_perc(sum(human_control=="pass")/sample_n), ASIC_perc=fmt_perc(sum(Assay_SIC == "pass")/total) ) %>% dplyr::select(-total, -sample_n) %>% dplyr::arrange(factor(!!vv, levels=c(unique(manifest %>% dplyr::pull (!!vv) ), "")),Assay_Plate_Code )

    return(rv)
}

#' Make contrl sumamry (Table 5)
#' @param control_for_report
#' @param specimen_control_defs
#' @NoRd

.control_sumamry <- function(control_for_report, specimen_control_defs, for_batch=F){
    vv <- ifelse(! for_batch, "Assay_Batch_Code", "Project") %>% rlang::sym()

        rv <- control_for_report %>% dplyr::mutate_if(is.factor, ~ as.character(.) ) %>%  inner_join(( specimen_control_defs %>% dplyr::select(Owner_Sample_ID=Control_Code,Control_type) %>% unique )) %>% bind_rows(dplyr::mutate(., !!vv := "", Assay_Plate_Code = "All_plates")) %>% group_by(!!vv, Assay_Plate_Code)%>%  summarise(n=n(), Num_Pos_control_Passed=sum(control_result == "pass" & Control_type == "pos"), Num_Neg_control_Passed=sum( control_result == "pass" & Control_type == "neg"), Num_pos_control_failed=sum(control_result == "fail" & Control_type == "pos"), Num_neg_control_failed= sum(control_result == "fail" & Control_type == "neg")) %>% dplyr::select(-n) %>% dplyr::arrange(factor(!!vv, levels=c(unique(manifest$Project), "")),Assay_Plate_Code )

    return(rv)

}


.plate_summary <- function(control_for_report,samples_only_for_report, is_clinical=F,for_batch=F){

}

# plate_summary (control_for_report,samples_only_for_report, is_clinical=F,for_batch=T)