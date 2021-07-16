# Knative

Serveless 是一种云原生开发模型，可使开发人员专注构建和运行应用，而无需管理服务器。

Serveless 方案中仍然有服务器，但它们已从应用开发中抽离了出来。云提供商负责置备、维护和扩展服务器基础架构等例行工作。开发人员可以简单地将代码打包到容器中进行部署。

部署之后，Serveless 应用即可响应需求，并根据需要自动扩容。公共云提供商的 Serveless 产品通常通过一种事件驱动执行模型来按需计量。因此，当 Serveless功能闲置时，不会产生费用。

knative 是谷歌牵头的 Serverless 架构方案，旨在提供一套简单易用的 Serverless 开源方案，把 Serverless 标准化和平台化。目前参与 knative 项目的公司主要有： Google、Pivotal、IBM、Red Hat和 SAP。

## Knative 核心组件

Knative 主要由 Serving 和 Eventing 核心组件构成。

### Serving
Knative 作为 Severless 框架最终是用来提供服务的，那么 Knative Serving 应运而生。Knative Serving 构建于 Kubernetes 和 Istio 之上，为 Serverless 应用提供部署和服务支持。Knative Serving 中定义了以下 CRD 资源：
* Service: 自动管理工作负载整个生命周期。负责创建 Route、Configuration 以及 Revision 资源。通过 Service 可以指定路由到指定的 Revision。
* Route：负责映射网络端点到一个或多个 Revision。可以通过多种方式管理流量。包括灰度流量和重命名路由。
* Configuration: 负责保持 Deployment 的期望状态，提供了代码和配置之间清晰的分离。修改一次 Configuration 产生一个 Revision。
* Revision：Revision 资源是对工作负载进行的每个修改的代码和配置的时间点快照。Revision 是不可变对象，可以长期保留。

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210715222815.png)

### Eventing

Eventing 主要由事件源（Event Source）、事件处理（Flow）以及事件消费者（Event Consumer）三部分构成。

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210715222919.png)

**事件源（Event Source）**
当前支持以下几种类型的事件源：
* ApiserverSource：每次创建或更新 Kubernetes 资源时，ApiserverSource 都会触发一个新事件。
* GitHubSource：GitHub 操作时，GitHubSource 会触发一个新事件。
* GcpPubSubSource：GCP 云平台 Pub/Sub 服务会触发一个新事件。
* AwsSqsSource：Aws 云平台 SQS 服务会触发一个新事件。
* ContainerSource: ContainerSource 将实例化一个容器，通过该容器产生事件。
* CronJobSource: 通过 CronJob 产生事件。
* KafkaSource: 接收 Kafka 事件并触发一个新事件。
* CamelSource: 接收 Camel 相关组件事件并触发一个新事件。

**事件接收 / 转发（Flow）**
当前 Knative 支持如下事件接收处理：
* 直接事件接收：通过事件源直接转发到单一事件消费者。支持直接调用 Knative Service 或者
Kubernetes Service 进行消费处理。这样的场景下，如果调用的服务不可用，事件源负责重试机制处理。
* 通过事件通道 (Channel) 以及事件订阅 (Subscriptions) 转发事件处理。这样的情况下，可以通过 Channel 保证事件不丢失并进行缓冲处理，通过 Subscriptions 订阅事件以满足多个消费端处理。
* 通过 brokers 和 triggers 支持事件消费及过滤机制。从 v0.5 开始，Knative Eventing 定义 Broker 和 Trigger 对象，实现了对事件进行过滤（亦如通过 ingress 和 ingress controller 对网络流量的过滤一样）。通过定义 Broker 创建 Channel，通过 Trigger 创建 Channel 的订阅（subscription），并产生事件过滤规则。

**事件消费者（Event Consumer）**

为了满足将事件发送到不同类型的服务进行消费，Knative Eventing 通过多个 Kubernetes 资源定义了两个通用的接口：
* Addressable 接口提供可用于事件接收和发送的 HTTP 请求地址，并通过 status.address.hostname 字段定义。 作为一种特殊情况，Kubernetes Service 对象也可以实现 Addressable 接口。
* Callable 接口接收通过 HTTP 传递的事件并转换事件。可以按照处理来自外部事件源事件的相同方式，对这些返回的事件做进一步处理。

## 阿里云 Serveless Kubernetes（ASK）

ASK 集群是阿里云推出的 Serveless Kubernetes 容器服务。无需购买节点即可直接部署容器应用，无需对集群进行节点维护和容量规划，并且根据应用配置的 CPU 和内存资源量进行按需付费。

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210714170307.png)

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210714164826.png)

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210714165201.png)

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210714170515.png)


在没有请求时，Knative 会创建一个资源消耗较少的 reserver Pod 来准备接收请求。
```sh
❯ kubectl --kubeconfig=/tmp/kubeconfig get pod
NAME                                               READY   STATUS    RESTARTS   AGE
coffee-9vklh-deployment-reserve-695c5474dc-6lt9t   2/2     Running   0          2m8s
```

客户端发送请求：

```sh
❯ curl -H "Host:coffee.default.example.com" http://47.241.164.117
Hello coffee!
```

此时会拉取新的 Pod 来接收请求，待新 Pod 启动成功后，退出 reserve Pod：
```sh
❯ kubectl --kubeconfig=/tmp/kubeconfig get pod
NAME                                               READY   STATUS    RESTARTS   AGE
coffee-9vklh-deployment-6bfbfdcd48-tcrtf           1/2     Running   0          26s
coffee-9vklh-deployment-reserve-695c5474dc-6lt9t   2/2     Running   0          4m20s
❯ kubectl --kubeconfig=/tmp/kubeconfig get pod
NAME                                               READY   STATUS        RESTARTS   AGE
coffee-9vklh-deployment-6bfbfdcd48-tcrtf           2/2     Running       0          27s
coffee-9vklh-deployment-reserve-695c5474dc-6lt9t   2/2     Terminating   0          4m21s
```