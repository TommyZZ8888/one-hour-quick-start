注意：

1.本课程适用于无docker基础者搭建minio分布式环境。

2.一定要阅读英文原版文档，地址：https://docs.min.io/minio/baremetal/，中文官网文档更新不及时。

## 1.准备工作 

- 虚拟机软件

VirtualBox：一款功能强大的虚拟化产品。免费、开源，IO性能好。

下载地址：https://download.virtualbox.org/virtualbox/6.1.34/VirtualBox-6.1.34-150636-Win.exe

- 系统镜像

Ubuntu 22.04 LTS （Server image）

​        下载地址：https://releases.ubuntu.com/22.04/ubuntu-22.04-live-server-amd64.iso

- MinIO安装包

由于在ubuntu可能遇到网络配置不对、安装源不能访问、访问速度慢等问题，因此建议提前将安装包下载到本地。

下载地址：https://dl.min.io/server/minio/release/linux-amd64/minio_20220508235031.0.0_amd64.deb

## 2.主机规划

注意：MinIO分布式模式至少需要4块磁盘(Driver)或者卷(Volume)，学习本课程需要8块磁盘。

| 主机   | 磁盘                                                         | 内存和CPU        | 虚拟机网络模式                                               |
| ------ | ------------------------------------------------------------ | ---------------- | ------------------------------------------------------------ |
| minio1 | /mnt/disk1            /mnt/disk2/mnt/disk3            /mnt/disk4 | 内存：2GCPU：2核 | 网卡1: Host-only 模式虚拟机和主机可以相互通信，但虚拟机无法访问外网网卡2: NAT网络可以访问外网 |
| minio2 | /mnt/disk1            /mnt/disk2/mnt/disk3            /mnt/disk4 | 内存：2GCPU：2核 |                                                              |

## 3.新建虚拟机

在VirtualBox中新建虚拟机

