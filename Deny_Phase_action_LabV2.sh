#!/bin/bash
fqdn="192.168.0.42"
user="admin"
password="VMware1!VMware1!"
keyword="INTEGR_"
file=$1
listing=0
echo -e "1-Disable with REJECT action \n2-Disable with DROP action\n3-Rollback\n4-List rules configuration"
read -e -i "$option" -p "Please enter option number : " input
option="${input:-$option}"

if [[ "$option" == "1" ]] #Disable with REJECT action
then
action="true"
action2=REJECT
read -e -i "$comment" -p "Please enter the log label : " input
comment="${input:-$comment}"
while [[ $(echo $comment | grep "," ) ]]
do
echo -e "\033[1;31mPlease do not add ',' in the log label ! \033[0m"
read -e -i "$comment" -p "Please enter the log label : " input
comment="${input:-$comment}"
done
elif [[ "$option" == "2" ]] #Disable with DROP action
then
action="true"
action2=DROP
comment=''
elif [[ "$option" == "3" ]] #ROLLBACK
then
action="false"
action2=ALLOW
comment=''
elif [[ "$option" == "4" ]] #Listing
then
listing=1
else
echo -e "\033[1;31mWrong option! \033[0m"
exit 1
fi

list_of_policies=$(curl -u $user:$password -k -X GET https://$fqdn/policy/api/v1/infra/domains/default/security-policies -s | grep "\"id\"\|cursor" | sed 's/" : "/*/g' |sed 's/"//g' | sed 's/,//g')
cursor=$(echo $list_of_policies | tr ' ' '\n' | grep cursor | awk -F '*' '{print $2}' )
while [ $cursor ]
do
new_list_of_policies=$(curl -u $user:$password -k -X GET https://$fqdn/policy/api/v1/infra/domains/default/security-policies?cursor=$cursor -s | grep "\"id\"\|cursor" | sed 's/" : "/*/g' |sed 's/"//g' | sed 's/,//g')
cursor=$(echo -e $new_list_of_policies | tr ' ' '\n' | grep cursor | awk -F '*' '{print $2}')
list_of_policies=$list_of_policies" "$new_list_of_policies
done
tt=''
for i in $(echo -e $list_of_policies | tr ' ' '\n' | grep DENY_GROUP  | awk -F '*' '{print $2}') 
do 
tt=$i" "$(curl -u $user:$password -k -X GET https://$fqdn/policy/api/v1/infra/domains/default/security-policies/$i/rules -s |  grep "\"id\"" | awk -F ': "' '{print $2}' | awk -F '",' '{print $1}' | grep  "DENY_FROM_\|DENY_TO_")"\n"$tt
done

for policy in $(cat $file | grep -v ' ') 
do 
echo Working on policy $policy
Deny_rules=$(echo -e $tt | grep -w DENY_FROM_$policy | grep -w DENY_TO_$policy )
if [[ "$Deny_rules" ]]
then
policy2=$(echo $Deny_rules | awk '{print $1}')
Deny_rules=DENY_FROM_$policy" "DENY_TO_$policy
rules=$( curl -u $user:$password -k -X GET https://$fqdn/policy/api/v1/infra/domains/default/security-policies/$policy/rules/ -s | grep "\"id\"" | awk -F ': "' '{print $2}' | awk -F '",' '{print $1}' | grep $keyword)
fi
echo -e  "\033[1;32mThese Rules are going to be changed\033[0m" 

echo  $rules | tr ' ' '\n'
echo  $Deny_rules | tr ' ' '\n'
read -e -i "$respone" -p "Please enter <Y> to accept " input
respone="${input:-$respone}"
if [[ "$respone" == "Y" ]]
then
if [[ "$Deny_rules" && "$rules" ]]
then
for i in $(echo $rules ) ; 
do 
if [[ "$listing" == "1" ]]
then
result=$(curl -u $user:$password -k -X GET https://$fqdn/policy/api/v1/infra/domains/default/security-policies/$policy/rules/$i  -H "Accept: application/json" -s)
else
newjson=$(curl -u $user:$password -k -X GET https://$fqdn/policy/api/v1/infra/domains/default/security-policies/$policy/rules/$i  -H "Accept: application/json" -s   | sed "s+\"disabled\" :.*+\"disabled\" : $action ,+"  );
result=$(curl -u $user:$password -k -X PUT https://$fqdn/policy/api/v1/infra/domains/default/security-policies/$policy/rules/$i -s -d "$newjson" --header "Content-Type: application/json" );
fi
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
do 
if [[ "$comment" ]]
then
tag=$comment-$policy
else
tag=''
fi
if [[ "$listing" == "1" ]]
then
result=$(curl -u $user:$password -k -X GET https://$fqdn/policy/api/v1/infra/domains/default/security-policies/$policy2/rules/$i  -H "Accept: application/json" -s)
else
newjson=$(curl -u $user:$password -k -X GET https://$fqdn/policy/api/v1/infra/domains/default/security-policies/$policy2/rules/$i  -H "Accept: application/json" -s | sed "s+\"tag\" :.*++" | sed "s+\"action\" :.*+\"tag\" : \"$tag\" , \"action\" : \"$action2\" , +"  )
result=$(curl -u $user:$password -k -X PUT https://$fqdn/policy/api/v1/infra/domains/default/security-policies/$policy2/rules/$i -s -d "$newjson" --header "Content-Type: application/json" );
fi
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
echo -e "\033[1;31mPlease make sure that all rules exist\033[0m"; 
fi
fi
done
