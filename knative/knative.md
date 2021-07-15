# Knative

Serveless 是一种云原生开发模型，可使开发人员专注构建和运行应用，而无需管理服务器。

Serveless 方案中仍然有服务器，但它们已从应用开发中抽离了出来。云提供商负责置备、维护和扩展服务器基础架构等例行工作。开发人员可以简单地将代码打包到容器中进行部署。

部署之后，Serveless 应用即可响应需求，并根据需要自动扩容。公共云提供商的 Serveless 产品通常通过一种事件驱动执行模型来按需计量。因此，当 Serveless功能闲置时，不会产生费用。

knative 是谷歌牵头的 Serverless 架构方案，旨在提供一套简单易用的 Serverless 开源方案，把 Serverless 标准化和平台化。目前参与 knative 项目的公司主要有： Google、Pivotal、IBM、Red Hat和 SAP。

## 阿里云 Serveless Kubernetes（ASK）

ASK 集群是阿里云推出的 Serveless Kubernetes 容器服务。无需购买节点即可直接部署容器应用，无需对集群进行节点维护和容量规划，并且根据应用配置的 CPU 和内存资源量进行按需付费。

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210714170307.png)

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210714164826.png)

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210714165201.png)

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210714170515.png)

```sh
❯ kubectl --kubeconfig=/tmp/kubeconfig get pod
NAME                                               READY   STATUS    RESTARTS   AGE
coffee-9vklh-deployment-reserve-695c5474dc-6lt9t   2/2     Running   0          2m8s
```

```sh
❯ curl -H "Host:coffee.default.example.com" http://47.241.164.117
Hello coffee!
```

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