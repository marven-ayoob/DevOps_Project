provider "aws" {
  region = "us-east-1"
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_security_group" "allow_ssh_http" {
  name        = "allow_ssh_http"
  description = "Allow SSH and HTTP inbound traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "master" {
  ami                         = "ami-0c02fb55956c7d316"  # Ubuntu 22.04 LTS (تأكد من الأمين في منطقتك)
  instance_type               = "t3.medium"
  key_name                   = aws_key_pair.deployer.key_name
  security_groups            = [aws_security_group.allow_ssh_http.name]
  associate_public_ip_address = true

  tags = {
    Name = "k8s-master"
  }
}

# ملف انفينتوري للأنسبل يتكتب تلقائيًا
resource "local_file" "inventory" {
  content = <<-EOT
    [k8s-master]
    ${aws_instance.master.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa ansible_ssh_common_args='-o StrictHostKeyChecking=no'
  EOT

  filename = "./inventory.ini"
  depends_on = [aws_instance.master]
}

# تشغل أنسبل بعد ما يخلص انشاء الانستانس وكتابة ملف الانفينتوري
resource "null_resource" "run_ansible" {
  depends_on = [
    aws_instance.master,
    local_file.inventory
  ]

  provisioner "local-exec" {
    command = "ansible-playbook -i ./inventory.ini your_playbook.yml"
  }
}

output "ec2_public_ip" {
  value = aws_instance.master.public_ip
}
