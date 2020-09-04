#FROM cgrlab/typeseqhpv:base_200214
FROM cgrlab/typeseqhpv:base_190221

WORKDIR /mnt

RUN Rscript -e 'require(devtools); install_github("NCI-CGR/TypeSeqHPV2", ref = "master", force = TRUE)'


#clone repo to get other docs
RUN cd / && git clone --single-branch --branch master https://github.com/NCI-CGR/TypeSeqHPV2

RUN wget https://github.com/jgm/pandoc/releases/download/2.9.2/pandoc-2.9.2-1-amd64.deb \
&& dpkg -i pandoc-2.9.2-1-amd64.deb

RUN Rscript -e 'install.packages("gridExtra")'