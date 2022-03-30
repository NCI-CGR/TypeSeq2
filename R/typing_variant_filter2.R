#+

typing_variant_filter2 <- function(variants, args_df, user_files) {
  # Interface to match with the old function
  lineage_defs <- args_df$lineage_defs
  manifest <- user_files$manifest
  specimen_control_defs <- user_files$control_definitions
  internal_control_defs <- args_df$internal_control_defs
  pn_filters <- args_df$pn_filters
  scaling_table <- args_df$scaling_table
  is_clinical <- args_df$is_clinical == "yes"
  min_reads_per_sample <- args_df$min_reads_per_sample %>% .convert_numeric_config()
  min_hpv_reads_per_sample <- args_df$min_hpv_reads_per_sample %>% .convert_numeric_config()

  # add manifest to variants table ----
  mm <- manifest %>%
    unite("barcode", BC1, BC2, sep = "") %>%
    mutate_if(is.factor, ~ as.character(.))

  barcode2sample_id <- mm %>%
    select(barcode, Owner_Sample_ID) %>%
    deframe()

  contigs <- variants %>%
    filter(HS == 1) %>%
    pull(CHROM) %>%
    unique() %>%
    str_sort(numeric = T)

  hpv_ids_in_order <- str_sort(contigs %>% grep("^HPV", ., v = T), numeric = T)
  hpv_lines_in_order <- hpv_ids_in_order %>%
    gsub("_.*", "", .) %>%
    unique() %>%
    str_sort(numeric = T)


  ## empty_cnt <- expand.grid(
  ##   barcode = mm$barcode %>% unique(), CHROM = contigs,
  ##   depth = 0, stringsAsFactors = F
  ## )

  dp_df <- variants %>%
    filter(HS == 1) %>%
    group_by(barcode, CHROM) %>%
    summarize(depth = max(c(0, DP), na.rm = T))

  # "Owner_Sample_ID" "barcode"         "total_reads"
  dp_full_df <- .make_df(dp_df, list(mm$barcode, contigs)) %>%
    mutate(total_reads = rowSums(.), hpv_reads = select(., starts_with("HPV")) %>% rowSums())

  read_counts_matrix_wide <- mm %>%
    select(Owner_Sample_ID, barcode) %>%
    bind_cols(dp_full_df)


  # Match the same row order with manifest
  ## read_counts_matrix_wide <- mm %>%
  ##   inner_join(variants %>% filter(HS), by = "barcode") %>%
  ##   group_by(barcode, CHROM) %>%
  ##   summarize(depth = max(c(0, DP), na.rm = T)) %>%
  ##   bind_rows(empty_cnt) %>%
  ##   group_by(barcode, CHROM) %>%
  ##   summarize(depth = max(depth)) %>%
  ##   group_by(barcode) %>%
  ##   mutate(total_reads = sum(depth, na.rm = T)) %>%
  ##   spread(CHROM, depth, fill = 0) %>%
  ##   mutate(Owner_Sample_ID = barcode2sample_id[barcode]) %>%
  ##   select(Owner_Sample_ID, everything()) %>%
  ##   ungroup() %>%
  ##   mutate(hpv_reads = select(., starts_with("HPV")) %>% rowSums()) %>%
  ##   arrange(match(barcode, mm$barcode))

  read_counts_matrix_long <- read_counts_matrix_wide %>% gather(CHROM, depth, -total_reads, -hpv_reads, -Owner_Sample_ID, -barcode)


  read_count_matrix_report <- read_counts_matrix_wide %>%
    gather(HPV_Type, HPV_Type_count, -barcode, -total_reads, -hpv_reads, -Owner_Sample_ID, -`ASIC-Low`, -`ASIC-High`, -`ASIC-Med`, -`B2M-S2`, -`B2M-S`) %>%
    write.csv("read_count_matrix_report")

  # Rearranging column names to match the order of contigs in variant file.
  read_counts_matrix_wide_final <- mm %>%
    full_join(read_counts_matrix_wide[, str_sort(colnames(read_counts_matrix_wide), numeric = T)] %>%
      select(barcode, Owner_Sample_ID, total_reads, hpv_reads, `ASIC-Low`, `ASIC-Med`, `ASIC-High`, `B2M-S2`, `B2M-S`, everything()))


  cat("Scale the filters ... \n")

  # scale the filters - calculate the average reads per sample ----
  average_read_count <- mean(read_counts_matrix_wide$total_reads)

  scaling_factor <- read.csv(scaling_table, as.is = T) %>%
    filter(min_avg_reads_boundary <= average_read_count & max_avg_reads_boundary >= average_read_count) %>%
    pull(scaling_factor)

  cat("Load internal controls ... \n")

  # read in internal controls ----
  # ASIC-Low without checking name
  icd_df <- read.csv(internal_control_defs, as.is = T, check.names = F) %>% glimpse()

  # read in pn_filters ----
  # !!! pn_filters <- "/user_files/configs/TypeSeq2_Pos-Neg_matrix_filtering_criteria_T90-v2-ref_v1_EXTENDED.csv"
  pn_filter_df <- read.csv(pn_filters, as.is = T) %>%
    glimpse() %>%
    rename(CHROM = contig) %>%
    mutate(Min_reads_per_type = Min_reads_per_type * scaling_factor)

  # pn_filters will be used in signal_to_noise_plot
  write.csv(pn_filter_df, "pn_filters_report")


  # make detailed pn matrix ----

  # pn_sample should be in the same order as read_counts_matrix_wide and manifest
  pn_sample <- read_counts_matrix_wide %>%
    mutate(sequencing_qc = ifelse(total_reads >= min_reads_per_sample, "pass", "fail"), human_control = ifelse(hpv_reads >= min_hpv_reads_per_sample, "pass", NA)) %>%
    select(Owner_Sample_ID, barcode, sequencing_qc, human_control)

  ### pn_wide has all the internal control columns
  # join pn_sample first and reset depth of HPV amplicons to 0 if sequencing_qc is failed
  pn_wide <- (read_counts_matrix_long %>% inner_join(pn_sample %>% select(barcode, sequencing_qc), by = "barcode") %>% mutate(depth = ifelse(grepl("^HPV", CHROM) & sequencing_qc == "fail", 0, depth))) %>%
    inner_join(pn_filter_df, by = "CHROM") %>%
    mutate(status = ifelse(depth >= Min_reads_per_type & depth / total_reads >= Min_perc_per_type, "pos", "neg")) %>%
    glimpse() %>%
    select(-depth, -total_reads, -hpv_reads, -Min_reads_per_type, -Min_perc_per_type) %>%
    spread(CHROM, status) %>%
    .align_by_barcode(mm$barcode)


  sic_names <- c("ASIC-Low", "ASIC-Med", "ASIC-High")
  hc_names <- c("B2M-S", "B2M-S2")


  pn_sample$`Assay_SIC` <- pn_wide %>%
    unite(sic, one_of(sic_names)) %>%
    left_join(icd_df %>% unite(sic, one_of(sic_names)), by = "sic") %>%
    pull(qc_print)

  pn_sample$human_control <- coalesce(pn_sample$human_control, pn_wide %>% unite(human_control, one_of(hc_names)) %>% left_join(icd_df %>% unite(human_control, one_of(hc_names)), by = "human_control") %>% pull(qc_print))


  # Override step: assign HPV as neg if human control is failed to amplify
  pn_wide2 <- pn_wide %>%
    mutate_at(vars(starts_with("HPV")), ~ ifelse(pn_sample$human_control == "failed_to_amplify", "neg", .)) %>%
    select(barcode, one_of(hpv_ids_in_order))

  # assign line_id to pn_long

  pn_long <- pn_wide2 %>%
    tidyr::gather("type_id", "type_status", starts_with("HPV")) %>%
    mutate(line_id = gsub("_.*", "", type_id))

  # make simple pn matrix from pn_long
  # pn_wide2_line == simple_pn_matrix
  pn_wide2_line <- pn_long %>%
    group_by(barcode, line_id) %>%
    summarise(sum_status = sum(type_status == "pos", na.rm = T)) %>%
    mutate(simple_status = case_when(
      sum_status >= 2 & line_id %in% c("HPV16", "HPV18") ~ "pos",
      sum_status >= 1 & (!line_id %in% c("HPV16", "HPV18")) ~ "pos",
      TRUE ~ "neg"
    )) %>%
    select(-sum_status) %>%
    spread(line_id, simple_status) %>%
    select(barcode, one_of(hpv_lines_in_order)) %>%
    .align_by_barcode(mm$barcode) %>%
    glimpse()

  ### barcode sequencing_qc human_control Assay_SIC are available in pn_sample
  ### Order columns in this way: num_types_pos, sequencing_qc, human_control, and Assay_SIC columns
  pn_sample2 <- pn_sample %>%
    mutate(Num_Types_Pos = rowSums(pn_wide2_line[, -1] == "pos")) %>%
    select(Owner_Sample_ID, barcode, Num_Types_Pos, sequencing_qc, human_control, Assay_SIC)

  # pn_sample2 + pn_wide2 => make detailed pn matrix (no ASIC or B2M as requested by Sarah)
  detailed_pn_matrix <- pn_sample2 %>%
    bind_cols(pn_wide %>% select(one_of(sic_names), one_of(hc_names))) %>%
    left_join(pn_wide2, by = "barcode") %>%
    glimpse()
  write.csv(detailed_pn_matrix, "detailed_pn_matrix_report")

  #  print("line 110")

  # with more information from manifest file (used at the end of this function)
  deatiled_pn_matrix_for_report1 <- mm %>% inner_join(detailed_pn_matrix, by = c("barcode", "Owner_Sample_ID"))




  # Creating positive-negative matrix
  # Add additional informaiton from
  simple_pn_matrix_final <- mm %>%
    left_join(pn_sample2, by = c("Owner_Sample_ID", "barcode")) %>%
    left_join(pn_wide2_line)

  write.csv(simple_pn_matrix_final, "pn_matrix_for_groupings")

  print("line 148")

  # Creating a list of failed non-control samples
  ctrl_barcodes <- mm %>%
    fuzzyjoin::fuzzy_join(specimen_control_defs,
      mode = "inner",
      by = c("Owner_Sample_ID" = "Control_Code"), match_fun = function(x, y) str_detect(x, fixed(y, ignore_case = TRUE))
    ) %>%
    pull(barcode)

  ###  add samples with "fail" for the sequencing_qc
  failed_pn_matrix_final <- simple_pn_matrix_final %>% filter((human_control == "failed_to_amplify" | sequencing_qc == "fail") & (!barcode %in% ctrl_barcodes))

  # 2.  merge pn matrix with control defs (b2m + hpv)
  # add: "Control_Code","control_fail_code","control_result"

  print("line 158")
  specimen_control_defs_long <- specimen_control_defs %>%
    filter(!is.na(Control_Code)) %>%
    tidyr::gather("type", "status", -Control_Code, -qc_name, -Control_type, factor_key = F) %>%
    glimpse()

  # barcode control_result control_fail_code
  control_results <- pn_wide2_line %>%
    bind_cols(pn_wide %>% select(starts_with("B2M"))) %>%
    bind_cols(mm %>% select(Owner_Sample_ID)) %>%
    gather(type, status, -barcode, -Owner_Sample_ID) %>%
    fuzzyjoin::fuzzy_join(specimen_control_defs_long,
      mode = "inner",
      by = c("Owner_Sample_ID" = "Control_Code", "type"), match_fun = list(
        function(x, y) str_detect(x, fixed(y, ignore_case = TRUE)),
        `==`
      )
    ) %>%
    mutate(control_fail = ifelse(status.x == status.y, "", ifelse(status.x == "pos", "false-pos", "false-neg"))) %>%
    group_by(barcode) %>%
    summarise(control_result = ifelse(all(status.x == status.y), "pass", "fail"), control_fail_code = paste0(control_fail %>% unique() %>% setdiff(""), collapse = ";"))

  # Adding manifest to the final results
  # also add B2M and ASIC columns, num_types_pos
  control_results_final <- mm %>%
    # add extra internal control status for QC/QA
    bind_cols(pn_wide %>% select(one_of(sic_names), one_of(hc_names))) %>%
    inner_join(pn_sample2) %>%
    inner_join(control_results) %>%
    inner_join(pn_wide2_line)

  control_for_report <- control_results_final # no change
  write.csv(control_for_report, "control_for_report")


  print("Working on samples_only_pn_matrix ...")

  ### generate samples_only_pn_matrix from simple_pn_matrix_final
  # samples_only_pn_matrix = simple_pn_matrix[!(simple_pn_matrix$barcode %in% control_results_final$barcode),]

  samples_only_pn_matrix <- simple_pn_matrix_final %>%
    filter(!barcode %in% control_results_final$barcode) %>%
    glimpse()

  # Adding this to support runs with no samples

  if (nrow(samples_only_pn_matrix) > 0) {
    samples_only_pn_matrix_final <- samples_only_pn_matrix

    # add total count, human control, Num_Types_Pos
    samples_only_for_report <- samples_only_pn_matrix %>%
      inner_join(read_counts_matrix_wide %>% select(barcode, total_reads)) %>%
      inner_join(pn_sample2 %>% select(barcode, human_control, Num_Types_Pos))

    write_csv(samples_only_for_report, "samples_only_for_report")
  } else {
    # output the empty table
    write_csv(samples_only_pn_matrix, "samples_only_for_report")
  }


  # # identify lineages ----
  cat("\nIdentify lineages ... \n")

  lineage_df <- read.csv(lineage_defs, as.is = T) %>%
    rename(CHROM = Chr, POS = Base_num, REF = Base_ID, ALT = vcf_variant) %>%
    group_by(Lineage_ID) %>%
    mutate(def_count = n())

  # Counting the lineages per type here. Later this can be used to check if a sample has all the lineages.

  # Classifying as pass or fail based on set filters
  # assign status to qc_reason based on the VCF columns
  # for each barcode and lineage ID, assign lineage_status as 1 if qc_reason is PASS and all lineage components have the right variant.

  lineage_all <- variants %>%
    inner_join(lineage_df, by = c("CHROM", "POS", "REF", "ALT")) %>%
    mutate(AF = as.double(AF)) %>%
    mutate(qc_reason = "") %>%
    mutate(qc_reason = ifelse(SRF >= min_coverage_pos, qc_reason,
      paste0(qc_reason, ";", "min_coverage_pos")
    )) %>%
    mutate(qc_reason = ifelse(SRR >= min_coverage_neg, qc_reason,
      paste0(qc_reason, ";", "min_coverage_neg")
    )) %>%
    mutate(qc_reason = ifelse(SAF >= min_allele_coverage_pos, qc_reason,
      paste0(qc_reason, ";", "min_allele_coverage_pos")
    )) %>%
    mutate(qc_reason = ifelse(SAR >= min_allele_coverage_neg, qc_reason,
      paste0(qc_reason, ";", "min_allele_coverage_neg")
    )) %>%
    mutate(qc_reason = ifelse(QUAL >= min_qual, qc_reason,
      paste0(qc_reason, ";", "min_qual")
    )) %>%
    mutate(qc_reason = ifelse(STB <= max_alt_strand_bias, qc_reason,
      paste0(qc_reason, ";", "max_alt_strand_bias")
    )) %>%
    mutate(qc_reason = ifelse(AF >= min_freq, qc_reason,
      paste0(qc_reason, ";", "min_freq")
    )) %>%
    mutate(qc_reason = ifelse(AF <= max_freq, qc_reason,
      paste0(qc_reason, ";", "max_freq")
    )) %>%
    mutate(qc_reason = ifelse(FILTER == "PASS", qc_reason,
      paste0(qc_reason, ";", FILTER)
    )) %>%
    mutate(qc_reason = ifelse(qc_reason == "", "Pass", qc_reason)) %>%
    mutate(AF = ifelse(qc_reason == "Pass", AF, 0)) %>%
    group_by(barcode, Lineage_ID) %>%
    mutate(new_res = sum(qc_reason == "Pass")) %>%
    mutate(lineage_status = ifelse(qc_reason == "Pass" & new_res == def_count, 1, 0))


  # calculate AF with only the ones which passed the filters in the last step
  # Adding detailed_pn_matrix to filter out neg result contigs from AF calculation
  lineage_ids <- lineage_df$Lineage_ID %>%
    unique() %>%
    str_sort(numeric = T)

  # lineage_filtered_pass takes avg (AF) as AF and keep one barcode
  # We need filter lineage to have all component variants with "pos" status
  ## lineage_filtered_pass <- lineage_all %>%
  ##   filter(lineage_status == 1) %>%
  ##   group_by(barcode, Lineage_ID) %>%
  ##   mutate(AF = sum(AF) / sum(lineage_status)) %>%
  ##   ungroup() %>%
  ##   left_join(detailed_pn_matrix %>% gather("CHROM", "status", starts_with("HPV"), factor_key = F) %>% select(barcode, CHROM, Owner_Sample_ID, status, Num_Types_Pos), by = c("barcode", "CHROM")) %>%
  ##   unique() %>%
  ##   filter(status != "neg") %>% #TODO filter it earlier.
  ##   select(barcode, CHROM, POS, REF, ALT, Lineage_ID, AF)

  lineage_filtered_pass <- lineage_all %>%
    select(barcode, CHROM, POS, REF, ALT, Lineage_ID, AF, def_count, lineage_status) %>%
    filter(lineage_status == 1) %>%
    # to have additional dp status which is assigned to CHROM
    left_join(detailed_pn_matrix %>% gather("CHROM", "status", starts_with("HPV"), factor_key = F) %>% select(barcode, CHROM, status), by = c("barcode", "CHROM")) %>%
    # now we required all have "pos" status to "pass"
    group_by(barcode, Lineage_ID) %>%
    filter(sum(status == "pos") == def_count) %>%
    mutate(AF = mean(AF)) %>%
    # there is no need for CHROM, POS, REF, ALT any more
    select(barcode, Lineage_ID, AF) %>%
    unique()

  # Join the passed table to original table
  # a matrix of AF*100 (barcode x Lineage_ID) with the barcode column
  # TODO a better way to make it

  # The old code is too complicate and problematic
  ## lineage_for_report <- lineage_all %>%
  ##   select(barcode, CHROM, POS, REF, ALT, Lineage_ID) %>%
  ##   full_join(lineage_filtered_pass) %>%
  ##   mutate(AF = ifelse(is.na(AF), 0, AF)) %>%
  ##   select(-CHROM, -POS, -REF, -ALT) %>%
  ##   distinct() %>%
  ##   group_by(barcode, Lineage_ID) %>%
  ##   mutate(key = row_number()) %>%
  ##   mutate(AF = round(AF * 100,1) ) %>%
  ##   spread(Lineage_ID, AF) %>%
  ##   select(-key)

  # we just need to create a AF matrix with 0 by default, filled with AF values from
  # lineage_filtered_pass
  lineage_for_report <- .make_df(lineage_filtered_pass, list(mm$barcode, lineage_ids), 0)

  # Join manifest to add all the information
  lineage_final <- mm %>% bind_cols(lineage_for_report)

  write.csv(lineage_final, "lineage_for_report")

  # Adding Assay code to all result files

  # Get the assay code

  man <- manifest %>% transform(Assay_Batch_Code = as.factor(Assay_Batch_Code), Project = as.factor(Project))
  code <- levels(unique(man$Assay_Batch_Code))
  Project_code <- levels(unique(man$Project))

  for (i in code) {
    print(i)
    write_batch_csv(read_counts_matrix_wide_final, i, "read_counts_matrix_results.csv")
    # write_batch_csv(pn_filters, i, "pn_filters_report")
    write_batch_csv(deatiled_pn_matrix_for_report1, i, "detailed_pn_matrix_results.csv")

    write_batch_csv(simple_pn_matrix_final, i, "pn_matrix_results.csv")
    write_batch_csv(failed_pn_matrix_final, i, "failed_samples_pn_matrix_results.csv")
    write_batch_csv(control_results_final, i, "control_results.csv")
    write_batch_csv(lineage_final, i, "lineage_filtered_results.csv")

    if (nrow(samples_only_pn_matrix) > 0) {
      write_batch_csv(samples_only_pn_matrix_final %>%
        filter(!is.na(Owner_Sample_ID)), i, "samples_only_matrix_results.csv")
    }

    if (is_clinical) {
      write_batch_csv(simple_pn_matrix_final %>% select(-starts_with("HPV")), i, "pn_matrix_results.laboratory.csv")
    }
  }
}
