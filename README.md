# README
## Ettevalmistus
* Installi aws-cli, Terraform ja Ansible (kui Ansible varianti kasutada - see osa on välja kommenteeritud kuna eelistasin Data Source-ga lahendust hetkel)
* Seadista aws-cli ühendus AWS-iga `aws configure`
* Otsi välja olemasolev või tee uus EC2 võtme-paar millega hiljem WordPressi masinasse sisse logida üle SSH
* Tõmba alla kood https://github.com/pezzage/terraform-tvx.git

## Kasutusjuhised
* Lase repo kataloogis kämia `terraform init` (vajalik ainult korra aga korduv käivitamine pole kahjulik)
* Käivita `terraform apply -var wp_admin_password=XXXXXX -var database_password=XXXXXX` 
* (asenda X-id soovitud salasõnadega - ebaturvaline lahendus ja tuleks esmases järjekorras asendada mingi vault-iga)
* See käivitab alustuseks `terraform plan` käsu küsib kas käivitada `terraform apply` mis seejärel peaks kõik üles tulema.
* Lõpus väljastatakse WP ip aadress ja veeb ise peaks siis olema http://ip_aadress ja admin konsool http://ip_aadress/wp-admin
* Ja kui lõpuks kui enam vaja pole neid serveried siis `terraform destroy` et kõik eemaldada.

## Kokkuvõte
# Terraformiga tehti
* Muutujad
a. Ami id
b. WP instance_type
c. rds_instance_class
d. blog_title
e. database_name
f. database_password
g. wp_admin_username
h. wp_admin_email
i. wp_admin_password
j. private_key (~/.ssh/id_rsa)  (for ansible to be able to ssh to wp instance)
* Ressursid
a. aws_key_pair (pub of the ~/.ssh/id_rsa)(will be added to all instances for SSH access)
b. VPC wordpress-vpc
c. "aws_subnet" "subnet-app-1"
d. "aws_subnet" "subnet-rds-1" and subnet-rds-2
e. "aws_db_subnet_group" "wordpress"
f. aws_internet_gateway
g. "aws_route_table" "app-rt"
h. "aws_route_table_association" "rta-app-subnet-1"
i. "aws_security_group" "allow_mysql"
j. "aws_security_group" "allow_http_external" 
k. "aws_security_group" "allow_ssh"
l. "aws_instance" "wordpress"
m. "aws_db_instance" "db1"
* Väljundid
a. output "ip_address"
b. output "rds"

## Mida peaks edasi tegema
* Seadistama CDN plugina kasutama CDN-i päriselt (praegu see ootab võtit et kontot lisada)
* Lisada HTTPS
* Salasõnad panna mingisse šeifi

## Et lahendus kannataks rohkem koormust oleks vaja:
* Kui mitu inimest tahab korraga töötada sama Terraformi setupi kallal siis Lisada S3 state falide jaoks
* Teha kood mooduliteks et erinevat keskkonnad (DEV, TEST, STAGE, PROD) saaks sama koodi kasutada
* Liigutada wp-content/uploads (ja võimalik et ka muid katalooge) EFS-i peale ja mount-ida need serverite külge
* Teha mitu app serverit ja subnetti.
* Panna koormusjaotur ette ja lisada automaatne skaleerimine koormuse järgi näiteks

## Teadaolevad probleemid
* Tegin kaks varianti WP installimise jaoks (osaliselt kuna Ansiblet taheti ülessandes ja teiseks kuna Ansiblega saab kasutada lihtsalt kohaliku ip-d WP seadistamisel et siis üle ip aadressi leht ilusti töötaks). Kuna aga hetkle Data Source-i ilus, domeeni nime kasutav variant, ikkagi oli sobivam, siis jätsin selle ja kommenteerisin Ansible osa välja. Probleem on küll nüüd see, et kuna DNS väga kiirelt ei propageeru siis peaks kohaliku masina hosts faili panema rea
13.53.207.219 ulst.org
et http://ulst.org lehti ilusti töötaks.
* Ansiblega on veel see probleem, et provisioner jookseb liiga vara, kui teised protsessid veel lõpetanud pole ja see tekitas probleeme, tuli panna natuke "sleep" sekundeid sinna, et kõik töötaks.
* Lisaks Ansible "Quoted strings" lahendus ei ole perfektne, kui panna blogi nimesse ülakoma vms siis see teeb lahenduse katki (arvane et see on tänu |quote lahendusele mida kasutasin) ja üldiselt on Ansible osa päris kole ja vajaks ringi mõtlemist.




















