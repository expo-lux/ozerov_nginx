#!/usr/bin/env bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export ANSIBLE_REMOTE_USER=user
#не удалось подключить mitogen 0.3.0-0.3.3 к ansible 2.10, 2.11
#export ANSIBLE_STRATEGY=mitogen_linear 
#export ANSIBLE_STRATEGY_PLUGINS=/home/dmitry/.local/lib/python3.8/site-packages/ansible_mitogen/plugins/strategy

ansible-playbook -i rbr playbook.yml

sleep 1
echo "run 'forkstat -e all -S' in case of any problems"
BASE_DOMAIN=$(awk '$1 ~ "base_domain" {print $2}' "$SCRIPT_DIR/rbr/group_vars/nginx.yml")
cmd="curl --connect-timeout 5 http://$BASE_DOMAIN/admin/test1.html -s  -o /dev/null -w '%{http_code}'"
echo "Test http check $cmd"
res=$(eval $cmd)
if [[ "$res" != "301" ]]; then
    echo "Failed"
    exit 1
else
    echo "Passed"
fi

cmd="curl --connect-timeout 5 \"https://$BASE_DOMAIN/test?key=value\" 2>/dev/null"
echo "Test https check $cmd"
res=$(eval $cmd)

if [[ "$res" != "key=value" ]]; then
    echo "Failed"
    exit 1
else
    echo "Passed"
fi

