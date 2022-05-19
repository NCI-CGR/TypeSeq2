#' plate_summary
#'

plate_summary <- function(samples_only_for_report, is_clinical=F,for_batch=F){

    require(pander)

    vv <- ifelse(! for_batch, "Assay_Batch_Code", "Project") %>% rlang::sym()

    t3 <- samples_only_for_report %>% 
        group_by(!!vv, Assay_Plate_Code) %>% 
        summarise( 
            hpv_pos_perc = fmt_perc(sum(Num_Types_Pos >0, na.rm=T) / n(), digits=1 ),
            plate_total_reads = scales::comma(sum(total_reads, na.rm = TRUE)),
            number_of_samples = n(), 
            num_samples_failed = sum(overall_qc == "fail", na.rm=T)
        ) %>% 
        dplyr::select(!!vv, 
            `Assay Plate Code` = Assay_Plate_Code,
            `HPV % Positive` = hpv_pos_perc,
            `total reads` = plate_total_reads,
            `# samples total` = number_of_samples,
            `# samples failed` = num_samples_failed,
        )

    t3 %>% when(
                is_clinical ~  select(., -`HPV % Positive`),
                ~ .
            ) %>%
            pandoc.table(style = "multiline", caption = "Assay Plate Performance", split.cells = 12)

    
}
