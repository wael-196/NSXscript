#!/bin/bash
fqdn="xxxx"
user="xxx"
password="xxxx"
file="ports2.txt"
read -e -i "$policy" -p "Please enter policy name " input
policy="${input:-$policy}"
read -e -i "$rule" -p "Please enter rule name " input
rule="${input:-$rule}"
newservices=''
services=''
echo "========================================================================================"
echo -e "\033[1;32mAdding below services to Inventory : \033[0m"
echo "========================================================================================"
 for i in $(cat $file | grep -v " ");
 do 
 protocap=$(echo $i | awk -F '_' '{print $1}') ; 
 protosmall=$(echo $protocap| tr [:upper:] [:lower:]); 
 destport=$(echo $i | awk -F '_' '{print $2}') ;  
 if [[ $(echo $i | grep "[0-9]-[0-9]") ]] ;
 then
 i=R_$i
 fi
 Test=$(curl -u $user:$password -k -X PATCH "https://$fqdn/policy/api/v1/infra/services/$i" -s -d '{"display_name": "'$i'","_revision": 0,"service_entries": [{"resource_type": "L4PortSetServiceEntry","display_name": "'$protosmall'-ports","destination_ports": ["'$destport'"],"l4_protocol": "'$protocap'"}]}' --header "Content-Type: application/json") ; 
 if [ -z $Test ];
 then
 newservices=$newservices" "\"/infra/services/$i\", ;
 echo Service $i is added ;
 else
 echo -e "\033[1;31mCannot get services, something went wrong ! \033[0m"; 
 echo -e $Test  ;
 exit 1
 fi
done
services=$(curl -u $user:$password -k -X GET https://$fqdn/policy/api/v1/infra/domains/default/security-policies/$policy/rules/$rule -s )
if [[ -z $(echo $services | grep "\"services\" :" ) ]] ; 
then 
echo -e "\033[1;31mCannot get services, something went wrong ! \033[0m"; 
echo -e $services  ;
exit 1 ;
else  
echo "========================================================================================" ;
echo -e "\033[1;32mOld services associated with rule $rule (ignoring TCP_65535) :\033[0m" ;
echo "========================================================================================" ;
services=$(echo $services | awk -F '"services" : \\[' '{print $2}' | awk -F ']' '{print $1}'| sed 's+"/infra/services/TCP_65535",++' | sed 's+"/infra/services/TCP_65535"++')
echo -e "$services" | sed 's+/infra/services/++g' ; 
fi 
echo "========================================================================================"
echo -e "\033[1;32mAdding below services to Rule $rule: \033[0m"
echo "========================================================================================"
  if [ "$services" == "  " ] ;
  then
 newservices=${newservices:0:-1} ; 
  fi
  services="\"services\" : [$newservices $services],"
 #services="\"services\" : [ \"\/infra\/services\/R_TCP_1324-2345\" ],"

echo -e $newservices | sed 's+/infra/services/++g'
newjson=$(curl -u $user:$password -k -X GET https://$fqdn/policy/api/v1/infra/domains/default/security-policies/$policy/rules/$rule  -H "Accept: application/json" -s | sed "s+\"services\" :.*+$services+" )
result=$(curl -u $user:$password -k -X PUT https://$fqdn/policy/api/v1/infra/domains/default/security-policies/$policy/rules/$rule -s -d "$newjson" --header "Content-Type: application/json" )
if [[ -z $(echo $result | grep "\"services\" :" ) ]] ; 
then 
echo -e "\033[1;31mCannot get services, something went wrong ! \033[0m"; 
echo -e $result  ;
exit 1 ;
else  
echo "========================================================================================"
echo -e "\033[1;32m New services associated with rule $rule : \033[0m"
echo "========================================================================================"
echo $result | awk -F '"services" : \\[' '{print $2}' | awk -F ']' '{print $1}' | sed 's+/infra/services/++g'
fi