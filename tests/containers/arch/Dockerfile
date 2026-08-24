FROM archlinux:base@sha256:4bf33b21a715aac0b48ce6e9eaed4782a898eae96f88f5da3635572129c2584a

ENV container=docker

RUN pacman -Syu --noconfirm \
    ca-certificates \
    openssh \
    python \
    sudo \
    systemd \
    && pacman -Scc --noconfirm \
    && mkdir -p /run/sshd \
    && systemctl mask \
        dev-hugepages.mount \
        sys-fs-fuse-connections.mount \
        systemd-remount-fs.service

STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
