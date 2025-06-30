## 1. 使用mc客户端上传数据

提示：准备3个不同大小的文件，本示例中，image.jpg为小对象（387K），document.pdf为中等大小对象（13M），video.mp4为大对象（52M）

![img](https://cdn.nlark.com/yuque/0/2022/png/28915315/1653027114876-00a15537-ceb8-4f41-8fd9-299de18254a8.png)

使用mc命令创建别名、创建bucket、上传对象

```bash
# 设置别名  后三个参数为访问地址、用户名、密码
mc alias set my-minio http://minio1:9000 minioadmin minioadmin

# 创建bucket
mc mb my-minio/my-bucket

#上传小对象，并重名为small-object.jpg
mc cp image.jpg my-minio/my-bucket/small-object.jpg

#上传中等大小对象，并重名为medium-object.pdf
mc cp document.pdf my-minio/my-bucket/medium-object.pdf

#上传大对象，并重名为large-object.mp4
mc cp video.mp4 my-minio/my-bucket/large-object.mp4

#查看目录
mc tree --files my-minio
```

目录如下：

![img](https://cdn.nlark.com/yuque/0/2022/png/28915315/1652958330255-f5b519ad-4538-4fa9-b524-4415e1faa8ae.png)

## 2. 数据块和奇偶校验块

MinIO 使用 Reed-Solomon 算法根据磁盘总数将对象拆分为M个数据块（data block）和N个奇偶校验块（parity blocks）， M + N = 磁盘总数（即Erasure Set的大小），MinIO 将数据块和奇偶校验块随机存储到不同的磁盘，没有重叠，因此可以保障任意丢失 N 块磁盘，数据仍然可以恢复。

- 当磁盘数量 <= 8时，MinIO默认采用 M:N 为 1:1的方式存储数据。

假设磁盘总数为8，对象会被会拆分为 4 个数据块和 4 个奇偶校验块，分别存储到不同的磁盘中，这样即使有一半的硬盘损坏，如何仍可恢复。

注意：当 M 和 N 为 1:1 时,丢失 N 块磁盘数据仍可以读取，但是写入数据至少需要 N+1 块磁盘。

- 当磁盘数量 > 8时，默认奇偶校验块的数量为 4，即 N = 4 。

假设磁盘总数为 16，对象会被拆分为 12 个数据块和 4 个奇偶校验块，最多可以容忍4块磁盘丢失。

- 自定义奇偶校验块数量（EC:N）

用户可以在环境变量文件中加入[MINIO_STORAGE_CLASS_STANDARD](https://docs.min.io/minio/baremetal/reference/minio-server/minio-server.html#envvar.MINIO_STORAGE_CLASS_STANDARD)来自定义奇偶校验块数量。

MINIO_STORAGE_CLASS_STANDARD默认设置：

| 磁盘总数（Erasure Set大小） | 奇偶校验块数量（EC:N） |
| --------------------------- | ---------------------- |
| <= 5                        | 2                      |
| 6-7                         | 3                      |
| >= 8                        | 4                      |

在环境变量配置文件`/etc/default/minio `加入以下配置

```bash
#自定义奇偶校验块数量
#不能大于磁盘总数的一半
MINIO_STORAGE_CLASS_STANDARD="EC:4"
```

- 低冗余存储（REDUCED_REDUNDANCY）

MinIO除了允许配置上述的标准存储（MINIO_STORAGE_CLASS_STANDARD）类型，还提供了一种低冗余存储类型（MINIO_STORAGE_CLASS_RRS）。

低冗余存储类型适合存储不是很重要的对象，它允许产生更少的奇偶校验块，从而节省磁盘空间。

修改环境变量配置文件`/etc/default/minio `，完整内容如下

```bash
#自定义奇偶校验块数量
#不能大于磁盘总数的一半
MINIO_STORAGE_CLASS_STANDARD="EC:4"

#自定义低冗余存储类型的奇偶校验块数量 ，默认值为 2
MINIO_STORAGE_CLASS_RRS="EC:2"

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

采用低冗余存储类型上传数据。

```bash
#低冗余存储类型上传数据
mc cp --storage-class REDUCED_REDUNDANCY image.jpg my-minio/my-bucket/reduce.jpg

mc ls my-minio/my-bucket
```

![img](https://cdn.nlark.com/yuque/0/2022/png/28915315/1653038043695-f5d4baf9-8169-4ab3-9975-e0eda63e23c9.png)

## 3. 数据存储结构

MinIO将数据块和奇偶校验块写入不同的磁盘，每个磁盘都维护相同的目录结构，每个对象都包含一个元数据描述文件xl.json和存储文件part.1 , part.1可能是数据块，也可能是奇偶校验块。

![img](https://cdn.nlark.com/yuque/0/2022/png/28915315/1652958554004-83581bbc-4990-4d6d-9800-209e3d41390f.png)

注意：MinIO从2021-04-22版本之后，实际的磁盘存储结构发生了变化。

进入minio1，使用tree命令查看目录结构，实际的目录存储结构如下图所示

![img](https://cdn.nlark.com/yuque/0/2022/png/28915315/1653026030522-3217a62e-0d98-4ef0-bac4-923618d02b31.png)

- 元数据文件由 xl.json 变为了 xl.meta

从 2021-04-22 版本开始，MinIO将JSON格式的元数据文件（xl.json）序列化为二进制文件(xl.meta)，这将减少磁盘占用，提高CPU使用率。但是在调试过程中，查看元数据变得困难。

- 小对象

对于小对象，MinIO将元数据和数据都存储到xl.meta中。

通常小于 128KiB 的数据块可能会与元数据内联存储。

例如 small-object.jpg目录下，只有xl.meta文件，这样可以减少文件数量，提高读写性能。

注意：这里不是指对象自身小于 128 Kib，而是指被拆分之后的数据块小于 128 Kib。 

small-object.jpg大小为387K，被拆分后数据块仍会与元数据内联存储。

- 中等大小对象

例如 medium-object.pdf，元数据存在xl.meta中，存储文件为part.1，放在data-uuid文件夹下。

- 大对象

对于大对象，MinIO会生成1个元数据文件和多个part。

例如 large-object.mp4，data-uuid文件夹下有4个存储文件，分别为 part.1、part.2、part.3、part.4。

注意：MinIO单个对象最多允许被拆分为 10000 个part，每个part最大为5G，单个对象最大限制为5T。

如果你不希望存储文件被拆分多个part，可以使用 `--disable-multipart `参数。

```bash
mc cp --disable-multipart video.mp4 my-minio/my-bucket/video.mp4
```

使用控制台web上传对象时，默认使用--disable-multipart，不会被保存为多个part。

## 4.查看元数据

查看元数据需要安装go语言，由于网络或其他原因，安装可能报错，建议没有go基础者跳过此节内容。

每个对象都对应一个元数据文件 xl.meta，由于 xl.meta是二进制文件，因此需要特定的工具来查。

使用说明：https://github.com/minio/minio/tree/master/docs/debugging#decoding-metadata

```bash
sudo apt install golang-go

export GOPROXY=https://goproxy.cn

go install github.com/minio/minio/docs/debugging/xl-meta@latest

#版本号可能跟此不同
cd ~/go/pkg/mod/github.com/minio/minio@v0.0.0-20220519201849-18a4276e25a2/docs/debugging/xl-meta

go run main.go /mnt/disk1/my-bucket/reduce.jpg/xl.meta
{
  "Versions": [
    {
      "Header": {
        "Flags": 6,
        "ModTime": "2022-05-20T08:53:36.137838324Z",
        "Signature": "e2be7eaa",
        "Type": 1,
        "VersionID": "00000000000000000000000000000000"
      },
      "Idx": 0,
      "Metadata": {
        "Type": 1,
        "V2Obj": {
          "CSumAlgo": 1,
          "DDir": "FgF+/IJbS5u+w3Kpo1Km8A==",
          "EcAlgo": 1,
          "EcBSize": 1048576,
          "EcDist": [
            8,
            1,
            2,
            3,
            4,
            5,
            6,
            7
          ],
          "EcIndex": 1,
          "EcM": 6,
          "EcN": 2,
          "ID": "AAAAAAAAAAAAAAAAAAAAAA==",
          "MTime": 1653036816137838324,
          "MetaSys": {
            "x-minio-internal-inline-data": "dHJ1ZQ=="
          },
          "MetaUsr": {
            "content-type": "image/jpeg",
            "etag": "e48bfd6eccd6d5f256d4f5905c439038",
            "x-amz-storage-class": "REDUCED_REDUNDANCY"
          },
          "PartASizes": [
            395345
          ],
          "PartETags": null,
          "PartNums": [
            1
          ],
          "PartSizes": [
            395345
          ],
          "Size": 395345
        }
      }
    }
  ]
}
```

其中，"EcM": 6代表数据块数量， "EcN": 2代表奇偶校验块数量 。



参考：https://blog.min.io/minio-optimizes-small-objects/

https://blog.min.io/minio-versioning-metadata-deep-dive/









### 



## 

|      |      |      |
| ---- | ---- | ---- |
|      |      |      |
|      |      |      |
|      |      |      |
|      |      |      |