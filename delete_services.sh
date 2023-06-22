#!/bin/bash
fqdn="192.168.0.42"
user="admin"
password="VMware1!VMware1!"


# services=$(curl -u $user:$password -k -X GET https://$fqdn/policy/api/v1/infra/services -s  )
# # |  grep -A 1 "\"resource_type\" : \"Service\"" | grep \"id\" | grep "[T,U][C,D]P_[0-9]"  | awk -F ':' '{print $2}' | sed 's/"//g' | sed 's/,//g' )
# echo $services
#  for i in $(echo $services)
#  do curl -u $user:$password -k -X DELETE https://$fqdn/policy/api/v1/infra/services/$i -s
#  done 



for x in [1000-100000]
do
 curl -u $user:$password -k -X PATCH "https://$fqdn/policy/api/v1/infra/services/TCP_$x" -s -d '{"display_name": "TCP_'$x'","_revision": 0,"service_entries": [{"resource_type": "L4PortSetServiceEntry","display_name": "tcp-ports","destination_ports": ["'$x'"],"l4_protocol": "TCP"}]}' --header "Content-Type: application/json" ; )
done