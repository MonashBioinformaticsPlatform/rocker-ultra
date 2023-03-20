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

## Building a container

_You probably don't need to build these containers yourself_, since pre-built versions already exist on Dockerhub / Github Pacakges. However, you may want to build one to generate a custom version for some purpose.

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
singularity build "rocker-seurat_${VERSION_TAG}.sif" "${REGISTRY}/rocker-seurat:${VERSION_TAG}"

# Run with your custom Singularity image
IMAGE="./rocker-seurat_${VERSION_TAG}.sif" ./rstudio.sh
```

## Tunnelling to an M3 compute node

_Now some very specific instructions, for users of the M3 / MASSIVE HPC cluster_

You should run your RStudio session on a compute node, via a SLURM job submission, then SSH tunnel to that compute node.

Just commandline, without using `~/.ssh/config`:
```bash
# on login node, in tmux/screen (or adapt to sbatch)
srun --mem=1G --time=0-12:00 --job-name=my-rstudio ./rstudio.sh

# once running, find out which compute node it's on with squ or similar
squeue | grep my-rstudio

# we will use m3a002 in this example

# on you local machine
ssh -i ~/.ssh/m3 -J username@m3.massive.org.au -L 8787:localhost:8787 username@m3a002

# open the URL http://localhost:8787 in the browser on your laptop
```

OR, using the convenience of `~/.ssh/config`:
```
# ~/.ssh/config
Host m3
 HostName m3.massive.org.au
 User my_m3_username
 IdentityFile ~/.ssh/m3
 ForwardAgent yes
 LocalForward 8787 127.0.0.1:8787

# Other host wildcards may need to be added here over time
Host m3a* m3b* m3c* m3d* m3e* m3f* m3g* m3h* m3i* m3j*
 User my_m3_username
 IdentityFile ~/.ssh/m3
 ProxyJump m3
 LocalForward 8787 127.0.0.1:8787
```

Then just `ssh -i ~/.ssh/m3 username@m3a002` to the compute node from your laptop, and open https://localhost:8787 in your browser.

## History

`rocker-ultra` began with this [gist](https://gist.github.com/pansapiens/b46071f99dcd1f374354c1687f7a986a)
