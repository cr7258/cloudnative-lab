# Etcd
## Etcd 是什么
根据[Etcd官网](https://etcd.io/)的介绍：
> A distributed, reliable key-value store for the most critical data of a distributed system。
分布式，可靠的键值存储，用于分布式系统中最关键的数据。

在分布式系统中，各种服务配置信息的管理共享和服务发现是一个很基本也是很重要的问题，无论你调用服务还是调度容器，都需要知道对应的服务实例和容器节点地址信息。Etcd 就是这样一款实现了元数据信息可靠存储的组件。

Etcd 可集中管理配置信息。服务端将配置信息存储于 Etcd，客户端通过 Etcd 得到服务配置信息，并可以通过 watch 机制监听信息的变化。Etcd是 Kubernetes 集群中的一个十分重要的组件，用于保存集群所有的元信息配置和对象的状态信息。

而 Etcd 满足 CAP 理论中的 CP（一致性和分区容错性），Etcd 使用的是 raft一致性算法来实现的，关于raft一致性算法请参考该[动画演示](http://thesecretlivesofdata.com/raft/)。

CAP原理介绍：https://www.ruanyifeng.com/blog/2018/07/cap.html

## 二进制安装

```yaml
ETCD_VER=v3.4.4
GITHUB_URL=https://github.com/etcd-io/etcd/releases/download
DOWNLOAD_URL=${GITHUB_URL}
curl -L ${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o /usr/local/etcd-${ETCD_VER}-linux-amd64.tar.gz
tar xzvf /usr/local/etcd-${ETCD_VER}-linux-amd64.tar.gz -C /usr/local
rm -f /usr/local/etcd-${ETCD_VER}-linux-amd64.tar.gz
ln /usr/local/etcd-${ETCD_VER}-linux-amd64/etcd  /usr/local/bin/etcd
ln /usr/local/etcd-${ETCD_VER}-linux-amd64/etcdctl  /usr/local/bin/etcdctl
etcd --version
etcdctl version
```

## 初始化etcd集群
在每个台机器上设置etcd集群成员参数：

```yaml
TOKEN=cr7-etcd
CLUSTER_STATE=new
NAME_1=etcd1
NAME_2=etcd2
NAME_3=etcd3
HOST_1=192.168.1.91
HOST_2=192.168.1.92
HOST_3=192.168.1.93
CLUSTER=${NAME_1}=http://${HOST_1}:2380,${NAME_2}=http://${HOST_2}:2380,${NAME_3}=http://${HOST_3}:2380
```
分别在每台机器上运行初始化ectd集群，初始化成功后会在运行该命令的目录下生成data.etcd目录，用于存放etcd节点相关信息，只要该目录存在，停止后可以重新用该命令启动：

```yaml
# etcd1
THIS_NAME=${NAME_1}
THIS_IP=${HOST_1}
etcd --data-dir=data.etcd --name ${THIS_NAME} \
	--initial-advertise-peer-urls http://${THIS_IP}:2380 --listen-peer-urls http://${THIS_IP}:2380 \
	--advertise-client-urls http://${THIS_IP}:2379 --listen-client-urls http://${THIS_IP}:2379 \
	--initial-cluster ${CLUSTER} \
	--initial-cluster-state ${CLUSTER_STATE} --initial-cluster-token ${TOKEN}

# etcd2
THIS_NAME=${NAME_2}
THIS_IP=${HOST_2}
etcd --data-dir=data.etcd --name ${THIS_NAME} \
	--initial-advertise-peer-urls http://${THIS_IP}:2380 --listen-peer-urls http://${THIS_IP}:2380 \
	--advertise-client-urls http://${THIS_IP}:2379 --listen-client-urls http://${THIS_IP}:2379 \
	--initial-cluster ${CLUSTER} \
	--initial-cluster-state ${CLUSTER_STATE} --initial-cluster-token ${TOKEN}

# etcd3
THIS_NAME=${NAME_3}
THIS_IP=${HOST_3}
etcd --data-dir=data.etcd --name ${THIS_NAME} \
	--initial-advertise-peer-urls http://${THIS_IP}:2380 --listen-peer-urls http://${THIS_IP}:2380 \
	--advertise-client-urls http://${THIS_IP}:2379 --listen-client-urls http://${THIS_IP}:2379 \
	--initial-cluster ${CLUSTER} \
	--initial-cluster-state ${CLUSTER_STATE} --initial-cluster-token ${TOKEN}
```
后台启动可以加上：

```sh
nohup .... 2>&1 & 
```

参数说明：
* 默认2379端口是给client连接用的，而2380则在etcd集群各个节点之间交互用的。
* **--name**：etcd 集群中的节点名，这里可以随意，方便区分且不重复即可。
* **--listen-peer-urls**：监听用于节点之间通信的url，可监听多个，集群内部将通过这些url进行数据交互(如选举、数据同步等)。
* **--initial-advertise-peer-urls**：建议用于节点之间通信的 url，节点间将以该值进行通信。
* **--listen-client-urls**：监听用于客户端通信的url，同样可以监听多个。
* **--advertise-client-urls**：建议使用的客户端通信url，该值用于etcd代理或etcd成员与etcd节点通信。
* **--initial-cluster-token**：节点的token值，设置该值后集群将生成唯一ID，并为每个节点也生成唯一ID。当使用相同配置文件再启动一个集群时，只要该token值不一样，etcd集群就不会相互影响。
* **--initial-cluster**：集群中所有的 initial-advertise-peer-urls的合集。
* **--initial-cluster-state**：new，新建集群的标志。existing标识新加点加入集群。

## 环境变量设置
编辑/etc/profile，将etcd集群成员参数写入环境变量：

```sh
export ETCDCTL_API=3
HOST_1=192.168.1.91
HOST_2=192.168.1.92
HOST_3=192.168.1.93
export ENDPOINTS=$HOST_1:2379,$HOST_2:2379,$HOST_3:2379

#编辑完成后
source /etc/profile
```

## 检查etcd集群状态

```yaml
#查看etcd集群成员
[root@etcd1 ~]# etcdctl --endpoints=$ENDPOINTS member list  --write-out=table
+------------------+---------+-------+--------------------------+--------------------------+------------+
|        ID        | STATUS  | NAME  |        PEER ADDRS        |       CLIENT ADDRS       | IS LEARNER |
+------------------+---------+-------+--------------------------+--------------------------+------------+
| 597745dd5a1f190a | started | etcd3 | http://192.168.1.93:2380 | http://192.168.1.93:2379 |      false |
| 6a3e67577dbd3de0 | started | etcd2 | http://192.168.1.92:2380 | http://192.168.1.92:2379 |      false |
| d2b20b971efea8ef | started | etcd1 | http://192.168.1.91:2380 | http://192.168.1.91:2379 |      false |
+------------------+---------+-------+--------------------------+--------------------------+------------+

#检查集群健康状态
[root@etcd1 ~]# etcdctl endpoint health --cluster --endpoints=$ENDPOINTS
http://192.168.1.91:2379 is healthy: successfully committed proposal: took = 7.289365ms
http://192.168.1.92:2379 is healthy: successfully committed proposal: took = 13.173445ms
http://192.168.1.93:2379 is healthy: successfully committed proposal: took = 14.812638ms

#查看集群详细状态
[root@etcd1 ~]# etcdctl --write-out=table --endpoints=$ENDPOINTS endpoint status
+-------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|     ENDPOINT      |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+-------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| 192.168.1.91:2379 | d2b20b971efea8ef |   3.4.4 |   25 kB |     false |      false |         8 |         64 |                 64 |        |
| 192.168.1.92:2379 | 6a3e67577dbd3de0 |   3.4.4 |   25 kB |      true |      false |         8 |         64 |                 64 |        |
| 192.168.1.93:2379 | 597745dd5a1f190a |   3.4.4 |   25 kB |     false |      false |         8 |         64 |                 64 |        |
+-------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
```

## 写入数据

```sh
etcdctl --endpoints=$ENDPOINTS put foo "Hello World"
```
## 读取数据

```sh
[root@etcd1 ~]# etcdctl --endpoints=$ENDPOINTS get foo
foo
Hello World
```
通过前缀获取数据：

```sh
#分别插入web1，web2，web3 三条数据
[root@etcd1 ~]# etcdctl --endpoints=$ENDPOINTS put web1 value1
OK
[root@etcd1 ~]# etcdctl --endpoints=$ENDPOINTS put web2 value2
OK
[root@etcd1 ~]# etcdctl --endpoints=$ENDPOINTS put web3 value3
OK

#通过web前缀获取这三条数据
[root@etcd1 ~]# etcdctl --endpoints=$ENDPOINTS get web --prefix
web1
value1
web2
value2
web3
value3
```

## 删除数据

```sh
[root@etcd1 ~]# etcdctl --endpoints=$ENDPOINTS  del foo
1 #删除了1条数据
[root@etcd1 ~]# etcdctl --endpoints=$ENDPOINTS  del web --prefix
3 #删除了3条数据
```

## 事务写入

```sh
#先插入一条数据
[root@etcd1 ~]# etcdctl --endpoints=$ENDPOINTS put user1 bad
OK

#开启事务
[root@etcd1 ~]# etcdctl --endpoints=$ENDPOINTS txn --interactive

#输入判断条件，两次回车
compares:
value("user1") = "good"

#如果user1 = good，则执行del user1
success requests (get, put, del):
del user1

#如果user1 != good，则执行put user1 verygood
failure requests (get, put, del):
put user1 verygood

FAILURE

OK

#由于user1原先不等于good，所以执行put user1 verygood
[root@etcd1 ~]# etcdctl --endpoints=$ENDPOINTS get user1
user1
verygood  #现在user1的值已经被改为verygood
```

## 监听
watch用于获取监听信息的更改，并且支持持续地监听。
在窗口1开启监听：

```sh
[root@etcd1 ~]# etcdctl --endpoints=$ENDPOINTS watch 
```
另外开启一个窗口2写入数据：

```sh
etcdctl --endpoints=$ENDPOINTS put stock1 1000
```
此时窗口1会收到更新信息：
```sh
stock1
PUT
stock1
1000
```
也支持前缀监听：

```sh
etcdctl --endpoints=$ENDPOINTS watch stock --prefix
etcdctl --endpoints=$ENDPOINTS put stock1 10
etcdctl --endpoints=$ENDPOINTS put stock2 20
```
## 租约
lease用于设置key的TTL时间。
```sh
etcdctl --endpoints=$ENDPOINTS lease grant 300
# lease 2be7547fbc6a5afa granted with TTL(300s)

#创建数据，并指定lease
etcdctl --endpoints=$ENDPOINTS put sample value --lease=2be7547fbc6a5afa
#此时还可以获取到数据
etcdctl --endpoints=$ENDPOINTS get sample

#重置租约时间到原先指定的300s，会重复刷新
etcdctl --endpoints=$ENDPOINTS lease keep-alive 2be7547fbc6a5afa

#立即释放
etcdctl --endpoints=$ENDPOINTS lease revoke 2be7547fbc6a5afa

#租约到期或者直接revoke，就获取不到这个key了
etcdctl --endpoints=$ENDPOINTS get sample
```

## 分布式锁
窗口1给key1加锁：
```sh
[root@etcd1 ~]# etcdctl --endpoints=$ENDPOINTS lock key1
key1/28ef77fb1b464b49
```
窗口2也想给key1加锁，此时会卡住，直到窗口1释放锁以后，窗口2才能给key1加锁：

```sh
[root@etcd1 ~]# etcdctl --endpoints=$ENDPOINTS lock key1


```

## 快照
snapshot只能指定其中一个etcd节点：
```sh
[root@etcd1 snap]# ENDPOINTS=$HOST_1:2379
[root@etcd1 snap]# etcdctl --endpoints=$ENDPOINTS snapshot save my.db
{"level":"info","ts":1614828932.1646311,"caller":"snapshot/v3_snapshot.go:110","msg":"created temporary db file","path":"my.db.part"}
{"level":"info","ts":1614828932.166052,"caller":"snapshot/v3_snapshot.go:121","msg":"fetching snapshot","endpoint":"192.168.1.91:2379"}
{"level":"info","ts":1614828932.1835077,"caller":"snapshot/v3_snapshot.go:134","msg":"fetched snapshot","endpoint":"192.168.1.91:2379","took":0.018725853}
{"level":"info","ts":1614828932.1836193,"caller":"snapshot/v3_snapshot.go:143","msg":"saved","path":"my.db"}
Snapshot saved at my.db

#快照存放在data.etcd/member/snap
[root@etcd1 snap]# ls
db  my.db
[root@etcd1 snap]# etcdctl --write-out=table --endpoints=$ENDPOINTS snapshot status my.db
+----------+----------+------------+------------+
|   HASH   | REVISION | TOTAL KEYS | TOTAL SIZE |
+----------+----------+------------+------------+
| 4c02b18b |       36 |         44 |      25 kB |
+----------+----------+------------+------------+
```
## 添加&删除成员
删除老成员，添加新成员（在原先etcd节点上操作）：
```sh
# 获取成员ID
export ETCDCTL_API=3
HOST_1=192.168.1.91
HOST_2=192.168.1.92
HOST_3=192.168.1.93
etcdctl --endpoints=${HOST_1}:2379,${HOST_2}:2379,${HOST_3}:2379 member list

# 移除成员
MEMBER_ID=278c654c9a6dfd3b #移除node3
etcdctl --endpoints=${HOST_1}:2379,${HOST_2}:2379,${HOST_3}:2379 \
	member remove ${MEMBER_ID}

# 添加新成员 (etcd4)
export ETCDCTL_API=3
NAME_1=etcd-node-1
NAME_2=etcd-node-2
NAME_4=etcd-node-4
HOST_1=192.168.1.91
HOST_2=192.168.1.92
HOST_4=192.168.1.94 # new member
etcdctl --endpoints=${HOST_1}:2379,${HOST_2}:2379 \
	member add ${NAME_4} \
	--peer-urls=http://${HOST_4}:2380
```
在新etcd节点操作：
```sh
#如果新成员在相同的磁盘上启动，确保移除data目录
TOKEN=cr7-etcd
CLUSTER_STATE=existing  #加入新集群
NAME_1=etcd1
NAME_2=etcd2
NAME_4=etcd4
HOST_1=192.168.1.91
HOST_2=192.168.1.92
HOST_4=192.168.1.94 # new member
CLUSTER=${NAME_1}=http://${HOST_1}:2380,${NAME_2}=http://${HOST_2}:2380,${NAME_4}=http://${HOST_4}:2380

THIS_NAME=${NAME_4}
THIS_IP=${HOST_4}
etcd --data-dir=data.etcd --name ${THIS_NAME} \
	--initial-advertise-peer-urls http://${THIS_IP}:2380 \
	--listen-peer-urls http://${THIS_IP}:2380 \
	--advertise-client-urls http://${THIS_IP}:2379 \
	--listen-client-urls http://${THIS_IP}:2379 \
	--initial-cluster ${CLUSTER} \
	--initial-cluster-state ${CLUSTER_STATE} \
	--initial-cluster-token ${TOKEN}
```

## 认证
root 是 etcd 的超级管理员，拥有 etcd 的所有权限，在开启角色认证之前为们必须要先建立好 root 用户。还需要注意的是 root 用户必须拥有 root 的角色,允许在 etcd 的所有操作。（有一个特殊用户root，一个特殊角色root。）
```sh
#创建root用户，root用户自动有最高root权限
[root@etcd1 ~]# etcdctl  --endpoints=$ENDPOINTS user add root
#设置密码123456
Password of root: 
Type password of root again for confirmation: 
User root created

#创建一个普通权限，可以对foo这key进行读写操作
#创建一个role
[root@etcd1 ~]# etcdctl --endpoints=${ENDPOINTS} role add user1-role
Role user1-role created
#给role赋予权限
[root@etcd1 ~]# etcdctl --endpoints=${ENDPOINTS} role grant-permission user1-role  readwrite foo
Role user1-role updated
#查看创建的role
[root@etcd1 ~]# etcdctl --endpoints=${ENDPOINTS} role get user1-role
Role user1-role
KV Read:
        foo
KV Write:
        foo
        
#创建用户并关联权限
[root@etcd1 ~]# etcdctl --endpoints=${ENDPOINTS} user add user1
#设置密码123
Password of user1: 
Type password of user1 again for confirmation: 
User user1 created
#将user1-role的权限关联到user1
[root@etcd1 ~]# etcdctl --endpoints=${ENDPOINTS} user grant-role user1 user1-role
Role user1-role is granted to user user1

#启用认证
[root@etcd1 ~]# etcdctl --endpoints=${ENDPOINTS} auth enable
Authentication Enabled

#此时不指定用户将无法进行任何操作
[root@etcd1 ~]# etcdctl --endpoints=${ENDPOINTS} put foo bar
{"level":"warn","ts":"2021-03-04T22:53:30.740+0800","caller":"clientv3/retry_interceptor.go:61","msg":"retrying of unary invoker failed","target":"endpoint://client-b379b941-6eec-46a3-87ac-76417ae9ea5f/192.168.1.91:2379","attempt":0,"error":"rpc error: code = InvalidArgument desc = etcdserver: user name is empty"}
Error: etcdserver: user name is empty

#使用用户user1可以对foo进行读写操作
[root@etcd1 ~]# etcdctl --endpoints=${ENDPOINTS} put foo bar --user=user1:123
OK
[root@etcd1 ~]# etcdctl --endpoints=${ENDPOINTS} get foo --user=user1:123
foo
bar
#但是user1无法对其他key进行操作
[root@etcd1 ~]# etcdctl --endpoints=${ENDPOINTS} put foo2 bar2 --user=user1:123
{"level":"warn","ts":"2021-03-04T22:53:57.474+0800","caller":"clientv3/retry_interceptor.go:61","msg":"retrying of unary invoker failed","target":"endpoint://client-f67861bf-ce78-48b2-90a6-1f91ce508936/192.168.1.91:2379","attempt":0,"error":"rpc error: code = PermissionDenied desc = etcdserver: permission denied"}
Error: etcdserver: permission denied

#使用root用户关闭认证
[root@etcd1 ~]# etcdctl --endpoints=${ENDPOINTS} auth disable --user=root:123456
Authentication Disabled
```