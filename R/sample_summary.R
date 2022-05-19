#' **Sample Results Summary**
#'
#' The possibly() function guards against failure for all of the figures.
#' It is better to have the report be generated and troubleshoot later why the figure was absent
#'then to have the plugin fail at these steps.

sample_summary <- function(df){

    ## sampleSummary = df %>%
    ##     group_by(Project) %>%
    ##     mutate(numSamplesTested = n()) %>%
    ##     group_by(Project, numSamplesTested, human_control) %>%
    ##     summarize(count = n()) %>%
    ##     transform(human_control = as.character(human_control)) %>%   
    ##     mutate(human_control = ifelse(str_detect(human_control,'pass'),"pass",human_control)) %>%  
    ##     ungroup() %>% group_by(Project,human_control) %>% 
    ##     mutate(sum = sum(count)) %>% select(-count) %>% 
    ##     distinct() %>% 
    ##     spread(human_control, sum, fill=0) %>%
    ##     select(Project_ID = Project, `Number Samples Tested` = numSamplesTested, everything()) %>%
    ##     mutate(`Number Passed` = ifelse("pass" %in% colnames(.),pass,0)) %>%
    ##     mutate(`Number Failed` = ifelse("failed_to_amplify" %in% colnames(.),failed_to_amplify,0)) %>%
    ##     arrange(Project_ID) %>%
    ##     mutate(`Perc Passed` = ifelse(`Number Passed` != 0,paste0(round(`Number Passed`/`Number Samples Tested` * 100, digits=2), "%"),0))  %>%
    ##     mutate(`Perc Failed` = ifelse(`Number Failed` != 0,paste0(round(`Number Failed`/`Number Samples Tested` * 100, digits=2), "%"),0)) %>%
    ##     select(Project_ID,`Number Samples Tested`,`Number Passed`,`Number Failed`,`Perc Passed`,`Perc Failed`) 
      #  mutate(`Perc Passed` = paste0(round(pass/numSamplesTested) %>%
      #  mutate(`Perc Failed` = paste0(round(failed_to_amplify/numSamplesTested * 100, digits=2), "%"))

    sampleSummary <- df %>% 
      group_by(Project) %>% 
      summarize(n=n(), 
        pass_n = sum (overall_qc == "pass"), 
        fail_n= sum (overall_qc == "fail"), 
        pass_perc = fmt_perc(pass_n/n), 
        fail_perc= fmt_perc(fail_n/n)
      ) %>%  
      select(Project_ID=Project,`Number Samples Tested`=n,`Number Passed`=pass_n,`Number Failed`=fail_n, `Perc Passed`=pass_perc,`Perc Failed`=fail_perc) 
        
    panderOptions("table.split.table", 100)
    panderOptions("table.split.cells", 6)

    pandoc.table(as_tibble(sampleSummary), style = "multiline", justify=c("right", "left", "left", "left", "left", "left"),
                 caption = "SAMPLE Summary",
                 use.hyphening=FALSE)

    t4 <- qc_summary(df)
    t4 %>% pandoc.table(caption = "QC Metrics Summary") 
}
