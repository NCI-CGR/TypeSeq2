#### A. load packages ####
library(TypeSeq2)
library(drake)
library(tidyverse)
library(parallel)
library(rmarkdown)
library(furrr)
library(future)
library(fs)
library(jsonlite)
library(optigrab)
library(magrittr)

drake::clean("variants_final_table")

command_line_args = tibble(
    manifest = optigrab::opt_get('manifest'),
    control_definitions = optigrab::opt_get('control_definitions'),
    grouping_defs = optigrab::opt_get('grouping_defs'),
    barcode_file = optigrab::opt_get('barcode_file'),
    tvc_parameters = optigrab::opt_get('tvc_parameters'),
    reference = optigrab::opt_get('reference'),
    region_bed = optigrab::opt_get('region_bed'),
    hotspot_vcf = optigrab::opt_get('hotspot_vcf'),
    is_torrent_server = optigrab::opt_get('is_torrent_server'),
    is_clinical = optigrab::opt_get('is_clinical'),
    start_plugin = optigrab::opt_get('start_plugin'),
    config_file = optigrab::opt_get('config_file'),
    config_set = optigrab::opt_get('config_set'), # this option is ignored in the server mode
    lineage_defs = optigrab::opt_get('lineage_defs'),
    scaling_table = optigrab::opt_get('scaling_table'),
    pn_filters = optigrab::opt_get('pn_filters'),
    internal_control_defs = optigrab::opt_get('internal_control_defs'),
    ram = optigrab::opt_get('ram'),
    cores = optigrab::opt_get('cores'),
    tvc_cores = optigrab::opt_get('tvc_cores'),
    filteringTable = optigrab::opt_get('filteringTable')) %>%
    glimpse()

#### Define workers
future::plan(multiprocess)

# num_cores = availableCores() - 1
num_cores = availableCores(methods="system") - 1

tvc_cores <- as.numeric(command_line_args$tvc_cores)

if(is.null(tvc_cores)){
	tvc_scores <- 4
}

# workers <- floor(num_cores/tvc_cores)
workers <- num_cores - 1


vcf_file_func <- function(sorted_bam, args_df){
    tmp_workers <- floor(num_cores/tvc_cores)
        plan_workers(tmp_workers, num_cores)
 
        rv <- sorted_bam %T>%
        map_df(~ system(paste0("cp ", args_df$reference, " ./"))) %T>%
        map_df(~ system(paste0("samtools faidx ", basename(args_df$reference)))) %>%
        split(.$sample) %>%
        future_map_dfr(tvc_cli, args_df) %>%
        glimpse()

        plan_workers(workers, num_cores)
        rv      
}

plan_workers <- function(workers, num_cores){
    if(is.null(workers) || workers<1){
	    workers <- 1
    }
    cat(sprintf("Number of cores: %d and workers: %d \n", num_cores, workers))
    future::plan(multicore, workers = workers)
}




