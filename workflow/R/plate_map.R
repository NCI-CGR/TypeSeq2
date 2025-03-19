# redefine the function plate_map 
plate_map <- function(manifest,detailed_pn_matrix_for_report, specimen_control_defs,control_for_report){
    well_num = seq(1,12,length.out = 12)  
    well_ID = LETTERS[1:8]
    empty_wells = as.data.frame(expand.grid(rownum=well_ID, colnum= well_num,stringsAsFactors = F))

    # Note tha data contains multiple batch
    dat <- manifest %>% 
        separate(Assay_Well_ID,c("rownum","colnum"),sep =1) %>%
        select(barcode, rownum, colnum, Assay_Batch_Code, Assay_Plate_Code) %>% 
        left_join(control_for_report %>% select(barcode, control_result, Control_type)) %>% 
        inner_join(detailed_pn_matrix_for_report %>% select(barcode, starts_with("ASIC-"), overall_qc=overall_qc) )%>%
        mutate(Control_Code = case_when(
            is.na(Control_type) ~ "sample",
            TRUE ~ "control"
        )) %>% 
        mutate(ASIC_cnt = rowSums( select(., starts_with("ASIC-")) %>% mutate_all(~ .=="pos"))) %>% 
        mutate(ASIC_status = sprintf("%s/3_present", ASIC_cnt)) %>% 
        mutate(overall_qc = as.character(overall_qc)) %>% 
        mutate(control_status = ifelse(Control_Code=="control",  paste(Control_type, control_result, sep="_"), "sample"))


    # Plot for ASIC
    asic_levels <- c('0/3_present', '1/3_present', '2/3_present', '3/3_present', 'empty')
    asicColors <- c("red", "yellow", "orange", "green", "grey")
    asic_color <- scale_color_manual(name="ASIC status", values = setNames(asicColors, asic_levels), limits=asic_levels, drop = F)

    x1 <- dat %>% 
          mutate(ASIC_status = replace_na(ASIC_status, 'empty') %>% factor( levels=asic_levels) ) %>%
           group_by(Assay_Batch_Code, Assay_Plate_Code) %>% 
           do({
               plot_plate(., "ASIC_status", asic_color, title="ASIC plate map")
           })
    
    
    ############################################################
    qcColors <- c("fail" = "red","pass"="green","empty"="grey")
    qc_color <- scale_color_manual(name="Overall QC", values = qcColors, limits=names(qcColors), drop = F)

    # Plot for QC
    x2 <- dat %>% 
           mutate(overall_qc = replace_na(overall_qc, 'empty') %>% factor( levels=names(qcColors)) ) %>%
           group_by(Assay_Batch_Code, Assay_Plate_Code) %>% 
           do({
               plot_plate(., "overall_qc", qc_color, title="Overall QC plate map")
           })

    # make control plate plot
    ctrlColors <- c("pos_pass"='green',"pos_fail"='red',"neg_pass"='blue',"neg_fail"='yellow',"sample" ='white',"empty" ='grey')
    control_color <-  scale_color_manual(name="Control status", values = ctrlColors, limits=names(ctrlColors),  drop = F)

    x3 <- dat %>% 
            mutate(control_status = replace_na(control_status, 'empty') %>% factor( levels=names(ctrlColors)) ) %>%
           group_by(Assay_Batch_Code, Assay_Plate_Code) %>% 
           do({
               plot_plate(., "control_status", control_color, title="All batch control plate map")
           })
}