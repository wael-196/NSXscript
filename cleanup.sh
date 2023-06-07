#!/bin/bash
fqdn="192.168.0.42"
user="admin"
password="VMware1!VMware1!"
policy=default-layer3-section
rule_list="CATCH_APP_TO_INET CATCH_CLOSE_TO_NEAR CATCH_INTEGR_APP_TO_EXTRA CATCH_INTEGR_APP_TO_INTRA CATCH_INTEGR_EXTRA_TO_APP CATCH_INTEGR_INTRA_TO_APP CATCH_INTRA_APP CATCH_INTRA_NEAR CATCH_NEAR_TO_FAR"
result=''
adding_services(){
newjson=$(curl -u $user:$password -k -X GET https://$fqdn/policy/api/v1/infra/domains/default/security-policies/$policy/rules/$1  -H "Accept: application/json" -s | sed "s+\"services\" :.*+$2+" )
result=$(curl -u $user:$password -k -X PUT https://$fqdn/policy/api/v1/infra/domains/default/security-policies/$policy/rules/$1 -s -d "$newjson" --header "Content-Type: application/json" )
}

for i in $(echo $rule_list |  sed 's/CATCH_//g' ); 
do
services="\"services\" : [ \"\/infra\/services\/TCP_65535\" ],"
adding_services "$i" "$services"
if [[ -z $(echo $result | grep "\"services\" :" ) ]] ; 
then 
echo -e "\033[1;31mCannot get services, something went wrong ! \033[0m"; 
echo -e $result  ;
else  
echo "========================================================================================"
echo -e "\033[1;32mNew services associated with rule $i : \033[0m"
echo "========================================================================================"
echo $result | awk -F '"services" : \\[' '{print $2}' | awk -F ']' '{print $1}' | sed 's+/infra/services/++g'
fi

done 


