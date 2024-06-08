FROM cgrlab/typeseqhpv:base_190221

RUN apt-get install -y locales &&  locale-gen "en_US.UTF-8"
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    echo 'LANG="en_US.UTF-8"' | tee /etc/default/locale && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=en_US.UTF-8

RUN  apt-get install -y gnupg2

WORKDIR /mnt

RUN Rscript -e 'require(devtools); install_github("NCI-CGR/TypeSeq2", ref = "release/2.3.0", force = TRUE)'

#clone repo to get other docs
RUN cd / && git clone --single-branch -b release/2.3.0 https://github.com/NCI-CGR/TypeSeq2

RUN wget https://github.com/jgm/pandoc/releases/download/2.9.2/pandoc-2.9.2-1-amd64.deb \
    && dpkg -i pandoc-2.9.2-1-amd64.deb

RUN Rscript -e 'install.packages("gridExtra")'
# RUN Rscript -e 'install.packages("https://cran.r-project.org/src/contrib/vcfR_1.12.0.tar.gz", repos=NULL, type="source")'
RUN Rscript -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/vcfR/vcfR_1.12.0.tar.gz", repos=NULL, type="source")'