#FROM cgrlab/typeseqhpv:base_200214
FROM cgrlab/typeseqhpv:base_190221

WORKDIR /mnt

RUN Rscript -e 'require(devtools); install_github("NCI-CGR/TypeSeq2", ref = "development", force = TRUE)'


#clone repo to get other docs
RUN cd / && git clone --single-branch --branch development https://github.com/NCI-CGR/TypeSeq2

RUN wget https://github.com/jgm/pandoc/releases/download/2.9.2/pandoc-2.9.2-1-amd64.deb \
&& dpkg -i pandoc-2.9.2-1-amd64.deb

RUN Rscript -e 'install.packages("gridExtra")'
RUN Rscript -e 'install.packages("https://cran.r-project.org/src/contrib/vcfR_1.12.0.tar.gz", repos=NULL, type="source")'
