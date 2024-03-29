#######################################################################
# The metrics of the sequencing run is defined in TypeSeq2_run_stats_template_1.xlsx
#######################################################################
# modified from: https://stackoverflow.com/questions/21064761/how-to-parse-ini-like-configuration-files-with-r
# strcap <- function(s) paste(toupper(substr(s,1,1)), tolower(substring(s,2)), sep="")


### typing_variant_filter has no value in the prevous step,
# That I include it in the argument is just for to show this step depends on the step 7

collect_metrics <- function(user_files, variants_final_table, metrics_source_dir="./raw_metrics"){
    metrics <- list()

    ### Run metrics from expMeta.dat
    meta <- parse_key_value(file.path(metrics_source_dir, "expMeta.dat"))
    metrics$Run_Name <- meta[["Run Name"]]
    metrics$Run_Date <- meta[["Run Date"]]
    metrics$Analysis_Name <- meta[["Analysis Name"]]
    metrics$Run_Plan_Notes <- meta[["Notes"]]

    ### Get the barcde from startplugin.json
    # metrics$Chip_Barcode <- meta[["Barcode Set"]]
    startplugin <- my_parse_json("startplugin.json", "./")
    metrics$Chip_Barcode <- startplugin$expmeta$chipBarcode

    ### raw_peak_signal
    peak_signal <- parse_key_value(file.path(metrics_source_dir, "raw_peak_signal"))
    metrics$Key_Signal <- peak_signal[["Library"]] # numeric in string

    ### TFStats.json 
    tfstats.json <- my_parse_json("TFStats.json", metrics_source_dir)
    metrics$Perc_Test_Fragment_100AQ17 <- tfstats.json$TF_1$`Percent 100Q17`

    ### analysis.bfmask.stats in ini format
    bfmask <- parse_key_value(file.path(metrics_source_dir, "analysis.bfmask.stats")) %>% map( ~as.numeric(.x))

    metrics$Perc_Chip_Loading <- bfmask %$% {`Live Beads` /(`Total Wells` -`Excluded Wells` ) }
    
    ### ionstats_alignment.json
    align.json <- my_parse_json("ionstats_alignment.json", metrics_source_dir)

    metrics$Aligned_PF_Reads <- align.json$aligned$num_reads
    
    metrics$Perc_Aligned_PF_Reads <- align.json %$% {aligned$num_reads / full$num_reads}

    ### datasets_basecaller.json
    datasets_bc.json <- my_parse_json("datasets_basecaller.json", metrics_source_dir)

    metrics$No_Barcode_Reads <- datasets_bc.json$datasets %>% filter(basecaller_bam=="nomatch_rawlib.basecaller.bam") %>% pull(read_count)

    ### BaseCaller.json
    basecall <- my_parse_json("BaseCaller.json", metrics_source_dir)$Filtering$LibraryReport %>% map( ~as.numeric(.x))

    # = 48287626
    # metrics$Usable_Seq_Reads <- basecall$final_library_reads

    # calculate Usable_Seq_Reads by add No-barcode reads and reads to be algined = 48286902
    metrics$Usable_Seq_Reads <- align.json$full$num_reads + metrics$No_Barcode_Reads

    metrics$Perc_Usable_Seq_Reads <- basecall %$% {final_library_reads /sum(basecall %>% unlist) }

    
    metrics$Alignment_Filtered_Reads <- align.json %$% {full$num_reads - aligned$num_reads}

    metrics$Perc_Alignment_Filtered_Reads <- align.json %$% {1 -  aligned$num_reads / full$num_reads } 

    ### Work on read_summary.csv
    read_summary <- read.csv("read_summary.csv") %>% setNames(c("id", "total", "pass_za", "pass_mapq", "pass_hamming", "pass_za_perc", "pass_mapq_perc", "pass_hamming_perc"))

    # use pass_hamming instead
    metrics$TypeSeq2_Usable_Reads <- sum(read_summary$pass_hamming)

    ## Ref: read_summary_calcs.xlsx
    ## Perc_Reads_Filtered_ZA	(reads lost at this step)
    ## Perc_Reads_Filtered_MAPQ	(reads lost at this step, after ZA filtering)
    ## Perc_Reads_Filtered_BC2	(reads lost at this step, after ZA and MAPQ filtering)
    ## Perc_Reads_Usable_Total	

    metrics$Perc_Reads_Filtered_ZA <- read_summary %$% { (sum(total) - sum(pass_za)) / sum(total) }

    metrics$Perc_Reads_Filtered_MAPQ <- read_summary %$% { (sum(pass_za) - sum(pass_mapq)) / sum(total)}

    metrics$Perc_Reads_Filtered_BC2 <- read_summary %$% { (sum(pass_mapq) - sum(pass_hamming)) / sum(total)}

    metrics$Perc_Reads_Usable_Total <- read_summary %$% { sum(pass_hamming) / sum(total)}

    ### Get the link between batch and plate
    manifest <- user_files$manifest

    metrics$Assay_Batch_Code <- manifest %>% select(Assay_Batch_Code) %>% distinct %>% pull %>% paste( collapse=",")

    metrics$Project_Code <- manifest %>% select(Project) %>% distinct %>% pull %>% paste( collapse=",")

    ### "Number samples tested" in plugin pdf qc file, table 2
    # Ref: 30M
    # Input data are passed to the report page from the workflow (via render_ion_qc_report and the template page: Ion_Torrent_report.R)
    
    ### There 288 rows in the manifest.csv
    #  samples_only_for_report has been inner_join with the read count matrix (wide): only samples with read supported are counted here
    samples <- read.csv("samples_only_for_report")

    # metrics$Num_Samples <- samples %>% group_by(Assay_Batch_Code) %>% summarize(n=n(), Perc_HPV_Pos = sum(Num_Types_Pos>0)/n )

    ### Table 2 in the pdf report
    # ss <- sample_summary(samples)
    # Error: Column `Perc Failed` can't be converted from numeric to character

    ### Using the code below to modify the function sample_summary  
    # sampleSummary <- samples %>% group_by(Project) %>% summarize(n=n(), pass_n = sum (str_detect(human_control,'pass')), fail_n= sum (str_detect(human_control,'failed_to_amplify')), pass_perc = fmt_perc(pass_n/n), fail_perc= fmt_perc(fail_n/n)) %>%  select(Project_ID=Project,`Number Samples Tested`=n,`Number Passed`=pass_n,`Number Failed`=fail_n, `Perc Passed`=pass_perc,`Perc Failed`=fail_perc) %>% glimpse

    ### Using the similar code to generate summary for batch
    t1 <- samples %>% group_by(Assay_Batch_Code) %>% 
        summarize(  n=n(), 
                    pass_n = sum (overall_qc == "pass"), 
                    fail_n= sum (overall_qc == "fail"), 
                    pass_perc = fmt_perc(pass_n/n), 
                    fail_perc= fmt_perc(fail_n/n),
                    seq_qc_perc = fmt_perc(sum(sequencing_qc == "pass") /n),
                    ASIC_perc=fmt_perc(sum(grepl("pass", Assay_SIC))/n)) %>%  
        select(Assay_Batch_Code,
               `Number Samples Tested`=n,
               `Number Passed`=pass_n,
               `Number Failed`=fail_n, 
               `Overall QC Perc Passed`=pass_perc,
               `Overall QC Perc Failed`=fail_perc,
               `Sequencing QC perc passed` = seq_qc_perc,
               `ASIC perc passed` = ASIC_perc) 


    # specimen_control_defs = user_files$control_definitions

    ### Table 4 (see Internal_control_summary.R)
    # detailed_pn_matrix_for_report,manifest,control_for_report,specimen_control_defs
    detailed_pn_matrix_for_report = read.csv("detailed_pn_matrix_report")
    control_for_report = read.csv("control_for_report")
    specimen_control_defs = user_files$control_definitions

    # group by batch (not by plate any more)
    # we need sample_n here so we cannot get the metrics from t1
    # since b2m_perc is dropped, we can get asic_perc from t2,
    # so t2 is not needed any more

    ## t2 <- detailed_pn_matrix_for_report %>% inner_join(manifest %>% unite("barcode", BC1, BC2, sep="")) %>% left_join( 
    ##     specimen_control_defs %>% select(Owner_Sample_ID=Control_Code,Control_type) %>% unique ) %>% 
    ##     group_by(Assay_Batch_Code) %>% summarise( total = n(), sample_n = sum(is.na(Control_type)), B2M_perc = fmt_perc(sum(human_control=="pass" & is.na(Control_type))/sample_n), ASIC_perc=fmt_perc(sum(Assay_SIC == "pass")/total) ) %>% select(-total, -sample_n)

    ### Control_for_report has all the informatino
    t3 <- control_for_report %>%
          group_by(Assay_Batch_Code) %>%
          summarise(n = n(), 
            Num_Pos_Con_Passed = sum(control_result == "pass" & Control_type == "pos"), 
            Num_Neg_Con_Passed = sum(control_result == "pass" & Control_type == "neg"), 
            Num_pos_con_failed = sum(control_result == "fail" & Control_type == "pos"), 
            Num_neg_con_failed = sum(control_result == "fail" & Control_type == "neg")) %>%
        select(-n)
    

    if(nrow(t1) ==0){
        # special case: all samples are controls
        t1 <- t1 %>% tibble::add_row(Assay_Batch_Code = manifest %>% pull(Assay_Batch_Code) %>% unique)
    }
    batch_table <- t1 %>% left_join(t3)

    ### Assign NA if no value assigned
    # see https://stackoverflow.com/questions/50940269/r-using-the-unlist-function-for-a-list-that-has-some-elements-being-integer0/50940340
    is.na(metrics) <- lengths(metrics) == 0

    #  outfn="run_metrics.csv"
    outfn <- sprintf("%s.run_metrics.csv", gsub(",", "_", metrics$Assay_Batch_Code) )

    write.table(data.frame(Name=names(metrics), Value=unlist(metrics)),file=outfn, sep="," , row.names=F) 

    ### It was decided to save the batch information as a separated csv file.
    # Batch1_Batch2_Batch3.batch_metrics_summary.csv

    batch_outfn <- sprintf("%s.batch_metrics_summary.csv", gsub(",", "_", metrics$Assay_Batch_Code) )
    
    write.table(t(batch_table), file=batch_outfn, sep=",", col.names=F)

    metrics$batch_table <- batch_table 
    return(metrics)
}
