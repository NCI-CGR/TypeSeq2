#### A. load packages ####
library(targets)
library(tarchetypes)

library(tidyverse)
library(optigrab)
library(magrittr)

# singularity exec  --pwd /mnt --bind $(pwd):/mnt --bind $(pwd)/tmp:/tmp --bind /results/plugins/TypeSeq2/pluginMedia:/user_files --bind /mnt/DCEG/CGF:/CGF docker://cgrlab/typeseq2:v2.3.0 \
# Rscript /TypeSeq2/workflows/TypeSeq2.R \
# --is_torrent_server yes \
# --offload /CGF/Laboratory/LIMS/drop-box-prod/typeseq2,/CGF/Sequencing/IonTorrent/Offload_Results_Data \
# --cores 22 \
# --ram 24G \

#  /usr/local/bin/Rscript TypeSeq2.R  --debug yes --is_torrent_server yes --user_files ./user_files/


# tar_option_set(
#   controller = crew_controller_local(workers = parallel::detectCores() -1 )
# )

# Get the directory of the currently running R script
args <- commandArgs(trailingOnly = FALSE)


# Extract the script path
script_path <- normalizePath(substring(args[grep("--file=", args)], 8))

# Get the directory path
script_dir <- dirname(script_path)
# options(TARGETS_ROOT = script_dir)
# assign("targets_root", script_dir, envir = .GlobalEnv)
Sys.setenv(TARGETS_ROOT = script_dir)
  
# Print the directory path
print(paste("The script directory is:", script_dir))

command_line_args = tibble(
    is_torrent_server = optigrab::opt_get('is_torrent_server'),
    is_clinical = optigrab::opt_get('is_clinical'),
    offload = optigrab::opt_get('offload'),
    debug = optigrab::opt_get('debug'),
    ram = optigrab::opt_get('ram'),
    cores = optigrab::opt_get('cores'),
    user_files = optigrab::opt_get('user_files'),
) 

command_line_args %>% write.csv(file="cmd.csv", row.names = F)

script_fn <- sprintf("%s/_targets_main.R", script_dir);
cat("Script name: ",script_fn, "\n")

tar_config_set(project = "TypeSeq2", script=script_fn, store = "store_main")
Sys.setenv(TAR_PROJECT="TypeSeq2")
tar_make()
# tar_renv(script = "_targets_main.R")

# library(visNetwork)
# htmltools::save_html(html = tar_visnetwork(targets_only=T) %>% 
#                        visNetwork::visHierarchicalLayout(direction = "LR"), file = "TypeSeq2_workflow.html")
# 

is_debug <- (! is.na(command_line_args$debug)) && command_line_args$debug == "yes"
if(is_debug){
  cat ("Debug mode!\n\n")
}

# Get the progress summary
progress <- tar_progress()

# Check for any errors
any_errors <- any(!is.na(progress$error))

# Check if there are no errors
no_errors <- !any_errors

# Print the result
if (no_errors) {
  print("All targets succeeded.")
}

### Clean .drake if the drake workflow is completed successfully
if (no_errors && !is_debug){
  cat("Remove all cached results ...\n")
  # unlink("store_main", recursive = TRUE)
  tar_destroy(ask=F)
}