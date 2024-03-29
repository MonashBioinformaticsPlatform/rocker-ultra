FROM rocker/rstudio:4.1.2

# This exists as an image at: https://hub.docker.com/r/pansapiens/rocker-seurat
#
# Build like:
#   docker build -t pansapiens/rocker-seurat:latest -t pansapiens/rocker-seurat:4.1.2-4.1.0 -f Dockerfile .
# where 4.1.2 is the R version, 4.1.0 is the Seurat version

# See layers used at: https://hub.docker.com/r/satijalab/seurat
#                     https://github.com/satijalab/seurat-docker/blob/master/latest/Dockerfile
RUN apt-get update && \
    apt-get install --yes \
            build-essential git \
            libhdf5-dev libcurl4-openssl-dev libssl-dev libpng-dev libboost-all-dev \
            libxml2-dev openjdk-8-jdk python3-dev python3-pip wget git libfftw3-dev libgsl-dev \
            llvm-10 \
            libglpk40 libglpk-dev libigraph0-dev libigraph0v5 libfontconfig1-dev libcairo2-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install UMAP
RUN LLVM_CONFIG=/usr/lib/llvm-10/bin/llvm-config pip3 install llvmlite && \
    pip3 install numpy && \
    pip3 install umap-learn

RUN git clone --branch v1.2.1 https://github.com/KlugerLab/FIt-SNE.git && \
    cd FIt-SNE && g++ -std=c++11 -O3  src/sptree.cpp src/tsne.cpp src/nbodyfft.cpp  -o /usr/bin/fast_tsne -pthread -lfftw3 -lm -Wno-address-of-packed-member

RUN R --no-echo --no-restore --no-save -e "install.packages('BiocManager')" && \
    R --no-echo --no-restore --no-save -e "BiocManager::install(c('multtest', 'S4Vectors', 'SummarizedExperiment', 'SingleCellExperiment', 'MAST', 'DESeq2', 'BiocGenerics', 'GenomicRanges', 'IRanges', 'rtracklayer', 'monocle', 'Biobase', 'limma', 'glmGamPoi'))" && \
    R --no-echo --no-restore --no-save -e "install.packages(c('VGAM', 'R.utils', 'metap', 'Rfast2', 'ape', 'enrichR', 'mixtools'))" && \
    R --no-echo --no-restore --no-save -e "install.packages('hdf5r')" && \
    R --no-echo --no-restore --no-save -e "install.packages('remotes')" && \
    R --no-echo --no-restore --no-save -e "install.packages('renv')" && \
    R --no-echo --no-restore --no-save -e "install.packages(c('evaluate', 'highr', 'knitr', 'markdown', 'rmarkdown', 'tinytex', 'xfun'))" && \
    R --no-echo --no-restore --no-save -e "remotes::install_version('Seurat', version = '4.1.0')" && \
    R --no-echo --no-restore --no-save -e "remotes::install_github('mojaveazure/seurat-disk')"
