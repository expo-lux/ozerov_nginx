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

openssl verify -CAfile "$SCRIPT_DIR/files/ca.crt" "$SCRIPT_DIR/files/client.crt" &>/dev/null && echo client.crt signed by ca.crt || echo client.crt is not signed by ca.crt
openssl x509 -in "$SCRIPT_DIR/files/ca.crt" &>/dev/null && echo Test 2.1 success || echo Test 2.1 failed
openssl rsa -in "$SCRIPT_DIR/files/ca.key" &>/dev/null && echo Test 2.2 success || echo Test 2.2 failed
openssl x509 -in "$SCRIPT_DIR/files/client.crt" &>/dev/null && echo Test 2.3 success || echo Test 2.3 failed
openssl rsa -in "$SCRIPT_DIR/files/client.key" &>/dev/null && echo Test 2.4 success || echo Test 2.4 failed


cmd="curl --connect-timeout 5 \"https://$BASE_DOMAIN\" -s  -o /dev/null -w '%{http_code}'"
echo "Test 3.1 https check without client certificate $cmd"
res=$(eval $cmd)

if [[ "$res" != "400" ]]; then
    echo "Failed"
    exit 1
else
    echo "Passed"
fi

cmd="curl --connect-timeout 5 --cert \"$SCRIPT_DIR/files/client.crt\" --key  \"$SCRIPT_DIR/files/client.key\" \"https://$BASE_DOMAIN\" -s  -o /dev/null -w '%{http_code}'"
echo "Test 3.2 https check with certificate $cmd"
res=$(eval $cmd)

if [[ "$res" != "200" ]]; then
    echo "Failed"
    exit 1
else
    echo "Passed"
fi

