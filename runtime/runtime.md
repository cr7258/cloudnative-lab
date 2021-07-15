# gVisor 和 KataContainers

目前的容器技术仍然有许多广为人知的安全挑战，其中一个主要的问题是，从单一共享内核获得效率和性能意味着容器逃逸可能成为一个漏洞。

所以在 2015 年，几乎在同一个星期，Intel OTC （Open Source Technology Center） 和国内的 HyperHQ 团队同时开源了两个基于虚拟化技术的容器实现，分别叫做 Intel Clear Container 和 runV 项目。而在 2017 年，借着 Kubernetes 的东风，这两个相似的容器运行时项目在中立基金会的撮合下最终合并，就成了现在大家耳熟能详的 Kata Containers 项目。 由于 Kata Containers 的本质就是一个精简后的轻量级虚拟机，所以它的特点，就是“像虚拟机一样安全，像容器一样敏捷”。

2018 年，Google 公司则发布了一个名叫 gVisor 的项目。gVisor 项目给容器进程配置一个用 Go 语言实现的、运行在用户态的、极小的“独立内核”。这个内核对容器进程暴露 Linux 内核 ABI，扮演着“Guest Kernel”的角色，从而达到了将容器和宿主机隔离开的目的。

## KataContainers
首先，我们来看 KataContainers。它的工作原理可以用如下所示的示意图来描述。
![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Kubernetes/20210126225823.png)
Kata Containers 的本质，就是一个轻量化虚拟机。所以当你启动一个 Kata Containers 之后，你其实就会看到一个正常的虚拟机在运行。这也就意味着，一个标准的虚拟机管理程序（Virtual Machine Manager, VMM）是运行 Kata Containers 必备的一个组件。在我们上面图中，使用的 VMM 就是 Qemu。

### Docker使用KataContainers
安装参考链接：https://github.com/kata-containers/documentation/tree/master/install/docker

首先节点需要支持以下四种任意一种cpu虚拟化技术：
* Intel VT-x technology
* ARM Hyp mode
* IBM Power Systems
* IBM Z manframes
如果部署在VMware虚拟机中，需要在宿主机开启嵌套虚拟化的功能，开启步骤见链接：https://blog.51cto.com/11434894/2389180?source=dra

安装kataContainer:

```sh
ARCH=$(arch)
BRANCH="${BRANCH:-master}"
sudo sh -c "echo 'deb http://download.opensuse.org/repositories/home:/katacontainers:/releases:/${ARCH}:/${BRANCH}/xUbuntu_$(lsb_release -rs)/ /' > /etc/apt/sources.list.d/kata-containers.list"
curl -sL  http://download.opensuse.org/repositories/home:/katacontainers:/releases:/${ARCH}:/${BRANCH}/xUbuntu_$(lsb_release -rs)/Release.key | sudo apt-key add -
sudo -E apt-get update
sudo -E apt-get -y install kata-runtime kata-proxy kata-shim
```
设置docker配置文件：

```sh
cat > /etc/docker/daemon.json << EOF 
{
  "default-runtime": "kata-runtime",
  "runtimes": {
    "kata-runtime": {
      "path": "/usr/bin/kata-runtime"
    }
  }
}
EOF

systemctl daemon-reload
systemctl restart docker
```
运行一个容器，可以看到显示的内核版本和宿主机是不一样的：

```sh
root@cr7-ubuntu:~# docker run busybox uname -a
```
### Kubernetes使用kataContainer
配置containerd使用kataContainer：

```yaml
cat > /etc/containerd/config.toml << EOF
disabled_plugins = ["restart"]
[plugins.linux]
  shim_debug = true
[plugins.cri.containerd.runtimes.kata]  #kata这个名字可以自己定义，和runtimeClass指定的名字要一样
  runtime_type = "io.containerd.kata.v2"
[plugins.cri.registry.mirrors."docker.io"]
  endpoint = ["https://frz7i079.mirror.aliyuncs.com"]
EOF

systemctl daemon-reload  
systemctl restart containerd
```
配置kubelet使用containerd作为容器运行时：
```sh
cat > /etc/systemd/system/kubelet.service.d/0-cri-containerd.conf << EOF
[Service]
Environment="KUBELET_EXTRA_ARGS=--container-runtime=remote --runtime-request-timeout=15m -- container-runtime-endpoint=unix:///run/containerd/containerd.sock"
EOF

systemctl daemon-reload 
systemctl restart kubelet
```
kubernetes创建runtimeClass:

```yaml
apiVersion: node.k8s.io/v1beta1  # RuntimeClass is defined in the node.k8s.io API group
kind: RuntimeClass
metadata:
  name: kata  
handler: kata  # 这里与containerd配置文件中的 [plugins.cri.containerd.runtimes.{handler}] 匹配
```
创建pod：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: kata-nginx
spec:
  runtimeClassName: kata
  containers:
    - name: nginx
      image: nginx
      ports:
      - containerPort: 80
