# Linkerd

## 安装部署

### 安装 CLI

```sh
curl -sL https://run.linkerd.io/install | sh
```

### 校验 Kubernetes 集群

检查 Kubernetes 集群是否符合安装条件：

```sh
linkerd check --pre
```

如果有任何检查未通过，请确保按照提供的链接并在继续之前解决这些问题。

### 按装控制平面到 Kubernetes 集群

在此命令中，linkerd install 命令生成一个 Kubernetes manifest， 其中包含所有必要的控制平面资源。将此清单通过管道传输到 kubectl apply 然后 指示 Kubernetes 将这些资源添加到您的集群中。

```sh
linkerd install | kubectl apply -f -
```

现在让我们等待控制平面完成安装。根据集群 Internet 连接的速度， 这可能需要一两分钟。通过运行以下命令等待控制平面准备就绪：

```sh
linkerd check
```

接下来，我们将安装一些扩展。扩展为 Linkerd 添加了非关键但通常有用的功能。 对于本指南，我们需要 viz 扩展，它会将 Prometheus、 仪表板(dashboard)和指标组件(metrics components)安装到集群上：

```sh
linkerd viz install | kubectl apply -f - # on-cluster metrics stack
```

## 浏览 Linkerd

安装并运行控制平面和扩展后，现在可以通过运行以下命令查看 Linkerd 仪表板，此命令设置从本地系统到 linkerd-web pod 的端口：

```sh
linkerd viz dashboard &
```

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210716142822.png)

访问 Grafana：

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210716130341.png)

## 安装 demo app

要了解 Linkerd 如何为您的一项服务工作，您可以安装一个 demo 应用程序。 emojivoto 应用程序是一个独立的 Kubernetes 应用程序， 它混合使用 gRPC 和 HTTP 调用，允许用户对他们最喜欢的表情符号进行投票。

通过运行以下命令将 emojivoto 安装到 emojivoto 命名空间中：

```sh
curl -sL https://run.linkerd.io/emojivoto.yml \
  | kubectl apply -f -
```

在我们对它进行 mesh 划分之前，让我们先来看看这个应用程序。 如果此时您正在使用 Docker Desktop， 则可以直接访问 http://localhost。 如果你没有使用 Docker Desktop，我们需要转发 web-svc 服务。 要将 web-svc 本地转发到端口 8080，您可以运行：

```sh
kubectl -n emojivoto port-forward svc/web-svc 8080:80
```
通过 http://localhost:8080 访问 demo app：

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210716130308.png)

接下来，让我们通过运行以下命令将 linkerd 添加到 emojivoto：

```sh
kubectl get -n emojivoto deploy -o yaml \
  | linkerd inject - \
  | kubectl apply -f -
```

此命令检索在 emojivoto 命名空间中运行的所有部署(deployments)， 通过 linkerd inject 运行清单，然后将其重新应用到集群。 linkerd inject 命令向 pod spec 添加注解(annotations)， 指示 Linkerd 将代理(proxy)作为容器添加（“注入”）到 pod spec 中。

观测 demo appp 的运行情况，将显示每个部署的“黄金(golden)”指标：
* 成功率(Success rates)
* 请求率(Request rates)
* 延迟分布百分位数(Latency distribution percentiles)

```sh
❯ linkerd -n emojivoto viz stat deploy
NAME       MESHED   SUCCESS      RPS   LATENCY_P50   LATENCY_P95   LATENCY_P99   TCP_CONN
emoji         1/1   100.00%   1.8rps           1ms           1ms           1ms          3
vote-bot      1/1   100.00%   0.2rps           1ms           1ms           1ms          1
voting        1/1    85.71%   0.8rps           1ms           1ms           1ms          3
web           1/1    90.29%   1.7rps           1ms           2ms           3ms          3
```

这些指标也可以在 Dashboard 上查看：

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210716130108.png)

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210716130241.png)

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210716130712.png)



## 金丝雀发布

### 安装 Flagger

Linkerd 将管理实际的流量路由， 而 Flagger 会自动执行创建新 Kubernetes 资源(resources)、 观察指标(watching metrics)和逐步将用户流量发送到新版本的过程。

