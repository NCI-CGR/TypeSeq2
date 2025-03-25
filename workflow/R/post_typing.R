############################################################
# defines functions for compress, encryption and offload
############################################################
run_cmd <- function(cmd) {
  cat (sprintf("Run: %s\n", cmd))
  rv <- system(cmd)
  return(rv)
}

post_typing <- function(settings_lst, run_metrics) {
  names_by_batches <- gsub(",", "_", run_metrics$Assay_Batch_Code)
  
  # renameing read summary
  orig_fn <- "read_summary.csv"
  new_fn <- sprintf(
    "%s.read_summary.csv",
    names_by_batches
  )
  run_cmd(sprintf("cp %s %s", orig_fn, new_fn)) # use cp to keep the original file for the time being
  
  # make zip file
  run_cmd(sprintf("zip -r TypeSeq2_outputs.zip *.read_summary.csv *results.csv *QC_report.pdf *.batch_metrics_summary.csv *.run_metrics.csv Scaled_min-filters.csv control_definitions barcode_file grouping_file typing_manifest.csv *.full.csv %s.Table*.csv %s.*_plot_data.csv", get_output_prefix(), get_output_prefix() ))
  
  ### extra codes for Offload and encryption
  if (!is.na(settings_lst$is_clinical)) {
    # clinical modes
    
    # zip file for the lab
    run_cmd(
      "zip -r TypeSeq2_outputs.laboratory.zip *.read_summary.csv *control_results.csv  *failed_samples_pn_matrix_results.csv *-pn_matrix_results.laboratory.csv *laboratory_report.pdf  control_definitions barcode_file grouping_file typing_manifest.csv *.laboratory.csv "
    )
    
    # encrypt the zip file
    gpg_status <- run_cmd(
      sprintf(
        "gpg -e -R %s --batch --yes -o TypeSeq2_outputs.zip.pgp TypeSeq2_outputs.zip",
        settings_lst$is_clinical
      )
    )
    
    if (gpg_status == 0 || gpg_status == 2) {
      # remove the unencrypted files containing clinical outcomes
      run_cmd(
        " ls *.Table*.csv *.full.csv *QC_report.pdf *_plot_data.csv *results.csv TypeSeq2_outputs.zip | grep -v -e control_results.csv -e failed_samples_pn_matrix_results.csv | xargs rm -f "
      )
    }
    # # hide all files by default
    # system("chmod -R  go-rxw *")
    # system("chmod go+r drmaa_stdout.txt") # allow to view log file via web portal
    
    # # allow the selected files to view
    # system("chmod go+r TypeSeq2_outputs.zip.pgp TypeSeq2_outputs.laboratory.zip *laboratory_report.pdf")
    
    if (!is.na(settings_lst$offload)) {
      # Running at CGR lab as TypeSeq2_IMS
      cat("Running at the CGR lab in clinical mode!\n")
      
      folders <- unlist(strsplit(settings_lst$offload, split = ','))
      
      print(folders)
      
      ### Transfer files to the target folders
      # cp *-control_results.csv *-pn_matrix_results.laboratory.csv to $folder1
      run_cmd(
        sprintf(
          "cp *-control_results.csv *-pn_matrix_results.laboratory.csv %s",
          folders[1]
        )
      )
      
      # make new folder $folder2/<run_id>/plugin_out/ and copy TypeSeq2_outputs.laboratory.zip file there
      # TS2B0000219.run_metrics.csv:"Analysis_Name","Auto_user_S5XL-0040-271-T00062845_PC_NP0626-TS9_TS2B0000219_720"
      new_dir <- sprintf("%s/%s/plugin_out",
                         folders[2],
                         run_metrics$Analysis_Name)
      run_cmd(
        sprintf(
          "mkdir -p %s && cp TypeSeq2_outputs.laboratory.zip %s",
          new_dir,
          new_dir
        )
      )
      
      
      # copy encrypted file to $folder3 /CGF/Sequencing/Analysis/ion_projects/TypeSeq2_IMS_Encrypted_Results
      # rename TypeSeq2_outputs.zip.pgp to TypeSeq2_outputs_TS2B0000238_TS2B0000248.zip.pgp
      # gsub(",", "_", metrics$Assay_Batch_Code)
      run_cmd(
        sprintf(
          "cp TypeSeq2_outputs.zip.pgp %s/TypeSeq2_outputs_%s.zip.pgp",
          folders[3],
          names_by_batches
        )
      )
    }
  } else{
    # non-clinical mode:
    if (!is.na(settings_lst$offload)) {
      # Running at CGR lab as TypeSeq2
      cat("Running at the CGR lab in non-clinical mode!\n")
      folders <- unlist(strsplit(settings_lst$offload, split = ','))
      
      ### Transfer files to the target folders
      # cp *-control_results.csv *-pn_matrix_results.csv to $folder1
      # system(sprintf("cp *-control_results.csv *-pn_matrix_results.csv %s", folders[1]))
      
      # revise: <batchid>-samples_only_matrix_results.csv <batchid>-control_results.csv
      run_cmd(
        sprintf(
          "cp *-control_results.csv *-samples_only_matrix_results.csv %s",
          folders[1]
        )
      )
      
      # make new folder $folder2/<run_id>/plugin_out/ and copy TypeSeq2_outputs.zip file there
      new_dir <- sprintf("%s/%s/plugin_out",
                         folders[2],
                         run_metrics$Analysis_Name)
      run_cmd(sprintf(
        "mkdir -p %s && cp TypeSeq2_outputs.zip %s",
        new_dir,
        new_dir
      ))
    }
  }
  return(0)
}