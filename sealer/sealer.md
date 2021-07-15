# Sealer



```
export ACCESSKEYID=LTAI5tFC7ez4xCqqZgcvabub
export ACCESSKEYSECRET=ShKqqNNYgJZtL6XcRjmJfCAakD8ULp
```

```
sealer run kubernetes:v1.19.9 --masters 3 --nodes 3 # 在公有云上运行指定数量节点的kuberentes集群
```



![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210714000520.png)



sealer build 的过程中和 Docker build 一样，会拉起一个临时的 Kubernetes 集群，并执行用户在 Kubefile 中定义的 apply 指令。



![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210713235145.png)



![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210714000532.png)



Sealer 最出色的地方是可以非常方便的让用户自定义一个集群的镜像，通过像Dockerfile 一样的文件来描述和build，创建名为 Kubefile 的文件，定义构建集群镜像的指令:



```
FROM kubernetes:v1.19.9
RUN wget https://raw.githubusercontent.com/kubernetes/dashboard/v2.2.0/aio/deploy/recommended.yaml
CMD kubectl apply -f recommended.yaml
```

构建镜像：

```
sealer build -t registry.cn-shanghai.aliyuncs.com/sealer-namespace/dashboard:latest .
```

然后一个包含dashboard的集群镜像就被制作出来了，可以运行或者分享给别人。

把制作好的集群镜像推送到镜像仓库，集群镜像仓库兼容docker镜像仓库标准，可以把集群镜像推送到docker hub、阿里ACR、或者Harbor中。

```
sealer push registry.cn-shanghai.aliyuncs.com/sealer-namespace/dashboard:latest
```

