#'
get_command_line_args <- function(args_df){
    require(jsonlite)
    require(tidyverse)
    library(optigrab)

    if ( args_df$is_torrent_server == "yes") {
        # in the server model, the option is now passed from ./startplugin.json
        plugin_json = fromJSON(file("./startplugin.json"), simplifyDataFrame = TRUE, simplifyMatrix = TRUE)

        if(is.null(plugin_json$pluginconfig$config_set)){
            
            # cat("NULL value for config_set is not expected here!\n")
            # plugin_json$pluginconfig$config_set <- "T90" 
        }else{
            # Now NOT Null is NOT expected
            # I keep it for the future use
            args_df$config_file <- sprintf("/user_files/configs/config_file.%s.csv", plugin_json$pluginconfig$config_set)
        }
        
        ### Default config file is TS2_config.csv as requested by Casey
        args_df$config_general <- "/user_files/configs/TS2_config.csv"
    }

    ### --bind /results/plugins/TypeSeq2-dev/pluginMedia:/user_files
    # so that the pluginMedia folder is binded as /user_files here
    config_general_df = read_csv(args_df$config_general, col_names = c("key", "value")) %>%
        map_if(is.factor, as.character) %>%
        as_tibble() %>%
        mutate(value = paste0("/user_files/", value)) %>%
        glimpse()

    if(is.null(args_df$config_file)){
        config_file_df = config_general_df
    }else{
        # combine config_file_df with config_general_df
        # not expected though
        config_file_df = read_csv(args_df$config_file, col_names = c("key", "value")) %>%
            map_if(is.factor, as.character) %>%
            as_tibble() %>%
            mutate(value = paste0("/user_files/", value)) %>%
            glimpse()

        ### T90/T99 has high priority over config_general
        config_file_df <- config_general_df %>%
            anti_join(config_file_df, by = "key") %>%
            bind_rows(config_file_df) %>% 
            glimpse()

    }

    ### Note that anti_join remove the rows with the  same key from args_df
    # so that priority: config_file > config_general > args_df (command-line)
    new_args_df = args_df %>%
        gather() %>%
        anti_join(config_file_df, by = "key") %>%
        bind_rows(config_file_df) %>%
        spread("key", "value") %>%
        glimpse()

    return(new_args_df)

}




