# redefine the function plate_map 
plate_map <- function(manifest,detailed_pn_matrix_for_report, specimen_control_defs,control_for_report){
    well_num = seq(1,12,length.out = 12)  
    well_ID = LETTERS[1:8]
    empty_wells = as.data.frame(expand.grid(rownum=well_ID, colnum= well_num,stringsAsFactors = F))

    # Note tha data contains multiple batch
    dat <- manifest %>% 
        mutate(barcode = paste0(BC1,BC2)) %>% 
        separate(Assay_Well_ID,c("rownum","colnum"),sep =1) %>%
        select(barcode, rownum, colnum, Assay_Batch_Code, Assay_Plate_Code) %>% 
        left_join(control_for_report %>% select(barcode, control_result, Control_type)) %>% 
        inner_join(detailed_pn_matrix_for_report %>% select(barcode, starts_with("ASIC."), overall_qc=overall_qc) )%>%
        mutate(Control_Code = case_when(
            is.na(Control_type) ~ "sample",
            TRUE ~ "control"
        )) %>% 
        mutate(ASIC_cnt = rowSums( select(., starts_with("ASIC.")) %>% mutate_all(~ .=="pos"))) %>% 
        mutate(ASIC_status = sprintf("%s/3_present", ASIC_cnt)) %>% 
        mutate(overall_qc = as.character(overall_qc)) %>% 
        mutate(control_status = ifelse(Control_Code=="control",  paste(Control_type, control_result, sep="_"), "sample"))


    # Plot for ASIC
    asic_color <- scale_color_manual(name="ASIC status", values = c("0/3_present" = "red","1/3_present" = "yellow","2/3_present"="orange","3/3_present"="green","empty"="grey"),  limit = c("empty","1/3_present","2/3_present", "3/3_present"), drop = F)

    x1 <- dat %>% 
           group_by(Assay_Batch_Code, Assay_Plate_Code) %>% 
           do({
               plot_plate(., "replace_na(ASIC_status, 'empty')", asic_color, title="ASIC plate map")
           })
    
    qc_color <- scale_color_manual(name="Overall QC", values = c("fail" = "red","pass"="green","empty"="grey"),  limit = c("empty","fail","pass"), drop = F)

    # Plot for QC
    x2 <- dat %>% 
           group_by(Assay_Batch_Code, Assay_Plate_Code) %>% 
           do({
               plot_plate(., "replace_na(overall_qc, 'empty')", qc_color, title="Overall QC plate map")
           })

    # make control plate plot
    control_color <-  scale_color_manual(name="Control status", values = c("pos_pass"='green',"pos_fail"='red',"neg_pass"='blue',"neg_fail"='yellow',"sample" ='white',"empty" ='grey'),  limit = c("pos_pass","pos_fail","neg_pass","neg_fail","sample","empty"), drop = F)

    x3 <- dat %>% 
           group_by(Assay_Batch_Code, Assay_Plate_Code) %>% 
           do({
               plot_plate(., "replace_na(control_status, 'empty')", control_color, title="All batch control plate map")
           })
}