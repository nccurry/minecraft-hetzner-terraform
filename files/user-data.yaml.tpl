#cloud-config
users:
- name: fedora
  uid: 1001
  gid: 1001
  groups: users, admin
  sudo: ALL=(ALL) NOPASSWD:ALL
  shell: /bin/bash
  ssh_authorized_keys:
  - ${ public_ssh_key }
- name: mcserver
  uid: 1002
  gid: 1002
  groups: users
  shell: /bin/bash
package_update: true
package_upgrade: true
packages:
- podman
- curl
write_files:
- path: /usr/local/bin/partition-and-mount-disk.sh
  permissions: "0755"
  content: |
    ${indent(4, partition_and_mount_disk_sh_contents)}

- path: /usr/local/bin/download-papermc-plugins.sh
  permissions: "0755"
  content: |
    ${indent(4, download_papermc_plugins_sh_contents)}

- path: /etc/systemd/system/mcserver.service
  content: |
    ${indent(4, mcserver_service_contents)}

runcmd:
- /usr/local/bin/partition-and-mount-disk.sh
- /usr/local/bin/download-papermc-plugins.sh
- systemctl daemon-reload
- systemctl enable mcserver.service
- systemctl start mcserver.service
#- /usr/local/bin/download-papermc-plugins.sh
#- systemctl enable mcserver.service
#- mkfs.xfs /dev/sdb

#- systemctl enable nginx
#- ufw allow 'Nginx HTTP'
#- printf "[sshd]\nenabled = true\nbanaction = iptables-multiport" > /etc/fail2ban/jail.local
#- systemctl enable fail2ban
#- systemctl start fail2ban
#- ufw allow 'OpenSSH'
#- ufw enable
#- sed -ie '/^PermitRootLogin/s/^.*$/PermitRootLogin no/' /etc/ssh/sshd_config
#- sed -ie '/^PasswordAuthentication/s/^.*$/PasswordAuthentication no/' /etc/ssh/sshd_config
#- sed -ie '/^X11Forwarding/s/^.*$/X11Forwarding no/' /etc/ssh/sshd_config
#- sed -ie '/^#MaxAuthTries/s/^.*$/MaxAuthTries 2/' /etc/ssh/sshd_config
#- sed -ie '/^#AllowTcpForwarding/s/^.*$/AllowTcpForwarding no/' /etc/ssh/sshd_config
#- sed -ie '/^#AllowAgentForwarding/s/^.*$/AllowAgentForwarding no/' /etc/ssh/sshd_config
#- sed -ie '/^#AuthorizedKeysFile/s/^.*$/AuthorizedKeysFile .ssh/authorized_keys/' /etc/ssh/sshd_config
#- sed -i '$a AllowUsers devops' /etc/ssh/sshd_config
#- systemctl restart ssh
#- rm /var/www/html/*
#- echo "Hello! I am Nginx @ $(curl -s ipinfo.io/ip)! This record added at $(date -u)." >>/var/www/html/index.html


# The new disk is sdb