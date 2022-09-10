#!/usr/bin/env bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export ANSIBLE_REMOTE_USER=user
#не удалось подключить на ansible 2.10, 2.11 и mitogen 0.3.0-0.3.3
#export ANSIBLE_STRATEGY=mitogen_linear 
#export ANSIBLE_STRATEGY_PLUGINS=/home/dmitry/.local/lib/python3.8/site-packages/ansible_mitogen/plugins/strategy
ansible-playbook -i rbr playbook.yml

sleep 1
echo "run 'forkstat -e all -S' if any problems occurred"
BASE_DOMAIN=$(awk '$1 ~ "base_domain" {print $2}' "$SCRIPT_DIR/rbr/group_vars/all.yml")
res=$(curl --connect-timeout 5 $BASE_DOMAIN/test1.html -s)
if [[ "$res" != "test1" ]]; then
    echo "test1 failed"
    exit 1
else
    echo "test1 success"
fi


res=$(curl --connect-timeout 5 $BASE_DOMAIN/test3.html -s -o /dev/null -w "%{http_code}")
if [[ "$res" != "204" ]]; then
    echo "not found test failed"
    exit 1
else
    echo "not found test success"
fi

cmd="curl --connect-timeout 5 $BASE_DOMAIN/heya.html -s"
res="$($cmd)"
if [[ "$res" != "test3" ]]; then
    echo "heya test failed, check $cmd"
    exit 1
else
    echo "heya test success"
fi


# res=$(curl --connect-timeout 5 $BASE_DOMAIN/admin/img.jpg -s -o /dev/null -w "%{http_code}")
# if [[ "$res" != "403" ]]; then
#     echo "admin failed"
#     exit 1
# else
#     echo "admin success"
# fi
# res=$(curl --connect-timeout 5 $BASE_DOMAIN/admin/readme.md -s -o /dev/null -w "%{http_code}")
# if [[ "$res" != "200" ]]; then
#     echo "readme failed"
#     exit 1
# else
#     echo "readme success"
# fi
# res=$(curl --connect-timeout 5 $BASE_DOMAIN/admin.JPG -s -o /dev/null -w "%{http_code}")
# if [[ "$res" != "202" ]]; then
#     echo "JPG failed"
#     exit 1
# else
#     echo "JPG success"
# fi

