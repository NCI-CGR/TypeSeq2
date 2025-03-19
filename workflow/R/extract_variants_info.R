#+
extract_variants_info <- function(fn){
  require(tidyverse)
  
  df <- read.csv(fn) %>%
    select(filename, everything())
  
  variant_table_snv = df %>%
    filter(!(str_detect(ALT, ","))) 
  
  #This step is added to prevent selecting columns with NA which will cause problems in seperate rows step
  
  
  id_select<-c("ALT", "AO", "SAF", "SAR", "FAO", "AF", "FSAF", "FSAR", "TYPE", "LEN", "HRUN", "MLLD", 
               "FWDB", "REVB", "REFB", "VARB", "STB", "STBP", "RBI", 
               "FR", "SSSB", "SSEN", "SSEP", "PB", "PBP", "FDVR") 
  id_intersect<-intersect(id_select,colnames(df))
  
  
  variant_table_mult_split = df %>%
    filter(str_detect(ALT, ",")) %>%
    separate_rows(any_of(id_intersect), sep = ",") 
  
  variant_table_return = bind_rows(variant_table_snv, variant_table_mult_split) 
  
  contigs <- variant_table_return %>%
    filter(HS == 1) %>%
    pull(CHROM) %>%
    unique() %>%
    str_sort(numeric = T)
  
  hpv_ids_in_order <- str_sort(contigs %>% grep("^HPV", ., v = T), numeric = T)
  
  hpv_lines_in_order <- hpv_ids_in_order %>%
    gsub("_.*", "", .) %>%
    unique() %>%
    str_sort(numeric = T)
  
  return(list(
    variants.df = variant_table_return,
    contigs = contigs,
    hpv_ids = hpv_ids_in_order,
    hpv_lines = hpv_lines_in_order
  ))
  
  
}

