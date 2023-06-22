#!/bin/bash
fqdn="192.168.0.42"
user="admin"
password="VMware1!VMware1!"


curl -u $user:$password -k -X GET https://$fqdn/policy/api/v1/infra/services/ -s  |  grep -A 1 "\"resource_type\" : \"Service\"" | grep \"id\" | grep "[T,U][C,D]P_[0-9]" 

# for i in $(echo $services)
# do curl -u $user:$password -k -X DELETE https://$fqdn/policy/api/v1/infra/services/$i -s
# done 