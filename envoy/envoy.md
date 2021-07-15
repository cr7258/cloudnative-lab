# Envoy

Envoy 将自身定义为数据平面，并希望使用者可以通过控制平面来为 Envoy 提供动态配置。著名的 Service Mesh 项目 Istio 默认就是使用 Envoy 作为数据平面。Istio 高级的流量管理功能都要通过 Envoy 来实现。

Envoy 和 Nginx 配置对比：https://www.qikqiak.com/envoy-book/migrate-from-nginx-to-envoy/

## xDS API

xDS API 是 Envoy 定义用于控制平面和数据平面之间数据交互的通讯协议。

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210715170302.png)

Envoy 基于 API 的动态端点发现：https://github.com/salrashid123/envoy_discovery