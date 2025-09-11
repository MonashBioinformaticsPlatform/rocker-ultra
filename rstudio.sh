#!/bin/bash
#
# Loosely based on https://www.rocker-project.org/use/singularity/
#
# TODO:
#  - Allow srun/sbatch from within the container (likely very difficult, very host dependant).
#

#set -o xtrace

# This may be required at some sites if the Apptainer configuration
# prevents SLURM from setting the appropriate memory cgroups ? See:
# https://github.com/MonashBioinformaticsPlatform/rocker-ultra/issues/7
# export APPTAINER_DISABLE_CGROUPS=1

# We use this modified version of rocker/rstudio by default, with Seurat and required
# dependencies already installed.
# This version tag is actually {r_version}-{seurat_version}-{build_number}
IMAGE=${IMAGE:-ghcr.io/monashbioinformaticsplatform/rocker-ultra/rocker-seurat:4.4.1-5.1.0-2}
# You can uncomment this if you've like vanilla rocker/rstudio
#IMAGE=${IMAGE:-rocker/rstudio:4.4.1}

# Fully qualify the image location if not specified
if [[ "$IMAGE" =~ ^docker-daemon:|^docker://|^http:|^https:|^\.|^/ ]]; then
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

# Use a shared cache location if unspecified
# export SINGULARITY_CACHEDIR=${SINGULARITY_CACHEDIR:-/scratch/df22/andrewpe/singularity_cache}
# export APPTAINER_CACHEDIR=${SINGULARITY_CACHEDIR}

if [[ -z "${HOSTNAME}" ]]; then
    _hostname=$(hostname)
    export HOSTNAME="${_hostname}"
fi

# Originally developed for M3, what we are actually interested in if if we are in a Strudel2 environment
# Since we can't easily tell if we are in Strudel2 we will actually check if we are in SLURM
# Hardcode this to 'local' if you don't ever use an HPC cluster.
if [[ -z "${SLURM_JOB_ID}" ]]; then
    HPC_ENV="local"
else
    HPC_ENV="m3"
fi

function port_in_use {
    # iproute2, lsof and gawk are in the default Ubuntu 24.04 package list, so
    # we should have one of these available.
    local p="$1"
    if command -v ss >/dev/null 2>&1; then
        # Use ss if available (commonly installed via iproute2)
        ss -ltn "sport = :${p}" -H | grep -q .
        return $?
    elif command -v lsof >/dev/null 2>&1; then
        # Fallback to lsof
        lsof -iTCP -sTCP:LISTEN -P -n 2>/dev/null | awk '{print $9}' | grep -Eo ':[0-9]+$' | cut -d: -f2 | grep -wq "${p}"
        return $?
    elif [ -r /proc/net/tcp ]; then
        # parse /proc/net/tcp (ports are hex)
        awk 'NR>1 {print $2}' /proc/net/tcp | cut -d: -f2 | while read -r hex; do printf "%d\n" 0x${hex}; done | grep -wq "${p}"
        return $?
    else
        # If we can't determine, assume free
        return 1
    fi
}

function get_port {
    # Iterate until we find a port that is not in LISTEN state
    until ! port_in_use "${PORT}"; do
        ((PORT++))
        echo "Checking port: ${PORT}"
    done
    echo "Got one !"
}

# Make a dir name from the IMAGE
IMAGE_SLASHED=$(echo "${IMAGE}" | sed 's/:/\//g' | sed 's/\.\./__/g')
R_DIRS="${HOME}/.rstudio-rocker/${IMAGE_SLASHED}"
RSTUDIO_DOT_LOCAL="${R_DIRS}/.local/share/rstudio"
RSTUDIO_DOT_CONFIG="${R_DIRS}/.config/rstudio"
RSTUDIO_TMP="${R_DIRS}/tmp"
R_LIBS_USER="${R_DIRS}/R"
RENV_PATHS_ROOT="${R_DIRS}/renv-local"
mkdir -p "${RSTUDIO_DOT_LOCAL}"
mkdir -p "${RSTUDIO_DOT_CONFIG}"
mkdir -p "${R_LIBS_USER}"
mkdir -p "${RSTUDIO_TMP}/var/run"
mkdir -p "${RENV_PATHS_ROOT}"

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

# Filesystem binds specific to the M3 cluster
if [[ $HPC_ENV == "m3" ]]; then
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
echo "  (you can change this location by setting APPTAINER_CACHEDIR)"
# Test the image works, execute a no-op command
${SINGULARITY_BIN} exec "${IMAGE_LOCATION}" true

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
export LC_CTYPE="C.UTF-8"
export LC_TIME="C.UTF-8"
export LC_MONETARY="C.UTF-8"
export LC_MESSAGES="C.UTF-8"
# shellcheck disable=SC2034
export LC_PAPER="C.UTF-8"
# shellcheck disable=SC2034
export LC_MEASUREMENT="C.UTF-8"

if [[ $HPC_ENV == 'm3' ]]; then
    if [[ -n ${SLURM_JOB_ID} ]]; then
      # For Strudel
      echo '{"password":"'"${PASSWORD}"'", "port": '"${PORT}"'}' >"${HOME}/.rstudio-rocker/rserver-${SLURM_JOB_ID}.json"
    fi
fi

${SINGULARITY_BIN} exec \
    --cleanenv \
    --env PASSWORD="${PASSWORD}" \
    --env USER="${USER}" \
    --env DEFAULT_USER="${USER}" \
    --env LC_CTYPE="${LC_CTYPE}" \
    --env LC_TIME="${LC_TIME}" \
    --env LC_MONETARY="${LC_MONETARY}" \
    --env LC_MESSAGES="${LC_MESSAGES}" \
    --env LC_PAPER="${LC_PAPER}" \
    --env LC_MEASUREMENT="${LC_MEASUREMENT}" \
    --env HOSTNAME="${HOSTNAME}" \
    --env APPTAINER_BINDPATH="${APPTAINER_BINDPATH}" \
    --env SINGULARITY_BINDPATH="${SINGULARITY_BINDPATH}" \
    --env RENV_PATHS_ROOT="${RENV_PATHS_ROOT}" \
    --bind "/etc/passwd:/etc/passwd:ro" \
    --bind "/etc/group:/etc/group:ro" \
    --bind "${RSTUDIO_TMP}:/tmp" \
    --bind "${RSTUDIO_TMP}/var:/var/lib/rstudio-server" \
    --bind "${RSTUDIO_TMP}/var/run:/var/run/rstudio-server" \
    --bind "${RSTUDIO_DOT_LOCAL}:${HOME}/.local/share/rstudio" \
    --bind "${RSTUDIO_DOT_CONFIG}:${HOME}/.config/rstudio" \
    --bind "${R_LIBS_USER}:${HOME}/R" \
    "${IMAGE_LOCATION}" \
        rserver --auth-none=1 \
                --auth-pam-helper-path=pam-helper \
                --www-port="${PORT}" \
                --server-user="${USER}"

printf 'rserver exited' 1>&2
