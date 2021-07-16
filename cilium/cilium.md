# Cilium

Cilium 是一个基于 eBPF 和 XDP 的高性能容器网络方案，其主要功能特性包括：
* 安全上，支持 L3/L4/L7 安全策略，这些策略按照使用方法又可以分为：
    * 基于身份的安全策略（security identity）。
    * 基于 CIDR 的安全策略。
    * 基于标签的安全策略。
* 网络上，支持三层平面网络（flat layer 3 network），如
    * 覆盖网络（Overlay），包括 VXLAN 和 Geneve 等。
    * Linux 路由网络，包括原生的 Linux 路由和云服务商的高级网络路由等。
* 提供基于 BPF 的负载均衡。
* 提供便利的监控和排错能力。

Cilium 在它的 datapath 中重度使用了 BPF 技术：

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210715232341.png)

Cilium 是位于 Linux kernel 与容器编排系统的中间层。向上可以为容器配置网络，向下可以向 Linux 内核生成 BPF 程序来控制容器的安全性和转发行为。

对比传统容器网络（采用 iptables/netfilter）：

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210715231423.png)

eBPF 主机路由允许绕过主机命名空间中所有的 iptables 和上层网络栈，以节省资源开销。网络数据包到达网络接口设备时就被尽早捕获，并直接传送到 Kubernetes Pod的网络命名空间中。在流量出口侧，数据包同样穿过 Veth 对，被 eBPF 捕获后，直接被传送到外部网络接口上。


## Cilium + BGP + F5 CIS Kubernetes 集群网络架构

相关文章：https://mp.weixin.qq.com/s/KHSfgknXscbro3CpwHrLyQ

### 初始化 Kubernetes 集群

```yaml
apiVersion: kubeadm.k8s.io/v1beta2
bootstrapTokens:
- groups:
  - system:bootstrappers:kubeadm:default-node-token
  token: abcdef.0123456789abcdef
  ttl: 24h0m0s
  usages:
  - signing
  - authentication
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: 11.8.37.63
  bindPort: 6443
nodeRegistration:
  criSocket: /var/run/dockershim.sock
  name: ydt-net-cilium1-nomasquerade
  taints:
  - effect: NoSchedule
    key: node-role.kubernetes.io/master
---
apiServer:
  timeoutForControlPlane: 4m0s
apiVersion: kubeadm.k8s.io/v1beta2
certificatesDir: /etc/kubernetes/pki
clusterName: cilium-nomasquerade
controllerManager: {}
dns:
  type: CoreDNS
etcd:
  local:
    dataDir: /var/lib/etcd
imageRepository: k8s.gcr.io
kind: ClusterConfiguration
kubernetesVersion: v1.19.0
networking:
  dnsDomain: cluster.local
  serviceSubnet: 18.18.0.0/16
  podSubnet: 188.188.0.0/16
scheduler: {}
imageRepository: registry.aliyuncs.com/google_containers #阿里云镜像仓库地址
```
初始化集群，不安装kube-proxy

```vim
kubeadm init --config init-k8s.yaml --skip-phases=addon/kube-proxy
```
### 通过 Helm 部署 Cilium
#### 方式一：有 VXLAN（推荐）
```vim
helm install cilium cilium/cilium --version 1.8.4 \
--namespace kube-system \
--set config.ipam=kubernetes \
--set native-routing-cidr=11.8.37.0/24 \
--set global.ipMasqAgent.enabled=true \
--set global.kubeProxyReplacement=strict \
--set global.k8sServiceHost=11.8.37.63 \
--set global.k8sServicePort=6443
```
参数说明：
**config.ipam=kubernetes**：使用kubeadm定义的pod和service网段。
**native-routing-cidr=11.8.37.0/24**：指定不做masquerade的网段，后面可以通过名为ip-masq-agent的configmap来指定。
**global.ipMasqAgent.enabled=true**：可以通过配置configMap动态更改Cilium的Masquerade策略。
**global.k8sServiceHost**：指定api server的ip，由于禁用了kube-proxy，因此需要显式地指定。
**global.k8sServicePort**：指定api server的端口。
**global.kubeProxyReplacement=strict**：（可选）在缺少底层Linux内核支持的情况下，cilium agent将会退出，而不会使用kube-proxy来代替。



