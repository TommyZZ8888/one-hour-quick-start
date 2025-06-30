注意：

1.本教程适用于有docker基础者，没有docker基础者请参考：《四、安装分布式MinIO（虚拟机）》 

2.一定要阅读英文原版文档，地址：https://docs.min.io/minio/baremetal/，中文官网文档更新不及时。

## 1.准备工作 

- Docker 20.10+

请自行安装docker

## 2.主机规划

提示：

由于docker-compose部署比较简单，因此我们部署一个比较完整的分布式MinIO服务，包含1个nginx负载均衡节点，1个prometheus监控节点，4个minio节点，每个节点2个存储卷。

![image-20250630091339283](F:\java_study\gitee\quick-start\minio\images\image-20250630091339283.png)

| 主机       | 磁盘                                | 说明     | 暴露端口             | 网络                                        |
| ---------- | ----------------------------------- | -------- | -------------------- | ------------------------------------------- |
| nginx      |                                     | 负载均衡 | 9000，9001（控制台） | 网络类型：bridge（桥接）网络名称：minio_net |
| minio1     | 每个主机2块磁盘/mnt/disk1/mnt/disk2 | 对象存储 |                      |                                             |
| minio2     |                                     |          |                      |                                             |
| minio3     |                                     |          |                      |                                             |
| minio4     |                                     |          |                      |                                             |
| prometheus |                                     | 状态监控 | 9090                 |                                             |

## 3.创建docker-compose.yml

注意：docker-compose.yml，nginx.conf，prometheus.yml需要存放在同一个目录下

```yaml
version: '3.7'

# Settings and configurations that are common for all containers
x-minio-common: &minio-common
  image: quay.io/minio/minio:RELEASE.2022-05-08T23-50-31Z
  command: server --console-address ":9001" http://minio{1...4}:9000/mnt/disk{1...2}
  environment:
    MINIO_ROOT_USER: minioadmin
    MINIO_ROOT_PASSWORD: minioadmin
    MINIO_PROMETHEUS_AUTH_TYPE: public
    MINIO_PROMETHEUS_URL: "http://prometheus:9090"
    MINIO_PROMETHEUS_JOB_ID: minio-job
    MINIO_STORAGE_CLASS_STANDARD: EC:3
    MINIO_STORAGE_CLASS_RRS: EC:2
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
    interval: 30s
    timeout: 20s
    retries: 3
  networks:
    - minio_net
# starts 4 docker containers running minio server instances.
# using nginx reverse proxy, load balancing, you can access
# it through port 9000.
services:
  minio1:
    <<: *minio-common
    container_name: minio1
    hostname: minio1
    volumes:
      - data1_1:/mnt/disk1
      - data1_2:/mnt/disk2 

  minio2:
    <<: *minio-common
    container_name: minio2
    hostname: minio2
    volumes:
      - data2_1:/mnt/disk1
      - data2_2:/mnt/disk2

  minio3:
    <<: *minio-common
    container_name: minio3
    hostname: minio3
    volumes:
      - data3_1:/mnt/disk1
      - data3_2:/mnt/disk2

  minio4:
    <<: *minio-common
    container_name: minio4
    hostname: minio4
    volumes:
      - data4_1:/mnt/disk1
      - data4_2:/mnt/disk2

  nginx:
    image: nginx:1.19.2-alpine
    container_name: nginx
    hostname: nginx
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    ports:
      - "9000:9000"
      - "9001:9001"
    networks:
      - minio_net
    depends_on:
      - minio1
      - minio2
      - minio3
      - minio4

  prometheus:
    image:  prom/prometheus
    container_name: prometheus
    hostname: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    networks:
      - minio_net
    depends_on:
      - minio1
      - minio2
      - minio3
      - minio4

## By default this config uses default local driver,
## For custom volumes replace with volume driver configuration.
volumes:
  data1_1:
  data1_2:
  data2_1:
  data2_2:
  data3_1:
  data3_2:
  data4_1:
  data4_2:

## 网络
networks:
  minio_net:
    name: minio_net
    driver: bridge
  
```

## 4.创建nginx.conf

```nginx
user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

events {
    worker_connections  4096;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;
    sendfile        on;
    keepalive_timeout  65;

    # include /etc/nginx/conf.d/*.conf;

    upstream minio {
        server minio1:9000;
        server minio2:9000;
        server minio3:9000;
        server minio4:9000;
    }

    upstream console {
        ip_hash;
        server minio1:9001;
        server minio2:9001;
        server minio3:9001;
        server minio4:9001;
    }

    server {
        listen       9000;
        listen  [::]:9000;
        server_name  localhost;

        # To allow special characters in headers
        ignore_invalid_headers off;
        # Allow any size file to be uploaded.
        # Set to a value such as 1000m; to restrict file size to a specific value
        client_max_body_size 0;
        # To disable buffering
        proxy_buffering off;
        proxy_request_buffering off;

        location / {
            proxy_set_header Host $http_host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            proxy_connect_timeout 300;
            # Default is HTTP/1, keepalive is only enabled in HTTP/1.1
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            chunked_transfer_encoding off;

            proxy_pass http://minio;
        }
    }

    server {
        listen       9001;
        listen  [::]:9001;
        server_name  localhost;

        # To allow special characters in headers
        ignore_invalid_headers off;
        # Allow any size file to be uploaded.
        # Set to a value such as 1000m; to restrict file size to a specific value
        client_max_body_size 0;
        # To disable buffering
        proxy_buffering off;
        proxy_request_buffering off;

        location / {
            proxy_set_header Host $http_host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-NginX-Proxy true;

            # This is necessary to pass the correct IP to be hashed
            real_ip_header X-Real-IP;

            proxy_connect_timeout 300;
            
            # To support websocket
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            
            chunked_transfer_encoding off;

            proxy_pass http://console;
        }
    }
}
```

## 5.创建prometheus.yaml

```yaml
global:
   scrape_interval: 15s

scrape_configs:
   - job_name: minio-job
     metrics_path: /minio/v2/metrics/cluster
     scheme: http
     static_configs:
     - targets: [minio1:9000,minio2:9000,minio3:9000,minio4:9000]
```

## 6.启动docker-compose

 创建并运行容器

```bash
docker-compose up -d
```

其他容器命令

```bash
# 查看日志
docker-compose logs -f

#停止容器
docker-compose stop

#启动容器
docker-compose start

#停止并删除容器
docker-compose down
```

注意：

1.docker-compose down命令删除容器后，并不会删除容器的存储卷，下次docker-compose up启动时，会自动挂载之前对应的存储卷，数据不会丢失。

2.如果你想释放空间或者清空所有数据，请使用 `docker volume prune -f `命令，此命令会删除没有容器使用的所有存储卷，删除后不可恢复。

## 7.访问控制台

控制台访问地址：[http://127.0.0.1:9001](http://127.0.0.1:9001/)

由于接入了prometheus，我们可以看到更多的监控指标信息。

![image-20250630091410156](F:\java_study\gitee\quick-start\minio\images\image-20250630091410156.png)

## 8.在容器中使用mc命令

```bash
#拉取镜像
docker pull minio/mc

#运行容器
#使用exit退出，容器自动销毁
docker run -it --net minio_net --entrypoint=/bin/sh --rm minio/mc

#可在容器内运行mc命令
mc alias set minio http://nginx:9000 minioadmin minioadmin
```



参考文档：https://docs.min.io/docs/deploy-minio-on-docker-compose.html

|      |      |      |
| ---- | ---- | ---- |
|      |      |      |
|      |      |      |
|      |      |      |
|      |      |      |