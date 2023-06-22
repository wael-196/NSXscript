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
echo $services
read -e -i "$protocol" -p "Please enter protocol " input
protocol="${input:-$protocol}"
read -e -i "$lowest" -p "Please enter lowest " input
lowest="${input:-$lowest}"
read -e -i "$highest" -p "Please enter highest " input
highest="${input:-$highest}"
services_to_delete=''
for (( l=$lowest ; l<=$highest ; l++))
do 
$port=$protocol'_'$l
if [[ $(grep -w $port) ]]
then
services_to_delete=$services_to_delete" "$port 
fi
done
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
    let count=$count+1
    fi
    done 
fi
echo $count services were deleted 

