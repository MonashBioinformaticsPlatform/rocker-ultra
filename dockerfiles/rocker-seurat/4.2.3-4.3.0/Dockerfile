FROM ghcr.io/rocker-org/rstudio:4.2.3

# This exists as an image at: https://hub.docker.com/r/pansapiens/rocker-seurat
#
# Build like:
#   docker buildx build --platform linux/amd64 -t pansapiens/rocker-seurat:latest -t pansapiens/rocker-seurat:4.2.3-4.3.0 -f Dockerfile .
# where 4.2.3 is the R version, 4.3.0 is the Seurat version

# See layers used at: https://hub.docker.com/r/satijalab/seurat
#                     https://github.com/satijalab/seurat-docker/blob/master/latest/Dockerfile
RUN apt-get update && \
    apt-get install --yes \
            build-essential git pkg-config wget git \
            libhdf5-dev libcurl4-openssl-dev libssl-dev libpng-dev libboost-all-dev \
            libxml2-dev openjdk-8-jdk python3-dev python3-pip libfftw3-dev libgsl-dev \
            llvm \
            libglpk40 libglpk-dev libigraph-dev libigraph2 libfontconfig1-dev libcairo2-dev \
            libudunits2-dev libgdal-dev libgeos-dev libproj-dev libsqlite0-dev libproj-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install UMAP
RUN LLVM_CONFIG=/usr/lib/llvm-14/bin/llvm-config pip3 install llvmlite && \
    pip3 install numpy && \
    pip3 install umap-learn

RUN git clone --branch v1.2.1 https://github.com/KlugerLab/FIt-SNE.git && \
    cd FIt-SNE && g++ -std=c++11 -O3  src/sptree.cpp src/tsne.cpp src/nbodyfft.cpp  -o /usr/bin/fast_tsne -pthread -lfftw3 -lm -Wno-address-of-packed-member

RUN R --no-echo --no-restore --no-save -e "install.packages('BiocManager')" && \
    R --no-echo --no-restore --no-save -e "BiocManager::install(c(\
        'multtest', 'S4Vectors', 'SummarizedExperiment', 'SingleCellExperiment', \
        'MAST', 'DESeq2', 'BiocGenerics', 'GenomicRanges', 'IRanges', 'rtracklayer', 'monocle', 'Biobase', 'limma', \
        'glmGamPoi', 'DelayedArray', 'DelayedMatrixStats', 'lme4', 'batchelor', 'HDF5Array', 'terra', 'ggrastr'))" && \
    R --no-echo --no-restore --no-save -e "install.packages(c('VGAM', 'R.utils', 'metap', 'Rfast2', 'ape', 'enrichR', 'mixtools'))" && \
    R --no-echo --no-restore --no-save -e "install.packages('hdf5r')" && \
    R --no-echo --no-restore --no-save -e "install.packages('devtools')" && \
    R --no-echo --no-restore --no-save -e "install.packages('remotes')" && \
    R --no-echo --no-restore --no-save -e "install.packages('renv')" && \
    R --no-echo --no-restore --no-save -e "install.packages(c('evaluate', 'highr', 'knitr', 'markdown', 'rmarkdown', 'tinytex', 'xfun'))" && \
    R --no-echo --no-restore --no-save -e "remotes::install_version('Seurat', version = '4.3.0')" && \
    R --no-echo --no-restore --no-save -e "remotes::install_github('mojaveazure/seurat-disk')" && \
    R --no-echo --no-restore --no-save -e "devtools::install_github('cole-trapnell-lab/monocle3')"