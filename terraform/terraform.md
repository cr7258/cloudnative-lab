# Terraform

HashiCorp Terraform 是一个IT基础架构自动化编排工具，可以用代码来管理维护 IT 资源。Terraform的命令行接口（CLI）提供一种简单机制，用于将配置文件部署到阿里云或其他任意支持的云上，并对其进行版本控制。它编写了描述云资源拓扑的配置文件中的基础结构，例如虚拟机、存储帐户和网络接口。

Terraform是一个高度可扩展的工具，通过 Provider 来支持新的基础架构。Terraform能够让您在阿里云上轻松使用 简单模板语言 来定义、预览和部署云基础结构。您可以使用Terraform来创建、修改、删除ECS、VPC、RDS、SLB等多种资源。


## 安装和配置Terraform

### 在Cloud Shell中使用Terraform
阿里云Cloud Shell是一款帮助您运维的免费产品，预装了Terraform的组件，并配置好身份凭证（credentials）。因此您可直接在Cloud Shell中运行Terraform的命令。

打开浏览器，访问Cloud Shell的地址https://shell.aliyun.com。
![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210308202728.png)

### 在本地安装和配置Terraform
登录 [Terraform官网](https://www.terraform.io/downloads.html?spm=a2c4g.11186623.2.4.114816f2pdJJkW) 下载并安装适用于您的操作系统的程序包。

命令运行后将显示可用的Terraform选项的列表，如下所示，表示安装完成。

```sh
username:~$ terraform
Usage: terraform [-version] [-help] <command> [args]
```
创建环境变量，用于存放身份认证信息。
```sh
export ALICLOUD_ACCESS_KEY="LTAIUrZCw3********"
export ALICLOUD_SECRET_KEY="zfwwWAMWIAiooj14GQ2*************"
export ALICLOUD_REGION="cn-beijing"
```

## 编写terraform脚本
这里选择在Cloud Shell中使用Terraform，创建相关目录：

```sh
mkdir /home/shell/terraform_ecs
cd /home/shell/terraform_ecs
```
terraform脚本如下：
```sh
variable "profile" {
  default = "default"
}

#Region
variable "region" {
  default = "cn-shanghai"
}

#将公钥拷贝到ECS上
locals {
  user_data_ecs = <<TEOF
#!/bin/bash
cp ~/.ssh/authorized_keys /root/.ssh
TEOF
}

provider "alicloud" {
  region  = var.region
  profile = var.profile
}

#VPC
module "vpc" {
  source  = "alibaba/vpc/alicloud"
  region  = var.region
  profile = var.profile
  vpc_name = "ecs_terraform"
  vpc_cidr          = "10.10.0.0/16"
  availability_zones = ["cn-shanghai-b"]
  vswitch_cidrs      = ["10.10.1.0/24"]
}

#安全组
module "security_group" {
  source  = "alibaba/security-group/alicloud"
  profile = var.profile
  region  = var.region
  vpc_id  = module.vpc.this_vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_ports = [22]

  ingress_with_cidr_blocks_and_ports = [
    {
      protocol    = "tcp"
      priority    = 1
      description = "ingress for ssh"
    }
  ]
}

#ECS
module "ecs" {
  source  = "alibaba/ecs-instance/alicloud"
  profile = var.profile
  region  = var.region
  internet_max_bandwidth_out  = 1
  associate_public_ip_address = true

  name                        = "terraform_ecs"
  image_id                    = "centos_7_9_x64_20G_alibase_20201228.vhd"
  instance_type               = "ecs.t5-c1m2.xlarge"  #实例规格
  vswitch_id                  = module.vpc.this_vswitch_ids.0
  security_group_ids          = [module.security_group.this_security_group_id]

  system_disk_size     = 30
  number_of_instances = 3  #实例数量

  user_data = local.user_data_ecs
}

#设置本地~/.ssh/config的ssh信息
resource "local_file" "ssh_config" {
    content     = <<EOF
%{ for ip in module.ecs.this_public_ip }
Host ecs${index(module.ecs.this_public_ip, ip) + 1}
    StrictHostKeyChecking no
    HostName ${ip}
    User terraform
%{ endfor }
EOF
    filename = "/home/shell/.ssh/config"
}

#屏幕输出提示信息
resource "local_file" "info" {
    content     =  <<EOF
登录服务器：
%{ for ip in module.ecs.this_public_ip }
ssh root@ecs${index(module.ecs.this_public_ip, ip) + 1}%{ endfor }

公网 IP 地址（用于 ssh 登陆）：
%{ for ip in module.ecs.this_public_ip }
ecs${index(module.ecs.this_public_ip, ip) + 1}:    ${ip}%{ endfor }

内网 IP 地址（用于集群内部通信，没有端口限制）：
%{ for ip in module.ecs.this_private_ip }
ecs${index(module.ecs.this_private_ip, ip) + 1}:    ${ip}%{ endfor }

销毁服务器:
cd /home/shell/terraform_ecs
terraform destroy --auto-approve
EOF
    filename = "/home/shell/terraform_ecs/readme.txt"
}

output "服务器信息" {
   value = <<EOF

登录服务器：
%{ for ip in module.ecs.this_public_ip }
ssh root@ecs${index(module.ecs.this_public_ip, ip) + 1}%{ endfor }

公网 IP 地址（用于 ssh 登录）：
%{ for ip in module.ecs.this_public_ip }
ecs${index(module.ecs.this_public_ip, ip) + 1}:    ${ip}%{ endfor }

内网 IP 地址（用于集群内部通信，没有端口限制）：
%{ for ip in module.ecs.this_private_ip }
ecs${index(module.ecs.this_private_ip, ip) + 1}:    ${ip}%{ endfor }

销毁服务器:
cd /home/shell/terraform_ecs
terraform destroy --auto-approve

查看以上信息:
cat /home/shell/terraform_ecs/readme.txt

EOF
}
```
运行以下命令启动ECS：

```sh
terraform init #安装相关module
terraform apply --auto-approve #创建ECS
```
创建成功后会有如下输出：
```sh
Apply complete! Resources: 11 added, 0 changed, 0 destroyed.

Outputs:

服务器信息 = 
登录服务器：

ssh root@ecs1
ssh root@ecs2
ssh root@ecs3

公网 IP 地址（用于 ssh 登录）：

ecs1:    47.117.170.15
ecs2:    47.117.172.214
ecs3:    47.117.152.20

内网 IP 地址（用于集群内部通信，没有端口限制）：

ecs1:    10.10.1.151
ecs2:    10.10.1.152
ecs3:    10.10.1.153

销毁服务器:
cd /home/shell/terraform_ecs
terraform destroy --auto-approve

查看以上信息:
cat /home/shell/terraform_ecs/readme.txt
```
查看创建好的ECS：

![](https://chengzw258.oss-cn-beijing.aliyuncs.com/Article/20210308203419.png)

登录ECS：

```sh
#脚本已经将在Cloud shell的公钥传到ECS上了，并且在~/.ssh/config配置了登录信息
ssh root@ecs1
```

官方文档：
* https://registry.terraform.io/providers/aliyun/alicloud/latest/docs
* https://github.com/terraform-alicloud-modules