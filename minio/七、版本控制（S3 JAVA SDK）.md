**版本控制（Versioning）：**允许将同一对象的多个版本保留在同一键（Key）下。

为存储桶启用版本控制后，针对同一对象的多个写入请求，它会存储所有对象。对于存储桶中存储的每个对象，可以使用版本控制功能来保留、检索和还原它们的各个版本。使用版本控制能够更加轻松地从用户意外操作和应用程序故障中恢复数据。

多版本对象有以下特点：

- 同一个对象写入多次不会覆盖之前的内容，而是会生成多个版本，每个版本对应唯一的版本ID

![img](https://cdn.nlark.com/yuque/0/2022/png/28915315/1653462156788-7039adc6-0805-41c0-ac41-0e3be7041b51.png)

- 如果不指定版本ID，默认获取对象的最新版本
- 删除操作不会真的删除对象，而是给对象加上逻辑删除标志，产生一个0B的新版本对象

![img](https://cdn.nlark.com/yuque/0/2022/png/28915315/1653462176977-0a7161c7-99c1-4ea2-8e2d-5d8820955d7b.png)

- 如果要彻底删除对象，需要指定版本ID删除对象的所用版本

# 1.启用bucket版本控制

```java
//启用bucket版本控制
BucketVersioningConfiguration configuration =
    new BucketVersioningConfiguration().withStatus("Enabled");

SetBucketVersioningConfigurationRequest setBucketVersioningConfigurationRequest =
    new SetBucketVersioningConfigurationRequest(bucketName, configuration);

s3Client.setBucketVersioningConfiguration(setBucketVersioningConfigurationRequest);

// 查看bucket版本配置状态
BucketVersioningConfiguration conf = s3Client.getBucketVersioningConfiguration(bucketName);
System.out.println("bucket versioning configuration status:    " + conf.getStatus());
```

# 2.同一对象写入多次

```java
//同一个对象写入多次
String keyName = "version.txt";
for (int i = 1; i < 4; i++) {
    PutObjectResult putResult = s3Client.putObject(bucketName, keyName,
                                                   "This is version " + i);
    Thread.sleep(1000);
    System.out.println("put object " + keyName + ", value: " + "This is version " + i);
}
```

# 3.查看对象所有版本

```java
//查看对象版本、修改时间
ListVersionsRequest listVersionsRequest = new ListVersionsRequest();
listVersionsRequest.setBucketName(bucketName);
listVersionsRequest.setPrefix(keyName);

VersionListing versionList = s3Client.listVersions(listVersionsRequest);

for (S3VersionSummary objectSummary :versionList.getVersionSummaries()) {
     System.out.printf("Retrieved object %s, version %s, last modified %s, deleted :%s \n",
                        objectSummary.getKey(),
                        objectSummary.getVersionId(),
                        objectSummary.getLastModified(),
                        objectSummary.isDeleteMarker());
}
```

![img](https://cdn.nlark.com/yuque/0/2022/png/28915315/1653466028666-2f58b1c7-223a-41f0-8cc7-514193b8a9d0.png)

# 4.删除对象（逻辑删除，可以恢复）

```java
//删除对象，逻辑删除，产生一个0b的新版本对象，可以从历史版本恢复
s3Client.deleteObject(bucketName, keyName);
```

提示：删除对象不会真的删除对象，而是将对象标记为删除，生成了一个新版本对象，大小为0kb

![img](https://cdn.nlark.com/yuque/0/2022/png/28915315/1653466168070-df087ce4-0239-49f3-b830-59b7e295d419.png)

# 5.从历史版本恢复

```java
CopyObjectRequest copyObjectRequest = new CopyObjectRequest().withSourceBucketName(bucketName)
    .withSourceKey(keyName)
    .withSourceVersionId(lastVersionId)
    .withDestinationBucketName(bucketName)
    .withDestinationKey(keyName);
s3Client.copyObject(copyObjectRequest);
```

# 6.删除对象所有版本（彻底删除，不可恢复）

```java
 //删除所有版本，彻底删除，不可恢复
System.out.println("-----delete all versions of this object-----");
versionList = s3Client.listVersions(listVersionsRequest);
for (S3VersionSummary objectSummary :
     versionList.getVersionSummaries()) {
    s3Client.deleteVersion(bucketName, keyName, objectSummary.getVersionId());
    System.out.printf("object %s, version %s\n",
                      objectSummary.getKey(),
                      objectSummary.getVersionId());
}
```

# 7.完整示例

```java
import com.amazonaws.AmazonServiceException;
import com.amazonaws.ClientConfiguration;
import com.amazonaws.SdkClientException;
import com.amazonaws.auth.AWSCredentials;
import com.amazonaws.auth.AWSStaticCredentialsProvider;
import com.amazonaws.auth.BasicAWSCredentials;
import com.amazonaws.client.builder.AwsClientBuilder;
import com.amazonaws.regions.Regions;
import com.amazonaws.services.s3.AmazonS3;
import com.amazonaws.services.s3.AmazonS3ClientBuilder;
import com.amazonaws.services.s3.model.*;

import java.io.File;
import java.io.IOException;
import java.util.Arrays;

public class VersionedBucket {

    public static void main(String[] args) {

        String bucketName = "versionedbucket";

        try {

            AWSCredentials credentials = new BasicAWSCredentials("minioadmin", "minioadmin");
            ClientConfiguration clientConfiguration = new ClientConfiguration();
            clientConfiguration.setSignerOverride("AWSS3V4SignerType");

            AmazonS3 s3Client = AmazonS3ClientBuilder
                    .standard()
                    .withEndpointConfiguration(new AwsClientBuilder.EndpointConfiguration("http://127.0.0.1:9000", Regions.US_EAST_1.name()))
                    .withPathStyleAccessEnabled(true)
                    .withClientConfiguration(clientConfiguration)
                    .withCredentials(new AWSStaticCredentialsProvider(credentials))
                    .build();

            //创建bucket
            if (s3Client.doesBucketExistV2(bucketName)) {
                System.out.format("Bucket %s already exists.\n", bucketName);
            } else {
                s3Client.createBucket(bucketName);
            }

            //启用bucket版本控制
            BucketVersioningConfiguration configuration =
                    new BucketVersioningConfiguration().withStatus("Enabled");

            SetBucketVersioningConfigurationRequest setBucketVersioningConfigurationRequest =
                    new SetBucketVersioningConfigurationRequest(bucketName, configuration);

            s3Client.setBucketVersioningConfiguration(setBucketVersioningConfigurationRequest);


            // 查看bucket版本配置状态
            BucketVersioningConfiguration conf = s3Client.getBucketVersioningConfiguration(bucketName);
            System.out.println("bucket versioning configuration status:    " + conf.getStatus());

            //同一个对象写入多次
            System.out.println("-----put object-----");
            String keyName = "version.txt";
            for (int i = 1; i < 4; i++) {
                PutObjectResult putResult = s3Client.putObject(bucketName, keyName,
                        "This is version " + i);
                Thread.sleep(1000);
                System.out.println("put object " + keyName + ", value: " + "This is version " + i);

            }

            //查看对象版本、修改时间
            System.out.println("-----list object versions-----");
            ListVersionsRequest listVersionsRequest = new ListVersionsRequest();
            listVersionsRequest.setBucketName(bucketName);
            listVersionsRequest.setPrefix(keyName);

            listVersions(s3Client, listVersionsRequest);


            //删除对象，逻辑删除，产生一个0b的新版本对象，可以从历史版本恢复
            s3Client.deleteObject(bucketName, keyName);
            System.out.println("-----delete object operation-----");

            String lastVersionId = listVersions(s3Client, listVersionsRequest);

            //从上一个版本恢复对象
            System.out.println("-----recover object from last version-----");
            CopyObjectRequest copyObjectRequest = new CopyObjectRequest().withSourceBucketName(bucketName)
                    .withSourceKey(keyName)
                    .withSourceVersionId(lastVersionId)
                    .withDestinationBucketName(bucketName)
                    .withDestinationKey(keyName);
            s3Client.copyObject(copyObjectRequest);

            listVersions(s3Client, listVersionsRequest);

            //删除所有版本，彻底删除，不可恢复
            System.out.println("-----delete all versions of this object-----");
            VersionListing versionList = s3Client.listVersions(listVersionsRequest);
            versionList = s3Client.listVersions(listVersionsRequest);

            for (S3VersionSummary objectSummary :
                    versionList.getVersionSummaries()) {
                s3Client.deleteVersion(bucketName, keyName, objectSummary.getVersionId());
                System.out.printf("object %s, version %s\n",
                        objectSummary.getKey(),
                        objectSummary.getVersionId());
            }


        } catch (AmazonServiceException e) {
            e.printStackTrace();
        } catch (SdkClientException | InterruptedException e) {
            e.printStackTrace();
        }
    }

    private static String listVersions(AmazonS3 s3Client, ListVersionsRequest listVersionsRequest) {
        String lastVersionId = null;
        VersionListing versionList;
        versionList = s3Client.listVersions(listVersionsRequest);
        for (S3VersionSummary objectSummary :
                versionList.getVersionSummaries()) {
            System.out.printf("object %s, version %s, last modified %s, size : %s kb, deleted : %s \n",
                    objectSummary.getKey(),
                    objectSummary.getVersionId(),
                    objectSummary.getLastModified(),
                    objectSummary.getSize(),
                    objectSummary.isDeleteMarker()
            );
            lastVersionId = objectSummary.getVersionId();
        }
        return lastVersionId;
    }
}
```

|      |      |      |
| ---- | ---- | ---- |
|      |      |      |
|      |      |      |
|      |      |      |
|      |      |      |