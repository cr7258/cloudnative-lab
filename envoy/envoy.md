# Envoy

Envoy 是为面向大型现代服务架构而设计的 L7 代理和通信总线。该项目源于以下理念：
**对于应用来说网络应该是透明的。当网络和应用出现故障时，应该非常容易定位问题发生的根源。**

事实上，实现上述的目标非常困难。Envoy 试图通过提供以下高级功能来实现这一目标：
* **进程外架构**：Envoy 是一个独立进程，伴随每个应用服务运行。所有的 Envoy 形成一个透明的通信网格，每个应用与 localhost 收发信息，对网络的拓扑结构无感知。
* **L3/L4 filter 架构**：Envoy 的核心是一个 L3/L4 网络代理。可插拔的 filter 链机制允许开发 filter 来执行不同 TCP/UDP 代理任务并将其插入到主服务中。现已有多个支持各种任务的 filter，如原始的 TCP 代理、UDP 代理、HTTP 代理、TLS 客户端证书认证、Redis、MongoDB 和 Postgres 等。
* **HTTP L7 filter 架构**：HTTP 是现代应用架构中的关键组件，Envoy 支持 额外的 HTTP L7 filter 层。可以将 HTTP filter 插入执行不同任务的 HTTP 连接管理子系统中，如 缓存、限速、路由/转发、嗅探 Amazon 的 DynamoDB 等。
* **HTTP/2 支持**：当以 HTTP 模式运行时，Envoy 同时 支持 HTTP/1.1 和 HTTP/2。Envoy 可以作为 HTTP/1.1 和 HTTP/2 之间的双向透明代理。这意味着任意 HTTP/1.1 和 HTTP/2 客户端和目标服务器的组合都可以桥接在一起。建议配置所有服务之间的 Envoy 使用 HTTP/2 来创建持久连接的网格，以便可以实现请求和响应的多路复用。
* **HTTP L7 路由**：当以 HTTP 模式运行时，Envoy 支持一种路由子系统，能够根据路径、权限、内容类型、运行时参数值等对请求进行路由和重定向。这项功能在将 Envoy 用作前端/边缘代理时非常有用，同时在构建服务网格时也会使用此功能。
* **gRPC 支持**：gRPC 是一个来自 Google 的 RPC 框架，它使用 HTTP/2 作为底层多路复用传输协议。Envoy 支持被 gRPC 请求和响应的作为路由和负载均衡底层的所有 HTTP/2 功能。这两个系统是非常互补的。
* **服务发现和动态配置**：Envoy 可以选择使用一组分层的 动态配置 API 来实现集中化管理。这些层为 Envoy 提供了以下内容的动态更新：后端集群内的主机、后端集群本身、HTTP 路由、监听套接字和加密材料。
* **健康检查**：Envoy 可以选择对上游服务集群执行主动健康检查。然后，Envoy 联合使用服务发现和健康检查信息来确定健康的负载均衡目标。Envoy 还通过 异常检查 子系统支持被动健康检查。
* **高级负载均衡**：负载均衡是分布式系统中不同组件之间的一个复杂问题。由于 Envoy 是一个独立代理而不是软件库，因此可以独立实现高级负载均衡以供任何应用程序访问。目前，Envoy 支持 自动重试、熔断、通过外部速率限制服务的 全局限速、请求映射 和 异常检测。
* **前端/边缘代理支持**：在边缘使用相同的软件大有好处（可观察性、管理、相同的服务发现和负载均衡算法等）。Envoy 包含足够多的功能，可作为大多数现代 Web 应用程序的边缘代理。包括 TLS 终止、HTTP/1.1 和 HTTP/2 支持，以及 HTTP L7 路由。
* **最佳的可观察性**：如上所述，Envoy 的主要目标是让网络透明化。然而，在网络层面和应用层面都有可能出现问题。Envoy 包含对所有子系统的强大统计支持。通过第三方提供商，Envoy 还支持分布式追踪。