#### B. create workflow plan ####
pkgconfig::set_config("drake::strings_in_dots" = "literals")
ion_plan <- drake::drake_plan(

    #### 1. adjust command line arguments ####
    args_df = get_command_line_args(command_line_args) %>%
        glimpse(),

    #### 2. parse plugin data ####
    user_files = startplugin_parse(args_df) %>%
        glimpse(),

    #### 3. demux bams ####
    demux_bam = adam_demux(user_files, args_df$ram, args_df$cores) %>%
        glimpse(),

    #### 4. split, sort, and index bams ####
    sorted_bam = demux_bam %>%
        split(.$sample) %>%
        future_map_dfr(samtools_sort) %>%
        glimpse(),

    #### 5. run tvc on demux bams ####
    vcf_files = vcf_file_func(sorted_bam, args_df), 

    #### 6. merge vcf files in to 1 table ####
    variant_table = vcf_files %>%
        filter(file_exists(vcf_out)) %>%
        split(.$vcf_out) %>%
        future_map_dfr(vcf_to_dataframe) %>%
        glimpse() %>%
        mutate_if(numCheck, ~ as.numeric(.)) %>%
        mutate(barcode = str_sub(filename, 5, 10)) %>%
        glimpse() %>%
        write_csv("variant_table.csv"),

    #### 7. joining variant table with sample sheet and write to file ####
    # variants_final_table = typing_variant_filter(variants = variant_table,
    #                                              lineage_defs = args_df$lineage_defs,
    #                                              manifest = user_files$manifest,
    #                                              specimen_control_defs = user_files$control_definitions,
    #                                              internal_control_defs = args_df$internal_control_defs,
    #                                              pn_filters = args_df$pn_filters,
    #                                              scaling_table = args_df$scaling_table, args_df$is_clinical == "yes" ) ,
    
    variants_final_table = typing_variant_filter2(variants=variant_table, args_df, user_files),
    #### 8. generate qc report ####
    ion_qc_report = render_ion_qc_report(variants_final_table = variants_final_table,
                                         args_df = args_df,
                                         manifest = user_files$manifest,
                                         control_for_report = read.csv("control_for_report"),
                                         samples_only_for_report = read.csv("samples_only_for_report"),
                                         detailed_pn_matrix_for_report = read.csv("detailed_pn_matrix_report"),
                                         read_count_matrix_report = read.csv("read_count_matrix_report"),
                                         pn_filters = read.csv("pn_filters_report"),
                                         specimen_control_defs = user_files$control_definitions,
                                         lineage_for_report = read.csv("lineage_for_report") ) ,

    #### 9. render_batch_qc_report
    ion_batch_report = render_batch_qc_report(variants_final_table = variants_final_table,
                                         args_df = args_df,
                                         manifest = user_files$manifest,
                                         control_for_report = read.csv("control_for_report"),
                                         samples_only_for_report = read.csv("samples_only_for_report"),
                                         detailed_pn_matrix_for_report = read.csv("detailed_pn_matrix_report"),
                                         read_count_matrix_report = read.csv("read_count_matrix_report"),
                                         pn_filters = read.csv("pn_filters_report"),
                                         specimen_control_defs = user_files$control_definitions,
                                         lineage_for_report = read.csv("lineage_for_report") ) ,

    #### 10. generate grouped pn_matrix           
    grouped_outputs = get_grouped_df(simple_pn_matrix_final = read.csv("pn_matrix_for_groupings"),
                                     groups_defs = user_files$grouping_defs,
                                     ion_qc_report = ion_qc_report),

    ### 11. collect run matrics
    run_metrics = collect_metrics(user_files, variants_final_table)


)  

#### C. execute workflow plan ####
system("mkdir vcf")


# future::plan(multicore, workers = workers)
plan_workers(workers, num_cores)

drake::make(ion_plan)


### Rename read_summary.csv
new_fn <- renaming_read_summary(readd(user_files))

### Compress file here
# include more files here
system(sprintf("zip -r TypeSeq2_outputs.zip *.read_summary.csv *results.csv *QC_report.pdf *.batch_metrics_summary.csv *.run_metrics.csv Scaled_min-filters.csv control_definitions barcode_file grouping_file typing_manifest.csv *.full.csv %s.Table*.csv %s.*_plot_data.csv", get_output_prefix(), get_output_prefix() ))

if( ! is.na(command_line_args$is_clinical) ){
    # zip file for the lab
    system("zip -r TypeSeq2_outputs.laboratory.zip *.read_summary.csv *control_results.csv  *failed_samples_pn_matrix_results.csv *-pn_matrix_results.laboratory.csv *laboratory_report.pdf  control_definitions barcode_file grouping_file typing_manifest.csv *.laboratory.csv ")

    # encrypt the zip file
    system(sprintf("gpg2 -e -R %s --batch --yes -o TypeSeq2_outputs.zip.pgp TypeSeq2_outputs.zip", command_line_args$is_clinical ))

    # hide all files by default
    system("chmod -R  go-rxw *")

    # allow the selected files to view
    system("chmod go+r TypeSeq2_outputs.zip.pgp TypeSeq2_outputs.laboratory.zip *laboratory_report.pdf")
}

#### E. make html block for torrent server ####
html_block = if ( command_line_args$is_torrent_server == "yes") {
    # system("cp /TypeSeq2/inst/typeseq2/torrent_server_html_block.R ./")
    system(paste0("cp ", system.file("typeseq2", "torrent_server_html_block.R",  package = "TypeSeq2"), " ./"))

    render("./torrent_server_html_block.R", output_dir = "./", params = list(is_clinical = !is.na(command_line_args$is_clinical)))
}


### Clean .drake if the drake workflow is completed successfully
if (length(failed()) == 0){
    cache <- get_cache()
    cache$destroy()
}
