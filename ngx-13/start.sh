#!/usr/bin/env bash
#не удалось подключить mitogen 0.3.0-0.3.3 к ansible 2.10, 2.11
#export ANSIBLE_STRATEGY=mitogen_linear 
#export ANSIBLE_STRATEGY_PLUGINS=/home/dmitry/.local/lib/python3.8/site-packages/ansible_mitogen/plugins/strategy

ansible-playbook -i inventories/rbr deploy_nginx.yml
ansible-playbook -i inventories/rbr test_nginx.yml

echo "run 'forkstat -e all -S' in case of any problems"