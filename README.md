# rocker-ultra
_Containerised RStudio with bells+whistles for HPC and everywhere_

----
`rocker-ultra` aims to simplify launching an RStudio server in Singularity with a single wrapper script, 
with managment of package directories per-version in your home directory, auto-free port finding, 
per-session password generation and SSH port forwarding instructions for free. It is based on the
[containers](https://www.rocker-project.org/use/singularity/) developed by the 
[rocker project](https://github.com/rocker-org/rocker-versioned2) (but not affiliated).

By default `rocker-ultra` uses a custom image based on `rocker/rstudio` but with [Seurat](https://satijalab.org/seurat/) 
dependencies pre-installed.

## Quickstart

Run:
```bash
# Download the `rstudio.sh` from this repo
wget https://raw.githubusercontent.com/MonashBioinformaticsPlatform/rocker-ultra/main/rstudio.sh

chmod +x ./rstudio.sh
./rstudio.sh
```

It may take some time to download images. Eventually you'll be presented with instructions to login, including a generated password, eg
```
INFO:    Creating SIF file...
INFO:    Build complete: rstudio_3.6.0.sif

Finding an available port ...
Got one !

On you local machine, open an SSH tunnel like:
  ssh -N -L 8787:localhost:8787 myusername@login-node.example.com
  or
  ssh -N -L 8787:localhost:8787 myusername@192.16.0.10

Point your web browser at http://localhost:8787

Login to RStudio with:
  username: myusername
  password: Y9qmTCxlM30ArhY7biC5

Protip: You can choose your version of R from any of the tags listed here: https://hub.docker.com/r/rocker/rstudio/tags
        and set the environment variable IMAGE, eg
        IMAGE=rocker/rstudio:3.5.3 rstudio.sh

Starting RStudio Server (R version 3.6.0)
```

If you'd like to select your R version, set the `IMAGE` environment variable like this:
```
IMAGE=rocker/rstudio:3.5.3 ./rstudio.sh
```
As long as there is a corresponding versioned container provided by Rocker, most common R versions should work.

Note that by default the script uses a custom image based on `rocker/rstudio` (`pansapiens/rocker-seurat:4.1.1-4.0.4`) 
that has the Seurat package and require dependencies pre-installed.

----

## On M3 / Massive

[Specific instructions for the M3 HPC site are here](m3/).

## Building a container

_You probably don't need to build these containers yourself_, since pre-built versions already exist on Dockerhub / Github Pacakges, and are automatically build via CI. However, you may want to build one to generate a custom version for some purpose.

For example:
```bash
REGISTRY="pansapiens"
VERSION_TAG="4.2.3-4.3.0"
docker build \
  -t "${REGISTRY}/rocker-seurat:latest" \
  -t "${REGISTRY}/rocker-seurat:${VERSION_TAG}" \
  -f "dockerfiles/rocker-seurat/${VERSION_TAG}/Dockerfile" \
  "dockerfiles/rocker-seurat/${VERSION_TAG}"

# Generate a Singularity image file
singularity build "rocker-seurat_${VERSION_TAG}.sif" "docker-daemon://${REGISTRY}/rocker-seurat:${VERSION_TAG}"

# Run with your custom Singularity image
IMAGE="./rocker-seurat_${VERSION_TAG}.sif" ./rstudio.sh
```

## History

`rocker-ultra` began with this [gist](https://gist.github.com/pansapiens/b46071f99dcd1f374354c1687f7a986a)
