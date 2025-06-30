## 1.用户（User）与服务账户（Service Account）

如果MinIO为多个业务应用系统（例如CRM系统、OA系统）提供对象存储服务，那么你可以为每个应用系统创建一个用户。

由于每个业务系统下可能会有很多帐户，这些对于MinIO来说属于外部帐户，MinIO不可能知道外部业务系统有哪些账户，因此通过MinIO管理员给外部账户赋权是不符合实际的。因此，MinIO允许用户创建下级服务账户。这样MinIO管理员只需要给各应用系统创建用户，由用户来管理各业务系统的账户。

注意：子帐户不能登录控制台，但可以通过mc命令或S3协议来操作桶和对象。

![img](https://cdn.nlark.com/yuque/0/2022/png/28915315/1653378749433-c10eaffe-b0a6-435f-a6fb-fdba9e1187bd.png)

如上图所以，我们分别创建2个用户

- minio-crm-user只能操作以 `crm-`开头命名的bucket
- minio-oa-user只能操作以 `oa-`开头命名的bucket
- 每个用户为各自的业务系统创建子帐户。

1. 创建访问策略文件

![img](https://cdn.nlark.com/yuque/0/2022/png/28915315/1653379442959-25b2eede-cb05-4124-94c7-dbd3173fdb3a.png)

内容如下:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": [
                "arn:aws:s3:::crm-*/*"
            ]
        }
    ]
}
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": [
                "arn:aws:s3:::oa-*/*"
            ]
        }
    ]
}
```

2.创建用户并指定访问策略

![img](https://cdn.nlark.com/yuque/0/2022/png/28915315/1653379681876-622af54d-50c5-4375-b2f9-c0359de18d80.png)

![img](https://cdn.nlark.com/yuque/0/2022/png/28915315/1653379901212-fac57e76-b713-4c51-b346-b450190e2588.png)

创建Service Accounts

![img](https://cdn.nlark.com/yuque/0/2022/png/28915315/1653380065512-6bb18ccd-907a-4370-b433-18f58d5299b1.png)

2.验证策略文件是否生效

```bash
#设置别名，并使用oa1帐户进行身份认证
mc alias set minio-oa http://minio1:9000 oa1 12345678

#创建 oa- 开头的文件夹，成功
#Bucket created successfully `minio-oa/oa-images`.
mc mb minio-oa/oa-images

#创建 crm- 开头的文件夹，失败
#<ERROR> Unable to make bucket `minio-oa/crm-images`. Access Denied.
mc mb minio-oa/crm-images

#设置别名，并使用crm3帐户进行身份认证
mc alias set minio-crm http://nginx:9000 crm3 12345678

#创建以crm-开头的bucket成功
mc mb minio-crm/crm-vedios

#创建以oa-开头的bucket失败
mc mb minio-crm/oa-vedios
```

![img](https://cdn.nlark.com/yuque/0/2022/png/28915315/1653380992413-c17113d1-0fc2-400b-b2a2-a5699efbdb50.png)

参考：

https://docs.aws.amazon.com/zh_cn/IAM/latest/UserGuide/introduction.html

|      |      |      |
| ---- | ---- | ---- |
|      |      |      |
|      |      |      |
|      |      |      |
|      |      |      |