编辑agent-config/config文件，添加如下内容：
```yaml
nonMasqueradeCIDRs:
#LinkLocal地址
- 169.254.0.0/16
#F5 SNAT Pool地址
- 11.8.37.4/32
- 11.8.37.5/32
- 11.8.37.6/32
- 11.8.37.7/32
- 11.8.37.8/32
- 11.8.37.9/32
- 11.8.37.10/32
#思科交换机地址
- 11.8.37.252/32
- 11.8.37.253/32
- 11.8.37.254/32
# F5健康检查地址
- 11.11.248.0/21
masqLinkLocal: false
```
生成ConfigMap：

```vim
kubectl create configmap ip-masq-agent --from-file=agent-config --namespace=kube-system
```
等待大约60S，cilium pod会动态更新规则：

```vim
root@ydt-net-cilium1-nomasquerade:/root #kubectl exec -n kube-system cilium-kwd7t -- cilium bpf ipmasq list
IP PREFIX/ADDRESS
11.8.37.4/32
11.8.37.5/32
11.8.37.9/32
11.8.37.252/32
11.8.37.254/32
11.11.248.0/21
169.254.0.0/16
11.8.37.6/32
11.8.37.7/32
11.8.37.8/32
11.8.37.10/32
11.8.37.253/32
```
查看创建的ConfigMap：

```yaml
root@ydt-net-cilium1-nomasquerade:/root #kubectl get cm -n kube-system ip-masq-agent  -o yaml
apiVersion: v1
data:
  config: |
    nonMasqueradeCIDRs:
    - 11.8.37.252/32
    - 11.8.37.253/32
    - 11.8.37.254/32
    - 11.8.37.4/32
    - 11.8.37.5/32
    - 11.8.37.6/32
    - 11.8.37.7/32
    - 11.8.37.8/32
    - 11.8.37.9/32
    - 11.8.37.10/32
    - 11.11.248.0/21
    masqLinkLocal: false
kind: ConfigMap
metadata:
  creationTimestamp: "2020-10-22T03:43:14Z"
  managedFields:
  - apiVersion: v1
    fieldsType: FieldsV1
    fieldsV1:
      f:data: {}
    manager: kubectl-create
    operation: Update
    time: "2020-10-22T03:43:14Z"
  - apiVersion: v1
    fieldsType: FieldsV1
    fieldsV1:
      f:data:
        f:config: {}
    manager: kubectl-edit
    operation: Update
    time: "2020-10-22T08:10:34Z"
  name: ip-masq-agent
  namespace: kube-system
  resourceVersion: "47575"
  selfLink: /api/v1/namespaces/kube-system/configmaps/ip-masq-agent
  uid: d53fc4d9-df3b-4243-9bf0-9e53209932ff
```
生成的配置文件会存放在cilium agent的/etc/config目录下。
#### 方式二：没有 VXLAN
```vim
helm install cilium cilium/cilium --version 1.8.4 \
--namespace kube-system \
--set config.ipam=kubernetes \
--set global.masquerade=false \
--set global.tunnel=disabled
```

### 配置BGP 
#### 查看各个 Node 分配的地址段
```vim
root@ydt-net-cilium1-nomasquerade:/root #kubectl exec -n kube-system cilium-kwd7t -- cilium node list
Name                           IPv4 Address   Endpoint CIDR    IPv6 Address   Endpoint CIDR
ydt-net-cilium1-nomasquerade   11.8.37.63     188.188.0.0/24
ydt-net-cilium2-nomasquerade   11.8.37.67     188.188.1.0/24
ydt-net-cilium3-nomasquerade   11.8.37.68     188.188.2.0/24
```
#### BIRD 配置 BGP
##### 安装 BIRD

```vim
yum install epel* -y
yum update -y
yum install bird2 -y
systemctl enable bird && systemctl restart bird
```
##### 配置BIRD文件
编辑/etc/bird.conf
```vim
log syslog all;

router id 11.8.37.63;

protocol device {
        scan time 10;           # Scan interfaces every 10 seconds
}

# Disable automatically generating direct routes to all network interfaces.
protocol direct {
        disabled;               # Disable by default
}

# Forbid synchronizing BIRD routing tables with the OS kernel.
protocol kernel {
        ipv4 {                    # Connect protocol to IPv4 table by channel
                import none;      # Import to table, default is import all
                export none;      # Export to protocol. default is export none
        };
}

# Static IPv4 routes.
protocol static {
      ipv4;
      #该Node所分配的Pod网段
      route 188.188.0.0/24 via "cilium_host"; 
}

# BGP peers
protocol bgp uplink0 {
      description "BGP uplink 0";
      local 11.8.37.63 as 64512;
      neighbor 11.11.255.1 as 64512;
      ipv4 {
              import filter {reject;};
              export filter {accept;};
      };
}

protocol bgp uplink1 {
      description "BGP uplink 1";
      local 11.8.37.63 as 64512;
      neighbor 11.11.255.2 as 64512;
      ipv4 {
              import filter {reject;};
              export filter {accept;};
      };
}
```
配置完成后`systemctl restart bird`

