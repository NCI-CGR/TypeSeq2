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
    if(is.na(x) || is.infinite(x)){
        return(NA_character_)
    }
    rv <- ifelse(x != 0, paste0(round(x * 100, digits = digits), "%"), "0")
    return(rv)
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
#' @param control_for_report
#' @NoRd

.internal_control_summary <- function(detailed_pn_matrix_for_report, manifest, control_for_report, for_batch=F){
    # when the data is for each batch, data is straitified by Project
    v <- ifelse(!for_batch, "Assay_Batch_Code", "Project")
    
    vv <- v %>% rlang::sym()
    # vn <- v %>% rlang::quo_name()

    # we need Assay_Batch_Code/Project, Control_type
    rv <- detailed_pn_matrix_for_report %>% 
        dplyr::mutate_if(is.factor, ~ as.character(.) ) %>% 
        # join manifest to have Assay_Batch_Code/Project for all samples
        inner_join(manifest %>% unite("barcode", BC1, BC2, sep="")) %>% 
        # join control_for_report to get the number of control samples
        left_join( control_for_report %>% dplyr::select(barcode,Control_type) %>% unique ) %>% 
        # A trick to have summary row
        bind_rows(dplyr::mutate(., !!vv :="", Assay_Plate_Code = "All_plates")) %>% 
        group_by(!!vv, Assay_Plate_Code) %>% 
        summarise( total = n(), 
                   sample_n = sum(is.na(Control_type)), 
                   B2M_perc = fmt_perc(sum(human_control=="pass" & is.na(Control_type) )/sample_n), 
                   ASIC_perc=fmt_perc(sum(Assay_SIC == "pass")/total) ) %>%
        # remove those intermediate variabes           
        dplyr::select(-total, -sample_n) %>% 
        # to make sure to order rows properly
        dplyr::arrange(factor(!!vv, levels=c(unique(manifest %>% dplyr::pull (!!vv) ), "")),Assay_Plate_Code )

    return(rv)
}

#' Make contrl sumamry (Table 5)
#' @param control_for_report
#' @param specimen_control_defs
#' @NoRd

.control_summary <- function(control_for_report,  for_batch=F){
    vv <- ifelse(! for_batch, "Assay_Batch_Code", "Project") %>% rlang::sym()

        rv <- control_for_report %>% 
            dplyr::mutate_if(is.factor, ~ as.character(.) )  %>% 
            # a trick to have summary row
            bind_rows(dplyr::mutate(., !!vv := "", Assay_Plate_Code = "All_plates")) %>% 
            group_by(!!vv, Assay_Plate_Code)%>%  
            summarise(n=n(), 
                Num_Pos_control_Passed=sum(control_result == "pass" & Control_type == "pos"), 
                Num_Neg_control_Passed=sum( control_result == "pass" & Control_type == "neg"), 
                Num_pos_control_failed=sum(control_result == "fail" & Control_type == "pos"), 
                Num_neg_control_failed= sum(control_result == "fail" & Control_type == "neg")) %>% 
            dplyr::select(-n) %>% dplyr::arrange(factor(!!vv, levels=c(control_for_report %>% pull(!!vv) %>% as.character %>% unique, "")),Assay_Plate_Code )

    return(rv)

}

#' Make data frame
#' @param df is a data.frame with 3 columns: row id, column id, value
#' @param dimnames, a list of two character vectors for dimnames of the output df
#' @param default_value, default value for the data frame
#' @NoRd
.make_df <- function( df, dimnames, default_value = 0){

    df <- df[,1:3] %>% as.data.frame 
    out <- matrix(default_value, nrow=length(dimnames[[1]]), ncol=length(dimnames[[2]]), dimnames=dimnames) %>% as.data.frame(check.names = F)
    
    for( i in seq_len(nrow(df))){
        out[df[i,1], df[i,2]] <- df[i,3]
    }
    return(out)
}

.convert_numeric_config <- function(v){
    v %>% sub("^/user_files/", "",.) %>% as.numeric
}

write_batch_csv <- function(df, batch, fn) {
    df %>%
        filter(Assay_Batch_Code == batch) %>%
        write.csv(paste0(batch, "-", fn), row.names = F)
}

.align_by_barcode <- function(df, barcode){
    rv <- data.frame(barcode=barcode, stringsAsFactors=F) %>% left_join(df, by="barcode")
    return(rv)
}

renaming_read_summary <- function(user_files){
    # rename read_summary.csv
    orig_fn <- "read_summary.csv"
    new_fn <- sprintf("%s.read_summary.csv",  user_files$manifest$Assay_Batch_Code %>% unique %>% paste(collapse="_")) 
    system(sprintf("cp %s %s", orig_fn, new_fn) ) # use cp to keep the original file for the time being
    return(new_fn)
}

.sort_ids <- function(str){
    rv <- factor(str, levels=stringr::str_sort(unique(str), numeric=T))
    return(rv)
}

numCheck <- function(x, na.coding = c("NA", "")) {
    x[x %in% na.coding] <- NA

    x <- x[!is.na(x)]
    if (suppressWarnings(all(!is.na(as.numeric(x))))) {
        return(T)
    } else {
        return(F)
    }
}

### add new "overall_qc"
###  "overall_qc", "sequencing_qc", "human_control", "Assay_SIC" after barcode
# pn_sample: Owner_Sample_ID  barcode sequencing_qc total_HPV_reads Assay_SIC human_control
# output: Owner_Sample_ID    barcode overall_qc sequencing_qc Assay_SIC human_control 
add_overall_qc <- function(pn_sample, overall_qc_defs.fn){
  # OVERALL_QC sequencing_qc human_control total_HPV_reads Assay_SIC
  defs.df <- read.csv(overall_qc_defs.fn, stringsAsFactors=F)  
  
  cols <- names(defs.df)[-1]

  .d <- pn_sample %>% mutate(human_control = ifelse(grepl("pass", human_control), "pass", "fail")) %>% unite("combo", one_of(cols))

  rv <- pn_sample %>% mutate(overall_qc = 
    .d %>% left_join( 
        defs.df %>% unite("combo", one_of(cols)), 
        by="combo") %>% 
        pull(OVERALL_QC) %>% 
        replace_na("fail")) %>% 
    # .after is not supported so use the old way to order the columns
    # drop total_HPV_reads as it is not required
    select(Owner_Sample_ID, barcode, overall_qc, everything(), -total_HPV_reads)
  return(rv)
}