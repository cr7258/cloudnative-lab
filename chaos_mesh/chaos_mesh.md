# Chaos Mesh

现实世界中，各类故障可能会随时随地的发生，其中有很多故障我们无法避免，例如磁盘突然写坏，或者机房突然断网断电等等。这些故障可能会给公司造成巨大损失，因此提升系统对于故障的容忍度成为很多工程师努力的目标。

为了更方便地验证系统对于各种故障的容忍能力，Netflix 创造了一只名为 Chaos 的猴子，并且将它放到 AWS 云上，用于向基础设施以及业务系统中注入各类故障类型。这只 “猴子” 就是混沌工程起源。

Chaos Mesh 支持许多故障注入：
* pod-kill：模拟 Kubernetes Pod 被 kill。
* pod-failure：模拟 Kubernetes Pod 持续不可用，可以用来模拟节点宕机不可用场景。
* network-delay：模拟网络延迟。
* network-loss：模拟网络丢包。
* network-duplication: 模拟网络包重复。
* network-corrupt: 模拟网络包损坏。
* network-partition：模拟网络分区。
* I/O delay : 模拟文件系统 I/O 延迟。
* I/O errno：模拟文件系统 I/O 错误 。

Chaos Mesh 提供在 Kubernetes 平台上进行混沌测试的能力，它具有以下组成部分：
* Chaos Operator：混沌编排的核心组件。
* Chaos Dashboard：用于管理、设计、监控 Chaos Experiments 的 Web UI。

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210716102330.png)

## 安装 Chaos Mesh

```sh
helm repo add chaos-mesh https://charts.chaos-mesh.org
kubectl create ns chaos-testing
helm install chaos-mesh chaos-mesh/chaos-mesh --namespace=chaos-testing
```

确认 Chaos Mesh 的 Pod 已经运行成功：

```sh
❯ kubectl get pods --namespace chaos-testing -l app.kubernetes.io/instance=chaos-mesh
NAME                                       READY   STATUS    RESTARTS   AGE
chaos-controller-manager-749597967-pdq6p   1/1     Running   0          12m
chaos-daemon-dqst5                         1/1     Running   0          12m
chaos-daemon-xq6xt                         1/1     Running   0          12m
chaos-dashboard-7855d56fcb-k7t4l           1/1     Running   0          12m
```

## 访问 Chaos Dashboard

Chaos Dashboard 通过 NodePort 的方式暴露到集群外部：

```sh
❯ kubectl get svc -n chaos-testing
NAME                            TYPE        CLUSTER-IP        EXTERNAL-IP   PORT(S)                       AGE
chaos-daemon                    ClusterIP   None              <none>        31767/TCP,31766/TCP           16m
chaos-dashboard                 NodePort    100.100.116.134   <none>        2333:30105/TCP                16m
chaos-mesh-controller-manager   ClusterIP   100.100.22.72     <none>        10081/TCP,10080/TCP,443/TCP   16m
```
浏览器输入 http://192.168.1.191:30105（集群节点 IP:NodePort） 访问 Chaos Dashboard：

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210716001636.png)

使用 helm 安装 Chaos Mesh 默认情况下会启用 security 模式，你需要创建一个 account 和 token 来登录 dashboard。RBAC 所需的 clusterrole，serviceaccount,clusterrolebinding 文件放在 rbac 目录下。

```sh
kubectl apply -f rbac
```

获取 token：

```sh
kubectl -n chaos-testing describe secret $(kubectl -n chaos-testing get secret | grep account-cluster-manager | awk '{print $1}')
#返回结果
❯ kubectl -n chaos-testing describe secret $(kubectl -n chaos-testing get secret | grep account-cluster-manager | awk '{print $1}')
Name:         account-cluster-manager-token-h8qv6
Namespace:    chaos-testing
Labels:       <none>
Annotations:  kubernetes.io/service-account.name: account-cluster-manager
              kubernetes.io/service-account.uid: 06cfe6b0-6123-4d17-8605-dcda23758d95

Type:  kubernetes.io/service-account-token

Data
====
ca.crt:     1025 bytes
namespace:  13 bytes
token:      eyJhbGciOiJSUzI1NiIsImtpZCI6Ik9nNDBvcE1tNzI3dWstc0dZY0hnQ2FBMjlBdHRNa1hfZW9wcWtUOHZoVWsifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJjaGFvcy10ZXN0aW5nIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZWNyZXQubmFtZSI6ImFjY291bnQtY2x1c3Rlci1tYW5hZ2VyLXRva2VuLWg4cXY2Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQubmFtZSI6ImFjY291bnQtY2x1c3Rlci1tYW5hZ2VyIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQudWlkIjoiMDZjZmU2YjAtNjEyMy00ZDE3LTg2MDUtZGNkYTIzNzU4ZDk1Iiwic3ViIjoic3lzdGVtOnNlcnZpY2VhY2NvdW50OmNoYW9zLXRlc3Rpbmc6YWNjb3VudC1jbHVzdGVyLW1hbmFnZXIifQ.YA7BJlojiYXT89FcEn7yO9IgVt4Jg2PhPmOJNgK6sJjoeXdRcBkuUZzl7T1knty5zDUe7Tpkm7E37kjgXUtbqOzAo2B4mcMAcF9V1qcwkgbc_nO_62auRuYIjC91Yvb9y-4tr5BLFaWfnXZHq6QlsY6zxib6BaNJ3zjfQNJTCzvMqybnnz5Fch1cnK2-cxElunhXDDPQNEiBC6lKisawf3Bag6iUP5SI6mg8J5t8YLaZHp4zoTEV3BQHkBQgpxZaRdR6_K4WJ3bnZCEBuO0szowdEd4-230RiHWEmvOEeqmlMyFPJKthXWTCUUhZY3oPID60Mj09vXXCGXKpeSA5iA
```

在 Dashboard 输入 serviceAccount 和 token：

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210716002452.png)

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210716002558.png)

## Chaos Experiments

创建一个 PodChaos Experiment，模拟 Pod 被 kill 的场景。

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210716101845.png)

可以在 Chaos Dashboard 或者 yaml 配置文件的方式部署。

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210716093256.png)

```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  generation: 5
  name: pod-kill-example
spec:
  action: pod-kill
  containerName: ""
  duration: 15s
  gracePeriod: 0
  mode: one
  scheduler:
    cron: '@every 1m'
  selector:
    labelSelectors:
      app: hostname-nginx
    namespaces:
    - default
  value: ""
```

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210716093317.png)

创建一个 NetworkChaos Experiment，模拟网络延迟的情况。

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210716093958.png)
```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  generation: 2
  name: network-delay-example
spec:
  action: delay
  delay:
    correlation: "0"
    jitter: 0ms
    latency: 15s
  direction: to
  mode: one
  selector:
    labelSelectors:
      app: nginx
    namespaces:
    - default
  value: ""
```

验证客户端在有网络延迟的情况下请求的结果：

```sh
❯ curl 192.168.1.191:32513 -I
curl: (28) Failed to connect to 192.168.1.191 port 32513: Operation timed out
❯ curl 192.168.1.191:32513 -I
3HTTP/1.1 200 OK
Server: nginx/1.21.1
Date: Fri, 16 Jul 2021 01:42:51 GMT
Content-Type: text/html
Content-Length: 612
Last-Modified: Tue, 06 Jul 2021 14:59:17 GMT
Connection: keep-alive
ETag: "60e46fc5-264"
Accept-Ranges: bytes
```

查看整体信息：

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210716094314.png)