
# TypeSeq2
***NCI CGR laboratory HPV typing analysis workflows and R package***

TypeSeq HPV is an R package that includes  

* several helper functions for working with TypeSeq data  
* contains a "make" based pipeline for processing Ion or Illumina runs  
* contains a docker build file that includes all the dependencies inside a single container  
  
We recommend running the pipeline inside the docker container ```cgrlab/typeseqhpv:final_2018080604``` as it contains all the required dependencies in the correct locations.

The workflow manager we use is **drake** https://github.com/ropensci/drake


There are currently two main workflows each supporting either the Ion Torrent or Illumina NGS platforms.  Since TypeSeqHPV can be used on either platform we therefore have analysis for either. 

The only requirement for either workflow is either ```docker``` or ```singularity```



Ion Torrent Plugin
================

We also include a wrapper for the Ion Torrent server that can be uploaded via the provided zip file.  The prerequisite for running the Ion Torrent Plugin successfully is to install docker on the server ahead of time.

## Install Docker Community Edition On Torrent Server

Following instructions posted here https://docs.docker.com/install/linux/docker-ce/ubuntu/

### Uninstall previous version

It may be required to uninstall previous version of docker.  Skip this step if no previous version of docker installed.

```
sudo apt-get remove docker docker-engine docker.io
````

### Update Package Index and Install

````
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

sudo apt-get update

sudo apt-get install -y docker-ce
````
### Post Installation Setup
  
Give plugin access to docker.
````
sudo usermod -aG docker ionadmin
sudo usermod -aG docker ionian
````

Try a hello world install test.
````
docker run hello-world
````

### Make Docker storage more robust on torrent server

Docker doesn't always clean up after itself.  Changing were docker keeps it's image layers will prevent critical partitions from filling up.  If this step is skipped after several runs of a docker plugin the Torrent Service job scheduler will stop working.

````
sudo service docker stop
sudo rm -rf  /var/lib/docker
sudo vim /etc/default/docker
````

Modify this line
````
 #DOCKER_OPTS="--dns 8.8.8.8 --dns 8.8.4.4"
````
Changing it to this
````
DOCKER_OPTS="--dns 8.8.8.8 --dns 8.8.4.4 -g /results/plugins/scratch/docker"
````
Restart Docker
````
sudo service docker start 
````


## Download and add hpv-typing plugin zip file via torrent server gui

https://github.com/cgrlab/TypeSeqHPV/releases/download/2.1808.2701/TypeSeqHPV_TSv1_Ion_Torrent_Plugin.zip

Illumina Workflow
================
### 1. Generate fastq files from raw sequencing data using modified parameters
  
The Illumina fastq files need to be regenerated using the following custom bcl2fastq parameters:  
```  
bcl2fastq --runfolder-dir [location of run directory (local or networked drive) ]  
--output-dir [ any directory]  
--with-failed-reads  
--minimum-trimmed-read-length 11  
--mask-short-adapter-reads 11  
```  

This should generate two new fastq files, one for R1 and one for R2. Any version of bcl2fastq higher than  
2.19 should work.
  
### 2. Create New Directory for The Project  

The pre-built image, cwl file, and helper bash script are hosted in an archive on the NIH HPC at `https://hpc.nih.gov/~robersondw/TypeSeqerHPV_0.18.314.tar.gz`

The workflow will need to utilize a fresh working directory. Make sure that the contents of
`typeseqerHPV.0.18.31403.simg.tar.gz` are in this working directory.  The complete set of files needed for the task are:
  
  
   1. Bash script with execution command (in archive)
   2. Common workflow language file (in archive)
   3. The Singularity image (in archive)
   4. Pair of fastq files (provided by user)
   5. TypeSeqHPV run manifest (provided by user)
   6. Control definitions file (provided by user)
   
As an alternative the user can generate the singularity image by building from the Dockerfile.  The user will still need to download the latest cwl and shell script from this repository.     
    
### 3. Adjust the Shell Variables  

In the shell script there are 5 variables that will need to be entered manually to help with the Singularity
exec command. These include fastq1, fastq2, control_defs, run_manifest and working_dir.  
  
Note that the file paths specified should be relative to the working_dir so that the relationship is
maintained inside the container. Any paths relative to your local environment will not work inside
Singularity.
  
