#!/bin/bash
fqdn="192.168.0.42"
user="admin"
password="VMware1!VMware1!"
keyword="CATCH_"
policy=$1
action=\"$2\"
rules=$( curl -u $user:$password -k -X GET https://$fqdn/policy/api/v1/infra/domains/default/security-policies/$policy/rules/ -s | grep "\"id\"" | awk -F ': "' '{print $2}' | awk -F '",' '{print $1}' | grep $keyword)
echo Rules this are going to be changed $rules
for i in $(echo $rules ) ; 
do newjson=$(curl -u $user:$password -k -X GET https://$fqdn/policy/api/v1/infra/domains/default/security-policies/$policy/rules/$i  -H "Accept: application/json" -s | sed "s+\"action\" :.*+\"action\" : $action ,+" );
result=$(curl -u $user:$password -k -X PUT https://$fqdn/policy/api/v1/infra/domains/default/security-policies/$policy/rules/$i -s -d "$newjson" --header "Content-Type: application/json" );
if [[ -z $(echo $result | grep "\"action\" :" ) ]] ; 
then 
echo -e "\033[1;31mCannot get rule configuration, something went wrong ! \033[0m"; 
echo -e $result  ;
exit 1 ;
else  
echo "========================================================================================"
echo -e "\033[1;32m New action associated with rule $i : \033[0m"
echo "========================================================================================"
echo $result | awk -F '"action" : ' '{print $2}' | awk -F ',' '{print $1}'
fi
done