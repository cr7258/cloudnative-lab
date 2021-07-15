## Kafka

本例展示如何对 Kafka 的 Topic 实施细粒度的访问控制：

创建一个目录，用于存放 OPA 策略：

```sh
mkdir -p policies
```

创建 OPA 策略：

vim policies/tutorial.rego：

```yaml
#-----------------------------------------------------------------------------
# High level policy for controlling access to Kafka.
#
# * Deny operations by default.
# * Allow operations if no explicit denial.
#
# The kafka-authorizer-opa plugin will query OPA for decisions at
# /kafka/authz/allow. If the policy decision is _true_ the request is allowed.
# If the policy decision is _false_ the request is denied.
#-----------------------------------------------------------------------------
package kafka.authz

default allow = false

allow {
     not deny
}

#限制消费消息
deny {
     is_read_operation
     topic_contains_pii
     not consumer_is_whitelisted_for_pii
}

#限制生产消息
deny {
  is_write_operation
  topic_has_large_fanout
  not producer_is_whitelisted_for_large_fanout
}

#-----------------------------------------------------------------------------
# Data structures for controlling access to topics. In real-world deployments,
# these data structures could be loaded into OPA as raw JSON data. The JSON
# data could be pulled from external sources like AD, Git, etc.
#-----------------------------------------------------------------------------

consumer_whitelist = {
  "pii": {
     "pii_consumer"
   }
}

producer_whitelist = {
  "large-fanout": {
    "fanout_producer",
  }
}

topic_metadata = {
  "click-stream": {
    "tags": ["large-fanout"],
  },
  "credit-scores": {
    "tags": ["pii"],
  }
}

#-----------------------------------
# Helpers for checking topic access.
#-----------------------------------

topic_contains_pii {
	topic_metadata[topic_name].tags[_] == "pii"
}

consumer_is_whitelisted_for_pii {
	consumer_whitelist.pii[_] == principal.name
}

topic_has_large_fanout {
  topic_metadata[topic_name].tags[_] == "large-fanout"
}

producer_is_whitelisted_for_large_fanout {
  producer_whitelist["large-fanout"][_] == principal.name
}

#-----------------------------------------------------------------------------
# Helpers for processing Kafka operation input. This logic could be split out
# into a separate file and shared. For conciseness, we have kept it all in one
# place.
#-----------------------------------------------------------------------------

is_write_operation {
    input.operation.name == "Write"
}

is_read_operation {
	input.operation.name == "Read"
}

is_topic_resource {
	input.resource.resourceType.name == "Topic"
}

topic_name = input.resource.name {
	is_topic_resource
}

principal = {"fqn": parsed.CN, "name": cn_parts[0]} {
	parsed := parse_user(urlquery.decode(input.session.sanitizedUser))
	cn_parts := split(parsed.CN, ".")
}

parse_user(user) = {key: value |
	parts := split(user, ",")
	[key, value] := split(parts[_], "=")
}
```

创建 docker-compose.yml 文件：

policy 目录挂载在 OPA 容器中，当该文件发送改变时，OPA 容器会自动重新加载策略。

