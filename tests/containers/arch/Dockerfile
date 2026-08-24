FROM archlinux:base@sha256:e5bfcd41ddf6190dc3fdafe0d2979b039a82f006b1666a3d207e80c9e70a00d9

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
