#!/usr/bin/env bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export ANSIBLE_REMOTE_USER=user
ansible-playbook -i rbr playbook.yml

sleep 1
echo "run 'forkstat -e all -S' if any problems occurred"
BASE_DOMAIN=$(awk '$1 ~ "base_domain" {print $2}' "$SCRIPT_DIR/rbr/group_vars/all.yml")
res=$(curl --connect-timeout 5 $BASE_DOMAIN/admin/img.jpg -s -o /dev/null -w "%{http_code}")
if [[ "$res" != "403" ]]; then
    echo "admin failed"
    exit 1
else
    echo "admin success"
fi
res=$(curl --connect-timeout 5 $BASE_DOMAIN/admin/readme.md -s -o /dev/null -w "%{http_code}")
if [[ "$res" != "200" ]]; then
    echo "readme failed"
    exit 1
else
    echo "readme success"
fi
res=$(curl --connect-timeout 5 $BASE_DOMAIN/admin.JPG -s -o /dev/null -w "%{http_code}")
if [[ "$res" != "202" ]]; then
    echo "JPG failed"
    exit 1
else
    echo "JPG success"
fi

