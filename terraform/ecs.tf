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