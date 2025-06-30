# 启用ssh密码认证
echo "[TASK 1] Enable ssh password authentication"
sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
systemctl reload sshd

# ssh以root用户登陆，需要重置root密码
echo "[TASK 2] change root password"
echo "root:123456" | sudo chpasswd

echo "[TASK 3] Add Aliyun registry mirror to containerd "  
mkdir -p /etc/rancher/k3s
cat >>/etc/rancher/k3s/registries.yaml<<EOF
mirrors:
  docker.io:
    endpoint:
      - "https://fsp2sfpr.mirror.aliyuncs.com/"
EOF