![img](https://cdn.nlark.com/yuque/0/2022/png/28915315/1652855336749-11d7fb3e-7abb-490c-9e8c-18571c59278e.png)

设置如下：

- 内存：2G

![img](https://cdn.nlark.com/yuque/0/2022/png/28915315/1652857102898-1134c39e-f79e-4df4-9904-e95a3cf12178.png)

- CPU：2核

![img](https://cdn.nlark.com/yuque/0/2022/png/28915315/1652857129067-647e3205-26aa-4193-a4bc-85c8de3f91e3.png)

- 存储

1块系统盘（10G），4块数据存储盘（1G），光驱载入ubuntu安装镜像。

数据存储盘推荐使用 xfs 格式，可以提高性能和稳定性。

![img](https://cdn.nlark.com/yuque/0/2022/png/28915315/1652857253240-0ee94b23-b591-40db-b45b-ce836c37f68e.png)

| 磁盘         | 容量 | 用途       | 挂载目录     | 格式 |
| ------------ | ---- | ---------- | ------------ | ---- |
| minio1.vdi   | 10G  | 系统盘     | /   ,  /boot | ext4 |
| minio1_1.vdi | 1G   | 数据存储盘 | /mnt/disk1   | xfs  |
| minio1_2.vdi | 1G   | 数据存储盘 | /mnt/disk2   | xfs  |
| minio1_3.vdi | 1G   | 数据存储盘 | /mnt/disk3   | xfs  |
| minio1_4.vdi | 1G   | 数据存储盘 | /mnt/disk4   | xfs  |

- 网络

新建全局网络

![img](https://cdn.nlark.com/yuque/0/2022/png/28915315/1653033824442-f259b7ee-52eb-4c66-ad9c-40a7c47165c5.png)

网卡1 :  Host-Only 模式

![img](https://cdn.nlark.com/yuque/0/2022/png/28915315/1653033917395-18b5e6a6-c14f-4ed8-8fb3-fde06590267c.png)

网卡2 : NAT 网络

![img](https://cdn.nlark.com/yuque/0/2022/png/28915315/1653033973391-e3bb84b7-5cf7-420e-8032-ceca858fc443.png)

## 4.安装系统

#### 1.安装Ubuntu Server。

注意：安装类型选择Ubuntu Server，不要选择minimized，最小化安装可能会导致后续缺少必要的依赖包。

![img](https://cdn.nlark.com/yuque/0/2022/png/28915315/1652856049057-e82bf025-b4bb-443e-a3ef-502be9988483.png)

#### 2.磁盘格式化、挂载

将数据盘格式为xfs，并挂载到规划的目录下

![img](https://cdn.nlark.com/yuque/0/2022/png/28915315/1652856279766-f0c7fa23-59a5-4e73-87ff-f380363951c7.png)

![img](https://cdn.nlark.com/yuque/0/2022/png/28915315/1652856304146-f3eb1e9c-e9e4-42f9-a9ad-6c40745b3b15.png)

![img](https://cdn.nlark.com/yuque/0/2022/png/28915315/1652856337609-382e88e1-ad1c-4048-80c7-d0407d69ddf4.png)

![img](https://cdn.nlark.com/yuque/0/2022/png/28915315/1652856387575-9a5f120d-8513-4b41-ab07-e233494b8871.png)

**最终文件系统目录如下**

![img](https://cdn.nlark.com/yuque/0/2022/png/28915315/1652858979339-0ef369f8-ce21-4d1f-b127-107154fba2a9.png)

#### 3.设置主机名、用户名、密码

主机名：minio1

用户名/密码：minio/minio

![img](https://cdn.nlark.com/yuque/0/2022/png/28915315/1652856620777-312a4d49-eedb-4f12-ab65-f0e0e8af9488.png)

#### 4.安装OpenSSH

安装OpenSSH，用户可通过ssh命令远程操作服务器。

![img](https://cdn.nlark.com/yuque/0/2022/png/28915315/1652856654807-6c82bf22-8a16-48c1-8753-eb7815deeb90.png)

#### 5.安装完毕，重启系统

![img](https://cdn.nlark.com/yuque/0/2022/png/28915315/1652860184604-194c1bfd-2016-4776-b964-8665cad5eff9.png)

#### 6.查看IP

重启后，进入虚拟机，通过`ip a`命令查看IP，主机可通过此IP访问虚拟机。

![img](https://cdn.nlark.com/yuque/0/2022/png/28915315/1652862032890-49a057d5-ef9f-42a0-9622-5dcc587ae211.png)

## 5.安装MinIO（单节点）

- **上传安装包**

将安装包下载到本地后，用scp命令上传到虚拟机。

```bash
scp minio_20220508235031.0.0_amd64.deb minio@192.168.56.104:~
```

- **在虚拟机里运行安装命令**

```bash
sudo dpkg -i minio_20220508235031.0.0_amd64.deb
```

注意：安装完成后，会自动生成service文件 `/etc/systemd/system/minio.service`

- **创建用户、组、目录访问权限**

```bash
sudo groupadd -r minio-user
sudo useradd -M -r -g minio-user minio-user
chown minio-user:minio-user /mnt/disk1 /mnt/disk2 /mnt/disk3 /mnt/disk4
```

- **创建启动环境变量配置文件**

注意：本示例没有配置http证书，配置文件里的访问地址统一使用http，请不要使用https

创建一个新的文件：`/etc/default/minio`，内容如下：

```bash
# 主机和卷设置
# 没有配置证书，使用http
MINIO_VOLUMES="http://minio1:9000/mnt/disk{1...4}"

# 控制台端口
MINIO_OPTS="--console-address :9001"

# 用户名
MINIO_ROOT_USER=minioadmin

# 密码
MINIO_ROOT_PASSWORD=minioadmin

# 对象存储服务地址
MINIO_SERVER_URL="http://minio1:9000"
```

- **启动minio服务、查看状态、查看日志**

```plain
#启动minio
sudo systemctl start minio.service

#查看状态
sudo systemctl status minio.service

#查看日志
journalctl -u minio.service -f
```

- **访问控制台**

通过虚拟机IP访问控制台：[http://192.168.56.104:9001](http://192.168.56.104:9001/)

默认用户名/密码：minioadmin/minioadmin

![img](https://cdn.nlark.com/yuque/0/2022/png/28915315/1652864898889-ff9b1481-fdc8-45b1-a7b4-4d01deed66b0.png)

- **在控制台查看运行指标**

## ![img](https://cdn.nlark.com/yuque/0/2022/png/28915315/1652865104069-640bfa96-c173-46c3-960f-c8757d77ac4b.png)

## 6.多节点安装

- 将虚拟机minio1复制一份，进入虚拟机修改hostname为minio2

注意：minio的主机名和磁盘目录命名格式一定要一致，且数字连续。

```bash
sudo hostnamectl set-hostname minio2
```

#### 1.配置静态IP

注意：默认网络配置启动DHCP自动获取IP，主机重启后IP有可能发生变化，因此需要配置静态IP。

修改 minio1、minio2的网络配置

```bash
sudo vi /etc/netplan/00-installer-config.yaml
```

配置文件内容如下：

```yaml
network:
  ethernets:
    enp0s3:
      dhcp4: no
      addresses:
        - 192.168.56.104/24
    enp0s8:
      dhcp4: true
      nameservers:
          addresses: [1.1.1.1, 8.8.8.8, 4.4.4.4]
  version: 2
```

配置生效

```bash
sudo netplan apply
```

同理修改minio2

```yaml
network:
  ethernets:
    enp0s3:
      dhcp4: no
      addresses:
        - 192.168.56.105/24
    enp0s8:
      dhcp4: true
      nameservers:
          addresses: [1.1.1.1, 8.8.8.8, 4.4.4.4]
  version: 2
```

#### 2.修改hosts文件

修改minio1、minio2的 `/etc/hosts`，内容如下：

```bash
192.168.56.104  minio1
192.168.56.105  minio2
127.0.0.1 localhost
```

#### 3.修改环境变量配置文件

修改 `/etc/default/minio` ，内容如下：

```bash
# 主机和卷设置
# 没有配置证书，使用http
MINIO_VOLUMES="http://minio{1...2}:9000/mnt/disk{1...4}"

# 控制台端口
MINIO_OPTS="--console-address :9001"

# 用户名
MINIO_ROOT_USER=minioadmin

# 密码
MINIO_ROOT_PASSWORD=minioadmin

# 对象存储服务地址
MINIO_SERVER_URL="http://minio1:9000"
```

#### 4.启动服务

注意：由于之前minio1已经启动过，重新部署会报错如下错误：

ERROR Unable to initialize backend: /mnt/disk1 disk is already being used in another erasure deployment

解决此问题，需要启动服务前清空数据目录下的所有数据，包括隐藏的.minio.sys文件夹

清空minio1、minio2数据目录下的所有数据。

```bash
sudo rm -rf /mnt/disk*/* 
sudo rm -rf /mnt/disk*/.* 
```

分别在minio1、minio2启动服务

```bash
systemctl start minio.service
```

查看启动日志

```bash
journalctl -u minio.service -f
```

可以访问任意主机的控制台

http://192.168.56.104:9001/login

http://192.168.56.104:9001/login

在控制台里可以看到server变成了2台，一共8块硬盘。

![img](https://cdn.nlark.com/yuque/0/2022/png/28915315/1652931629781-bfa43546-adcb-4a50-94f6-ecebb2dfa8ed.png)

#### 5.配置开机启动

在每台主机上运行下列命令

```bash
sudo systemctl enable minio.service
```

## 7.安装客户端

下载mc客户端到本地，下载地址：https://dl.min.io/client/mc/release/linux-amd64/mc

上传到任意一台服务器用户目录下

```bash
scp mc minio@192.168.56.104:~
```

登录到服务器，将mc拷贝到/usr/local/bin目录下，添加执行权限

```bash
sudo scp ~/mc /usr/local/bin/
sudo chmod +x /usr/local/bin/mc
mc -version
```

|      |      |      |
| ---- | ---- | ---- |
|      |      |      |
|      |      |      |
|      |      |      |
|      |      |      |