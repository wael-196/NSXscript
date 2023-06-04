#!/bin/bash
rule_list="CATCH_APP_TO_INET CATCH_CLOSE_TO_NEAR CATCH_INTEGR_APP_TO_EXTRA CATCH_INTEGR_APP_TO_INTRA CATCH_INTEGR_EXTRA_TO_APP CATCH_INTEGR_INTRA_TO_APP CATCH_INTRA_APP CATCH_INTRA_NEAR CATCH_NEAR_TO_FAR"
for i in $(echo $rule_list |  sed 's/CATCH_//g' ); 
services="\"services\" : [ \"\/infra\/services\/TCP_65535\" ],"
newjson=$(curl -u $user:$password -k -X GET https://$fqdn/policy/api/v1/infra/domains/default/security-policies/$policy/rules/$i  -H "Accept: application/json" -s | sed "s+\"services\" :.*+$services+" )
result=$(curl -u $user:$password -k -X PUT https://$fqdn/policy/api/v1/infra/domains/default/security-policies/$policy/rules/$i -s -d "$newjson" --header "Content-Type: application/json" )
done 