### 4. Run the Workflow  
  
These instructions were tested on the NIH HPC which uses Slurm Workload Manager. We used an
interactive node but the shell script can easily be adjusted for a batch job. For a fast completion time try
to use at least 16 or 24 cores and at least 60 GB RAM. A typical MiSeq run should complete in 45
minutes with 24 cores.
  
The workflow will generate a sub directory with the name of the cwl file and a time stamp (e.g.
Illumina_TypeSeqHPV-2018-03-15-185300.647).  

Inside this folder will be sub folders for each of the tools in the workflow. The Illumina_TypeSeqHPV* folder
and its sub directories can be considered temporary files and may be deleted as soon the workflow
finishes. This folder will need about 50 GB of disk space but will be reduced to about 2GB after the run
completes (these are typical sizes for MiSeq runs; NextSeq runs will require more space).  
  
The folder the end user should keep is called Illumina_TypeSeq_output and will be about 1 MB. This
will contain a report PDF and CSV tables.  

The version of Singularity we used to run the container is 2.4.4

## Tools utilized in the Ion Torrent and Illumina Workflows
### Ion Torrent Plugin
- Drake 
   - Function: workflow engine
   - https://github.com/ropensci/drake
- Sambamba view
   - Function: creates a json that is more easily parsed
   - https://github.com/biod/sambamba
- Samtools view header
   - Function: extracts a header from one of the BAM files to determine list of contigs
   - Li H, Handsaker B, Wysoker A, Fennell T, Ruan J, Homer N, Marth G, Abecasis G, Durbin R, and 1000 Genome Project Data Processing Subgroup, The Sequence alignment/map (SAM) format and SAMtools, Bioinformatics (2009) 25(16) 2078-9 [19505943]
- TypeSeqHPV R package
   - Function: wrangles data, filter-based QC, creates report and matrix deliverables
   - R packages this depends on:
      - Tidyverse, ggplot, ggsci, Rmarkdown, fuzzyjoin, drake, furrr
         - https://github.com/tidyverse/tidyverse
         - https://github.com/tidyverse/ggplot2
         - https://github.com/rstudio/rmarkdown
         - https://github.com/dgrtwo/fuzzyjoin
         - https://github.com/ropensci/drake
         6. https://github.com/DavisVaughan/furrr
- Docker
   - Function: enables portability
   - The plugin runs inside a docker container with all dependencies
   - Docker run triggers the workflow
   - https://www.docker.com/


### Illumina Containerized Workflow
- Rabix common workflow language executor 
   - Function: workflow orchestration
   - http://rabix.io/
- bwa mem
   - Function: aligner
   - Li H. (2013) Aligning sequence reads, clone sequences and assembly contigs with BWA-MEM. arXiv:1303.3997v1 [q-bio.GN]
- Sambamba view
   - Function: creates a json that is more easily parsed
   - https://github.com/biod/sambamba
- Samtools view header
   - Function: wrangles data, filter-based QC, creates report and matrix deliverables
   - Li H, Handsaker B, Wysoker A, Fennell T, Ruan J, Homer N, Marth G, Abecasis G, Durbin R, and 1000 Genome Project Data Processing Subgroup, The Sequence alignment/map (SAM) format and SAMtools, Bioinformatics (2009) 25(16) 2078-9 [19505943]
- TypeSeqHPV R package
   - Function: wrangles data, filter-based QC, creates report and matrix deliverables
   - R packages this depends on:
      - Tidyverse, ggplot, ggsci, Rmarkdown, fuzzyjoin
       - https://github.com/tidyverse/tidyverse
       - https://github.com/tidyverse/ggplot2
       - https://github.com/rstudio/rmarkdown
         4. https://github.com/dgrtwo/fuzzyjoin

- Singularity
   - Function: enables portability
   - The plugin runs inside a docker container with all dependencies
   - Singularity exec triggers the workflow
   - https://github.com/singularityware/singularity


Insights about this plugin
============================