Envoy 将自身定义为数据平面，并希望使用者可以通过控制平面来为 Envoy 提供动态配置。著名的 Service Mesh 项目 Istio 默认就是使用 Envoy 作为数据平面。Istio 高级的流量管理功能都要通过 Envoy 来实现。

Envoy 和 Nginx 配置对比：https://www.qikqiak.com/envoy-book/migrate-from-nginx-to-envoy/

## xDS API

xDS API 是 Envoy 定义用于控制平面和数据平面之间数据交互的通讯协议。

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210715170302.png)

## Envoy 基于 API 的动态端点发现：

该实验总体来说有三个部分：
* 1.Envoy Server（监听在 10000 端口），将外部请求代理到上游真实的应用服务，向 EDS 服务器获取 endpoints 列表。
* 2.EDS gRPC 服务器（gRPC 监听在 8080 端口，HTTP 监听在 5000 端口），向 Envoy 返回 endpoints 列表。
* 3.上游服务（分别监听在 8081，8082 端口），这些是最终提供服务的应用。在启动时，这些 Python 服务器会告知 EDS 服务器它们的存在，然后在 EDS 服务器将会通知 Envoy。
![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210715205907.png)

### Envoy 配置文件

```yaml
   
admin:
  access_log_path: /dev/null
  address:
    socket_address:
      address: 127.0.0.1
      port_value: 9000

node:
  cluster: mycluster
  id: test-id

static_resources:
  listeners:
  - name: listener_0

    address:
      socket_address: { address: 0.0.0.0, port_value: 10000 }

    filter_chains:
    - filters:
      - name: envoy.filters.network.http_connection_manager
        typed_config:  
          "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager  
          stat_prefix: ingress_http
          codec_type: AUTO
          route_config:
            name: local_route
            virtual_hosts:
            - name: local_service
              domains: ["*"]
              routes:
              - match: { prefix: "/" }
                route: { cluster: service_backend }
          http_filters:
          - name: envoy.filters.http.router
  clusters:
  - name: service_backend
    type: EDS  
    connect_timeout: 0.25s
    ignore_health_on_host_removal: true
    health_checks: 
      - timeout: 1s
        interval: 5s
        unhealthy_threshold: 1
        healthy_threshold: 1
        http_health_check: 
          path: /healthz    
    eds_cluster_config:
      service_name: myservice
      eds_config:
        resource_api_version: V3
        api_config_source:
          api_type: GRPC
          transport_api_version: V3
          grpc_services:
          - envoy_grpc:
              cluster_name: eds_cluster
          refresh_delay: 5s
  - name: eds_cluster
    type: STATIC
    connect_timeout: 0.25s
    http2_protocol_options: {}
    load_assignment:
      cluster_name: eds_cluster
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address:
                address: 127.0.0.1  #EDS服务器地址
                port_value: 8080
```

## 启动 Envoy

使用 debug 模式启动 Envoy：

```sh
envoy -c envoy_config.yaml -l debug
```

此时 Envoy 会去尝试连接 EDS 服务器（127.0.0.1:8080），但是由于 EDS 服务器尚未启动，此时访问 Envoy 将相应失败。

```sh
$ curl -v  http://localhost:10000/

> GET / HTTP/1.1
> Host: localhost:10000
> User-Agent: curl/7.72.0
> Accept: */*
> 

< HTTP/1.1 503 Service Unavailable
< content-length: 19
< content-type: text/plain
< date: Fri, 25 Dec 2020 13:26:05 GMT
< server: envoy
< 

no healthy upstream
```

## 启动 EDS 服务器

```sh
cd eds_server
go run grpc_server.go
```

此时 Envoy 将连接到 EDS 服务器。但是由于 EDS 服务器不知道任何其他应用服务器，它的 endpoints 列表为空，当 Envoy 联系 EDS 服务器时，它将返回一个空列表。

