#' Collect settings of HPV typing from args and configure files
#' 
gather_settings <- function(args_df, user_files){
  lst <- list(
    lineage_defs = args_df$lineage_defs %>% 
      read.csv(as.is = T) %>%
      rename(CHROM = Chr, POS = Base_num, REF = Base_ID, ALT = vcf_variant) %>%
      group_by(Lineage_ID) %>%
      mutate(def_count = n()),
    manifest = user_files$manifest %>%
      unite("barcode", BC1, BC2, sep = ""),
    specimen_control_defs = args_df$control_definitions %>%
      read.csv(as.is = T, check.names = F),
    internal_control_defs = args_df$internal_control_defs %>%
      read.csv(as.is = T, check.names = F),
    grouping_defs = args_df$grouping_defs %>%
      read.csv(as.is = T, check.names = F),
    pn_filters = args_df$pn_filters %>%
      read.csv(as.is = T) %>%
      select_if(function(x) !all(is.na(x))) %>%
      rename(CHROM = contig),
    scaling_df= args_df$scaling_table %>% read.csv( as.is = T),
    overall_qc_defs.fn = args_df$overall_qc_defs,
    is_clinical = args_df$is_clinical, # public code is defined if not NA
    offload = args_df$offload,
    debug = args_df$debug,
    min_reads_per_sample = args_df$min_reads_per_sample %>% .convert_numeric_config(),
    min_hpv_reads_per_sample = args_df$min_hpv_reads_per_sample %>% .convert_numeric_config()
    
  )
  
  stopifnot(sum(duplicated(lst$manifest$barcode))==0)
  lst[["barcode"]] = lst$manifest$barcode
  return(lst)
}