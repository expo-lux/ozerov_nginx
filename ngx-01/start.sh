#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

BASE_DOMAIN_OLD="8bbbee05719ed2d7b4afd99c45a0f9ea.kis.im"
BASE_DOMAIN="base_domain"

mv "$SCRIPT_DIR/sites-enabled/alpha.$BASE_DOMAIN_OLD.conf" "$SCRIPT_DIR/sites-enabled/alpha.$BASE_DOMAIN.conf"
mv "$SCRIPT_DIR/sites-enabled/beta.$BASE_DOMAIN_OLD.conf" "$SCRIPT_DIR/sites-enabled/beta.$BASE_DOMAIN.conf"
mv "$SCRIPT_DIR/sites-enabled/gamma.$BASE_DOMAIN_OLD.conf" "$SCRIPT_DIR/sites-enabled/gamma.$BASE_DOMAIN.conf"

sed -i -e "s/$BASE_DOMAIN_OLD/$BASE_DOMAIN/" "$SCRIPT_DIR/sites-enabled/alpha.$BASE_DOMAIN.conf"
sed -i -e "s/$BASE_DOMAIN_OLD/$BASE_DOMAIN/" "$SCRIPT_DIR/sites-enabled/beta.$BASE_DOMAIN.conf"
sed -i -e "s/$BASE_DOMAIN_OLD/$BASE_DOMAIN/" "$SCRIPT_DIR/sites-enabled/gamma.$BASE_DOMAIN.conf"



for i in  $(docker ps | grep -v CONTAINER | awk  '{ print $1 }'); do 
    docker stop $i &>/dev/null
done
docker run -d --rm -p 80:80 -p 8080:8080 -v "$SCRIPT_DIR/nginx.conf":/etc/nginx/nginx.conf -v "$SCRIPT_DIR/sites-enabled":/etc/nginx/sites-enabled ubuntu/nginx

sleep 1
a=$(curl --connect-timeout 5 -H "Host: alpha.$BASE_DOMAIN" localhost:80/ 2>/dev/null)
b=$(curl --connect-timeout 5 localhost:80/ 2>/dev/null)
g=$(curl --connect-timeout 5 -H "Host: gamma.$BASE_DOMAIN" -s -o /dev/null -w "%{http_code}" localhost:8080/)
if [[ "$a" != 'ALPHA' ]]; then
    echo "ALPHA failed"
    exit 1
else
    echo "ALPHA success"
fi
if [[ "$b" != 'BETA' ]]; then
    echo "BETA failed"
    exit 1
else
    echo "BETA success"
fi
if [[ "$g" != "301" ]]; then
    echo "GAMMA failed"
    exit 1
else
    echo "GAMMA success"
fi

for i in  $(docker ps | grep -v CONTAINER | awk  '{ print $1 }'); do 
    docker stop $i &>/dev/null
done


#установка mainline version для ubuntu из инструкции https://nginx.org/ru/linux_packages.html
#проверка HTTP/1.0 и без заголовка Host curl -vvv -0  -H "Host:" 188.166.31.64 - должно выдавать BETA
#если проверять HTTPS/1.1 с отсутствующим заголовком Host, то команда curl -vvv -H "Host:" 188.166.31.64  выдает HTTP 400, это нормально, т.к. в HTTP 1.1 заголовок Host обязателен

