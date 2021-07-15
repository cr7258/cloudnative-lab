# Dapr

官网地址：https://docs.dapr.io/

Dapr 是一个可移植的、事件驱动的分布式应用运行时，它使任何开发人员能够轻松构建出弹性的、无状态和有状态的应用程序，并可运行在云平台或边缘计算中，它同时也支持多种编程语言和开发框架。

Bilgin Ibryam 在 [Multi-Runtime Microservices Architecture](https://www.infoq.com/articles/multi-runtime-microservice-architecture/) 文章中提及的分布式应用的四大需求：
* 网络（Networking）
* 生命周期（Lifecycle）
* 状态（State）
* 捆绑（Binding）

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210712225008.png)

Dapr 提出的分布式应用运行时就是实现了以上四个需求并将其下沉作为分布式应用的运行环境。Dapr 通过以 HTTP/gRPC API 这种与语言无关的方式暴露封装的分布式能力供应用调用，从而支持使用任意语言或框架进行开发集成。其中网络层面和 Service Mesh 的功能有一定的重叠，例如 Istio，Linkerd。

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210712225501.png)

## Sidecar 架构

业务容器通过 localhost 地址调用 darp 容器，Dapr 和 Istio 相比，二者虽然都是通过 sidecar 的模式进行网络控制，但二者是有区别的。Dapr 是以 API 的方式，而 Istio 是以代理的方式（不改变 HTTP 请求 URI)。

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210714155223.png)

## 构建块

https://docs.dapr.io/zh-hans/concepts/building-blocks-concept/

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210714155719.png)


## 在 Kubernetes 环境中运行 Pub-Sub 示例


![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210714151643.png)

### 安装 Helm

```sh
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
```

### 部署 Dapr

```sh
helm repo add dapr https://dapr.github.io/helm-charts/
helm repo update
helm install dapr dapr/dapr \
--version=1.2 \
--namespace dapr-system \
--create-namespace \
--wait
```

查看 dapr：

```sh
❯ kubectl get pod -n dapr-system
NAME                                     READY   STATUS    RESTARTS   AGE
dapr-dashboard-58b4647996-h9978          1/1     Running   0          103s
dapr-operator-85bdd7d89d-kftlm           1/1     Running   1          103s
dapr-placement-server-0                  1/1     Running   1          103s
dapr-sentry-76bfc5f7c7-4c7vx             1/1     Running   0          103s
dapr-sidecar-injector-786645f444-w6bfn   1/1     Running   0          103s
```

### 部署 Redis 集群

https://github.com/bitnami/charts/tree/master/bitnami/redis
```sh
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install redis bitnami/redis  -n cloudnative-lab --set auth.password=abcd123456
```

查看 Redis：

```sh
❯ kubectl get pod -n cloudnative-lab
NAME                            READY   STATUS    RESTARTS   AGE
redis-master-0                  1/1     Running   0          38h
redis-replicas-0                1/1     Running   1          38h
redis-replicas-1                1/1     Running   0          38h
redis-replicas-2                1/1     Running   0          38h
```

修改 dapr 的 component 文件，每一个 pod 中包含两个容器，一个是应用容器，另一个是 dapr 容器，dapr 容器根据此配置连接 redis 集群。

vim quickstarts/pub-sub/deploy/redis.yaml
```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: pubsub
spec:
  type: pubsub.redis
  version: v1
  metadata:
  - name: "redisHost"
    value: "redis-master:6379"
  - name: "redisPassword"
    value: "abcd123456"
```

为了方便集群外部访问服务，修改 react 容器服务的暴露方式为 NodePort：

```yaml
kind: Service
apiVersion: v1
metadata:
  name: react-form
  labels:
    app: react-form
spec:
  selector:
    app: react-form
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
  type: NodePort #修改为 NodePort
```

应用配置：

```sh
❯ kubectl apply -f quickstarts/pub-sub/deploy -n cloudnative-lab
deployment.apps/node-subscriber created
deployment.apps/python-subscriber created
service/react-form created
deployment.apps/react-form created
component.dapr.io/pubsub created
```

查看创建的 pod：

```sh
❯ kubectl get pod -n cloudnative-lab
NAME                                 READY   STATUS    RESTARTS   AGE
node-subscriber-7dc79579bc-qzl8b     2/2     Running   0          2m36s
python-subscriber-6fd5dc7f8c-56q87   2/2     Running   0          2m36s
react-form-7975b5fff9-sntvp          2/2     Running   4          2m36s
```

查看 service：

```sh
❯ kubectl get svc -n cloudnative-lab
NAME                            TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)                               AGE
node-subscriber-dapr            ClusterIP   None           <none>        80/TCP,50001/TCP,50002/TCP,9090/TCP   6m14s
python-subscriber-dapr          ClusterIP   None           <none>        80/TCP,50001/TCP,50002/TCP,9090/TCP   6m14s
react-form                      NodePort    24.3.152.48    <none>        80:32590/TCP                          6m14s
react-form-dapr                 ClusterIP   None           <none>        80/TCP,50001/TCP,50002/TCP,9090/TCP   6m14s
```

浏览器输入 http://11.8.38.43:32590（宿主机IP:NodePort）访问 react 前端服务：

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210714153024.png)


分别发送 type A、B、C 类型的消息：

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210714153349.png)

分别查看 node 和 python 容器的日志：

```sh
kubectl logs -n cloudnative-lab node-subscriber-7dc79579bc-qzl8b -c node-subscriber -f
kubectl logs -n cloudnative-lab python-subscriber-6fd5dc7f8c-56q87 -c python-subscriber -f
```

node 订阅者会收到 type A 和 type B 的消息，python 订阅者会收到 type A 和 Type B 的消息。

清理现场：

```sh
kubectl delete -f quickstarts/pub-sub/deploy -n cloudnative-lab
```