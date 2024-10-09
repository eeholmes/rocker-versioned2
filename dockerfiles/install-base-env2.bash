#!/bin/bash
# This downloads and installs a pinned version of micromamba
# and sets up the base environment
set -ex

cd $(dirname $0)

export MAMBA_VERSION=1.5.9
export CONDA_VERSION=24.5.0

URL="https://anaconda.org/conda-forge/micromamba/${MAMBA_VERSION}/download/${CONDA_PLATFORM}/micromamba-${MAMBA_VERSION}-0.tar.bz2"

# make sure we don't do anything funky with user's $HOME
# since this is run as root
unset HOME
mkdir -p ${CONDA_DIR}

export MICROMAMBA_EXE="/usr/local/bin/micromamba"

time wget -qO- ${URL} | tar -xvj bin/micromamba
mv bin/micromamba "$MICROMAMBA_EXE"
chmod 0755 "$MICROMAMBA_EXE"

eval "$(${MICROMAMBA_EXE} shell hook -p ${CONDA_DIR} -s posix)"

micromamba activate

export PATH="${PWD}/bin:$PATH"

cat <<EOT >> ${CONDA_DIR}/.condarc
channels:
  - conda-forge
auto_update_conda: false
show_channel_urls: true
update_dependencies: false
# channel_priority: flexible
EOT

micromamba install conda=${CONDA_VERSION} mamba=${MAMBA_VERSION} -y

echo "installing notebook env:"
cat "${NB_ENVIRONMENT_FILE}"


#time ${MAMBA_EXE} create -p ${NB_PYTHON_PREFIX} --file "${NB_ENVIRONMENT_FILE}"
# create empty env
#time ${MAMBA_EXE} create -p ${NB_PYTHON_PREFIX}
# empty conda history file,
# which seems to result in some effective pinning of packages in the initial env,
# which we don't intend.
# this file must not be *removed*, however
# echo '' > ${NB_PYTHON_PREFIX}/conda-meta/history

# Clean things out!
time ${MAMBA_EXE} clean --all -f -y

# Remove the pip cache created as part of installing micromamba
rm -rf /root/.cache

chown -R $NB_USER:$NB_USER ${CONDA_DIR}

# Capture the output of 'conda list icu'
icu_output=$(conda list icu)
echo "$icu_output"

#${MAMBA_EXE} list -p ${NB_PYTHON_PREFIX}

# Set NPM config
#${NB_PYTHON_PREFIX}/bin/npm config --global set prefix ${NPM_DIR}
