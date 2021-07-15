# Gatekeeper

## 安装 Gatekeeper

```sh
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm install gatekeeper gatekeeper/gatekeeper -n cloudnative-lab
```

查看 gatekeeper

```sh
❯ kgp -n cloudnative-lab
NAME                                             READY   STATUS    RESTARTS   AGE
gatekeeper-audit-557cf8dc74-qs2b9                1/1     Running   0          46s
gatekeeper-controller-manager-5f49449b8f-2lzcv   1/1     Running   0          46s
gatekeeper-controller-manager-5f49449b8f-d7rbg   1/1     Running   0          46s
gatekeeper-controller-manager-5f49449b8f-sw62r   1/1     Running   0          46s
```

## Constraint Templates

在定义 Constraint 之前，您需要创建一个 Constraint Template，允许声明新的 Constraint。Constraint 是由 ConstraintTemplate 这个 CRD 的描述再次由 Gatekeeper 生成的 CRD（即通过 CRD 再生成 CRD）。

```yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
      validation:
        # Schema for the `parameters` field
        openAPIV3Schema:
          properties:
            labels:
              type: array
              items: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredlabels

        violation[{"msg": msg, "details": {"missing_labels": missing}}] {
          provided := {label | input.review.object.metadata.labels[label]}
          required := {label | label := input.parameters.labels[_]}
          missing := required - provided
          count(missing) > 0
          msg := sprintf("you must provide labels: %v", [missing])
        }
```
应用 Constraint Template：

```sh
kubectl apply -f ConstraintTemplate.yaml
```

应用 Constraint Template 后，会生成新的 k8srequiredlabels CRD 对象：

```sh
❯ kubectl get crd k8srequiredlabels.constraints.gatekeeper.sh
NAME                                          CREATED AT
k8srequiredlabels.constraints.gatekeeper.sh   2021-07-15T07:26:35Z
```

## Constraints

在集群中部署了 Constraint Template 后，现在可以创建由 Constraint Template 定义的单个 Constraint CRD。例如，这里以下是一个 Constraint CRD，要求标签 gatekeeper 出现在所有命名空间上。

```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: ns-must-have-gk
spec:
  #match 字段定义了约束的对象范围。
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Namespace"]
  parameters:
    labels: ["gatekeeper"]
```

应用 Constraints：

```sh
kubectl apply -f Constraints.yaml
```

## 验证

直接创建 namespace 资源对象会报错：

```sh
❯ kubectl create ns test-ns
Error from server ([ns-must-have-gk] you must provide labels: {"gatekeeper"}): admission webhook "validation.gatekeeper.sh" denied the request: [ns-must-have-gk] you must provide labels: {"gatekeeper"}
```

可以成功创建含有 gatekeeper 标签的 namespace：

```sh
❯ cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: test-ns
  labels:
    gatekeeper: good
EOF
#返回结果
namespace/test-ns created
```