# Dragonfly

Dragonfly 是一款基于 P2P 的智能镜像和文件分发工具。它旨在提高文件传输的效率和速率，最大限度地利用网络带宽，尤其是在分发大量数据时，例如应用分发、缓存分发、日志分发和镜像分发。

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210716111146.png)

## Dragonfly 工作原理

**下载普通文件**
SuperNode 充当 CDN，并负责调度对等节点（Peer）之间的文件分块传输。dfget 是 P2P 客户端，也称为“Peer”（对等节点），主要用于下载和共享文件分块。

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210716110428.png)

**下载镜像文件**
Registry 类似于文件服务器。dfget proxy 也称为 dfdaemon，会拦截来自 docker pull 或 docker push 的 HTTP 请求，然后使用 dfget 来处理那些跟镜像分层相关的请求。

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210716110511.png)

**下载文件分块**

每个文件会被分成多个分块，并在对等节点之间传输。一个对等节点就是一个 P2P 客户端。SuperNode 会判断本地是否存在对应的文件。如果不存在，则会将其从文件服务器下载到 SuperNode。

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210716110605.png)

## Dragonfly 术语

**SuperNode**
SuperNode 是一个常驻进程，主要有两个作用：
* 它是 P2P 网络中的追踪者和调度者，负责为每个对等节点（Peer）选择适当的下载网络路径。
* 它也是 CDN 服务端，会缓存从源下载的数据，以避免反复下载相同的文件。

**dfget**
dfget 是 Dragonfly 用于下载文件的客户端。它与 wget 类似。同时，它也扮演对等节点（Peer）的角色，可在 P2P 网络中与其他对等节点互相传输数据。

**dfdaemon**
dfdaemon 仅用于拉取镜像。它会在 dockerd/pouchd 和 Registry 之间建立代理。
dfdaemon 会从 dockerd/pouchd 拉取镜像时发送的全部请求中筛选出获取分层的请求，然后使用 dfget 下载这些分层。

## 部署 Dragonfly

supernode 组件至少需要两节点部署，hostnetwork，一般部署在管理节点，比如k8s master上。
supernode 需要使用8001、8002端口。如果跟kube-apiserver部署在一个节点上，需要确保不要有端口冲突。
supernode 所在节点对网络带宽、磁盘空间、磁盘IO要求较高。
dfdaemon 组件使用daemonset部署在所有的node节点上，hostnetwork，占用65001端口
需要修改所有node的docker启动参数 --registry-mirror http://{kubernetes节点地址}:65001。

```sh
kubectl apply -f deploy.yaml
```

确保 dragonfly pod 已经正常运行：

```sh
❯ kubectl get pod  -n kube-system -l "app in(dfdaemon,supernode)"
NAME                         READY   STATUS    RESTARTS   AGE
dfdaemon-6gc8g               1/1     Running   0          4m6s
dfdaemon-ctrr8               1/1     Running   0          4m6s
dfdaemon-czb4t               1/1     Running   0          4m6s
supernode-6c867c99ff-cvmvm   1/1     Running   0          4m6s
supernode-6c867c99ff-xbzgs   1/1     Running   0          4m6s
```

## 客户端 Docker 参数设置

设置启动参数 registry-mirror，其中 65001 是 dfdaemon 的服务端口:

方法1: 修改/etc/systemd/system/multi-user.target.wants/docker.service

```sh
ExecStart=/usr/bin/dockerd -H fd:// --registry-mirror http://192.168.1.191:65001
```

方法2: 修改/etc/docker/daemon.json

```json
{
  "registry-mirrors": ["http://192.168.1.191:65001"]
}
```

修改完成后重启 Docker 服务：

```sh
systemctl daemon-reload 
systemctl restart docker 
```

## 客户端拉取镜像

```sh
[root@envoy1 ~]# docker pull nginx
Using default tag: latest
latest: Pulling from library/nginx
b4d181a07f80: Pull complete 
66b1c490df3f: Pull complete 
d0f91ae9b44c: Pull complete 
baf987068537: Pull complete 
6bbc76cbebeb: Pull complete 
32b766478bc2: Pull complete 
Digest: sha256:353c20f74d9b6aee359f30e8e4f69c3d7eaea2f610681c4a95849a2fd7c497f9
Status: Downloaded newer image for nginx:latest
```