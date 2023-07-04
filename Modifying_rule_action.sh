#!/bin/bash
fqdn="192.168.0.42"
user="admin"
password="VMware1!VMware1!"
keyword="INTEGR_"
file=$1
read -e -i "$comment" -p "Please enter the comment" input
comment="${input:-$comment}"
for i in $(curl -u $user:$password -k -X GET https://$fqdn/policy/api/v1/infra/domains/default/security-policies -s | grep "\"id\"" | awk -F ': "' '{print $2}' | awk -F '",' '{print $1}' | grep DENY_GROUP ) 
do 
tt=$i" "$(curl -u $user:$password -k -X GET https://$fqdn/policy/api/v1/infra/domains/default/security-policies/$i/rules -s |  grep "\"id\"" | awk -F ': "' '{print $2}' | awk -F '",' '{print $1}' | grep  "DENY_FROM_\|DENY_TO_")"\n"$tt
done
for policy in $(cat $file) 
do action="true"
action2=REJECT
Deny_rules=$(echo -e $tt | grep -w "DENY_FROM_$policy\|DENY_TO_$policy" )
if [[ "$Deny_rules" ]]
then
policy2=$(echo $Deny_rules | awk '{print $1}')
Deny_rules=$(echo $Deny_rules | sed 's+\<'$policy2'\>++g')
echo $Deny_rules jjjjj
fi
rules=$( curl -u $user:$password -k -X GET https://$fqdn/policy/api/v1/infra/domains/default/security-policies/$policy/rules/ -s | grep "\"id\"" | awk -F ': "' '{print $2}' | awk -F '",' '{print $1}' | grep $keyword)
echo -e "\033[1;31mThese Rules are going to be changed\033[0m" 
echo  $rules | tr ' ' '\n'
echo  $Deny_rules | tr ' ' '\n'
read -e -i "$respone" -p "Please enter <Y> to accept " input
respone="${input:-$respone}"
if [[ "$respone" == "Y" ]]
then
if [[ "$Deny_rules" ]]
then
for i in $(echo $rules ) ; 
do tag=$i
newjson=$(curl -u $user:$password -k -X GET https://$fqdn/policy/api/v1/infra/domains/default/security-policies/$policy/rules/$i  -H "Accept: application/json" -s   | sed "s+\"disabled\" :.*+\"disabled\" : $action ,+"  );
result=$(curl -u $user:$password -k -X PUT https://$fqdn/policy/api/v1/infra/domains/default/security-policies/$policy/rules/$i -s -d "$newjson" --header "Content-Type: application/json" );
if [[ -z $(echo $result | grep "\"disabled\" :" ) ]] ; 
then 
echo -e "\033[1;31mCannot get rule configuration, something went wrong ! \033[0m"; 
echo -e $result  ;
exit 1 ;
else  
echo "========================================================================================"
echo -e "\033[1;32mNew configuration of rule $i : \033[0m"
echo "========================================================================================"
disabled=$(echo $result | awk -F '"disabled" : ' '{print $2}' | awk -F ',' '{print $1}')
echo disabled=$disabled
fi
done

for i in $(echo $Deny_rules ) ; 
do tag=$comment" "$policy
newjson=$(curl -u $user:$password -k -X GET https://$fqdn/policy/api/v1/infra/domains/default/security-policies/$policy2/rules/$i  -H "Accept: application/json" -s | sed "s+\"action\" :.*++" | sed "s+\"tag\" :.*+\"tag\" : \"$tag\" , \"action\" : \"$action2\" , +"  );
result=$(curl -u $user:$password -k -X PUT https://$fqdn/policy/api/v1/infra/domains/default/security-policies/$policy2/rules/$i -s -d "$newjson" --header "Content-Type: application/json" );
if [[ -z $(echo $result | grep "\"tag\" :" ) ]] ; 
then 
echo -e "\033[1;31mCannot get rule configuration, something went wrong ! \033[0m"; 
echo -e $result  ;
exit 1 ;
else  
echo "========================================================================================"
echo -e "\033[1;32mNew configuration of rule $i : \033[0m"
echo "========================================================================================"
tag2=$(echo $result | awk -F '"tag" : ' '{print $2}' | awk -F ',' '{print $1}')
echo log label=$tag2 
action3=$(echo $result | awk -F '"action" : ' '{print $2}' | awk -F ',' '{print $1}')
echo Action=$action3 
fi
done
else
echo -e "\033[1;31mCannot find Deny rules with names DENY_FROM_$policy or DENY_TO_$policy\033[0m"; 
fi
fi
done
