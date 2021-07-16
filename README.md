# CloudNative

## 基于虚拟化的传统云平台面临的挑战
* 资源利用率低
   * 虚拟机的资源开销
   * 资源隔离粒度过大
* 操作系统复杂，维护困难
   * 宿主机
   * Hypervisor
   * 虚拟机
* 业务代码与基础架构相互割裂
  * 虚拟机构建和业务代码部署分离
  * 可变的基础架构使后续维护风险变大
  * 基础架构无法感知业务状态，升级和维护困难
* 缺少自动化
  * 需要自己构建应用高可用方案
  * 故障转移难
  * 扩容缩容难

## 什么是云原生
在公有云、私有云、混合云等动态环境中构建和运行规模化应用的能力。

## 云原生技术演进路线
* 应用架构演进
  * 单体应用到分层架构到 SOA 到微服务
* Kubernetes 架构演进
  * API 定义标准化
  * 基于扩展API形成的系统生态
  * 实现标准化
  * 接口和实现分离：CRI、CNI、CSI
* 服务网格化
  * 基于 Sidecar，提升数据面的可管理性
  * 协议升级
  * API 级别的认证鉴权
  * 提升可观察性
* 应用规模化
  * 概念验证阶段到大规模生产应用
  * 计算边缘化
  * 以数据中心为主的云计算到面向边缘节点的边缘计算
  * 部署多样化
  * 私有云和公有云融合的多云和混合云
* 应用复杂化
  * 简单的无状态应用到复杂的有状态应用管理
  * 传统微服务框架到服务网格
  * 长生命周期的服务到短生命周期的无服务
* 不断的局部技术革新
  * 基于 XDP 和 eBPF 的网络加速和应用隔离
  * 不断增强的安全保证手段
     * Kata、gVisor
     * 基于零信任架构的细粒度安全保证手段

## 云原生项目介绍

Application Definition & Image Build
* [Operator](operator/operator.md) -- 应用程序的控制器

Coordination & Service Discovery
* [Etcd](etcd/etcd.md) -- 分布式，可靠的键值存储

Service Proxy
* [Envoy](envoy/envoy.md) -- 面向云原生的 L7 代理和通信总线

Service Mesh
* [Linkerd](linkerd/linkerd.md) -- 服务网格

Container Runtime
* [gVisor](runtime/runtime.md) -- 安全容器运行时
* [Kata](runtime/runtime.md) 

Security & Compliance
* [OPA](opa/opa.md) -- 全场景通用的轻量策略引擎

Cloud Native Network
* [Cilium](cilium/cilium.md) -- 基于 eBPF/XDP 的高性能网络方案

Serverless
* [Dapr](dapr/dapr.md) -- 分布式应用运行时
* [Knative](knative/knative.md) -- serverless 架构方案

Automation & Configuration
* [Sealer](sealer/sealer.md) -- 高效的集群交付
* [Terraform](terraform/terraform.md) -- IT 基础架构自动化编排工具

Container Registry
* [Dragonfly](dragonfly/dragonfly.md) -- 基于P2P的镜像及文件分发系统

Observability and Analysis
* [Chaos Mesh](chaos_mesh/chaos_mesh.md) -- 混沌工程平台

Streaming & Messaging
* [Pulsar](pulsar/pulsar.md) -- 下一代消息平台