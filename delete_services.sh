#!/bin/bash
fqdn="192.168.0.42"
user="admin"
password="VMware1!VMware1!"
services=''
read -e -i "$u" -p "Please enter U " input
u="${input:-$u}"
for (( i=0 ; i<=$u; i++)) 
do
echo $i
new=$(curl -u $user:$password -k -X GET https://$fqdn/policy/api/v1/infra/services?cursor=0004"$i"000 -s |  grep -A 1 "\"resource_type\" : \"Service\"" | grep \"id\" | grep "[T,U][C,D]P_[0-9]"  | awk -F ':' '{print $2}' | sed 's/"//g' | sed 's/,//g' )
services=$services" "$new
done

echo $services | tr ' ' '\n' | wc -l
#  for i in $(echo $services)
#  do curl -u $user:$password -k -X DELETE https://$fqdn/policy/api/v1/infra/services/$i -s
#  done 



