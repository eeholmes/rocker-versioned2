FROM docker.io/library/buildpack-deps:jammy
  # Avoid prompts from apt
  ENV DEBIAN_FRONTEND=noninteractive
  # Set up locales properly
  RUN apt-get -qq update && \
      apt-get -qq install --yes --no-install-recommends locales > /dev/null && \
      apt-get -qq purge && \
      apt-get -qq clean && \
      rm -rf /var/lib/apt/lists/*
  RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
      locale-gen
  ENV LC_ALL=en_US.UTF-8 \
      LANG=en_US.UTF-8 \
      LANGUAGE=en_US.UTF-8
  # Use bash as default shell, rather than sh
  ENV SHELL=/bin/bash
  # Set up user
  ENV NB_USER="jovyan"
  ENV NB_UID=1000
  ENV USER=${NB_USER} \
      HOME=/home/${NB_USER}
  RUN groupadd \
          --gid ${NB_UID} \
          ${NB_USER} && \
      useradd \
          --comment "Default user" \
          --create-home \
          --gid ${NB_UID} \
          --no-log-init \
          --shell /bin/bash \
          --uid ${NB_UID} \
          ${NB_USER}
  # Base package installs are not super interesting to users, so hide their outputs
  # If install fails for some reason, errors will still be printed
  RUN apt-get -qq update && \
      apt-get -qq install --yes --no-install-recommends \
         gettext-base \
         less \
         unzip \
         > /dev/null && \
      apt-get -qq purge && \
      apt-get -qq clean && \
      rm -rf /var/lib/apt/lists/*
  EXPOSE 8888
  # Environment variables required for build
  ENV APP_BASE=/srv
  ENV CONDA_DIR=${APP_BASE}/conda
  ENV NB_PYTHON_PREFIX=${CONDA_DIR}/envs/notebook
  ENV NPM_DIR=${APP_BASE}/npm
  ENV NPM_CONFIG_GLOBALCONFIG=${NPM_DIR}/npmrc
  ENV NB_ENVIRONMENT_FILE=/tmp/env/environment.lock
  ENV MAMBA_ROOT_PREFIX=${CONDA_DIR}
  ENV MAMBA_EXE=${CONDA_DIR}/bin/mamba
  ENV CONDA_PLATFORM=linux-64
  ENV KERNEL_PYTHON_PREFIX=${NB_PYTHON_PREFIX}
  # Special case PATH
  ENV PATH=${NB_PYTHON_PREFIX}/bin:${CONDA_DIR}/bin:${NPM_DIR}/bin:${PATH}
  RUN mkdir -p ${NPM_DIR} && \
  chown -R ${NB_USER}:${NB_USER} ${NPM_DIR}
  # ensure root user after build scripts
  USER root
  ENV REPO_DIR="/srv/repo"
  # Create a folder and grant the user permissions if it doesn't exist
  RUN if [ ! -d "${REPO_DIR}" ]; then \
          /usr/bin/install -o ${NB_USER} -g ${NB_USER} -d "${REPO_DIR}"; \
      fi
  WORKDIR ${REPO_DIR}
  RUN chown ${NB_USER}:${NB_USER} ${REPO_DIR}
  # We want to allow two things:
  #   1. If there's a .local/bin directory in the repo, things there
  #      should automatically be in path
  #   2. postBuild and users should be able to install things into ~/.local/bin
  #      and have them be automatically in path
  #
  # The XDG standard suggests ~/.local/bin as the path for local user-specific
  # installs. See https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
  ENV PATH=${HOME}/.local/bin:${REPO_DIR}/.local/bin:${PATH}
  # The rest of the environment
  ENV CONDA_DEFAULT_ENV=${KERNEL_PYTHON_PREFIX}
  # Run pre-assemble scripts! These are instructions that depend on the content
  # of the repository but don't access any files in the repository. By executing
  # them before copying the repository itself we can cache these steps. For
  # example installing APT packages.
  # ensure root user after preassemble scripts
  USER root
  # Copy stuff.
  COPY --chown=1000:1000 . ${REPO_DIR}/
  # Run assemble scripts! These will actually turn the specification
  # in the repository into an image.
  # Container image Labels!
  # Put these at the end, since we don't want to rebuild everything
  # when these change! Did I mention I hate Dockerfile cache semantics?
  LABEL repo2docker.ref="refs/heads/dev2"
  LABEL repo2docker.repo="https://github.com/nmfs-opensci/py-rocket-2"
  LABEL repo2docker.version="[202](https://github.com/nmfs-opensci/py-rocket-2/actions/runs/11257663103/job/31302445744#step:5:205)4.07.0+28.g239c4f5"
  # We always want containers to run as non-root
  USER ${NB_USER}
  # Add entrypoint
  ENV PYTHONUNBUFFERED=1
  # Specify the default command to run
  CMD ["jupyter", "notebook", "--ip", "0.0.0.0"]
  # Appendix:
  # Re-enable man pages disabled in Ubuntu 18 minimal image
  # https://wiki.ubuntu.com/Minimal
  USER root
  ENV R_VERSION="4.4.1"
  ENV R_HOME="/usr/local/lib/R"
  ENV TZ="Etc/UTC"
  RUN mkdir /rocker_scripts && \
    cp ${REPO_DIR}/scripts/install_R_source.sh /rocker_scripts/install_R_source.sh && \
    chmod +x /rocker_scripts/install_R_source.sh && \
    cd / && \
    /rocker_scripts/install_R_source.sh
  # Revert to default user
  USER ${NB_USER}