```
## gVisor
相比之下，gVisor 的设计其实要更加“激进”一些。它的原理，可以用如下所示的示意图来表示清楚。
![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Kubernetes/20210126225926.png)
gVisor 工作的核心，在于它为应用进程、也就是用户容器，启动了一个名叫 Sentry 的进程。 而 Sentry 进程的主要职责，就是提供一个传统的操作系统内核的能力，即：运行用户程序，执行系统调用。所以说，Sentry 并不是使用 Go 语言重新实现了一个完整的 Linux 内核，而只是一个对应用进程“冒充”内核的系统组件。
### Docker使用gVisor
查看原本的runtime:
```sh
root@cr7-ubuntu:~# docker info
...
 Runtimes: runc
 Default Runtime: runc
...
```
安装gVisor:

```sh
(
  set -e
  ARCH=$(uname -m)
  URL=https://storage.googleapis.com/gvisor/releases/release/latest/${ARCH}
  wget ${URL}/runsc ${URL}/runsc.sha512 \
    ${URL}/containerd-shim-runsc-v1 ${URL}/containerd-shim-runsc-v1.sha512
  sha512sum -c runsc.sha512 \
    -c containerd-shim-runsc-v1.sha512
  rm -f *.sha512
  chmod a+rx runsc containerd-shim-runsc-v1
  sudo mv runsc containerd-shim-runsc-v1 /usr/local/bin
)
```
设置docker配置文件：

```yaml
cat > /etc/docker/daemon.json << EOF 
{
    "registry-mirrors": ["https://frz7i079.mirror.aliyuncs.com"],
    "runtimes": {
        "gvisor": {  #这个名字可以自己制定，docker run的时候--runtime使用
            "path": "/usr/local/bin/runsc"
        }
    }
}
EOF

systemctl daemon-reload
systemctl restart docker
```
查看此时的runtime:

```sh 
root@cr7-ubuntu:~# docker info
...
Runtimes: runc gvisor
Default Runtime: runc
...
```
运行gvisor为runtime的容器：

```sh
docker run -itd --name web1 --runtime=gvisor  nginx
```
在宿主机上是看不到这个进程的，如果是runc的容器是能看到进程的：

```sh
root@cr7-ubuntu:~/gvisor# ps -ef | grep nginx | grep -v grep
#没有输出
```

### Kubernetes使用gVisor
配置containerd使用gvisor：

```yaml
cat > /etc/containerd/config.toml << EOF
disabled_plugins = ["restart"]
[plugins.linux]
  shim_debug = true
[plugins.cri.containerd.runtimes.gvisor]  #gvisor这个名字可以自己定义，和runtimeClass指定的名字要一样
  runtime_type = "io.containerd.runsc.v1"
[plugins.cri.registry.mirrors."docker.io"]
  endpoint = ["https://frz7i079.mirror.aliyuncs.com"]
EOF

systemctl restart containerd
```
配置crictl使用containerd作为作为容器运行时:

```yaml
runtime-endpoint: unix:///var/run/containerd/containerd.sock
image-endpoint: ""
timeout: 0
debug: false
```
配置kubelet使用containerd作为容器运行时：

```sh
cat > /var/lib/kubelet/kubeadm-flags.env  << EOF
KUBELET_KUBEADM_ARGS="--network-plugin=cni --pod-infra-container- image=registry.aliyuncs.com/google_containers/pause:3.2 --container-runtime=remote --container-runtime-endpoint=unix:///run/containerd/containerd.sock"
EOF

systemctl daemon-reload 
systemctl restart kubelet
```
kubeadm join将node加入kubernetes集群，master使用docker作为容器运行时，node使用containerd作为容器运行时。

创建runtimeClass:

```yaml
apiVersion: node.k8s.io/v1beta1
kind: RuntimeClass
metadata:
  name: gvisor
handler: gvisor  #对应CRI配置的名称
```
创建pod使用gvisor作为runtime：
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-gvisor
spec:
  runtimeClassName: gvisor
  containers:
  - name: nginx
    image: nginx
  nodeName: cks3
```
## 对比
在性能上，KataContainers 和 KVM 实现的 gVisor 基本不分伯仲，在启动速度和占用资源上，基于用户态内核的 gVisor 还略胜一筹。但是，对于系统调用密集的应用，比如重 I/O 或者重网络的应用，gVisor 就会因为需要频繁拦截系统调用而出现性能急剧下降的情况。此外，gVisor 由于要自己使用 Sentry 去模拟一个 Linux 内核，所以它能支持的系统调用是有限的，只是 Linux 系统调用的一个子集。