```yaml
version: "2"
services:
  opa:
    hostname: opa
    image: openpolicyagent/opa:0.30.2
    ports:
      - 8181:8181
    # WARNING: OPA is NOT running with an authorization policy configured. This
    # means that clients can read and write policies in OPA. If you are deploying
    # OPA in an insecure environment, you should configure authentication and
    # authorization on the daemon. See the Security page for details:
    # https://www.openpolicyagent.org/docs/security.html.
    command: "run --server --watch /policies"
    volumes:
      - ./policies:/policies
  zookeeper:
    image: confluentinc/cp-zookeeper:4.0.0-3
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      zk_id: "1"
  kafka:
    hostname: kafka
    image: openpolicyagent/demo-kafka:1.0
    links:
      - zookeeper
      - opa
    ports:
      - "9092:9092"
    environment:
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: "1"
      KAFKA_ZOOKEEPER_CONNECT: "zookeeper:2181"
      KAFKA_ADVERTISED_LISTENERS: "SSL://:9093"
      KAFKA_SECURITY_INTER_BROKER_PROTOCOL: SSL
      KAFKA_SSL_CLIENT_AUTH: required
      KAFKA_SSL_KEYSTORE_FILENAME: kafka.broker.keystore.jks
      KAFKA_SSL_KEYSTORE_CREDENTIALS: broker_keystore_creds
      KAFKA_SSL_KEY_CREDENTIALS: broker_sslkey_creds
      KAFKA_SSL_TRUSTSTORE_FILENAME: kafka.broker.truststore.jks
      KAFKA_SSL_TRUSTSTORE_CREDENTIALS: broker_truststore_creds
      KAFKA_AUTHORIZER_CLASS_NAME: com.lbg.kafka.opa.OpaAuthorizer
      KAFKA_OPA_AUTHORIZER_URL: "http://opa:8181/v1/data/kafka/authz/allow"
      KAFKA_OPA_AUTHORIZER_ALLOW_ON_ERROR: "false"
      KAFKA_OPA_AUTHORIZER_CACHE_INITIAL_CAPACITY: 100
      KAFKA_OPA_AUTHORIZER_CACHE_MAXIMUM_SIZE: 100
      KAFKA_OPA_AUTHORIZER_CACHE_EXPIRE_AFTER_MS: 600000
```

启动 docker compose：
```sh
docker-compose --project-name opa-kafka-tutorial up
```

上面定义的 Docker Compose 文件要求 对连接到代理的客户端进行SSL 客户端身份验证。启用 SSL 客户端身份验证允许将服务身份作为策略的输入提供。下面的示例显示了输入结构。

```json
{
  "operation": {
    "name": "Write"
  },
  "resource": {
    "resourceType": {
      "name": "Topic"
    },
    "name": "credit-scores"
  },
  "session": {
    "principal": {
      "principalType": "User"
    },
    "clientAddress": "172.21.0.5",
    "sanitizedUser": "CN%3Danon_producer.tutorial.openpolicyagent.org%2COU%3DTUTORIAL%2CO%3DOPA%2CL%3DSF%2CST%3DCA%2CC%3DUS"
  }
}
```

客户端身份是从客户端连接到代理时提供的 SSL 证书中提取的。客户端身份信息在input.session.sanitizedUser字段中编码。该字段可以在策略内解码。

### 限制消费消息

首先运行 kafka-console-producer 指令往 credit-scores Topic 生产 10 条消息，：

```sh
docker run --rm --network opa-kafka-tutorial_default \
    openpolicyagent/demo-kafka:1.0 \
    bash -c 'for i in {1..10}; do echo "{\"user\": \"bob\", \"score\": $i}"; done | kafka-console-producer --topic credit-scores --broker-list kafka:9093 -producer.config /etc/kafka/secrets/anon_producer.ssl.config'
```

然后运行 kafka-console-consumer 指令消费 credit-scores Topic 中的消息，带上 pii_consumer 凭证，可以成功消费消息：

```sh
❯ docker run --rm --network opa-kafka-tutorial_default  \
    openpolicyagent/demo-kafka:1.0 \
    kafka-console-consumer --bootstrap-server kafka:9093 --topic credit-scores --from-beginning --consumer.config /etc/kafka/secrets/pii_consumer.ssl.config
#返回结果
{"user": "bob", "score": 1}
{"user": "bob", "score": 2}
{"user": "bob", "score": 3}
{"user": "bob", "score": 4}
{"user": "bob", "score": 5}
{"user": "bob", "score": 6}
{"user": "bob", "score": 7}
{"user": "bob", "score": 8}
{"user": "bob", "score": 9}
{"user": "bob", "score": 10}
```

