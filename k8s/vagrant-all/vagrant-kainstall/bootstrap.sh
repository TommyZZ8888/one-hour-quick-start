#!/bin/bash
echo "[TASK 0] Set Aliyun Ubuntu mirrors"
sed -i '/^#/d;/^$/d' /etc/apt/sources.list
sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list
sed -i 's/security.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list
apt-get update -qq >/dev/null 2>&1

echo "[Task 1] Enable ssh password authentication"
sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
systemctl reload sshd

echo "[Task 2] Set root password"
echo -e "123456\n123456" | passwd root >/dev/null 2>&1
echo "export TERM=xterm" >> /etc/bash.bashrc

echo "[Task 3] Install sshpass"
apt-get update -qq && apt-get install -y -qq sshpass >/dev/null 2>&1