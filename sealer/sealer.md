# Sealer

## 部署 Kubernetes 集群

在阿里云上创建RAM用户并授予相应权限：
```sh
export ACCESSKEYID=LTAI5tFC7ez4xCqqZgcxxxxx
export ACCESSKEYSECRET=ShKqqNNYgJZtL6XcRjmJfCAaxxxxx

```

在阿里云上创建一个 3 master，3 worker 的节点：
```sh
sealer run kubernetes:v1.19.9 --masters 3 --nodes 3 
```


![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210714000520.png)


## 构建镜像

sealer build 的过程中和 Docker build 一样，会拉起一个临时的 Kubernetes 集群，并执行用户在 Kubefile 中定义的 apply 指令。



![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210713235145.png)



![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210714000532.png)



Sealer 最出色的地方是可以非常方便的让用户自定义一个集群的镜像，通过像Dockerfile 一样的文件来描述和build，创建名为 Kubefile 的文件，定义构建集群镜像的指令，该镜像中会安装 Kubernetes Dashboard:

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

## 通过 ClusterFile 部署 Kubernetes 集群

sealer apply -f Clusterfile

```yaml
apiVersion: sealer.aliyun.com/v1alpha1
kind: Cluster
metadata:
  name: my-cluster
spec:
  image: registry.cn-shanghai.aliyuncs.com/sealer-namespace/dashboard:latest
  provider: ALI_CLOUD
  network:
    # in use NIC name
    interface: eth0
    # Network plug-in name
    cniName: calico
    podCIDR: 100.64.0.0/10
    svcCIDR: 10.96.0.0/22
    withoutCNI: false
  certSANS:
    - aliyun-inc.com
    - 10.0.0.2
    
  masters:
    cpu: 4
    memory: 4
    count: 3
    systemDisk: 100
    dataDisks:
    - 100
  nodes:
    cpu: 4
    memory: 4
    count: 3
    systemDisk: 100
    dataDisks:
    - 100
```