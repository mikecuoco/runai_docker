FROM mambaorg/micromamba:2.3.2 AS mamba-gvl-micro
LABEL maintainer="Mike Cuoco <mcuoco@salk.edu>"
LABEL build.type="locked"
LABEL build.reproducible="true"

# Environment file
ARG ENVIRONMENT_FILE=gvl.yml
# SSH public key
ARG SSH_PUBLIC_KEY=""
# Create your user
ARG NEW_MAMBA_USER=mcuoco
ARG NEW_MAMBA_USER_ID=2022
ARG NEW_MAMBA_USER_GID=2022

USER root

# Locale
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

# Install apt packages
COPY apt-packages.txt /apt-packages.txt
RUN apt-get update && \
    xargs -a /apt-packages.txt -r apt-get install -y --no-install-recommends && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /var/run/sshd

# SSH config and helper scripts
COPY configs/ssh/sshd_config /etc/ssh/sshd_config
COPY scripts/sshd-start.sh /usr/local/bin/sshd-start.sh
RUN chmod +x /usr/local/bin/sshd-start.sh

RUN usermod "--login=${NEW_MAMBA_USER}" "--home=/home/${NEW_MAMBA_USER}" \
        --move-home "-u ${NEW_MAMBA_USER_ID}" "${MAMBA_USER}" && \
    groupmod "--new-name=${NEW_MAMBA_USER}" \
        "-g ${NEW_MAMBA_USER_GID}" "${MAMBA_USER}" && \
    # Update the expected value of MAMBA_USER for the
    # _entrypoint.sh consistency check.
    echo "${NEW_MAMBA_USER}" > "/etc/arg_mamba_user" && \
    :
ENV MAMBA_USER=$NEW_MAMBA_USER

# Dotfiles and init scripts, as these change most often
USER $MAMBA_USER
COPY scripts/setup-dotfiles.sh /home/${MAMBA_USER}/setup-dotfiles.sh
RUN /home/${MAMBA_USER}/setup-dotfiles.sh

# Install micromamba environment as user
COPY environments/ /home/${MAMBA_USER}/environments/
RUN micromamba install --yes --name base --file "/home/${MAMBA_USER}/environments/${ENVIRONMENT_FILE}" && \
    micromamba clean --all --yes

# expose ports
EXPOSE 22 6006