Many issues have been posted and addressed in the [related issue page](https://github.com/NCI-CGR/TypeSeqHPV_issues/issues).   Some of the common issues are to be highlighted here.

### 1. Demultiplexing and the related issues

In TypeSeq2 assay, samples are dual barcoded to increase productivity. The standard Ion Torrent pipeline processes 5\`-barcodes but not 3\`-barcodes. The demultiplexing step is a key component of this *TypeSeq2* plugin: it processes the raw bam files and demultiplex them by the 3\`-barcode.  Please note that those "raw" bam files are generated by the standard IonTorrent pipeline, having already been demultiplexed by the 5\`-barcode.  

In particular, the input raw bam files are IonXpress_0XX_rawlib.bam, where *XX* is the ID of 5\`-barcode, range from 49 to 96.  The output bam after this step is something like: AXXPYY_sorted.bam, where *YY* is the ID of 3`-barcode, range from 01 to 48.

Within this step, adam/spark is employed to make the demultiplexing in the programming language Scala (see inst/methylation/demux_3prime_barcode_adam.scala). Briefly, it processes each alignment in the bam files with the following steps:
+ Parse information in the files *barcodes.csv* and *.manifest.csv*.
+ Filtering alignment
   + full length and mapq >4 
+ Obtain 3`-barcode ID if there is perfect match and replace read group name
   + For example, RG:Z:MRFF6.IonXpress_080 => RG:Z:A80P06.MRFF6.IonXpress_080
+ Finally, save all the modified alignment records into one file *demux_reads.bam*.

Then, samtools are used to split *demux_reads.bam* by new read group names, and further some each of them as *AXXPYY_sorted.bam*.

The whole demultiplexing process is complicated and high cost in terms of CPU and RAM. As the code were developed several years before, some libraries are not supported any more and we have to rely on the containerization to keep it functional.  

There is one issue in this step, which is hard to fix.  In the scalar code, the sample names are expected to be matched with the ID of their 5`-barcode, like, 49,50,...,96.  


+ Problematic scalar code
```scala
withColumn("recordGroupSample", concat(lit("A"), $"recordGroupSample")).
  filter($"recordGroupSample" === $"BC1").
```


+ The read group example in a properly named bam file.
[:boom:] Note that ***SM:80*** is recognized by the scalar code.  

```
@RG     ID:MRFF6.IonXpress_080  CN:OptimusFry/S5XL-0040 DS:chef 
DT:2022-06-27T10:35:58-0400     
FO:TACGTACGTCTGAGCATCGATCGATGTACAGCTACGTACGTCTGAGCATCGATCGATGTACAGCTACGTACGTCTGAGCATCGATC
GATGTACAGCTACGTACGTCTGAGCATCGATCGATGTACAGCTACGTACGTCTGAGCATCGATCGATGTACAGCTACGTACGTCTGAGC
ATCGATCGATGTACAGCTACGTACGTCTGAGCATCGATCGATGTACAGCTACGTACGTCTGAGCATCGATCGATGTACAGCTACGTACG
TCTGAGCATCGATCGATGTACAGCTACGTACGTCTGAGCATCGATCGATGTACAGCTACGTACGTCTGAGCATCGATCGATGTACAGCT
ACGTACGTCTGAGCATCGATCGATGTACAGCTACGTACGTCTGAGCATCGATCGATGTACAGCTACGTACGTCTGAGCATCGATCGATG
TACAGCTACGTACGTCTGAGCATCGATCGATGTACAGCTACGTACGTCTGAGCATCGA KS:TCAGTCAGACCAGGTGAT
PG:tmap PL:IONTORRENT   PU:s5/540/Q2FV82/18/DAIC01728/IonXpress_080     SM:80
```

If the samples are not named in this way, it will caused issues as reported before:
+  https://github.com/NCI-CGR/TypeSeqHPV_issues/issues/99
  
It is ideal to pull 5`-barcode ID from ID:MRFF6.IonXpress_080 rather than from the hard-coded SM:80.   However, the adam library used in this plugin is outdated, so that it is difficult to find the related documents/references about how to make such changes properly. 

Noticeably, dual barcode seems supported by TorrentSuite now (see https://assets.thermofisher.com/TFS-Assets/LSG/manuals/MAN0017972_031419_TorrentSuite_5_12_UG_.pdf), which is likely to be a better solution.  The feature has been explored by Sarah at certain extension (see https://github.com/NCI-CGR/TypeSeqHPV_issues/issues/84).  A successful adoption of this solution will reduce the computation cost of this plugin dramatically.
