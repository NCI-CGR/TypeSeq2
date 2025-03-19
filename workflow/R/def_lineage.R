def_lineage <- function(variants, lineage_df, all_pn, hpv_line_pn, mm, pn_sample2) {
  lineage_all <- variants %>%
    inner_join(lineage_df,
               by = c("CHROM", "POS", "REF", "ALT"),
               relationship =
                 "many-to-many") %>%
    mutate(AF = as.double(AF)) %>%
    mutate(qc_reason = "") %>%
    mutate(qc_reason = ifelse(
      SRF >= min_coverage_pos,
      qc_reason,
      paste0(qc_reason, ";", "min_coverage_pos")
    )) %>%
    mutate(qc_reason = ifelse(
      SRR >= min_coverage_neg,
      qc_reason,
      paste0(qc_reason, ";", "min_coverage_neg")
    )) %>%
    mutate(qc_reason = ifelse(
      SAF >= min_allele_coverage_pos,
      qc_reason,
      paste0(qc_reason, ";", "min_allele_coverage_pos")
    )) %>%
    mutate(qc_reason = ifelse(
      SAR >= min_allele_coverage_neg,
      qc_reason,
      paste0(qc_reason, ";", "min_allele_coverage_neg")
    )) %>%
    mutate(qc_reason = ifelse(
      QUAL >= min_qual,
      qc_reason,
      paste0(qc_reason, ";", "min_qual")
    )) %>%
    mutate(qc_reason = ifelse(
      STB <= max_alt_strand_bias,
      qc_reason,
      paste0(qc_reason, ";", "max_alt_strand_bias")
    )) %>%
    mutate(qc_reason = ifelse(AF >= min_freq, qc_reason, paste0(qc_reason, ";", "min_freq"))) %>%
    mutate(qc_reason = ifelse(AF <= max_freq, qc_reason, paste0(qc_reason, ";", "max_freq"))) %>%
    mutate(qc_reason = ifelse(FILTER == "PASS", qc_reason, paste0(qc_reason, ";", FILTER))) %>%
    mutate(qc_reason = ifelse(qc_reason == "", "Pass", qc_reason)) %>%
    mutate(AF = ifelse(qc_reason == "Pass", AF, 0)) %>%
    group_by(barcode, Lineage_ID) %>%
    mutate(new_res = sum(qc_reason == "Pass")) %>%
    mutate(lineage_status = ifelse(qc_reason == "Pass" &
                                     new_res == def_count, 1, 0))
  
  ### Join with simple_pn_matrix_long to acquire the status from simple pn
  simple_pn_matrix_long <- gather(hpv_line_pn, key = "simple.id", value =
                                    "simple.status", -barcode)
  
  lineage_filtered_pass <- lineage_all %>%
    select(barcode,
           CHROM,
           POS,
           REF,
           ALT,
           Lineage_ID,
           AF,
           def_count,
           lineage_status) %>%
    filter(lineage_status == 1) %>%
    # to have additional dp status which is assigned to CHROM
    left_join(
      all_pn %>% gather("CHROM", "status", starts_with("HPV"), factor_key = F) %>% select(barcode, CHROM, status),
      by = c("barcode", "CHROM")
    ) %>%
    # now we required all have "pos" status to "pass"
    group_by(barcode, Lineage_ID) %>%
    # add status from simple_pn here
    mutate(simple.id = gsub("_.*", "", Lineage_ID)) %>%
    left_join(simple_pn_matrix_long, by = c("barcode", "simple.id")) %>%
    filter(sum(status == "pos") == def_count &
             simple.status == "pos") %>%
    mutate(AF = min(AF)) %>%
    # there is no need for CHROM, POS, REF, ALT any more
    select(barcode, Lineage_ID, AF) %>%
    unique()
  
  # we just need to create a AF matrix with 0 by default, filled with AF values from
  lineage_ids <- lineage_df$Lineage_ID %>%
    unique() %>%
    str_sort(numeric = T)
  
  lineage_for_report <- .make_df(lineage_filtered_pass, list(mm$barcode, lineage_ids), 0)
  
  # Join manifest to add all the information
  # add qc column from pn_sample2
  
  
  lineage_final <- mm %>%
    bind_cols(pn_sample2 %>% select(overall_qc:Assay_SIC)) %>%
    bind_cols(lineage_for_report)
  
  row.names(lineage_final) <- NULL
  write.csv(lineage_final, "lineage_for_report")
  
  return(lineage_final)
}