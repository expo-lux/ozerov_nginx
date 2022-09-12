#!/usr/bin/env bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export ANSIBLE_REMOTE_USER=user
#не удалось подключить mitogen 0.3.0-0.3.3 к ansible 2.10, 2.11
#export ANSIBLE_STRATEGY=mitogen_linear 
#export ANSIBLE_STRATEGY_PLUGINS=/home/dmitry/.local/lib/python3.8/site-packages/ansible_mitogen/plugins/strategy

# ansible-playbook -i inventories/rbr playbook.yml

sleep 1
echo "run 'forkstat -e all -S' in case of any problems"
BASE_DOMAIN=$(awk '$1 ~ "base_domain" {print $2}' "$SCRIPT_DIR/inventories/rbr/group_vars/nginx.yml")


cmd="curl -D - -s \"http://$BASE_DOMAIN/country\" | grep -Z X-Country | tr -d '\r'"
echo "Test 3.1 check $cmd"
res=$(eval $cmd)

if [[ "$res" != "X-Country: RUS" ]]; then
    echo "Failed"
    exit 1
else
    echo "Passed"
fi

cmd="curl -D - -s \"http://$BASE_DOMAIN/name\" | grep X-Country-Name | tr -d '\r'"
echo "Test 3.2  check $cmd"
res=$(eval $cmd)

if [[ "$res" != "X-Country-Name: Russian Federation" ]]; then
    echo "Failed"
    exit 1
else
    echo "Passed"
fi