##### 思科交换机配置BGP

```vim
router bgp 64512
  neighbor 11.8.37.63 remote-as 64512
    update-source loopback0
    address-family ipv4 unicast
  neighbor 11.8.37.67 remote-as 64512
    update-source loopback0
    address-family ipv4 unicast
  neighbor 11.8.37.68 remote-as 64512
    update-source loopback0
    address-family ipv4 unicast
```
##### 查看路由
K8S节点查看宣告的BGP路由和BGP邻居状态

```vim
root@ydt-net-cilium1-nomasquerade:/root #birdc show route
BIRD 2.0.7 ready.
Table master4:
188.188.0.0/24       unicast [static1 21:25:54.420] * (200)
	dev cilium_host
root@ydt-net-cilium1-nomasquerade:/root #birdc show protocol
BIRD 2.0.7 ready.
Name       Proto      Table      State  Since         Info
device1    Device     ---        up     16:33:30.989
direct1    Direct     ---        down   16:33:30.989
kernel1    Kernel     master4    up     16:33:30.989
static1    Static     master4    up     16:33:30.989
uplink0    BGP        ---        up     16:33:34.738  Established
uplink1    BGP        ---        up     16:33:35.642  Established
```
思科交换机查看从K8S节点宣告的BGP路由和BGP邻居状态

```vim
YL_TEST_HW_DIS1# show ip route bgp 
IP Route Table for VRF "default"
'*' denotes best ucast next-hop
'**' denotes best mcast next-hop
'[x/y]' denotes [preference/metric]
'%<string>' in via output denotes VRF <string>

188.188.0.0/24, ubest/mbest: 1/0
    *via 11.8.37.63, [200/0], 00:08:55, bgp-64512, internal, tag 64512, 
188.188.1.0/24, ubest/mbest: 1/0
    *via 11.8.37.67, [200/0], 00:00:20, bgp-64512, internal, tag 64512, 
188.188.2.0/24, ubest/mbest: 1/0
    *via 11.8.37.68, [200/0], 4w0d, bgp-64512, internal, tag 64512, 
    
YL_TEST_HW_DIS1# show ip bgp all summary 
BGP summary information for VRF default, address family IPv4 Unicast
BGP router identifier 11.11.255.1, local AS number 64512
BGP table version is 114, IPv4 Unicast config peers 20, capable peers 11
11 network entries and 11 paths using 1276 bytes of memory
BGP attribute entries [1/140], BGP AS path entries [0/0]
BGP community entries [0/0], BGP clusterlist entries [0/0]

Neighbor        V    AS MsgRcvd MsgSent   TblVer  InQ OutQ Up/Down  State/PfxRcd
11.8.37.63      4 64512   46784   40920      116    0    0 05:01:35 1         
11.8.37.67      4 64512   46449   40628      116    0    0 00:00:41 1         
11.8.37.68      4 64512   46750   40919      116    0    0     4w0d 1 
```
##### 最终效果
* 集群中跨Node的Pod互访通过VXLAN。
* F5和思科交换机主动访问Pod，Pod回包不做SNAT。
* Pod主动出访通过SNAT（除了F5和思科交换机地址）。

### 配置 F5 Ingress Controller
#### 添加 serviceaccount

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: bigip-ctlr
  namespace: kube-system
