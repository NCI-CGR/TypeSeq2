
==============
Input Files
==============

TypeSeqHPV2 has four required files and one optional 


1. Sample sheet or manifest
2. Control definitions
3. Barcode file
4. Config file
5. Grouping file



All these files have some required fields. Empty rows/columns, wrong column names break the plugin. 



Sample Sheet
------------


Required fields - Sort_Order, Project, Panel, Assay_Batch_Code, Assay_Plate_Code, Assay_Well_ID, Owner_Sample_ID, BC1, BC2

Sort order is often used to put the rows in order after data processing. Project is important for generating project specific output files. Panel is used in grouping. Batch, plate and well ID codes are used in platemap and other plot generation. Owner Sample sheet and barcodes are very important in almost all steps of the plugin.




Control Definitions
-------------------

All Columns are required in this file. The Control code matches the owner sample ID when we are merging these two files. Control_type defines the type of control (positive or negative) and other contig information is very specific. Once the result table is generated, this control table is merged to the result table, controls are extracted and control results are generated. An exact match between contigs, control type and Control_code(OwnerSampleID) is required for pass result. 

Example - Let us say we have hg19 control which has control_type as "pos", Human_Control contig as "pos" and all the HPV contigs as "neg". In the result file, this needs to be an exact match meaning if we have a sample with Owner_SampleID hg19, Human_Control as "pass" and all other HPV as "neg", then only it will match and declared "pos". We will count the number of pos and see if that is equal. If not, it is fail. 





Barcode File
------------

All columns are required for plugin steps and important for demplutiplexing





Config File
-----------


This has file path information for all the other files listed below -

* hotspot_vcf
* tvc_parameters
* reference
* region_bed
* lineage_defs
* scaling_table
* pn_filters
* internal_control_defs



Grouping Defs
-------------


This file defines how the samples should be grouped or masked. Suppose we have three different panels or want to only look at high risk types, this file can be used to generate grouped/masked output. Refer to this for more information - https://github.com/NCI-CGR/TypeSeqHPV2/blob/master/docs/TypeSeq_HPV_Analysis_Instructions.pdf
















