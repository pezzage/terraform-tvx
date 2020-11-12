provider "aws" {
  region       = "eu-north-1"
  version      = "3.14.1"
}

variable "ami" {
  type         = string
  default      = "ami-0a3a4169ad7cb0d77"
  description  = "The AMI used to spin up images. The default is Ubuntu 20.04 LTS"
}

variable "instance_type" {
  type         = string
  default      = "t3.micro"
  description  = "The instance type to create for each Wordpress instance"
}

variable "rds_instance_class" {
  type         = string
  default      = "db.t3.small"
  description  = "The instance type to create for RDS"  
}

variable "blog_title" {
  type         = string
  default      = "My Wordpress Blog"
  description  = "The blog title"  
}

variable "database_name" {
  type         = string
  default      = "wordpress"
  description  = "The MySQL database name"  
}

variable "database_username" {
  type         = string
  default      = "wp_user"
  description  = "The MySQL database user - this is actually the admin user, so really another should be created for Wordpress"  
}

variable "database_password" {}
### liigutasin selle command-line var-iks: `terraform apply -var wp_admin_password=XXXXXX -var database_password=XXXXXX`
#  type         = string
#  default      = "xxxxx"
#  description  = "The MySQL database password"
#}

variable "wp_admin_username" {
  type         = string
  default      = "wpadmin"
  description  = "The Wordpress admin username"
}

variable "wp_admin_email" {
  type         = string
  default      = "peeteru@gmail.com"
  description  = "The Wordpress admin email"
}

variable "wp_admin_password" {}
### liigutasin selle command-line var-iks: `terraform apply -var wp_admin_password=XXXXXX -var database_password=XXXXXX`
#  type         = string
#  default      = "xxxxx"
#  description  = "The Wordpress admin password"
#}

variable "ssh_user" {
  type         = string
  default      = "ubuntu"
  description  = "The user, used by Ansible for accessing the Wordpress instance over SSH"
}

variable "private_key" {
  type         = string
  default      = "~/.ssh/wordpress-key-id_rsa"
  description  = "Private key location of the below public_key (wordpress-ssh-key), it will be used by Ansible for accessing instances"
}

###  See pub võti pannakase WP masinasse ubuntu kasutaja authorized_keys faili (Ubuntu AMI-idel pole vaike salasõna)
resource "aws_key_pair" "wordpress-ssh-key" {
  key_name   = "wordpress-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCunC+37jWYdN4WNfPpQmM/BWZRuuXRlYMGZwlpnLFwZeuOifhhCRLUIOlBkpRfeuA+ziTAF3HYKV4plRVbGJ63XGLCOl66Ox6yTcS4wZo2rzT8JK9NZxlFbOR+8ILEgEIz04Ywrix4h26xEJDpuFZbHJ/e9QqTEYooySqOpFRblk1fyqkYJPZTyEK1FoJbsCTRB2ZKT560Xaxhh2N6pcRtmapvRf6mxgPgjkKF3IhvRbd1QJ3oacM9igrllK4ZE/mUErITkNjZ1pR2VyN3e9HglCo3t3eFjIIvkhvLtcKpzR/CyPx7nxS0gbRzxfXGgxO63Y5BAWbm3ELpvdJsEGcB bigfoot@KAST"
  tags = {
    Name = "wordpress-ssh-key-public_key"
  }
}

###
### VPC
###
resource "aws_vpc" "main-vpc" {
    cidr_block = "10.0.0.0/16"
    instance_tenancy = "default"    
    tags = {
        Name = "wordpress-vpc"
    }
}

### Teeme kolm subnet-i. Üks avalik WP jaoks ja kaks privaatset RDS-i jaoks 
### (et RDSi VPC-sse panna peab olema neid kaks ja need peavad olema eri AZ tsoonides - nagu 
### Amazon ütleb, siis ala juhuks kui tulevikus tahame standby baasi juurde panna vms)
resource "aws_subnet" "subnet-app-1" {
    vpc_id = aws_vpc.main-vpc.id
    cidr_block = "10.0.1.0/24"
    map_public_ip_on_launch = "true" # This makes it a public subnet
    availability_zone = "eu-north-1a"
    tags = {
        Name = "wordpress-app1-10.0.1.0"
    }
}

resource "aws_subnet" "subnet-rds-1" {
    vpc_id = aws_vpc.main-vpc.id
    cidr_block = "10.0.100.0/24"
    map_public_ip_on_launch = "false" # Database shouldn't be internet-accessible
    availability_zone = "eu-north-1a"
    tags = {
        Name = "wordpress-db1-10.0.100.0"
    }
}

resource "aws_subnet" "subnet-rds-2" {
    vpc_id      = aws_vpc.main-vpc.id
    cidr_block  = "10.0.101.0/24"
    map_public_ip_on_launch = "false" # Database shouldn't be internet-accessible
    availability_zone = "eu-north-1b"
    tags        = {
        Name    = "wordpress-db2-10.0.101.0"
    }
}

### Järgmiseks on vaja teha subnet grupp DB jaoks
resource "aws_db_subnet_group" "wordpress" {
  name       = "wordpress"
  subnet_ids = [aws_subnet.subnet-rds-1.id, aws_subnet.subnet-rds-2.id]

  tags       = {
    Name     = "Wordpress DB Subnet Group"
  }
}

### Defineerima ruutingu tabelid ja gw
resource "aws_internet_gateway" "igw" {
    # This should only be attached to the app subnets - direct internet access
    vpc_id   = aws_vpc.main-vpc.id
    tags     = {
        Name = "wordpress-igw"
    }
}

