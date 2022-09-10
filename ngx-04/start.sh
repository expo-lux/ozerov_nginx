#!/usr/bin/env bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export ANSIBLE_REMOTE_USER=user
#не удалось подключить mitogen 0.3.0-0.3.3 к ansible 2.10, 2.11
#export ANSIBLE_STRATEGY=mitogen_linear 
#export ANSIBLE_STRATEGY_PLUGINS=/home/dmitry/.local/lib/python3.8/site-packages/ansible_mitogen/plugins/strategy

ansible-playbook -i rbr playbook.yml

sleep 1
echo "run 'forkstat -e all -S' in case of any problems"
BASE_DOMAIN=$(awk '$1 ~ "base_domain" {print $2}' "$SCRIPT_DIR/rbr/group_vars/all.yml")
cmd="curl --connect-timeout 5 $BASE_DOMAIN/admin/test1.html -s  -o /dev/null -w '%{http_code}'"
echo "Test 2.1 check $cmd"
res=$(eval $cmd)
if [[ "$res" != "301" ]]; then
    echo "Failed"
    exit 1
else
    echo "Passed"
fi

cmd="curl --connect-timeout 5 $BASE_DOMAIN/user/myuser 2>/dev/null"
echo "Test 2.2 check $cmd"
res=$(eval $cmd)

if [[ "$res" != "user=myuser" ]]; then
    echo "Failed"
    exit 1
else
    echo "Passed"
fi

cmd="curl --connect-timeout 5 $BASE_DOMAIN/index.php  -s -o /dev/null -w '%{http_code}'"
echo "Test 2.3 check $cmd"
res="$(eval $cmd)"
if [[ "$res" != "200" ]]; then
    echo "Failed"
    exit 1
else
    echo "Passed"
fi


