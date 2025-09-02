# syntax=docker/dockerfile:1.6
# Multi-target stack Dockerfile for GVL images (root paths)

# ============ Base: micromamba minimal ============
FROM mambaorg/micromamba:2.3.0 AS base-micromamba
USER root

COPY configs/ssh/sshd_config /etc/ssh/sshd_config
COPY environments/ /tmp/env/
COPY scripts/setup-dotfiles.sh /root/setup-dotfiles.sh
COPY scripts/user_env_install.sh /root/user_env_install.sh
COPY scripts/user_post_setup.sh /root/user_post_setup.sh
COPY scripts/provision-gvl.sh /root/provision-gvl.sh
COPY apt-packages.txt /apt-packages.txt
RUN --mount=type=secret,id=user_password \
    chmod +x /root/provision-gvl.sh /root/setup-dotfiles.sh && \
    NEW_USER=mcuoco NEW_USER_ID=2022 NEW_USER_GID=2022 /root/provision-gvl.sh

# ============ Target: mamba-gvl-micro ============
FROM base-micromamba AS mamba-gvl-micro
LABEL maintainer="Mike Cuoco <mcuoco@salk.edu>"
LABEL build.type="locked"
LABEL build.reproducible="true"
ENV CONDA_DEFAULT_ENV=base
EXPOSE 22 6006
USER root
CMD ["/usr/sbin/sshd", "-D"]

# ============ Base: jupyter minimal ============
FROM jupyter/minimal-notebook AS base-jupyter
USER root

COPY configs/ssh/sshd_config /etc/ssh/sshd_config
COPY environments/ /tmp/env/
COPY scripts/setup-dotfiles.sh /root/setup-dotfiles.sh
COPY scripts/user_env_install.sh /root/user_env_install.sh
COPY scripts/user_post_setup.sh /root/user_post_setup.sh
COPY scripts/provision-gvl.sh /root/provision-gvl.sh
COPY apt-packages.txt /apt-packages.txt
RUN --mount=type=secret,id=user_password \
    chmod +x /root/provision-gvl.sh /root/setup-dotfiles.sh && \
    NEW_USER=${NB_USER} NEW_USER_ID=${NB_UID} NEW_USER_GID=${NB_GID} /root/provision-gvl.sh

# ============ Target: mamba-gvl (notebook) ============
FROM base-jupyter AS mamba-gvl
LABEL maintainer="Mike Cuoco <mcuoco@salk.edu>"
LABEL build.type="locked"
LABEL build.reproducible="true"
ENV CONDA_DEFAULT_ENV=base
EXPOSE 22 8888
USER root
CMD ["/usr/sbin/sshd", "-D"]

# ============ Base: NVIDIA Parabricks ============
FROM nvcr.io/nvidia/clara/clara-parabricks:latest AS base-parabricks
USER root

COPY configs/ssh/sshd_config /etc/ssh/sshd_config
COPY environments/ /tmp/env/
COPY scripts/setup-dotfiles.sh /root/setup-dotfiles.sh
COPY scripts/user_env_install.sh /root/user_env_install.sh
COPY scripts/user_post_setup.sh /root/user_post_setup.sh
COPY scripts/provision-gvl.sh /root/provision-gvl.sh
COPY apt-packages.txt /apt-packages.txt
ENV NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility
RUN --mount=type=secret,id=user_password \
    chmod +x /root/provision-gvl.sh /root/setup-dotfiles.sh && \
    NEW_USER=mcuoco NEW_USER_ID=2022 NEW_USER_GID=2022 /root/provision-gvl.sh

# ============ Target: parabricks-gvl ============
FROM base-parabricks AS parabricks-gvl
LABEL maintainer="Mike Cuoco <mcuoco@salk.edu>"
LABEL build.type="locked"
LABEL build.reproducible="true"
ENV CONDA_DEFAULT_ENV=base
EXPOSE 22 6006
USER root
CMD ["/usr/sbin/sshd", "-D"]


