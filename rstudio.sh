#!/bin/bash
#
# Loosely based on https://www.rocker-project.org/use/singularity/
#
# TODO:
#  - Set the LC_* environment variables to suppress warnings in Rstudio console
#  - Use an actually writable common Singularity cache somewhere to share images between users
#    (current setup has permissions issue).
#  - Determine why laptop -> login-node -> compute-node SSH forwarding isn't working (sshd_config ?)
#  - Allow srun/sbatch from within the container (likely very difficult, very host dependant).
#

#set -o xtrace

# Deactivate any active conda environment
if [[ -n "$CONDA_DEFAULT_ENV" ]]; then
    conda deactivate; conda deactivate
fi

# This may be required at some sites if the Apptainer configuration
# prevents SLURM from setting the appropriate memory cgroups ? See:
# https://github.com/MonashBioinformaticsPlatform/rocker-ultra/issues/7
# export APPTAINER_DISABLE_CGROUPS=1

# We use this modified version of rocker/rstudio by default, with Seurat and required
# dependencies already installed.
# This version tag is actually {R_version}-{Seurat_version}
IMAGE=${IMAGE:-ghcr.io/monashbioinformaticsplatform/rocker-ultra/rocker-seurat:4.4.1-5.1.0-2}
# You can uncomment this if you've like vanilla rocker/rstudio
#IMAGE=${IMAGE:-rocker/rstudio:4.1.1}

