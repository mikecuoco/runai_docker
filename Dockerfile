FROM mambaorg/micromamba:2.3.2 AS mamba-gvl-micro
LABEL maintainer="Mike Cuoco <mcuoco@salk.edu>"
LABEL build.type="locked"
LABEL build.reproducible="true"

# Environment file
ARG ENVIRONMENT_FILE=gvl.yml
# Optional: SSH public key (provide at build with --build-arg SSH_PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)")
ARG SSH_PUBLIC_KEY=""
# Create your user
ARG NEW_MAMBA_USER=mcuoco
ARG NEW_MAMBA_USER_ID=2022
ARG NEW_MAMBA_USER_GID=2022
ENV MAMBA_ROOT_PREFIX=/opt/conda

USER root

# Locale
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

# Install apt packages (expects openssh-server and openssh-client in apt-packages.txt)
COPY apt-packages.txt /apt-packages.txt
RUN apt-get update && \
    xargs -a /apt-packages.txt -r apt-get install -y --no-install-recommends && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /var/run/sshd && ssh-keygen -A

# SSH server config
COPY configs/ssh/sshd_config /etc/ssh/sshd_config

# Rename base mambauser -> NEW_MAMBA_USER and update UID/GID
RUN usermod "--login=${NEW_MAMBA_USER}" "--home=/home/${NEW_MAMBA_USER}" \
        --move-home "-u ${NEW_MAMBA_USER_ID}" "${MAMBA_USER}" && \
    groupmod "--new-name=${NEW_MAMBA_USER}" "-g ${NEW_MAMBA_USER_GID}" "${MAMBA_USER}" && \
    echo "${NEW_MAMBA_USER}" > "/etc/arg_mamba_user" && \
    echo "$NEW_MAMBA_USER:password" | chpasswd && \
    usermod -aG sudo "$NEW_MAMBA_USER" && \
    echo "$NEW_MAMBA_USER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    chown -R "$NEW_MAMBA_USER_ID":"$NEW_MAMBA_USER_GID" "/home/$NEW_MAMBA_USER" && \
    chown -R "$NEW_MAMBA_USER_ID":"$NEW_MAMBA_USER_GID" "$MAMBA_ROOT_PREFIX"
ENV MAMBA_USER=$NEW_MAMBA_USER

# Dotfiles and init scripts (as your user)
USER $MAMBA_USER
COPY scripts/setup-dotfiles.sh /home/${MAMBA_USER}/setup-dotfiles.sh
RUN /home/${MAMBA_USER}/setup-dotfiles.sh 

# Install micromamba environment as user from environments/ directory
USER $MAMBA_USER
COPY environments/ /home/${MAMBA_USER}/environments/
RUN micromamba install --yes --name base --file "/home/${MAMBA_USER}/environments/${ENVIRONMENT_FILE}" && \
micromamba clean --all --yes

# Expose SSH
EXPOSE 22

# Run as root to manage sshd
USER root
# System-wide micromamba init + auto-activate base (ensure correct prefix)
RUN printf "%s\n" \
  'export MAMBA_ROOT_PREFIX=/opt/conda' \
  'eval "$(micromamba shell hook -s bash)"' \
  'micromamba activate base' \
  > /etc/profile.d/micromamba.sh && echo "source /etc/profile.d/micromamba.sh" > /home/${MAMBA_USER}/.dotfiles/.extra
CMD ["/usr/sbin/sshd", "-D"]