```
#### 配置RBAC

```yaml
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: bigip-ctlr-clusterrole
rules:
- apiGroups: ["", "extensions"]
  resources: ["nodes", "services", "endpoints", "namespaces", "ingresses", "pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["", "extensions"]
  resources: ["configmaps", "events", "ingresses/status"]
  verbs: ["get", "list", "watch", "update", "create", "patch"]
- apiGroups: ["", "extensions"]
  resources: ["secrets"]
  resourceNames: ["<secret-containing-bigip-login>"]
  verbs: ["get", "list", "watch"]

---

kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: bigip-ctlr-clusterrole-binding
  namespace: kube-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: bigip-ctlr-clusterrole
subjects:
- apiGroup: ""
  kind: ServiceAccount
  name: bigip-ctlr
  namespace: kube-system
```

#### 创建 F5 Container Ingress Controller
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: k8s-bigip-ctlr-clusterip
  namespace: kube-system
spec:
  # DO NOT INCREASE REPLICA COUNT
  replicas: 1
  selector:
    matchLabels:
      app: k8s-bigip-ctlr
  template:
    metadata:
      name: k8s-bigip-ctlr
      labels:
        app: k8s-bigip-ctlr
    spec:
      # Name of the Service Account bound to a Cluster Role with the required
      # permissions
      serviceAccountName: bigip-ctlr
      containers:
        - name: k8s-bigip-ctlr
          image: 11.8.84.11:5000/f5networks/k8s-bigip-ctlr:latest
          env:
            - name: BIGIP_USERNAME
              value: admin
            - name: BIGIP_PASSWORD
              value: f5,123
          command: ["/app/bin/k8s-bigip-ctlr"]
          args: [
            # See the k8s-bigip-ctlr documentation for information about
            # all config options
            # https://clouddocs.f5.com/products/connectors/k8s-bigip-ctlr/latest
            "--bigip-username=admin",
            "--bigip-password=f5,123",
            "--bigip-url=11.11.250.12",
            "--bigip-partition=Cilium",
            "--pool-member-type=cluster",
            #F5 Ingress Controller使用在Common Partition的名为SNAT-vlan130的SNAT Pool做SNAT
            "--vs-snat-pool-name=SNAT-vlan130" 
            ]
      imagePullSecrets:
        # Secret that gives access to a private docker registry
        - name: f5-docker-images
        # Secret containing the BIG-IP system login credentials
        - name: bigip-login
```

### 创建服务
#### 创建Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-http     #定义deployment的名字
  labels:
    app: nginx-http    #定义deployment的标签
spec:
  replicas: 3        #定义Pod的副本数
  selector:
    matchLabels:
      app: nginx-http         #定义Deployment选择管理的Pod的标签，要和template里的labels一致（标红色的两个要一致）
  template:
    metadata:
      labels:
        app: nginx-http        #定义创建的pod的标签，方便之后Deployment对Pod进行管理
    spec:
      containers:
      - name: nginx-http         #定义容器的名字
        image: registry.cn-shanghai.aliyuncs.com/secret-namespace/cr7-nginx-hostname:v3     #定义容器的镜像以及版本
        ports:
        - containerPort: 80
```

#### 创建Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-http  #定义service的名字
spec:
  selector:
    app: nginx-http    #定义service所选择负载均衡的Pod的标签
  ports:
   - protocol: TCP
     port: 80    #定义service提供访问的端口
     targetPort: 80      #指定pod的端口
```

#### 创建ConfigMap
##### 通过GET的方式做健康检查
```yaml
kind: ConfigMap
apiVersion: v1
metadata:
  name: nginx-vs-http
  labels:
    f5type: virtual-server
data:
  schema: "f5schemadb://bigip-virtual-server_v0.1.7.json"
  data: |
    {
      "virtualServer": {
        "backend": {
          "servicePort": 80,
          "serviceName": "nginx-http",
          "healthMonitors": [{
            "interval": 5,
            "protocol": "http",
            "send": "GET /health.html HTTP/1.1\r\nHost:11.11.250.12\r\n\r\n",
            "recv": "server is ok",
            "timeout": 16
          }]
        },
        "frontend": {
          "virtualAddress": {
            "port": 80,
            "bindAddr": "11.16.22.80"
          },
          "partition": "Cilium",
          "balance": "least-connections-member",
          "mode": "http"
        }
      }
    }
```

##### 通过HEAD的方式做健康检查
```yaml
kind: ConfigMap
apiVersion: v1
metadata:
  name: nginx-vs-http
  labels:
    f5type: virtual-server
data:
  schema: "f5schemadb://bigip-virtual-server_v0.1.7.json"
  data: |
    {
      "virtualServer": {
        "backend": {
          "servicePort": 80,
          "serviceName": "nginx-http",
          "healthMonitors": [{
            "interval": 5,
            "protocol": "http",
            "send": "HEAD / HTTP/1.1\r\n\r\n",
            "recv": "Server",
            "timeout": 16
          }]
        },
        "frontend": {
          "virtualAddress": {
            "port": 80,
            "bindAddr": "11.16.22.80"
          },
          "partition": "Cilium",
          "balance": "least-connections-member",
          "mode": "http"
        }
      }
    }
```