```sh
$ go run grpc_server.go 
INFO[0000] Starting control plane                       
INFO[0000] management server listening                   port=8080
INFO[0022] OnStreamOpen 1 open for type.googleapis.com/envoy.config.endpoint.v3.ClusterLoadAssignment 
INFO[0022] OnStreamRequest type.googleapis.com/envoy.config.endpoint.v3.ClusterLoadAssignment 
INFO[0022] OnStreamRequest ResourceNames [myservice]    
INFO[0022] []                                           
INFO[0022] >>>>>>>>>>>>>>>>>>> creating snapshot Version 1 
INFO[0022] OnStreamResponse...                          
INFO[0022] cb.Report()  callbacks                        fetches=0 requests=1
INFO[0022] OnStreamRequest type.googleapis.com/envoy.config.endpoint.v3.ClusterLoadAssignment 
INFO[0022] OnStreamRequest ResourceNames [myservice]  
```

此时 Envoy 仍然无法将请求转发给上游应用：

```sh
$ curl -v  http://localhost:10000/

no healthy upstream
```

### 启动上游应用

启动上游应用，监听 8081 端口。

```sh
cd upstream/

virtualenv env --python=/usr/bin/python3
source env/bin/activate
pip install -r requirements.txt

python server.py -p 8081
```

当服务启动时，会发送 HTTP REST API 请求给 EDS 服务器，告知 EDS 服务器应用监听的 IP:Port 信息。以下是应用服务向 EDS 服务器注册的代码：

```python
def main(argv):
   port = 18080
   print("Registering endpoint: 127.0.0.1:", port)
   url = 'http://localhost:5000/edsservice/register?endpoint=127.0.0.1:' + port
   f = urllib.request.urlopen(url)
   print(f.read().decode('utf-8'))
```

此时 Envoy 向 EDS 服务器请求时，将会获取到刚刚注册上来的应用服务的地址信息。

```sh
INFO[0556] >>>>>>>>>>>>>>>>>>> creating cluster, remoteHost, nodeID myservice,  127.0.0.1:8081, test-id 
INFO[0556] [lb_endpoints:{endpoint:{address:{socket_address:{address:"127.0.0.1" port_value:8081}}}}] 
INFO[0556] >>>>>>>>>>>>>>>>>>> creating snapshot Version 10 
INFO[0556] OnStreamResponse...                          
INFO[0556] cb.Report()  callbacks                        fetches=0 requests=10
INFO[0556] OnStreamRequest type.googleapis.com/envoy.config.endpoint.v3.ClusterLoadAssignment 
INFO[0556] OnStreamRequest ResourceNames [myservice]   
```

此时 Envoy 就可以成功将客户端的请求代理到上游服务：

```sh
$ curl -v  http://localhost:10000/
 
< HTTP/1.1 200 OK
< content-type: text/html; charset=utf-8
< content-length: 36
< server: envoy
< date: Mon, 30 Apr 2018 06:21:43 GMT
< x-envoy-upstream-service-time: 3
< 
* Connection #0 to host localhost left intact
40b9bc6f-77b8-49b7-b939-1871507b0fcc
```

请求 EDS 服务器注销服务：

```sh
$ curl http://localhost:5000/edsservice/deregister?endpoint=127.0.0.1:8081
127.0.0.1:8081 ok
```

注销服务后，客户端再次请求就无法正常响应了：

```sh
$ curl -v  http://localhost:10000/
* About to connect() to localhost port 10000 (#0)
*   Trying ::1...
* Connection refused
*   Trying 127.0.0.1...
* Connected to localhost (127.0.0.1) port 10000 (#0)
> GET / HTTP/1.1
> User-Agent: curl/7.29.0
> Host: localhost:10000
> Accept: */*
> 
< HTTP/1.1 503 Service Unavailable
< content-length: 19
< content-type: text/plain
< date: Thu, 15 Jul 2021 13:49:35 GMT
< server: envoy
< 
* Connection #0 to ho
```