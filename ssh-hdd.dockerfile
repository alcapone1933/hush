FROM alcapone1933/alpine:latest
ENV TZ=Europe/Berlin
# System vorbereiten & OpenSSH installieren
RUN apk update && apk add --no-cache openssh bash tzdata smartmontools hdparm libfdisk \
    && mkdir -p /root/.ssh \
    && sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#Port 22/Port 22/' /etc/ssh/sshd_config \
    && ssh-keygen -A \
    && rm -rf /var/cache/apk/*

RUN cat <<'EOF' > /usr/local/bin/entrypoint.sh
#!/bin/sh

: "${SFTP_PASSWORD:=rootpass}"
: "${TZ:=Europe/Berlin}"
ln -snf /usr/share/zoneinfo/"$TZ" /etc/localtime && echo "$TZ" > /etc/timezone

echo "root:${SFTP_PASSWORD}" | chpasswd
echo "[INFO] Root password set to value from SFTP_PASSWORD"

exec /usr/sbin/sshd -D
EOF

RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 22

ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/entrypoint.sh"]