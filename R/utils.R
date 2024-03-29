#' parse an ini likely file without section
#' @param fn input file name
#' @NoRd
parse_key_value <- function(fn){
    read.delim(fn, header=F)  %>% separate(V1, into=c("key", "value"), sep=" *= *", fill="right") %$% setNames(value, key) 
    
}

#' a wrapper to parse the json file under raw_metrics by default
#' @param fn the josn file name under raw_metrics
#' @NoRd
my_parse_json <- function(fn, metrics_source_dir="./raw_metrics"){
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

qc_summary <- function(samples_only_for_report,  for_batch=F){
    vv <- ifelse(! for_batch, "Assay_Batch_Code", "Project") %>% rlang::sym()

    rv <- samples_only_for_report %>% 
        dplyr::mutate_if(is.factor, ~ as.character(.) )  %>% 
        # a trick to have summary row
        bind_rows(dplyr::mutate(., !!vv := "", Assay_Plate_Code = "All_plates")) %>% 
        group_by(!!vv, Assay_Plate_Code) %>%  
        summarise(n=n(), 
            Sequencing_qc_pass=fmt_perc(sum(sequencing_qc == "pass")/n), 
            ASIC_qc_pass=fmt_perc(sum(grepl("pass", Assay_SIC))/n), 
            Overall_qc_pass=fmt_perc(sum(overall_qc == "pass")/n )
        )%>% 
        dplyr::select(-n) %>% dplyr::arrange(factor(!!vv, levels=c(samples_only_for_report %>% pull(!!vv) %>% as.character %>% unique, "")),Assay_Plate_Code )

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

# > read.csv(args_df$overall_qc_defs)
#   OVERALL_QC sequencing_qc human_control total_HPV_reads Assay_SIC
# 1       pass          pass          pass            fail      pass
# 2       pass          pass          pass            pass      pass
# 3       pass          pass          fail            pass      pass
# 4       pass          pass          pass            pass      fail
# 5       pass          pass          fail            pass      fail

### Note that pass statuses in Assay_SIC and human_control
# icd_df %$% table( qc_name, qc_print)
#                qc_print
# qc_name         failed_all failed_low-high failed_low-med failed_med-high
#   Assay_SIC              1               1              1               1
#   human_control          0               0              0               0
#                qc_print
# qc_name         failed_to_amplify pass pass_flag-high pass_flag-low
#   Assay_SIC                     0    1              1             1
#   human_control                 1    2              0             0
#                qc_print
# qc_name         pass_flag-med pass_low-concentration
#   Assay_SIC                 1                      0
#   human_control             0                      1
add_overall_qc <- function(pn_sample, overall_qc_defs.fn){
  # OVERALL_QC sequencing_qc human_control total_HPV_reads Assay_SIC
  defs.df <- read.csv(overall_qc_defs.fn, stringsAsFactors=F)  
  
  cols <- names(defs.df)[-1]

  .d <- pn_sample %>% mutate(
      human_control = ifelse(grepl("pass", human_control), "pass", "fail"),
      Assay_SIC = ifelse(grepl("pass", Assay_SIC), "pass", "fail")
      ) %>% unite("combo", one_of(cols))

  rv <- pn_sample %>% mutate(overall_qc = 
    .d %>% left_join( 
        defs.df %>% unite("combo", one_of(cols)), 
        by="combo") %>% 
        pull(OVERALL_QC) %>% 
        replace_na("fail")) %>% 
        ### Apply special rule to NTC
        mutate(overall_qc = ifelse( 
            grepl("NTC", Owner_Sample_ID) & 
            sequencing_qc == "pass" &
            (!grepl("pass", human_control)) &
            total_HPV_reads == "fail" &
            grepl("pass", Assay_SIC), "pass", overall_qc )) %>%
    # .after is not supported so use the old way to order the columns
    # drop total_HPV_reads as it is not required
    select(Owner_Sample_ID, barcode, overall_qc, everything(), -total_HPV_reads)
  return(rv)
}

plot_plate <- function(df, color_var, custom_color, title){
    well_num = seq(1,12,length.out = 12)  %>% as.character
    well_ID = LETTERS[1:8]
    empty_wells = as.data.frame(expand.grid(rownum=well_ID, colnum= well_num,stringsAsFactors = F))

    dat2 <- df %>%   
        full_join(empty_wells ) %>%
        mutate(Control_Code = ifelse(is.na(Control_Code),"empty",Control_Code)) 
    
    p <- dat2 %>% ggplot(aes(x = fct_reorder(colnum,sort(as.numeric(colnum))),y = fct_reorder(rownum,desc(rownum)),shape = Control_Code)) + 
      geom_point(aes_string(col = color_var), size =12) +
      scale_shape_manual(name="Control Code", values = c("empty"=16,"control"=17,"sample"=16), limit = c("empty","control","sample"), drop = F) +
      custom_color + 
      labs(x= sprintf("Batch: %s, Plate: %s", dat2$Assay_Batch_Code[1], dat2$Assay_Plate_Code[1]), y = "TypeSeqHPV_plate_data")+
      ggtitle(title)
      

    print(p)
    dat2
}

get_scaling_factor <- function( read_count, scaling_df){
    scaling_df %>% filter(min_avg_reads_boundary <= read_count & max_avg_reads_boundary >= read_count) %>%
    pull(scaling_factor)
}

### Get the output prefix for the whole run
# Casey suggested to use the run name 
get_output_prefix <- function(){
    if(!exists(".TYPESEQ2_PREFIX", envir =.GlobalEnv)){
        # cat("Reading...\n")
        plugin_json = jsonlite::fromJSON(file("./startplugin.json"), simplifyDataFrame = TRUE, simplifyMatrix = TRUE)
        .p <- plugin_json$plan$planName

        ### only global attribute can survive
        assign(".TYPESEQ2_PREFIX",.p, envir =.GlobalEnv)
    }
    
    output_prefix <- get(".TYPESEQ2_PREFIX", envir =.GlobalEnv)
    return(output_prefix)
}