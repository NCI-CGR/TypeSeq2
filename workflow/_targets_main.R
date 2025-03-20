library(tarchetypes)
library(targets)

options(tidyverse.quiet = TRUE)

### to be used in the tar_targets
tar_option_set(packages = c("tidyverse", "openxlsx",  "magrittr", "jsonlite",
                            "data.table", "bigreadr", "purrr", "furrr",
                            "fuzzyjoin"))


library(conflicted)
conflict_prefer("select", "dplyr")
conflict_prefer("filter", "dplyr")
conflict_prefer("%>%", "dplyr")
conflict_prefer("%in%", "base")
conflict_prefer("set", "sets")
conflict_prefer("setdiff", "base")
conflict_prefer("intersect", "base")
conflict_prefer("arrange", "dplyr")
conflict_prefer("n", "dplyr")
conflict_prefer("summarise", "dplyr")
conflict_prefer("extract", "tidyr")



# TARGETS_ROOT <- getOption("TARGETS_ROOT")
# TARGETS_ROOT <- get("targets_root", envir = .GlobalEnv)
TARGETS_ROOT <- Sys.getenv("TARGETS_ROOT")
# stop("TARGETS_ROOT: ", TARGETS_ROOT, "\n")

tar_source(sprintf("%s/R", TARGETS_ROOT))
           
# define some constants
SIC_NAMES <- c("ASIC-Low", "ASIC-Med", "ASIC-High")
HC_NAMES <- c("B2M-S", "B2M-S2")
CTRL_CONTIGS <- c(SIC_NAMES, HC_NAMES)
SAMPLE_ID <- c("CGR_Sample_ID", "Blinded_Sample_ID")

