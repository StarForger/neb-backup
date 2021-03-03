FROM alpine:3.12 as builder

# Required Arguments for git downloads
ARG NEB_BASH_VERSION=0.1.0
ARG NEB_RCON_VERSION=0.1.0  

# Get Bash Commons
RUN wget -O /tmp/neb-bash.tgz \
  https://github.com/StarForger/neb-bash/releases/download/v${NEB_BASH_VERSION}/neb-bash.tgz \
  && mkdir -p /opt/builder/neb-bash/ \
  && tar -xf /tmp/neb-bash.tgz -C /opt/builder/neb-bash/;

# Get RCON cli
RUN wget -O /tmp/neb-mc-rcon.tgz \
  https://github.com/StarForger/neb-mc-rcon/releases/download/v${NEB_RCON_VERSION}/neb-mc-rcon-linux-amd64.tgz \
  && mkdir -p /opt/builder/neb-mc-rcon/ \
  && tar -xf /tmp/neb-mc-rcon.tgz -C /opt/builder/neb-mc-rcon/;

# Copy root assets
COPY assets/root/ /root-assets

RUN find /root-assets -exec chmod 0644 {} \; ;

# <:>:<:>:<:>:<:>:<:>:<:>:<:>:<:>:<:>:<:>:<:>:<:>:<:>:<:>:<:> #

FROM alpine

# Dependencies
# 
# - bash
# - coreutils
# - openssh-client
# - restic
# - sudo
# TODO finish dependency descriptions
RUN apk --update-cache --no-cache upgrade; \
    apk add --update-cache --no-cache \
    bash \
    coreutils \
    openssh-client \
    restic \
    sudo \
  ; 

# Default environment variables
ENV NEB_BACKUP_TYPE="tar" \
    NEB_BACKUP_NAME="neb-backup" \ 
    NEB_BACKUP_RETENTION=7d \
    NEB_BACKUP_EXCLUDES=*.tmp,cache,logs \
    NEB_BACKUP_DELAY=2m \
    NEB_BACKUP_INTERVAL=12h \
    RESTIC_REPOSITORY="/usr/local/backup"   

# Copy requirements from builder
COPY --from=builder /root-assets/. /root/
COPY --from=builder /root-assets/. /etc/skel/
COPY --from=builder /opt/builder/ /opt/

# TODO improve RUNs

# Add user
RUN addgroup -g 9999 backer; \
    adduser -Ss /bin/false -u 1000 -G backer -h /home/backer backer; \
    echo "%backer ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/backer;

# Copy scripts
COPY scripts/ /opt/neb-backup

# Add sym links
RUN ln -s /opt/neb-backup/entrypoint.sh /usr/local/bin/entrypoint; \
    ln -s /opt/neb-mc-rcon/neb-mc-rcon /usr/local/bin/rcon;

# User and Working Directory
USER backer

# Entrypoint
ENTRYPOINT [ "entrypoint" ] 
