
# New release of TypeSeq2 (V2.3.0) and TypeSeq2_IMS (V1.4.0)

## Introduction

In this release, there are several major changes:
+ Added OffLoad function to save the key output files of TypeSeq2 to the targeted T drive folders.
+ Fixed file permission issues in the data archive.
+ Update batch control file in both TypeSeq2 and TypeSeq2-IMS.
  + [TS2_config.csv](data/TS2_config.csv)
  + [TypeSeq2_Batch-controls_v1.3.csv](data/TypeSeq2_Batch-controls_v1.3.csv)

The new docker image docker://cgrlab/typeseq2:v2.3.0 has been created for this new release, using [the dockerfile TypeSeq2.v2.3.0.dockerfile](data/TypeSeq2.v2.3.0.dockerfile).

The new packages are available here:
+ https://github.com/NCI-CGR/IonTorrent_plugins/blob/main/TypeSeq2/archive/TypeSeq2.2_3_0.zip
+ https://github.com/NCI-CGR/IonTorrent_plugins/blob/main/TypeSeq2/archive/TypeSeq2_IMS.1_4_0.zip

## Details of the plugin packages
The details of the changes in TypeSeq2 is available here: 

https://github.com/NCI-CGR/IonTorrent_plugins/commit/88a8df2603aeeb9034b8ff608c196e338c975a93

And the similar changes in TypeSeq2_IMS is available here: 
https://github.com/NCI-CGR/IonTorrent_plugins/commit/498cf34b81a716927552473662ade5af516da172