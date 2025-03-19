#'
#'
#'
#'

get_args <- function(args_df, path){
    args_df$config_general <- sprintf("%s/configs/TS2_config.csv", path)
    config_file_df = read_csv(args_df$config_general, col_names = c("key", "value"), col_types="cc")  %>%
        as_tibble() %>%
        mutate(value= ifelse(grepl("^min", key), value, paste0(path, value))) 

    # anything defined at args_df has high priority than config_general
    new_args_df = args_df %>%
        gather() %>%
        anti_join(config_file_df, by = "key") %>%
        bind_rows(config_file_df) %>%
        spread("key", "value") 

    return(new_args_df)

}