### App serveri jaoks teeme rt, et see saaks välismaailmaga suhelda.
resource "aws_route_table" "app-rt" {
    vpc_id          = aws_vpc.main-vpc.id
    route {
        cidr_block  = "0.0.0.0/0" 
        gateway_id  = aws_internet_gateway.igw.id
    }
    tags = {
        Name        = "wordpress-app-rt"
    }
}

### Seome app alamvõrgu ruutingu tabeliga
resource "aws_route_table_association" "rta-app-subnet-1" {
    subnet_id       = aws_subnet.subnet-app-1.id
    route_table_id  = aws_route_table.app-rt.id
}

### improtisin olemasoleva ulst.org domeeni Terraformi eelnevalt nii:
### terraform import aws_route53_zone.ulst-org ZXXXXXXXXXXXXX
resource "aws_route53_zone" "ulst-org" {
name = "ulst.org"
}

### tekitame värske app serveri jaoks DNS kirje
resource "aws_route53_record" "ulst-org-A" {
zone_id = aws_route53_zone.ulst-org.zone_id
name = "ulst.org"
type = "A"
ttl = "30"

records = [aws_instance.wordpress.public_ip]
}

### Turvagrupid et ligipääs tekitada
resource "aws_security_group" "allow_mysql" {
  name        = "allow_mysql"
  description = "Allow MySQL inbound traffic from entire VPC"
  vpc_id      = aws_vpc.main-vpc.id
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }

  tags = {
    Name = "allow_mysql"
  }
}

resource "aws_security_group" "allow_http_external" {
  name          = "allow_http_external"
  description   = "Allow HTTP from the Internet"
  vpc_id        =  aws_vpc.main-vpc.id
  ingress {
    description = "HTTP"
    to_port     = 80
    from_port   = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags          = {
    Name        = "allow_http"
  }
}


### Hoiame SSH eraldi igaks juhukus kuna mitu ingress reeglit võivad põhjustada ressursi uuesti tegemist
### (https://github.com/hashicorp/terraform/issues/507)
resource "aws_security_group" "allow_ssh" {
  name   = "allow_ssh"
  vpc_id = aws_vpc.main-vpc.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    ### need aadressid tuleks whitelist muutujasse panna
    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }
  ### Lubame liikluse välja (selle võiks eraldi SG-sse panna)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "allow_ssh in and all out"
  }
}

### Loome Data muutuja Wordpress-i jaoks (teine variant mida katsetasin oli seda teha Ansiblega mis on praegu välja kommenteeritud)
data "template_file" "wordpress_config" {
  template      = file("user-data.sh")

  vars = {
    wp-cli      = "php wp-cli.phar --allow-root"
    path        = "/var/www/html"
    url         = "ulst.org"
    db_host     = aws_db_instance.db1.address
    db_user     = var.database_username
    db_pass     = var.database_password
    admin_user  = var.wp_admin_username
    admin_email = var.wp_admin_email 
    admin_pass  = var.wp_admin_password
    blog_title  = var.blog_title
  }
}

resource "aws_instance" "wordpress" {
  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = aws_key_pair.wordpress-ssh-key.key_name
  ### Kui Ansiblet kasutada siis tuleks see rida välja kommenteerida ja alt poolt kõik kommentaari märgid eemaldada.
  user_data              = data.template_file.wordpress_config.rendered
  vpc_security_group_ids = [aws_security_group.allow_http_external.id, aws_security_group.allow_ssh.id]
  subnet_id              = aws_subnet.subnet-app-1.id

#  ### Selleks et olla kindel et masin on üleval enne kui Ansible sellel kallale lasta siis käivitame remote-exec-i mis 
#  ### ootab kuni masin üles tuleb ja lisame sina sleep ootamise sest tundub, et provisioner skript jookseb enne kui kõik
#  ### tegevused lõppenud on ja Ansible jooksutamine võib sellel ajal võib apt baasi katki teha.
#  provisioner "remote-exec" {
#    inline = ["sleep 60"]
#  }
#  ### See on remote-exec-i jaoks. 
#  connection {
#    private_key = file(var.private_key)
#    user        = "ubuntu"
#    host        = self.public_ip
#  }
#
#  ### Kui jooksutada seda enne remote-exec-it siis see tõnäoliselt nurjub.
#  provisioner "local-exec" {
#    command = <<EOF
#ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i '${self.public_ip},' --private-key=${var.private_key} -u ${var.ssh_user} ansible/provision.yml --extra-vars #"path=/var/www/html url=${self.public_ip} db_name=${var.database_name} db_host=${aws_db_instance.db1.address} db_user=${var.database_username} db_pass=${var.#database_password} admin_user=${var.wp_admin_username} admin_email=${var.wp_admin_email} admin_pass=${var.wp_admin_password} blog_title=\"${var.blog_title}\""
#EOF
#  }

  tags      = {
      Name  = "wordpress-aws_instance"
  }
}


### RDS DB
resource "aws_db_instance" "db1" {
  identifier                   = "wordpress-db1"
  engine                       = "mysql"
  allocated_storage            = 20
  instance_class               = var.rds_instance_class
  db_subnet_group_name         = aws_db_subnet_group.wordpress.id
  name                         = var.database_name
  username                     = var.database_username
  password                     = var.database_password
  engine_version               = "5.6.41"
  vpc_security_group_ids       = [aws_security_group.allow_mysql.id]
  publicly_accessible          = false
  # Don't skip in production, but if you don't add this you can't destroy the database without a snapshot identifier
  skip_final_snapshot          = true
  # RDS can take a long time to create. Default timeout is 30m.
  timeouts {
    create = "2h"
  }
  tags = {
      Name = "aws_db_instance-db1"
  }
}


output "ip_address" {
  value = aws_instance.wordpress.public_ip
}

output "rds" {
  value = aws_db_instance.db1.address
}