```sh
kubectl apply -k flagger/kustomize/linkerd
```

### 设置 demo

该 demo 由三个组件组成：负载生成器(load generator)、部署(deployment)和前端(frontend)。 部署会创建一个 pod，该 pod 会返回一些信息，例如名称。 您可以使用响应(responses)来观察随着 Flagger 编排的增量部署。 由于需要某种活动流量才能完成操作，因此负载生成器可以更轻松地执行部署。 这些组件的拓扑结构如下所示：

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210716132526.png)

要将这些组件添加到您的集群并将它们包含在 Linkerd 数据平面中：

```sh
kubectl create ns test && \
  kubectl apply -f demo.yml
```

通过在本地转发前端服务并通过运行在本地的 http://localhost:8080 来打开检查它：
```sh
kubectl -n test port-forward svc/frontend 8080
```
![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210716133025.png)

### 配置发布

```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: podinfo
  namespace: test
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: podinfo
  service:
    port: 9898
  analysis:
    interval: 10s
    threshold: 5
    stepWeight: 10
    maxWeight: 100
    metrics:
    - name: request-success-rate
      thresholdRange:
        min: 99
      interval: 1m
    - name: request-duration
      thresholdRange:
        max: 500
      interval: 1m
```

Flagger 控制器正在监视这些定义(definitions)，并将在集群上创建一些新的资源。 要观察这个过程，运行：

```sh
kubectl -n test get ev --watch
#返回结果
0s          Normal    Synced                   canary/podinfo                          Initialization done! podinfo.test
```

将创建一个名为 podinfo-primary 的 deployment，其副本数量与 podinfo 具有的副本数量相同。

```sh
❯ kubectl get deployments.apps -n test
NAME              READY   UP-TO-DATE   AVAILABLE   AGE
frontend          1/1     1            1           90s
load              1/1     1            1           90s
podinfo           1/1     1            1           89s
podinfo-primary   0/1     1            0           3s
```

一旦新 Pod 准备就绪，原始部署将缩减为零：

```sh
❯ kubectl get deployments.apps -n test
NAME              READY   UP-TO-DATE   AVAILABLE   AGE
frontend          1/1     1            1           112s
load              1/1     1            1           112s
podinfo           0/0     0            0           111s
podinfo-primary   1/1     1            1           25s
```

除了托管部署之外，还创建了一些服务来协调应用程序的新旧版本之间的路由流量。 这些可以使用 kubectl -n test get svc 查看，应该如下所示：

```sh
❯ kubectl get -n test svc
NAME              TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
frontend          ClusterIP   192.168.86.61    <none>        8080/TCP   15m
podinfo           ClusterIP   192.168.241.0    <none>        9898/TCP   15m
podinfo-canary    ClusterIP   192.168.197.22   <none>        9898/TCP   4m26s
podinfo-primary   ClusterIP   192.168.16.161   <none>        9898/TCP   4m26s
```

此时，拓扑看起来有点像：

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210716134335.png)

### 升级

```sh
kubectl -n test set image deployment/podinfo \
  podinfod=quay.io/stefanprodan/podinfo:1.7.1
```

更新时，金丝雀部署 (podinfo) 将扩大(scaled up)。 准备就绪后，Flagger 将开始逐步更新 TrafficSplit CRD。 配置 stepWeight 为 10，每增加一次，podinfo 的权重就会增加 10。 对于每个周期，都会观察成功率，只要超过 99% 的阈值，Flagger 就会继续推出(rollout)。 要查看整个过程，请运行：

```sh
kubectl -n test get ev --watch
```

在发生更新时，资源和流量在较高级别将如下所示：

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210716140013.png)

在 Dashboard 上可以看到新旧版本流量百分比的变化情况：

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210716134121.png)

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210716134210.png)

再次访问 http://localhost:8080。刷新页面将显示新版本和不同标题颜色之间的切换。

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210716134141.png)

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210716134150.png)

### 清理

要进行清理，请从集群中删除 Flagger 控制器并通过运行以下命令删除 test 命名空间：

```sh
kubectl delete -k github.com/fluxcd/flagger/kustomize/linkerd && \
  kubectl delete ns test
```