# opa run (interactive)

```sh
#加载 data 文件
❯ opa run input.json
OPA 0.30.1 (commit 03b0b1f, built at 2021-07-02T09:53:49Z)

Run 'help' to see a list of commands and check for updates.

#取值
> data.servers[0].protocols[1]
"ssh"
> net := data.networks[_]; net.public
+-----------------------------+
|             net             |
+-----------------------------+
| {"id":"net3","public":true} |
| {"id":"net4","public":true} |
+-----------------------------+
```

# opa run (server)

默认情况下， OPA 服务监听 HTTP 0.0.0.0:8181。

```sh
opa run --server ./example.rego
```

分别请求 violation 和 allow 接口：

```sh

❯ curl localhost:8181/v1/data/example/violation -d @v1-data-input.json -H 'Content-Type: application/json'
{"result":[]}                                                                                                           
#如果没有 violation 满足才会返回 true                                                    
❯ curl localhost:8181/v1/data/example/allow -d @v1-data-input.json -H 'Content-Type: application/json'
{"result":true}%    
```