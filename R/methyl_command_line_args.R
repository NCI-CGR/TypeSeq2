#'
get_command_line_args <- function(args_df){
    require(jsonlite)
    require(tidyverse)
    library(optigrab)

if ( args_df$is_torrent_server == "yes") {
    # in the server model, the option is now passed from ./startplugin.json
    plugin_json = fromJSON(file("./startplugin.json"), simplifyDataFrame = TRUE, simplifyMatrix = TRUE)

    if(is.null(plugin_json$pluginconfig$config_set)){
        # Null is not expected, and this is for the testing pupose
        cat("NULL value for config_set is not expected here!\n")
        plugin_json$pluginconfig$config_set <- "T90" 
    }
    args_df$config_file <- sprintf("/user_files/configs/config_file.%s.csv", plugin_json$pluginconfig$config_set)
    args_df$config_general <- "/user_files/configs/config_general.csv"
}

### --bind /results/plugins/TypeSeq2-dev/pluginMedia:/user_files
# so that the pluginMedia folder is binded as /user_files here
config_general_df = read_csv(args_df$config_general, col_names = c("key", "value")) %>%
    map_if(is.factor, as.character) %>%
    as_tibble() %>%
    mutate(value = paste0("/user_files/", value)) %>%
    glimpse()

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

new_args_df = args_df %>%
    gather() %>%
    anti_join(config_file_df, by = "key") %>%
    bind_rows(config_file_df) %>%
    spread("key", "value") %>%
    glimpse()

return(new_args_df)

}