# Fully qualify the image location if not specified
if [[ "$IMAGE" =~ ^docker-daemon:|^docker://|^http:|^https:|^\.|^/ ]]; then
  IMAGE_LOCATION=$IMAGE
else
  IMAGE_LOCATION="docker://$IMAGE"
fi


# Use a shared cache location if unspecified
# export SINGULARITY_CACHEDIR=${SINGULARITY_CACHEDIR:-"/scratch/df22/andrewpe/singularity_cache"}

if [[ -z "${HOSTNAME}" ]]; then
    _hostname=$(hostname)
    export HOSTNAME="${_hostname}"
fi

# Orginally developed for M3, what we are acually interested in if if we are in a strudel2 environment
# Since we can't easily tell if we are in strudel2 we will actually check if we are in slurm (PBS should be the same)
# Hardcode this to 'local' if you don't ever use an HPC cluster.
if [[ -z "${SLURM_JOB_ID}" ]]; then
    HPC_ENV="shell"
else
    HPC_ENV="slurm"
fi
    

# Make a dir name from the IMAGE
IMAGE_SLASHED=$(echo "${IMAGE}" | sed 's/:/\//g' | sed 's/\.\./__/g')
R_DIRS="${HOME}/.rstudio-rocker/${IMAGE_SLASHED}/"
RSTUDIO_DOT_LOCAL="${R_DIRS}/.local/share/rstudio"
RSTUDIO_DOT_CONFIG="${R_DIRS}/.config/rstudio"
RSTUDIO_HOME="${R_DIRS}/session"
RSTUDIO_TMP="${R_DIRS}/tmp"
R_LIBS_USER="${R_DIRS}/R"
R_ENV_CACHE="${R_DIRS}/renv-local"
mkdir -p "${RSTUDIO_HOME}"
mkdir -p "${RSTUDIO_DOT_LOCAL}"
mkdir -p "${RSTUDIO_DOT_CONFIG}"
mkdir -p "${R_LIBS_USER}"
mkdir -p "${RSTUDIO_TMP}/var/run"
mkdir -p "${R_ENV_CACHE}"

# Set SINGULARITY_BIN to apptainer if it's on path, otherwise singularity
if command -v apptainer >/dev/null 2>&1; then
    SINGULARITY_BIN="apptainer"
else
    SINGULARITY_BIN="singularity"
fi
export SINGULARITY_BIN

if [[ -n "${APPTAINER_CACHEDIR}" ]]; then
    _cachedir="${APPTAINER_CACHEDIR}"
elif [[ -n "${SINGULARITY_CACHEDIR}" ]]; then
    _cachedir="${SINGULARITY_CACHEDIR}"
else
    _cachedir=${HOME}/.apptainer/cache/
fi

if [[ $HPC_ENV == "slurm" ]]; then
    BINDPATHS=("/fs02" "/fs03" "/fs04" "/scratch" "/scratch2" "/projects")
    SINGULARITY_BINDPATH=""
    for path in "${BINDPATHS[@]}"; do
        if [[ -d "$path" ]]; then
            if [[ -z "$SINGULARITY_BINDPATH" ]]; then
                SINGULARITY_BINDPATH="$path"
            else
                SINGULARITY_BINDPATH="$SINGULARITY_BINDPATH,$path"
            fi
        fi
    done
    export SINGULARITY_BINDPATH
    export APPTAINER_BINDPATH=${SINGULARITY_BINDPATH}
fi

echo "Getting required containers ... this may take a while ..."
echo "  Storing image in ${_cachedir}"
# Test the image works, execute a no-op command
${SINGULARITY_BIN} exec "${IMAGE_LOCATION}" true

get_socketid() {
  if [[ -n "$SLURM_JOB_ID" ]]; then
    SOCKETID="$SLURM_JOB_ID"
  else
    SOCKETID="rserver"
  fi
}

echo
echo "Finding an available port ..."
get_socketid
SOCKET="/home/${USER}/.sock${SOCKETID}"

LOCALPORT=${PORT}
# LOCALPORT=8787
PUBLIC_IP=$(curl --silent https://checkip.amazonaws.com)

echo "On you local machine, open an SSH tunnel like:"
# echo "  ssh -N -L ${LOCALPORT}:localhost:${PORT} ${USER}@m3-bio1.erc.monash.edu.au"
echo "  ssh -N -L ${LOCALPORT}:${SOCKET} ${USER}@$(hostname -f)"
echo "  or"
echo "  ssh -N -L ${LOCALPORT}:${SOCKET} ${USER}@${PUBLIC_IP}"

# For smux/srun/sbatch jobs, route via the login node to a the compute node where rserver runs - not working for me
# echo "  ssh -N -L ${LOCALPORT}:${HOSTNAME}:${PORT} ${USER}@m3.massive.org.au"
echo
echo "Point your web browser at http://localhost:${LOCALPORT}"
echo
echo "Protip: You can choose your version of R from any of the tags listed here: https://hub.docker.com/r/rocker/rstudio/tags"
echo "        and set the environment variable IMAGE, eg"
echo "        IMAGE=rocker/rstudio:4.1.1 $(basename "$0")"
echo
echo "Starting RStudio Server (R version from image ${IMAGE})"




# Set some locales to suppress warnings
export LC_CTYPE="C.UTF-8"
export LC_TIME="C.UTF-8"
export LC_MONETARY="C.UTF-8"
export LC_MESSAGES="C.UTF-8"
# shellcheck disable=SC2034
export LC_PAPER="C.UTF-8"
# shellcheck disable=SC2034
export LC_MEASUREMENT="C.UTF-8"

if [[ $HPC_ENV == 'slurm' ]]; then
    if [[ -n ${SLURM_JOB_ID} ]]; then
      # For Strudel
      echo '{"tunnelid":"s2rtid'${SOCKETID}'", "socket":"'${SOCKET}'"}'>"${HOME}/.rstudio-rocker/rserver-${SLURM_JOB_ID}.json"
    fi
    APPTAINERENV_PASSWORD="${PASSWORD}" \
    SINGULARITYENV_PASSWORD="${PASSWORD}" \
    ${SINGULARITY_BIN} exec --bind "${RSTUDIO_HOME}:${HOME}/.rstudio" \
                     --bind "${RSTUDIO_TMP}:/tmp" \
                     --bind "${RSTUDIO_TMP}/var:/var/lib/rstudio-server" \
                     --bind "${RSTUDIO_TMP}/var/run:/var/run/rstudio-server" \
                     --bind "${R_ENV_CACHE}:/home/rstudio/.local/share/renv" \
                     --bind "${RSTUDIO_DOT_LOCAL}:/home/rstudio/.local/share/rstudio" \
                     --bind "${RSTUDIO_DOT_CONFIG}:/home/rstudio/.config/rstudio" \
                     --bind "${R_LIBS_USER}:/home/rstudio/R" \
                     "${IMAGE_LOCATION}" \
                     rserver --auth-none=1 --www-socket="${SOCKET}" --server-user="${USER}" --www-root-path="s2rtid${SOCKETID}"
                     #--bind ${RSITELIB}:/usr/local/lib/R/site-library \
else
    APPTAINERENV_PASSWORD="${PASSWORD}" \
    SINGULARITYENV_PASSWORD="${PASSWORD}" \
    ${SINGULARITY_BIN} exec --bind "${RSTUDIO_HOME}:${HOME}/.rstudio" \
                     --bind "${RSTUDIO_TMP}:/tmp" \
                     --bind "${RSTUDIO_TMP}/var:/var/lib/rstudio-server" \
                     --bind "${RSTUDIO_TMP}/var/run:/var/run/rstudio-server" \
                     --bind "${R_ENV_CACHE}:/home/rstudio/.local/share/renv" \
                     --bind "${RSTUDIO_DOT_LOCAL}:/home/rstudio/.local/share/rstudio" \
                     --bind "${RSTUDIO_DOT_CONFIG}:/home/rstudio/.config/rstudio" \
                     --bind "${R_LIBS_USER}:/home/rstudio/R" \
                     "${IMAGE_LOCATION}" \
                     rserver --auth-none=1 --www-socket="${SOCKET}" --server-user="${USER}"
fi

printf 'rserver exited' 1>&2
