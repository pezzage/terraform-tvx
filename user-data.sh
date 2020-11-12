#!/bin/bash
apt-get update
apt-get install -y apache2 php7.4-mysql libapache2-mod-php php7.4-cli mysql-client
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
rm -f /var/www/html/index.html
# See https://stackoverflow.com/questions/61649764/mysql-error-2026-ssl-connection-error-ubuntu-20-04
sed -i '1s/^/openssl_conf = default_conf/' /usr/lib/ssl/openssl.cnf
echo "
[ default_conf ]

ssl_conf = ssl_sect

[ssl_sect]

system_default = ssl_default_sect

[ssl_default_sect]
MinProtocol = TLSv1
CipherString = DEFAULT:@SECLEVEL=1
" >> /usr/lib/ssl/openssl.cnf
${wp-cli} --path=${path} core download
${wp-cli} --path=${path} config create --dbname=wordpress --dbhost=${db_host} --dbuser=${db_user} --dbpass=${db_pass}
${wp-cli} --path=${path} core install --url="${url}" --title="${blog_title}" --admin_user="${admin_user}" --admin_email="${admin_email}" --admin_password="${admin_pass}"
${wp-cli} --path=${path} plugin install simple-history --activate
${wp-cli} --path=${path} plugin install cloudimage --activate
${wp-cli} --path=${path} plugin install g-business-reviews-rating --activate
echo "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAgEAwRFCL5R4I3tTNr4cq7PyuB6+/PbvAvPzlqeFW8/4SuiR9lJErZvm/UwEuETCOe9WNHMvWwcOGJ6SAmv+GMFD7zCNBaKuih9whhGyFnKr04vt6l83HgzxvA1edmyDLtqKwUi9l9laUamiRprkFbDkcCaAlh1LLYcs/D0VpItZuJLlxi6v08Ud6bGDfUT5Kz7txO9XM3hY91YuOErq4j3AQTcgxTvil78zt7VXAqWlGtjR8BE++wQJf2BSaaM+UZNhtJynoFjRnMbZCx63yQEF9zMDruOBc1RKv6z9HE0dii5B+buT1Wk2DqAlAvgd5VeB8d58dT2IjZ3n+Q1k740CVC/wqiyMZ8Br9qiHOK9vcaV6BL4J/R0MoHIz5kzu2lMYUt0gWqSfqFhZ0t3nvqLE1/6uNAHW78wnlwtwhw59+8Iwe76gOW8/QE34kGR+R8Ey5Kw2QN/3zOiuPkSlgnIfCTx/W/ZbGQzZ5xPj2OfUri2ecnUc6QUSKS2DX8Zn3imckWy0ur82Vevr7y8qJAOO0jFHXGO5EiXttemWJA2yf/C04Xn9fS3DSd5EFbHAKA+rlJuxS7jpC9cxTr/EcLHgiP3DnCgcj8ExyL/SSJV6jbVs5DbIR5QmqLFhfP0HckH2pZ6NNe3WxWKMax4fFrHtbSh8CRFW8nVS6ZTA2AYi3Hs= Indrek Kalluste" >> /home/ubuntu/.ssh/authorized_keys
