#!/bin/bash
fqdn="192.168.0.42"
user="admin"
password="VMware1!VMware1!"
keyword="INTEGR_"
policy=$1
policy=default-layer3-section
action=\"$2\"
rules=$( curl -u $user:$password -k -X GET https://$fqdn/policy/api/v1/infra/domains/default/security-policies/$policy/rules/ -s | grep "\"id\"" | awk -F ': "' '{print $2}' | awk -F '",' '{print $1}' | grep $keyword)
echo -e "\033[1;31mThese Rules are going to be changed\033[0m" 
echo  $rules | tr ' ' '\n'
read -e -i "$respone" -p "Please enter <Y> to accept " input
respone="${input:-$respone}"
if [[ "$respone" == "Y" ]]
then
for i in $(echo $rules ) ; 
do 
tag=$rules
newjson=$(curl -u $user:$password -k -X GET https://$fqdn/policy/api/v1/infra/domains/default/security-policies/$policy/rules/$i  -H "Accept: application/json" -s |  sed "s+\"tag\" :.*++" | sed "s+\"disabled\" :.*+\"disabled\" : $action , \"tag\" : \"$tag\" ,+"  );
result=$(curl -u $user:$password -k -X PUT https://$fqdn/policy/api/v1/infra/domains/default/security-policies/$policy/rules/$i -s -d "$newjson" --header "Content-Type: application/json" );
if [[ -z $(echo $result | grep "\"disabled\" :" ) ]] ; 
then 
echo -e "\033[1;31mCannot get rule configuration, something went wrong ! \033[0m"; 
echo -e $result  ;
exit 1 ;
else  
echo "========================================================================================"
echo -e "\033[1;32m New action associated with rule $i : \033[0m"
echo "========================================================================================"
echo $result | awk -F '"disabled" : ' '{print $2}' | awk -F ',' '{print $1}'
echo $result | awk -F '"tag" : ' '{print $2}' | awk -F ',' '{print $1}'
fi
done
fi
