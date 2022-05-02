#!/bin/bash
#
# Loosely based on https://www.rocker-project.org/use/singularity/
#
# TODO:
#  - Set the LC_* environment variables to suppress warnings in Rstudio console
#  - Use an actually writable common Singularity cache somewhere to share images between users
#    (current setup has permissions issue).
#  - Determine why laptop -> login-node -> compute-node SSH forwarding isn't working (sshd_config ?)
#  - Allow srun/sbatch from within the container.
#

#set -o xtrace

# We use this modified version of rocker/rstudio by default, with Seurat and required
# dependencies already installed.
# This version tag is actually {R_version}-{Seurat_version}
IMAGE=${IMAGE:-pansapiens/rocker-seurat:4.1.1-4.0.4}
# You can uncomment this if you've like vanilla rocker/rstudio
#IMAGE=${IMAGE:-rocker/rstudio:4.1.1}

# Fully qualify the image location if not specified
if [[ "$IMAGE" =~ ^docker-daemon:|^docker://|^\. ]]; then
  IMAGE_LOCATION=$IMAGE
else
  IMAGE_LOCATION="docker://$IMAGE"
fi

PORT=${RSTUDIO_PORT:-8787}

# Create a new password, or use whatever password is passed in the environment
if [[ -z "$PASSWORD" ]]; then
  PASSWORD=$(openssl rand -base64 15)
fi
export PASSWORD

SINGULARITY_VERSION=3.9.2
# Use a shared cache location if unspecified
# export SINGULARITY_CACHEDIR=${SINGULARITY_CACHEDIR:-"/scratch/df22/andrewpe/singularity_cache"}

# We detect if we are on M3/MASSIVE by the hostname.
# Hardcode this to `local` if you don't ever use M3/MASSIVE.
if [[ $HOSTNAME == m3* ]]; then
    HPC_ENV="m3"
else
    HPC_ENV="local"
fi

function get_port {
    # lsof doesn't return open ports for system services, so we use netstat
    # until ! lsof -i -P -n | grep -qc ':'${PORT}' (LISTEN)';

    until ! netstat -ln | grep "  LISTEN  " | grep -iEo  ":[0-9]+" | cut -d: -f2 | grep -wqc "${PORT}";
    do
        ((PORT++))
        echo "Checking port: ${PORT}"
    done
    echo "Got one !"
}

# try to load a singularity module, just in case we need to
(module load singularity/${SINGULARITY_VERSION} || true) 2>/dev/null

IMAGE_SLASHED=$(echo "${IMAGE}" | sed 's/:/\//g')
RSTUDIO_HOME="${HOME}/.rstudio-rocker/${IMAGE_SLASHED}/session"
RSTUDIO_TMP="${HOME}/.rstudio-rocker/${IMAGE_SLASHED}/tmp"
# RSITELIB="${HOME}/.rstudio-rocker/${IMAGE_SLASHED}/site-library"
R_LIBS_USER="${HOME}/.rstudio-rocker/${IMAGE_SLASHED}"
#mkdir -p ${HOME}/.rstudio
mkdir -p "${RSTUDIO_HOME}"
#mkdir -p "${RSITELIB}"
mkdir -p "${R_LIBS_USER}"
mkdir -p "${RSTUDIO_TMP}"
mkdir -p "${RSTUDIO_TMP}/var/run"


echo "Getting required containers ... this may take a while ..."
echo
# by doing `singularity test` we cache the container image without dumping a local sif file here
# mksquashfs isn't installed everywhere, so we pull on a head node
if [[ $HPC_ENV == "m3" ]]; then
    # we use `singularity test` instead of `pull` to avoid leaving a .img file around
    #ssh m3.massive.org.au bash -c "true && \
    #                               module load singularity/${SINGULARITY_VERSION} && \
    #                               singularity test docker://${IMAGE}"
    module load singularity/${SINGULARITY_VERSION}
    singularity test "${IMAGE_LOCATION}"
elif [[ "$IMAGE" =~ ^\. ]]; then
    # Don't need pull local image
    singularity test "${IMAGE_LOCATION}"
else
    # pull to ensure we have the image cached
    singularity pull "${IMAGE_LOCATION}"
fi


echo
echo "Finding an available port ..."
get_port

LOCALPORT=${PORT}
# LOCALPORT=8787
PUBLIC_IP=$(curl --silent https://checkip.amazonaws.com)

echo "On you local machine, open an SSH tunnel like:"
# echo "  ssh -N -L ${LOCALPORT}:localhost:${PORT} ${USER}@m3-bio1.erc.monash.edu.au"
echo "  ssh -N -L ${LOCALPORT}:localhost:${PORT} ${USER}@$(hostname -f)"
echo "  or"
echo "  ssh -N -L ${LOCALPORT}:localhost:${PORT} ${USER}@${PUBLIC_IP}"

# For smux/srun/sbatch jobs, route via the login node to a the compute node where rserver runs - not working for me
# echo "  ssh -N -L ${LOCALPORT}:${HOSTNAME}:${PORT} ${USER}@m3.massive.org.au"
echo
echo "Point your web browser at http://localhost:${LOCALPORT}"
echo
echo "Login to RStudio with:"
echo "  username: ${USER}"
echo "  password: ${PASSWORD}"
echo
echo "Protip: You can choose your version of R from any of the tags listed here: https://hub.docker.com/r/rocker/rstudio/tags"
echo "        and set the environment variable IMAGE, eg"
echo "        IMAGE=rocker/rstudio:4.1.1 $(basename "$0")"
echo
echo "Starting RStudio Server (R version from image ${IMAGE})"

# Set some locales to suppress warnings
LC_CTYPE="C"
LC_TIME="C"
LC_MONETARY="C"
# shellcheck disable=SC2034
LC_PAPER="C"
# shellcheck disable=SC2034
LC_MEASUREMENT="C"

if [[ $HPC_ENV == 'm3' ]]; then
    SINGULARITYENV_PASSWORD="${PASSWORD}" \
    singularity exec --bind "${HOME}:/home/rstudio" \
                     --bind "${RSTUDIO_HOME}:${HOME}/.rstudio" \
                     --bind "${R_LIBS_USER}:${R_LIBS_USER}" \
                     --bind "${RSTUDIO_TMP}:/tmp" \
                     --bind "${RSTUDIO_TMP}/var:/var/lib/rstudio-server" \
                     --bind "${RSTUDIO_TMP}/var/run:/var/run/rstudio-server" \
                     --bind /scratch:/scratch \
                     --bind /projects:/projects \
                     --writable-tmpfs \
                     --env "R_LIBS_USER=${R_LIBS_USER}" \
                     "${IMAGE_LOCATION}" \
                     rserver --auth-none=0 --auth-pam-helper-path=pam-helper --www-port="${PORT}"
                     #--bind ${RSITELIB}:/usr/local/lib/R/site-library \
else
    SINGULARITYENV_PASSWORD="${PASSWORD}" \
    singularity exec --bind "${HOME}:/home/rstudio" \
                     --bind "${RSTUDIO_HOME}:${HOME}/.rstudio" \
                     --bind "${R_LIBS_USER}:${R_LIBS_USER}" \
                     --bind "${RSTUDIO_TMP}:/tmp" \
                     --bind "${RSTUDIO_TMP}/var:/var/lib/rstudio-server" \
                     --bind "${RSTUDIO_TMP}/var/run:/var/run/rstudio-server" \
                     --env R_LIBS_USER="${R_LIBS_USER}" \
                     "${IMAGE_LOCATION}" \
                     rserver --auth-none=0 --auth-pam-helper-path=pam-helper --www-port="${PORT}"
                     # --bind "${RSITELIB}:/usr/local/lib/R/site-library" \
fi

printf 'rserver exited' 1>&2
