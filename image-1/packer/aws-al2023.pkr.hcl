# plugin
packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.5"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

# Variables for customization
variable "region" {
  type    = string
  default = "us-east-1"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "ami_name_prefix" {
  type    = string
  default = "al2023-nginx-docker"
}
variable "ami_name_final" {
  type    = string
  default = "IBM-Golden-nginx"
}

#variable "account_to_share" {
 # description = "List of AWS account IDs to share the AMI with"
 # type    = list(string)
#}

# base image part
# The source block defines where to start
source "amazon-ebs" "al2023" {
  ami_name        = "${var.ami_name_final}-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  ami_description = "Amazon Linux 2023 with Nginx and Docker pre-installed"
  instance_type   = var.instance_type
  region          = var.region
  #ami_users       = var.account_to_share
  
  # Find the latest Amazon Linux 2023 AMI
  source_ami_filter {
    filters = {
      name                = "al2023-ami-*-kernel-6.1-x86_64"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["137112412989"] # Amazon's owner ID
  }
  
  ssh_username = "ec2-user"
  
  # Add tags to the resulting AMI
  tags = {
    Name        = "${var.ami_name_prefix}"
    Environment = "training"
    Builder     = "Packer"
    BuildDate   = formatdate("YYYY-MM-DD hh:mm:ss", timestamp())
  }
  
  # Add tags to the snapshot that's created
  snapshot_tags = {
    Name = "${var.ami_name_prefix}-snapshot"
  }
}

# ami customization part 

build {
  name = "build-al2023-nginx-docker"
  sources = [
    "source.amazon-ebs.al2023"
  ]
  
  # Upload the provisioning script
  provisioner "file" {
    source      = "${path.root}/scripts/setup.sh"
    destination = "/tmp/setup.sh"
  }
  
  # Execute the provisioning script
  provisioner "shell" {
    inline = [
      "chmod +x /tmp/setup.sh",
      "sudo /tmp/setup.sh"
    ]
  }
  
  # Verify installations
  provisioner "shell" {
    inline = [
      "nginx -v",
      "docker --version",
      "sudo systemctl status nginx",
      "sudo systemctl status docker"
    ]
  }
}

# post-processor part