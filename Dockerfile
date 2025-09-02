# syntax=docker/dockerfile:1.6
# Multi-target stack Dockerfile for GVL images (root paths)

# ============ Base: micromamba minimal ============
FROM mambaorg/micromamba:2.3.2 AS base-micromamba
ARG ENVIRONMENT_FILE=gvl.yml
USER root

# Files
COPY apt-packages.txt /apt-packages.txt
COPY environments/ /tmp/env/
COPY configs/ssh/sshd_config /etc/ssh/sshd_config
COPY scripts/user-setup.sh /root/user-setup.sh

# Packages and SSHD dir
RUN apt-get update && \
xargs -a /apt-packages.txt -r apt-get install -y --no-install-recommends && \
apt-get clean && rm -rf /var/lib/apt/lists/* && \
mkdir -p /var/run/sshd && chmod 755 /var/run/sshd

# Generate SSH host keys at build time
RUN ssh-keygen -A

# User setup
RUN chmod +x /root/user-setup.sh && \
NEW_USER=${NEW_USER} NEW_USER_ID=${NEW_USER_ID} NEW_USER_GID=${NEW_USER_GID} /root/user-setup.sh

# micromamba root prefix and env install
ENV NEW_USER=mcuoco NEW_USER_ID=2022 NEW_USER_GID=2022

# MAMBA_ROOT_PREFIX and MAMBA_EXE exist from parent image
RUN mkdir -p "$MAMBA_ROOT_PREFIX" && \
chown -R ${NEW_USER_ID}:${NEW_USER_GID} "$MAMBA_ROOT_PREFIX" && \
$MAMBA_EXE install --yes --root-prefix "$MAMBA_ROOT_PREFIX" --name base --file "/tmp/env/${ENVIRONMENT_FILE}" && \
$MAMBA_EXE clean --all --yes && \
chown -R ${NEW_USER_ID}:${NEW_USER_GID} "$MAMBA_ROOT_PREFIX"

# Dotfiles setup as user
USER $NEW_USER
COPY scripts/setup-dotfiles.sh /home/${NEW_USER}/setup-dotfiles.sh
COPY scripts/user_post_setup.sh /home/${NEW_USER}/user_post_setup.sh
RUN /home/${NEW_USER}/setup-dotfiles.sh && /home/${NEW_USER}/user_post_setup.sh


# ============ Target: mamba-gvl-micro ============
FROM base-micromamba AS mamba-gvl-micro
LABEL maintainer="Mike Cuoco <mcuoco@salk.edu>"
LABEL build.type="locked"
LABEL build.reproducible="true"
ENV CONDA_DEFAULT_ENV=base
EXPOSE 22 6006
USER root
CMD ["/usr/sbin/sshd", "-D"]
