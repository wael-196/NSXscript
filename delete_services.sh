#!/bin/bash
fqdn="192.168.0.42"
user="admin"
password="VMware1!VMware1!"
services=''
read -e -i "$u" -p "Please enter U " input
u="${input:-$u}"
for (( i=0 ; i<=$u; i++)) 
do
new=$(curl -u $user:$password -k -X GET https://$fqdn/policy/api/v1/infra/services?cursor=0004"$i"000 -s |  grep -A 1 "\"resource_type\" : \"Service\"" | grep \"id\" | grep "[T,U][C,D]P_[0-9]"  | awk -F ':' '{print $2}' | sed 's/"//g' | sed 's/,//g' )
services=$services" "$new
done

total=$(echo $services | tr ' ' '\n' | wc -l)
read -e -i "$lowest" -p "Please enter lowest " input
lowest="${input:-$lowest}"
read -e -i "$highest" -p "Please enter highest " input
highest="${input:-$highest}"
services_to_delete=$(echo $services | tr ' ' '\n' | sed -n ''$lowest','$highest'p' |  tr '\n' ' ' ) 
echo services to be deleted
echo $services_to_delete
read -e -i "$reponse" -p "Please enter Y to accept " input
reponse="${input:-$reponse}"
if [[ $reponse == Y ]]
then
    count=0
    for i in $(echo $services_to_delete )
    do test=$(curl -u $user:$password -k -X DELETE https://$fqdn/policy/api/v1/infra/services/$i -s)
    if [[ ! "$test" ]]
    then 
    echo $i deleted
    count=(($count+1))
    fi
    done 
fi
echo $count

