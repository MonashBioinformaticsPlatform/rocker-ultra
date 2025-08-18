FROM ghcr.io/rocker-org/rstudio:4.4.3

# This exists as an image at: https://ghcr.io/monashbioinformaticsplatform/rocker-ultra/rocker-seurat:latest
#
# Build like:
#
#   docker buildx build --platform linux/amd64 \
#     -t ghcr.io/monashbioinformaticsplatform/rocker-ultra/rocker-seurat:latest \
#     -t ghcr.io/monashbioinformaticsplatform/rocker-ultra/rocker-seurat:4.4.1-5.1.0 \
#     -f Dockerfile .
#
# where 4.4.1 is the R version, 5.1.0 is the Seurat version

# See layers used at: https://hub.docker.com/r/satijalab/seurat
#                     https://github.com/satijalab/seurat-docker/blob/master/latest/Dockerfile

ARG SEURAT_VERS=5.2.1
ARG QUARTO_VERS=1.6.42
ARG BIOCONDUCTOR_VERS=3.20

# https://rocker-project.org/images/versioned/r-ver#switch-the-default-cran-mirror
#ARG CRAN="https://cloud.r-project.org" 
ARG CRAN="https://mirror.aarnet.edu.au/pub/CRAN/"
ARG BIOC_MIRROR="https://bioconductor.org"

RUN echo "options(repos = c(CRAN = '${CRAN}'))" >>"${R_HOME}/etc/Rprofile.site"
RUN echo "options(BioC_mirror = '${BIOC_MIRROR}')" >>"${R_HOME}/etc/Rprofile.site"

RUN apt-get update && \
    apt-get install --yes \
    build-essential git pkg-config wget curl htop pandoc \
    libhdf5-dev libcurl4-openssl-dev libssl-dev libpng-dev libboost-all-dev \
    libxml2 libxml2-dev openjdk-21-jdk python3-dev python3-pip libfftw3-dev libgsl-dev \
    llvm \
    libglpk40 libglpk-dev libigraph-dev libigraph3 libfontconfig1-dev libcairo2-dev \
    libudunits2-dev libgdal-dev libgeos-dev libproj-dev libsqlite3-dev \
    gfortran \
    libbz2-dev libsuperlu-dev libarpack2-dev libxt-dev tcl8.6-dev tk8.6-dev \
    texinfo texlive-fonts-extra libtiff5-dev libpango1.0-dev freeglut3-dev libxmu-dev \
    libglu1-mesa-dev libcgal-dev libnetcdf-dev libudunits2-0 libmagick++-dev \
    libboost-iostreams-dev libboost-log-dev libboost-system-dev libboost-test-dev \
    libpcre2-dev libgit2-dev libharfbuzz-dev libfribidi-dev libjpeg62 liborc-0.4-0 \
    cmake && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install UMAP
RUN LLVM_CONFIG=/usr/lib/llvm-14/bin/llvm-config \
    pip3 install --break-system-packages --no-cache-dir llvmlite && \
    pip3 install --break-system-packages --no-cache-dir numpy && \
    pip3 install --break-system-packages --no-cache-dir umap-learn

RUN git clone --branch v1.2.1 https://github.com/KlugerLab/FIt-SNE.git && \
    cd FIt-SNE && g++ -std=c++11 -O3  src/sptree.cpp src/tsne.cpp src/nbodyfft.cpp  -o /usr/bin/fast_tsne -pthread -lfftw3 -lm -Wno-address-of-packed-member

RUN wget "https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERS}/quarto-${QUARTO_VERS}-linux-amd64.deb" && \
    apt install -y ./quarto-${QUARTO_VERS}-linux-amd64.deb && \
    rm quarto-${QUARTO_VERS}-linux-amd64.deb

RUN R --no-echo --no-restore --no-save -e "install.packages(c('devtools', 'remotes', 'renv', 'R.utils'))" && \
    R --no-echo --no-restore --no-save -e "install.packages(c('tidyverse'))" && \
    R --no-echo --no-restore --no-save -e "install.packages(c('BiocManager'))" && \
    R --no-echo --no-restore --no-save -e "BiocManager::install(version = '${BIOCONDUCTOR_VERS}')" && \
    R --no-echo --no-restore --no-save -e "BiocManager::install(c(\
    'multtest', 'S4Vectors', 'SummarizedExperiment', 'SingleCellExperiment', \
    'MAST', 'DESeq2', 'BiocGenerics', 'GenomicRanges', 'IRanges', 'rtracklayer', 'monocle', 'Biobase', 'limma', \
    'glmGamPoi', 'DelayedArray', 'DelayedMatrixStats', 'lme4', 'batchelor', 'HDF5Array', 'terra', 'ggrastr' \
    ))" && \
    R --no-echo --no-restore --no-save -e "BiocManager::install(c('edgeR', 'Glimma'))" && \
    R --no-echo --no-restore --no-save -e "BiocManager::install(c('celldex', 'SingleR'))" && \
    R --no-echo --no-restore --no-save -e "install.packages(c('Matrix.utils'))" && \
    R --no-echo --no-restore --no-save -e "install.packages(c('VGAM', 'R.utils', 'metap', 'Rfast2', 'ape', 'enrichR', 'mixtools'))" && \
    R --no-echo --no-restore --no-save -e "install.packages(c('spatstat.explore', 'spatstat.geom'))" && \
    R --no-echo --no-restore --no-save -e "install.packages(c('hdf5r'))" && \
    R --no-echo --no-restore --no-save -e "install.packages(c('evaluate', 'highr', 'knitr', 'markdown', 'rmarkdown', 'tinytex', 'xfun'))" && \
    R --no-echo --no-restore --no-save -e "install.packages(c('rgeos'))" && \
    R --no-echo --no-restore --no-save -e "remotes::install_version('Seurat', version = '${SEURAT_VERS}')" && \
    R --no-echo --no-restore --no-save -e "remotes::install_github('mojaveazure/seurat-disk')" && \
    R --no-echo --no-restore --no-save -e "devtools::install_github('cole-trapnell-lab/monocle3')" && \
    R --no-echo --no-restore --no-save -e "remotes::install_version('RcppArmadillo')" && \
    R --no-echo --no-restore --no-save -e "remotes::install_version('harmony', upgrade='never')" && \
    R --no-echo --no-restore --no-save -e "install.packages(c('clustree', 'RColorBrewer'))" && \
    R --no-echo --no-restore --no-save -e "remotes::install_github('plotly/plotly.R')" && \
    R --no-echo --no-restore --no-save -e "remotes::install_github('pfh/langevitour')"