如果使用 anon_consumer 凭证就无法消费消息了，会提示没有授权：
```sh
❯ docker run --rm --network opa-kafka-tutorial_default \
    openpolicyagent/demo-kafka:1.0 \
    kafka-console-consumer --bootstrap-server kafka:9093 --topic credit-scores --from-beginning --consumer.config /etc/kafka/secrets/anon_consumer.ssl.config
#返回结果
[2021-07-15 04:35:47,028] WARN [Consumer clientId=consumer-1, groupId=console-consumer-29011] Not authorized to read from topic credit-scores. (org.apache.kafka.clients.consumer.internals.Fetcher)
[2021-07-15 04:35:47,031] ERROR Error processing message, terminating consumer process:  (kafka.tools.ConsoleConsumer$)
org.apache.kafka.common.errors.TopicAuthorizationException: Not authorized to access topics: [credit-scores]
[2021-07-15 04:35:47,044] ERROR [Consumer clientId=consumer-1, groupId=console-consumer-29011] Offset commit failed on partition credit-scores-0 at offset 0: Not authorized to access topics: [Topic authorization failed.] (org.apache.kafka.clients.consumer.internals.ConsumerCoordinator)
[2021-07-15 04:35:47,044] ERROR [Consumer clientId=consumer-1, groupId=console-consumer-29011] Not authorized to commit to topics [credit-scores] (org.apache.kafka.clients.consumer.internals.ConsumerCoordinator)
[2021-07-15 04:35:47,044] WARN [Consumer clientId=consumer-1, groupId=console-consumer-29011] Synchronous auto-commit of offsets {credit-scores-0=OffsetAndMetadata{offset=0, metadata=''}} failed: Not authorized to access topics: [credit-scores] (org.apache.kafka.clients.consumer.internals.ConsumerCoordinator)
Processed a total of 0 messages
```

### 限制生产消息

运行 kafka-console-producer 指令往 click-stream Topic 生产 10 条消息，带上 fanout_producer 凭证可以成功生产消息：

```sh
docker run --rm --network opa-kafka-tutorial_default \
    openpolicyagent/demo-kafka:1.0 \
    bash -c 'for i in {1..10}; do echo "{\"user\": \"alice\", \"button\": $i}"; done | kafka-console-producer --topic click-stream --broker-list kafka:9093 -producer.config /etc/kafka/secrets/fanout_producer.ssl.config'
```

接着运行 kafka-console-consumer 指令消费消息：

```sh
❯ docker run --rm --network opa-kafka-tutorial_default \
    openpolicyagent/demo-kafka:1.0 \
    kafka-console-consumer --bootstrap-server kafka:9093 --topic click-stream --from-beginning --consumer.config /etc/kafka/secrets/anon_consumer.ssl.config
#返回结果
{"user": "alice", "button": "bogus"}
{"user": "alice", "button": "bogus"}
{"user": "alice", "button": 1}
{"user": "alice", "button": 2}
{"user": "alice", "button": 3}
{"user": "alice", "button": 4}
{"user": "alice", "button": 5}
{"user": "alice", "button": 6}
{"user": "alice", "button": 7}
{"user": "alice", "button": 8}
{"user": "alice", "button": 9}
{"user": "alice", "button": 10}
```

如果 producer 使用 anon_producer 凭证就无法往 click-stream Topic 生产消息了。

```sh
❯ docker run --rm --network opa-kafka-tutorial_default \
    openpolicyagent/demo-kafka:1.0 \
    bash -c 'echo "{\"user\": \"alice\", \"button\": \"bogus\"}" | kafka-console-producer --topic click-stream --broker-list kafka:9093 -producer.config /etc/kafka/secrets/anon_producer.ssl.config'
#返回结果
>>[2021-07-15 04:50:49,138] ERROR Error when sending message to topic click-stream with key: null, value: 36 bytes with error: (org.apache.kafka.clients.producer.internals.ErrorLoggingCallback)
org.apache.kafka.common.errors.TopicAuthorizationException: Not authorized to access topics: [click-stream]
```