tar_plan(
  args_df0 = read.csv(file="cmd.csv"),
  #### 1. adjust command line arguments ####
  args_df = get_args(args_df0, args_df0$user_files) %>% glimpse(),
  is_clinical = args_df %>% pull(is_clinical) %>% is.na %>% `!`,
  
  #### 2. parse plugin data ####
  user_files = startplugin_parse(args_df), 
  
  #### 2.5 vcf2table
  vcf_fns = dir("vcf", pattern="*.vcf", f=T) %>% grep("_filter",., invert = T, value=T),
  barcode = basename(vcf_fns) %>% sub(".vcf", "",.),
  variant_table = vcf_fns %>% setNames(barcode) %>% 
    future_map_dfr(vcf_to_dataframe, .id="barcode") %>%
    mutate_if(numCheck, ~ as.numeric(.)) 
  
  , tar_target(variant_table_csv, variant_table %>%
                 save_to_csv("variant_table.csv"),
               format="file"),
  
  #### 3. Load variant information
  variants_info = extract_variants_info(variant_table_csv),
  
  settings_lst = gather_settings(args_df, user_files),
  
  # a data frame of read counts with columns: sample_id, barcodes, contigs,total_reads, hpv_reads
  read_counts = settings_lst$manifest %>%
    select(Owner_Sample_ID, barcode) %>%
    bind_cols(
      variants_info$variants.df %>%
      filter(HS == 1) %>%
      group_by(barcode, CHROM) %>%
      summarize(depth = max(c(0, DP), na.rm = T), .groups="drop") %>%
      .make_df(list(settings_lst$barcode, variants_info$contigs)) %>%
      mutate(total_reads = rowSums(.), hpv_reads = select(., starts_with("HPV")) %>% rowSums())
    ),
  read_counts_long = read_counts %>% gather(CHROM, depth, -total_reads, -hpv_reads, -Owner_Sample_ID, -barcode)
  
  , tar_target(read_count_matrix_report, read_counts %>%
               gather(HPV_Type, HPV_Type_count, -barcode, -total_reads, -hpv_reads, -Owner_Sample_ID, -`ASIC-Low`, -`ASIC-High`, -`ASIC-Med`, -`B2M-S2`, -`B2M-S`) )
  # Join with manifest file and dislay columns in a proper order
  , read_counts_final = settings_lst$manifest %>%
      full_join(read_counts[, str_sort(colnames(read_counts), numeric = T)] %>%
      select(barcode, Owner_Sample_ID, total_reads, hpv_reads, `ASIC-Low`, `ASIC-Med`, `ASIC-High`, `B2M-S`, `B2M-S2`, everything()))
  
  # calculate scaling factor using total_reads and scaling_table
  , scaling_factors = sapply(read_counts$total_reads,  get_scaling_factor, scaling_df=settings_lst$scaling_df) %>% unlist
  
  # calculate per sample pn cutoff
  , pn_filter_df = {
      min_reads_per_type <- settings_lst$pn_filters %>% select(CHROM, Min_reads_per_type) %>% deframe
      settings_lst$pn_filters %>% bind_cols (outer( min_reads_per_type, scaling_factors) %>% as.data.frame)
  }
  , tar_target(pn_filter_df.csv, write.csv(pn_filter_df, "Scaled_min-filters.csv"), format="file")
  # assign PN status for each samples, HPV strains and HPV lines
  # , pn.lst = assign_pn(read_counts, read_counts_long, pn_filter_df2, settings_lst$min_reads_per_sample, settings_lst$min_hpv_reads_per_sample )
  , sample_pn = read_counts %>%
    mutate(
      sequencing_qc = ifelse(total_reads >= settings_lst$min_reads_per_sample, "pass", "fail"), 
      total_HPV_reads = ifelse(hpv_reads >= settings_lst$min_hpv_reads_per_sample, "pass", "fail")
    ) %>%
    select(Owner_Sample_ID, barcode, sequencing_qc, total_HPV_reads)
  
  ,contig_pn = (
    read_counts_long %>% 
      inner_join(
        sample_pn %>% select(barcode, sequencing_qc), by = "barcode"
      ) %>% 
      # HPV depth will be reset to 0 if sequecning_qc fails
      mutate(depth = ifelse(grepl("^HPV", CHROM) & sequencing_qc == "fail", 0, depth))
  ) %>%
    inner_join(
      # convert pn_filter to its long form
      pn_filter_df %>% 
        gather("barcode", "min_reads", -(CHROM:Min_perc_per_type))
      , by = c("barcode", "CHROM")
    ) %>%
    mutate(status = ifelse(depth >= min_reads & depth / total_reads >= Min_perc_per_type, "pos", "neg")) %>%
    select(-depth, -total_reads, -hpv_reads, -Min_reads_per_type, -Min_perc_per_type, -min_reads) %>%
    spread(CHROM, status) %>%
    .align_by_barcode(settings_lst$barcode)
  
  # append status of Assay_SIC, human_control and overal_qc
  # Owner_Sample_ID barcode overall_qc sequencing_qc Assay_SIC          human_control
  , sample_pn2 = { 
      
    Assay_SIC <- contig_pn %>%
      unite(sic, all_of(SIC_NAMES)) %>%
      left_join(settings_lst$internal_control_defs %>% unite(sic, all_of(SIC_NAMES)), by = "sic") %>%
      pull(qc_print)
    
    # now take human_control status directly from b2m-s/s2
    human_control <- contig_pn %>% 
      unite(human_control, all_of(HC_NAMES)) %>% 
      left_join(settings_lst$internal_control_defs %>% unite(human_control, all_of(HC_NAMES)), by = "human_control") %>% 
      pull(qc_print)
    
    # assign final qc status based on sequencing_qc,human_control,total_HPV_reads,Assay_SIC (see user_files/configs/TypeSeq2_Overall-qc-defs_v1.1.csv)
    add_overall_qc( sample_pn %>% 
                      mutate(Assay_SIC=Assay_SIC, human_control=human_control), 
                    settings_lst$overall_qc_defs.fn
                    )

  }
  
  # Override step: assign HPV as neg if human control is failed to amplify
  , hpv_pn = contig_pn %>%
    mutate_at(vars(starts_with("HPV")), ~ ifelse(sample_pn2$overall_qc == "fail", NA_character_, .)) %>%
    select(barcode, all_of(variants_info$hpv_ids))
  
  # now define HPV line status
  , hpv_line_pn = hpv_pn %>%
      tidyr::gather("type_id", "type_status", starts_with("HPV")) %>%
      mutate(line_id = gsub("_.*", "", type_id)) %>%
      group_by(barcode, line_id) %>%
      summarise(sum_status = sum(type_status == "pos", na.rm = T), na_status=any(is.na(type_status)), .groups="drop") %>%
      mutate(simple_status = case_when(
        sum_status >= 2 & line_id %in% c("HPV16", "HPV18") ~ "pos",
        sum_status >= 1 & (!line_id %in% c("HPV16", "HPV18")) ~ "pos",
        na_status ~ NA_character_,
        TRUE ~ "neg"
      )) %>%
      select(-sum_status, -na_status) %>%
      spread(line_id, simple_status) %>%
      select(barcode, all_of(variants_info$hpv_lines)) %>%
      .align_by_barcode(settings_lst$barcode)
  
  ### add count of hpv line to sample_pn2 and adjust the column orders
  # sample_pn2: 1] "Owner_Sample_ID" "barcode"         "overall_qc"      "sequencing_qc"   "Assay_SIC"  "human_control"
  , sample_pn_final = sample_pn2 %>%
    mutate(Num_Types_Pos = rowSums(hpv_line_pn[, -1] == "pos", na.rm=T)) %>%
    select(Owner_Sample_ID, barcode, Num_Types_Pos, overall_qc, sequencing_qc, human_control, Assay_SIC)
  
  ### sample_pn_final + control_contigs + hpv_pn
  # detailed_pn_matrix == all_pn
  # pn_sample2 == sample_pn_final 
  # pn_wide2_line == hpv_line_pn
  # read_counts_matrix_long == read_counts_long 
  # pn_wide2 == hpv_pn
  # pn_wide == contig_pn
  , all_pn = sample_pn_final %>%
      bind_cols(contig_pn %>% select(all_of(SIC_NAMES), all_of(HC_NAMES))) %>%
      left_join(hpv_pn, by = "barcode") 
  
  , detailed_pn_matrix_for_report = all_pn
  
  # pn report = all_pn + manifest 
  , deatiled_pn_matrix_for_report1 = settings_lst$manifest %>% inner_join(all_pn, by = c("barcode", "Owner_Sample_ID"))
  
  , simple_pn_matrix_final = settings_lst$manifest %>%
    left_join(sample_pn_final, by = c("Owner_Sample_ID", "barcode")) %>%
    left_join(hpv_line_pn)
  
  # write.csv(simple_pn_matrix_final, "pn_matrix_for_groupings")
  , tar_target(pn_matrix_for_groupings, simple_pn_matrix_final %>% 
                 save_to_csv("pn_matrix_for_groupings"), 
               format="file")
  
  ### get list of control samples (assume non-empty)
  , ctrl_barcodes = settings_lst$manifest %>%
    fuzzyjoin::fuzzy_join(settings_lst$specimen_control_defs,
                          mode = "inner",
                          by = c("Owner_Sample_ID" = "Control_Code"), match_fun = function(x, y) str_detect(x, fixed(y, ignore_case = TRUE))
    ) %>%
    pull(barcode)
  
  ### for run_id.full.csv
  , new_out = settings_lst$manifest %>% 
    select(
      Project,
      Assay_Batch_Code,
      Assay_Plate_Code,
      Assay_Well_ID,
      any_of(SAMPLE_ID),
      Owner_Sample_ID,
      barcode
    ) %>%
    left_join(sample_pn_final, by = c("Owner_Sample_ID", "barcode")) %>%
    left_join(read_counts_long, by = c("Owner_Sample_ID", "barcode")) %>% left_join(
      hpv_pn %>%
        tidyr::gather("Type", "Call", starts_with("HPV")) %>%
        bind_rows(
          contig_pn %>% select(barcode, all_of(CTRL_CONTIGS)) %>%
            gather("Type", "Call", -barcode)
        ),
      by = c("barcode", "CHROM" = "Type")
    ) %>%
    mutate(Control = barcode %in% ctrl_barcodes) %>%
    mutate(per_total = depth / total_reads * 100) %>%
    mutate(per_hpv = ifelse(CHROM %in% CTRL_CONTIGS, NA, depth / hpv_reads *
                              100)) %>%
    mutate(LIMS_Sample_ID = NA) %>%
    select(
      Project,
      Assay_Batch_Code,
      Assay_Plate_Code,
      Assay_Well_ID,
      any_of(SAMPLE_ID),
      Owner_Sample_ID,
      barcode,
      total_reads,
      `HPV reads` = hpv_reads,
      Control,
      Num_Types_Pos,
      Overall_qc = overall_qc,
      Sequencing_qc = sequencing_qc,
      Human_Control = human_control,
      Assay_SIC,
      Type = CHROM,
      Call,
      Reads = depth,
      `% of Total Reads` = per_total,
      `% of Total HPV Reads` = per_hpv
    ) %>%
    glimpse()
  
  , run_id = parse_key_value(file.path("./raw_metrics", "expMeta.dat"))[["Analysis Name"]]
  
  , tar_target(run_id_full.csv, new_out %>% 
                 save_to_csv(sprintf("%s.full.csv", run_id)),
               format="file")
  # write %s.laboratory.csv if is for clinical
  
  , run_id_lab.csv = ifelse(is_clinical,
          new_out %>% 
                 filter(Control) %>% 
                 save_to_csv(sprintf("%s.laboratory.csv", run_id)),
          "")
  
  ###  add samples with "fail" for the sequencing_qc
  , failed_pn_matrix_final = simple_pn_matrix_final %>% filter((overall_qc == "fail" ) & (!barcode %in% ctrl_barcodes))
  
  ### prepare results of control samples
  , specimen_control_defs_long = settings_lst$specimen_control_defs %>%
      filter(!is.na(Control_Code)) %>%
      tidyr::gather("type", "status", -Control_Code, -qc_name, -Control_type, factor_key = F) %>%
      # ignore "either" here
      filter(status != "either") %>% 
      glimpse()
  
  
  , control_results = hpv_line_pn %>%
    bind_cols(contig_pn %>% select(starts_with("B2M"))) %>%
    bind_cols(settings_lst$manifest %>% select(Owner_Sample_ID)) %>%
    gather(type, status, -barcode, -Owner_Sample_ID) %>%
    fuzzyjoin::fuzzy_join(
      specimen_control_defs_long,
      mode = "inner",
      by = c("Owner_Sample_ID" = "Control_Code", "type"),
      match_fun = list(function(x, y)
        str_detect(x, fixed(y, ignore_case = TRUE)), `==`)
    ) %>%
    mutate(control_fail = ifelse(
      status.x == status.y,
      "",
      case_when(
        is.na(status.x)   ~ "NA",
        status.x == "pos" ~ "false-pos",
        TRUE              ~ "false-neg"
      )
    )) %>%
    # to add Control_type information into control_for_reports
    group_by(barcode, Control_type) %>%
    summarise(
      control_result = ifelse(all(!is.na(status.x)) &
                                all(status.x == status.y), "pass", "fail"),
      control_fail_code = paste0(control_fail %>% unique() %>% setdiff(""), collapse = ";")
    )
  
  # Adding manifest to the final results
  # also add B2M and ASIC columns, num_types_pos
  , control_results_final = settings_lst$manifest %>%
      # add extra internal control status for QC/QA
      bind_cols(contig_pn %>% select(all_of(SIC_NAMES), all_of(HC_NAMES))) %>%
      inner_join(sample_pn_final) %>%
      inner_join(control_results) %>%
      inner_join(hpv_line_pn)
  
  , control_for_report = control_results_final
  # , tar_target(control_for_report, control_results_final %>%
  #                save_to_csv("control_for_report"),
  #              format="file")
  
  ### sample only (exclude control sample)
  , samples_only_pn_matrix = simple_pn_matrix_final %>%
    filter(!barcode %in% ctrl_barcodes)
  
  # special case samples_only_pn_matrix is empty
  , samples_only_for_report = {
      if(nrow(samples_only_pn_matrix) == 0) 
          samples_only_pn_matrix
      else
          samples_only_pn_matrix %>% inner_join(read_counts %>% select(barcode, total_reads))
  }
  #, tar_target(samples_only_for_report_fn, save_to_csv(samples_only_for_report, "samples_only_for_report"), format="file")
  
  ### Identify lineage
  , lineage_final = def_lineage(variants_info$variants.df, settings_lst$lineage_defs, all_pn, hpv_line_pn, settings_lst$manifest, sample_pn_final)
  
  , lineage_for_report = lineage_final
  
  #write.csv(lineage_final, "lineage_for_report")
  # , tar_target(lineage_for_report.fn, lineage_final %>% 
  #              save_to_csv( "lineage_for_report"),
  #            format="file")
  
  ### Generate results for each batch
  ### add two columns after Project in simple_pn_matrix_final
  , startplugin = my_parse_json("startplugin.json", "./") 
  , simple_pn_matrix_final2 = tibble::add_column(simple_pn_matrix_final, 
                                                chipBarcode=startplugin$expmeta$chipBarcode,
                                                run_date = startplugin$expmeta$run_date, .after = 'Project')
  , write_batch = settings_lst$manifest$Assay_Batch_Code %>% 
    unique() %>% map(function(i) {
      print(i)
      write_batch_csv(read_counts_final,
                      i,
                      "read_counts_matrix_results.csv")
      # write_batch_csv(pn_filters, i, "pn_filters_report")
      write_batch_csv(deatiled_pn_matrix_for_report1,
                      i,
                      "detailed_pn_matrix_results.csv")
      
      write_batch_csv(simple_pn_matrix_final2, i, "pn_matrix_results.csv")
      write_batch_csv(failed_pn_matrix_final,
                      i,
                      "failed_samples_pn_matrix_results.csv")
      write_batch_csv(control_results_final, i, "control_results.csv")
      write_batch_csv(lineage_final, i, "lineage_filtered_results.csv")
      
      if (nrow(samples_only_pn_matrix) > 0) {
        write_batch_csv(
          read_counts_final %>%
            filter(!is.na(Owner_Sample_ID)),
          i,
          "samples_only_matrix_results.csv"
        )
      }
      
      if (is_clinical) {
        write_batch_csv(
          simple_pn_matrix_final2 %>% select(-starts_with("HPV"), -Num_Types_Pos),
          i,
          "pn_matrix_results.laboratory.csv"
        )
      }
    })
     
  ## render report
  , tar_render(qc_report,
             path = sprintf("%s/inst/TypeSeq2_QC_template.Rmd", TARGETS_ROOT),
             output_file="TypeSeq2HPV_QC_report.pdf",
             output_dir = "./",
             intermediates_dir="./",
             clean = T,
             params = list(is_clinical = is_clinical, for_batch=F)
             )
  ### render batch report
  , batch_df = data.frame( batch_id= unique(settings_lst$manifest$Assay_Batch_Code), is_clinical=is_clinical, for_batch=T) %>%
    mutate(
           output_file=sprintf("%s_TypeSeq2HPV_QC_report.pdf", batch_id)
           )

  , tar_render_rep(batch_report,
                   path = sprintf("%s/inst/TypeSeq2_QC_template.Rmd", TARGETS_ROOT), 
                   output_dir = "./",
                   intermediates_dir="./",
                   clean = T,
                   params = batch_df)
  
  ### 10. generate grouped pn_matrix (as defined, like Carcinogenic, CVT, etc)
  # saved as masked.csv (could be none if not available)
  , grouped_outputs = get_grouped_df(simple_pn_matrix_final, settings_lst$grouping_defs)
  
  ### 11. collect run matrics
  , run_metrics = collect_metrics(settings_lst, samples_only_for_report, detailed_pn_matrix_for_report, control_for_report)
  
  ### 12. Other post-typing actions
  , post_status = post_typing(settings_lst, run_metrics)
  
  ### 13. render the html page
  , tar_render(html_page,
               path = sprintf("%s/inst/torrent_server_html_block.Rmd", TARGETS_ROOT),
               output_dir = "./",
               intermediates_dir="./",
               clean = T,
               params = list(is_clinical = is_clinical)
  )
)
