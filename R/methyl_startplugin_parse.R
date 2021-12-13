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
save_value_to_csv <- function(values, csv_fn, default_fn=NULL){
  if(!is.null(values)){
    data_frame(values = values) %>%
          mutate(values = str_replace(values, "\n", "" )) %>%
          filter(values!="") %>%
          separate(col = values, sep = ",", into = unlist(str_split(.$values[1], ","))) %>%
          slice(2:n()) %>%
          glimpse() %>%
          write_csv(csv_fn)
    return(csv_fn)
  }else{
    if(is.null(default_fn)){
      stop("There is no manifest file defined!")
    }
    return(default_fn)
  }
}

startplugin_parse <- function(args_df){
    require(jsonlite)
    require(tidyverse)



if ( args_df$is_torrent_server == "yes") {

    plugin_json = fromJSON(file("./startplugin.json"), simplifyDataFrame = TRUE, simplifyMatrix = TRUE)

    #manifest is required, so we not assign the default manifest_fn on purpose
    args_df$manifest <- save_value_to_csv( plugin_json$pluginconfig$typing_manifest, "manifest.csv")
     

    #control_defs
   
    args_df$control_definitions <- save_value_to_csv(plugin_json$pluginconfig$control_definitions, "control_defs.csv", args_df$control_definitions)

    #barcode_file
    args_df$barcode_file <- save_value_to_csv(plugin_json$pluginconfig$barcode_file, "barcodes.csv", args_df$barcode_file)
    
    #grouping
    args_df$grouping_defs <- save_value_to_csv(plugin_json$pluginconfig$grouping_defs, "grouping_defs.csv", args_df$grouping_defs)
    
}

manifest = read_csv(args_df$manifest) %>%
    map_if(is.factor, as.character) %>%
    as_tibble() %>%
    glimpse() %>%
    write_csv("manifest.csv") # csv needed for ADAM demux part

control_defs = read_csv(args_df$control_definitions) %>%
    map_if(is.factor, as.character) %>%
    as_tibble()  %>%
    glimpse()

barcode_file = read_csv(args_df$barcode_file) %>%
    map_if(is.factor, as.character) %>%
    as_tibble() %>%
    glimpse() %>%
    write_csv("barcodes.csv") # csv needed for ADAM demux part


grouping_defs = if(file.exists(args_df$grouping_defs)){
  read_csv(args_df$grouping_defs) %>%
    map_if(is.factor, as.character) %>%
    as_tibble() %>%
    glimpse() %>%
    write_csv("grouping_defs.csv")
    } else{
      data.frame()
    }

#return list output

return(list(manifest = manifest,
            barcode_file = barcode_file,
            control_definitions = control_defs,
            grouping_defs = grouping_defs
            ))



}


meth_startplugin_parse <- function(args_df){
  require(jsonlite)
  require(tidyverse)
  
  if ( args_df$is_torrent_server == "yes") {
    
    plugin_json = fromJSON(file("./startplugin.json"), simplifyDataFrame = TRUE, simplifyMatrix = TRUE)
    
    #manifest
    data_frame(values = plugin_json$pluginconfig$typing_manifest) %>%
      mutate(values = str_replace(values, "\n", "" )) %>%
      separate(col = values, sep = ",", into = unlist(str_split(.$values[1], ","))) %>%
      slice(2:n()) %>%
      glimpse() %>%
      write_csv("manifest.csv")
    
    #control_defs
    data_frame(values = plugin_json$pluginconfig$control_definitions) %>%
      mutate(values = str_replace(values, "\n", "" )) %>%
      separate(col = values, sep = ",", into = unlist(str_split(.$values[1], ","))) %>%
      slice(2:n()) %>%
      write_csv("control_defs.csv")
    
    #barcode_file
 #   data_frame(values = plugin_json$pluginconfig$barcode_file) %>%
  #    mutate(values = str_replace(values, "\n", "" )) %>%
   #   separate(col = values, sep = ",", into = unlist(str_split(.$values[1], ","))) %>%
    #  slice(2:n()) %>%
    #  glimpse() %>%
    #  write_csv("barcodes.csv")
    
    #grouping
    # data_frame(values = plugin_json$pluginconfig$grouping_defs) %>%
    #    mutate(values = str_replace(values, "\n", "" )) %>%
    #   separate(col = values, sep = ",", into = unlist(str_split(.$values[1], ","))) %>%
    #  slice(2:n()) %>%
    # glimpse() %>%
    #  write_csv("grouping_defs.csv")
    
    
    #control freq
    data_frame(values = plugin_json$pluginconfig$control_freq) %>%
       mutate(values = str_replace(values, "\n", "" )) %>%
       separate(col = values, sep = ",", into = unlist(str_split(.$values[1], ","))) %>%
       slice(2:n()) %>%
       glimpse() %>%
       write_csv("control_freq.csv")
    
    
  }
  
  manifest = read_csv(args_df$manifest) %>%
    map_if(is.factor, as.character) %>%
    as_tibble() %>%
    glimpse() %>%
    write_csv("manifest.csv") # csv needed for ADAM demux part
  
  control_defs = read_csv(args_df$control_definitions) %>%
    map_if(is.factor, as.character) %>%
    as_tibble()  %>%
    drop_na() %>%
    glimpse()
  
 # barcode_file = read_csv(args_df$barcode_file) %>%
#    map_if(is.factor, as.character) %>%
 #   as_tibble() %>%
#    glimpse() %>%
#    write_csv("barcodes.csv") # csv needed for ADAM demux part
  
  
  #grouping_defs = read_csv(args_df$grouping_defs) %>%
  #    map_if(is.factor, as.character) %>%
  #   as_tibble() %>%
  #  glimpse() %>%
  # write_csv("grouping_defs.csv")
  
  control_freq = read_csv(args_df$control_freq) %>%
        map_if(is.factor, as.character) %>%
        as_tibble() %>%
        glimpse() %>%
     write_csv("control_freq.csv")
  
  
  
  
  #return list output
  
  return(list(manifest = manifest,
             # barcode_file = barcode_file,
              control_definitions = control_defs,
              control_freq = control_freq
              #  grouping_defs = grouping_defs
  ))
  
  
  
}


