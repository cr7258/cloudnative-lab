# Open Policy Agent（OPA）

OPA 是一个全场景通用的轻量策略引擎（Policy Engine），OPA 提供了声明式表达的 Rego 语言来描述策略，并将策略的决策 offload 到 OPA，从而将策略的决策过程从策略的执行中解耦。OPA 可适用于多种场景，比如 Kubernetes、Terraform、Envoy 等等，简而言之，以前需要使用到 Policy 的场景理论上都可以用 OPA 来做一层抽象，如下所示：

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210715112927.png)

在大多数场景下，Policy 即是一系列用来控制服务的规则（可理解为就是 if-else 语句）。比如：
* Authorization 场景：定义哪些用户（Identity）可对哪些资源（Resource）进行什么类型的操作（Operation）的规则。
* 网络防火墙规则：比如 iptables 中设定的规则，Kubernetes 中的 Network Policy 都可认为是与网络相关的 Policy。
* 资源准入控制：符合某种 Policy 的资源（比如必须设置某些属性或字段）才可以被业务层处理，否则将被拒绝服务，典型的有 Kubernetes 的 Admission Control 机制。

**很多时候，Policy 的实现都与具体的服务耦合在一起，这导致 Policy 很难被单独抽象描述和灵活变更（比如动态加载新的规则）。而且，不同的服务对 Policy 有着不同的描述，比如采用 JSON、YAML 或其他 DSL，这样很难进一步将 Policy 以代码的形式进行管理（Policy As Code）。** 因此，为了更灵活和一致的架构，我们必须将 Policy 的决策过程从具体的服务解耦出去，这也是 OPA 整体架构的核心理念。如上图所示，在 OPA 的方案下我们对 Policy 的执行可抽象成以下 3 个步骤：
* 1.用 Rego 语言描述具体的 Policy
* 2.当某个服务需要执行 Policy 时将这个动作（Query）交给 OPA 来完成（OPA 可以以 library 或者第三方服务的形式出现）
* 3.OPA 在具体的输入数据下（Data）执行步骤 1 中的 Rego 代码，并将 Policy 执行后的结果返回给原始服务。

## Rego

Rego 在线运行：https://play.openpolicyagent.org/p/ZXkIlAEPCY

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210715143151.png)

Rego 语言为 OPA 项目提供一种领域无关的描述策略的声明式 DSL。Rego 的主要设计源于 Datalog，但是与 Datalog 不同的是，Rego 扩展了对 JSON 的支持，在 Rego 语言中，输入输出都是标准的 JSON 数据。

Rego 语言中最核心的一个功能的是对 Policy 的描述，即 Rules，Rules 是一个 if-then 的 logic statement。Rego 的 Rules 分为两类：complete rules 和 incremental rules。

complete rules 只会产生一个单独的值：

```sh
any_public_networks = true {
 net := data.networks[_]
 net.public
}
```

每一个 rule 都由 head 和 body 组成，比如上文 any_public_networks = true 就是 head，剩下的 {...} 则为 body。

incremental rules 则将产生所有满足 body 的 value 的集合，比如：

```sh
public_network[net.id] {
 net := data.networks[_]
 net.public
}
```
当执行 public_network 时，将返回一个 set，比如：

```sh
[
  "net3",
  "net4"
]
```

当 rule 内部出现多个布尔判断时，它们之间是逻辑与的关系，即多个布尔表达式的逻辑与构成整个 rule 最终的结果。

当多个 rule 组合在一起，其表达的是逻辑或的关系：

```sh
default shell_accessible = false

shell_accessible = true {
    input.servers[_].protocols[_] == "telnet"
}

shell_accessible = true {
    input.servers[_].protocols[_] == "ssh"
}
```

则 shell_accessible 是寻找 servers 中支持 telnet 或 ssh 的变量。

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210715145812.png)


## OPA Gatekeeper

OPA Gatekeeper 是一个提供 OPA 和 Kubernetes 之间集成的新项目。

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210715120544.png)

Gatekeeper 在 Kubernetes 中以 Pod 形式启动，启动后将向 API Server 中注册 Dynamic Admission Controller，本质上就是让 Gatekeeper 作为一个 Webhook Server。当用户使用 kubectl 或者其他方式向 API Server 发出对资源的 CURD 请求时，其请求经过 Authentication 和 Authorization 后，将发送给 Admission Controller，并最终以 AdmissionReview 请求的形式发送给 Gatekeeper。Gatekeeper 根据对应服务的 Policy（以 CRD 形式配置）对这个请求进行决策，并以 AdmissionReview 的响应返回给 API Server。

Gatekeeper v3.0 的架构如下所示：

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210715120748.png)

在目前的设计中，Gatekeeper 有 4 类 CRD：
* ConstraintTemplate：ConstraintTemplate 和 Constraint 可认为是类似于类和实例的关系。*ConstraintTemplate 的 rego 字段用 Rego 语言具体描述了 Policy，但并没有指定 Policy 中具体的参数。ConstraintTemplate 也描述了生成 Constraint CRD 的 schema
* Constraint：Constraint 可认为是对某一个 ConstraintTemplate 的实例化，其中对 ConstraintTemplate 的未指定参数进行了具体的配置。因此，对同一个 ConstraintTemplate 不同的参数配置可以生成多个 Constraint。Constraint 是由 ConstraintTemplate 这个 CRD 的描述再次由 Gatekeeper 生成的 CRD（即通过 CRD 再生成 CRD）。
* Audit：Gatekeeper 的 Audit 功能可以定期对从 Kubernetes 集群复制对应的资源应用具体的 Contraint，从而发现当前已存在服务中是否有违反 Policy 的配置。Audit 即是用以控制和配置该功能的 CRD。
* Sync：Audit 功能在 Gatekeeper 执行 Policy 时需要从 Kubernetes 集群中复制（replication）资源，Sync 即是用来控制和配置这一过程的 CRD。

## Admission Webhook

目前 Gatekeeper 仅支持 Validating Webhook，Mutating Webhook 正在开发中。在 Kubernetes apiserver 中包含两个特殊的准入控制器：MutatingAdmissionWebhook 和 ValidatingAdmissionWebhook。这两个控制器将发送准入请求到外部的 HTTP 回调服务并接收一个准入响应。

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210715121157.png)

准入控制器是在对象持久化之前用于对 Kubernetes API Server 的请求进行拦截的代码段，在请求经过身份验证和授权之后放行通过。准入控制器可能正在validating、mutating或者都在执行，Mutating 控制器可以修改他们的处理的资源对象，Validating 控制器不会，如果任何一个阶段中的任何控制器拒绝了请求，则会立即拒绝整个请求，并将错误返回给最终的用户。

现在非常火热的的 Service Mesh 应用istio就是通过 mutating webhooks 来自动将Envoy这个 sidecar 容器注入到 Pod 中去的：https://istio.io/docs/setup/kubernetes/sidecar-injection/。

实现一个准入控制器：https://www.qikqiak.com/post/k8s-admission-webhook/