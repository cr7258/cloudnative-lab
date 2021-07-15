# Elastic Cloud on Kubernetes (ECK)

Elastic Cloud on Kubernetes (ECK) 基于 Kubernetes Operator 模式构建，扩展了基本的 Kubernetes 编排功能，以支持 Elasticsearch、Kibana、APM Server、Enterprise Search 和 Beats 在 Kubernetes 环境中的设置和管理。


## 安装 ECK Operator

```
kubectl apply -f all-in-one.yaml
```

查看 ECK Operator：

```
❯ kgp -n elastic-system
NAME                 READY   STATUS    RESTARTS   AGE
elastic-operator-0   1/1     Running   1          2m12s
```

## 部署 Elasticsearch 集群

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: my-elasticsearch
  namespace: cloudnative-lab
spec:
  version: 7.13.3
  nodeSets:
  - name: default
    count: 3
    config:
      node.store.allow_mmap: false
EOF
```

查看 Elasitcsearch 集群：

```
❯ kubectl get elasticsearch -n cloudnative-lab
NAME               HEALTH   NODES   VERSION   PHASE   AGE
my-elasticsearch   green    3       7.13.3    Ready   8m30s

❯ kgp -n cloudnative-lab
NAME                            READY   STATUS    RESTARTS   AGE
my-elasticsearch-es-default-0   1/1     Running   0          3m27s
my-elasticsearch-es-default-1   1/1     Running   0          3m27s
my-elasticsearch-es-default-2   1/1     Running   0          3m26s
```

获取 elastic 用户密码，密码通过 base64 加密后保存在 secret 中：

```sh
kubectl get secret -n cloudnative-lab my-elasticsearch-es-elastic-user -o go-template='{{.data.elastic | base64decode}}'
#返回结果
0ne7Ub93eBZV175cTkU63U2V
```

修改 service 为 NodePort 类型，将服务暴露到集群外：

```sh
❯ kubectl patch svc -n cloudnative-lab my-elasticsearch-es-http  -p '{"spec":{"type":"NodePort"}}'
#返回结果
service/my-elasticsearch-es-http patched
```
查看 service：

```sh
❯ kubectl get svc -n cloudnative-lab
NAME                            TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
my-elasticsearch-es-default     ClusterIP   None           <none>        9200/TCP         17m
my-elasticsearch-es-http        NodePort    24.3.114.221   <none>        9200:32418/TCP   17m
my-elasticsearch-es-transport   ClusterIP   None           <none>        9300/TCP         17m
```

在集群外部通过 Kubernetes 节点 IP:NodePort 访问 Elasticsearch 集群：

```json
❯ curl -u "elastic:0ne7Ub93eBZV175cTkU63U2V" https://11.8.38.43:32418/_cluster/health -k -s | jq
{
  "cluster_name": "my-elasticsearch",
  "status": "green",
  "timed_out": false,
  "number_of_nodes": 3,
  "number_of_data_nodes": 3,
  "active_primary_shards": 0,
  "active_shards": 0,
  "relocating_shards": 0,
  "initializing_shards": 0,
  "unassigned_shards": 0,
  "delayed_unassigned_shards": 0,
  "number_of_pending_tasks": 0,
  "number_of_in_flight_fetch": 0,
  "task_max_waiting_in_queue_millis": 0,
  "active_shards_percent_as_number": 100
}
```

## 部署 Kibana

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: kibana.k8s.elastic.co/v1
kind: Kibana
metadata:
  name: my-kibana
  namespace: cloudnative-lab
spec:
  version: 7.13.3
  count: 3
  elasticsearchRef:
    name: my-elasticsearch
EOF
```

查看 Kibana：

```sh
❯ kubectl get pod -n cloudnative-lab
my-kibana-kb-5975f88459-kjd6r   1/1     Running   0          5m13s
my-kibana-kb-5975f88459-nsb4h   1/1     Running   0          5m13s
my-kibana-kb-5975f88459-qflcp   1/1     Running   0          5m13s

❯ kubectl get kibana -n cloudnative-lab
NAME        HEALTH   NODES   VERSION   AGE
my-kibana   green    3       7.13.3    5m38s
```

修改 service 为 NodePort 类型，将服务暴露到集群外：

```sh
❯  kubectl patch svc -n cloudnative-lab my-kibana-kb-http  -p '{"spec":{"type":"NodePort"}}'
#返回结果
service/my-kibana-kb-http patched
```

查看 service：

```sh
❯ kubectl get svc -n cloudnative-lab
NAME                            TYPE        CLUSTER-IP     EXTERNAL-IP   PORT
my-kibana-kb-http               NodePort    24.3.146.169   <none>        5601:31661/TCP   31m
```

浏览器访问 https://11.8.83.11:31661，用户名：elastic，密码：0ne7Ub93eBZV175cTkU63U2V，登录 Kibana。

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210714113511.png)