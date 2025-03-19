#'
#' 
## ####################################################################################
## save_value_to_csv is to save a list of strings to an CSV file
## "typing_manifest": [
##       "hotspot_vcf,TS2-T90_for-v2-ref_HOTSPOT_v1_ts-parsed.vcf\n", 
##       "tvc_parameters,TS2-T90_local_parameters_v2-ref_v1.json     \n", 
##       "reference,TypeSeq2_Ion_Ref_T90_v2.fasta\n", 
##       "region_bed,TS2-T90_for-v2-ref_v1_INSERTS.bed\n", 
##       "lineage_defs,TypeSeq2_Lineage-classification_T90-v1-ref_v1_multi-site.csv\n", 
##       "scaling_table,TypeSeq2_Filtering_Scaling_Table_v1.csv\n", 
##       "pn_filters,TypeSeq2_Pos-Neg_matrix_filtering_criteria_T90-v2-ref_v1.csv\n", 
##       "internal_control_defs,TS2_Internal_Control_Defs_v2_no-ESICs.csv"
##     ]

### add static_fn
## values: is the df data passed in the stings via json
## csv_fn: the target fn to be saved (original filename); this is expected if values is not NULL
## static_fn: the static file name to be saved. 
## default_fn is the default file name passed from the configure file; and will be used if there is no value from JSON.

save_value_to_csv <- function(values, csv_fn, static_fn,  default_fn=NULL){
  if(!is.null(values)){
    tibble(values = values) %>%
      mutate(values = str_replace(values, "\n", "")) %>%
      filter(values != "") %>%
      separate(col = values, sep = ",", into = unlist(str_split(.$values[1], ","))) %>%
      slice(2:n()) %>%
      write_csv(csv_fn) %>%
      write_csv(static_fn)
    
    return(csv_fn)
  }else{
    if(is.null(default_fn)){
      stop(sprintf("There is no file defined for %s!", csv_fn))
    }
    return(default_fn)
  }
}

startplugin_parse <- function(args_df){
  require(jsonlite)
  require(tidyverse)
  
  
  
  plugin_json = fromJSON(file("./startplugin.json"), simplifyDataFrame = TRUE, simplifyMatrix = TRUE)
  
  # create input folder 
  dir.create("input", showWarnings =F)
  # manifest is required, so we not assign the default manifest_fn on purpose
  args_df$manifest <- save_value_to_csv(
    plugin_json$pluginconfig$typing_manifest,
    sprintf("input/%s", plugin_json$pluginconfig$manifest_fn),
    "typing_manifest.csv"
  )

  # write_csv return df (write.csv return null)
  manifest = read_csv(args_df$manifest, show_col_types=F) %>%
    write_csv("manifest.csv") # csv needed for ADAM demux part
  
  
  return(list(manifest = manifest))
  
  
}