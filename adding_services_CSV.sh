#!/bin/bash
fqdn="192.168.0.42"
user="admin"
password="VMware1!VMware1!"
file=$1
dummyport=TCP_65535
newservices=''
services=''
flow=""
max_num=120
if [[ "$file" ]];
then 
policy=$(echo $file | awk -F '-' '{print $3}' | awk -F '.' '{print $1}' )
 policy=default-layer3-section
echo "========================================================================================"
echo -e "Processing flow of policy $policy and removing duplicates: "
echo "========================================================================================"
for i in $(cat $file |  grep -v "name,Protocol,Port" |  awk -F ']' '{print $2}' | sort -n | uniq | sed 's/ //g' | sed 's/"//g' );
do rule=$(echo $i | awk  -F ',' '{for(i=3; i<=NF; i++) {print $i}}' | grep  CATCH_* | sed 's/CATCH_//g');
# echo $i
# echo "rule=$rule" ;
protocap=$(echo $i | awk -F ',' '{print $2}');
# echo "protocap=$protocap" ;
destport=$(echo $i | awk -F ',' '{print $3}') ; 
# echo "destport=$destport" ;
for t in $(echo $rule); do flow=$destport"*"$protocap"*"$t"*""\n"$flow ; done 
done
echo "========================================================================================" ;
echo -e "\033[1;32mNon Zero Rules: \033[0m" ;
echo "========================================================================================" ;
echo -e $flow | sed '/^$/d' | awk -F '*' '{print $3}' | sort | uniq 

for i in $(echo -e $flow | sed '/^$/d' | awk -F '*' '{print $3}' | sort | uniq  ); 
do 
# if [[ "$i" == "INTEGR_APP_TO_INTRA" ]]
# then
echo "========================================================================================" ;
echo -e "\033[1;32mWorking on rule $i :\033[0m" ;
echo "========================================================================================" ;
services=$(curl -u $user:$password -k -X GET https://$fqdn/policy/api/v1/infra/domains/default/security-policies/$policy/rules/$i -s )
if [[ -z $(echo $services | grep "\"services\" :" ) ]] ; 
then 
echo -e "\033[1;31mCannot get services, something went wrong ! \033[0m"; 
echo -e $services  ;
exit 1 ;
else  
echo "========================================================================================" ;
echo -e "\033[1;32mOld services associated with rule $i (ignoring $dummyport) :\033[0m" ;
echo "========================================================================================" ;
services=$(echo $services | awk -F '"services" : \\[' '{print $2}' | awk -F ']' '{print $1}'| sed 's+"/infra/services/'$dummyport'",++' | sed 's+"/infra/services/'$dummyport'"++')
echo -e $services | sed 's+/infra/services/++g'
fi
newservices='';
Ranges=$(echo -e $flow | sed '/^$/d' | grep \*$i\* | grep "[0-9]-[0-9]" | sort -n | uniq |  awk -F '*' '{print $2"_"$1}' ) ;
if [[ "$Ranges" ]];
then
echo "========================================================================================"
echo -e "\033[1;32mChecking if there are Ranges of services to be concatinated: \033[0m"
echo "========================================================================================"
echo Ranges found $Ranges

for z in $(echo $Ranges) ; do 
e=$(echo $z | awk -F '_' '{print $2}'| awk -F '-' '{print $1}')
f=$(echo $z | awk -F '_' '{print $2}'| awk -F '-' '{print $2}')
protocap=$(echo $z | awk -F '_' '{print $1}')
for y in $(echo $Ranges) ; do
a=$(echo $y | awk -F '_' '{print $2}' | awk -F '-' '{print $1}');
b=$(echo $y | awk -F '_' '{print $2}' | awk -F '-' '{print $2}');
c=$(echo $y | awk -F '_' '{print $1}') ;
if [[ "$z" != "$y" ]] && (( "$e" >= "$a")) && (( "$f" <= "$b"))  && [[ "$c" == "$protocap" ]] ; 
then 
echo Removing $z as it is within range $y
Ranges=$(echo $Ranges | sed 's+\<'$z'\>++g')
fi
done
done
for x in $(echo $Ranges ) ; 
do 
c=$(echo  $x | awk -F '_' '{print $2}'| awk -F '-' '{print $1}') ;
d=$(echo  $x | awk -F '_' '{print $2}'| awk -F '-' '{print $2}');
e=$(echo  $x | awk -F '_' '{print $1}');
for R in $(echo  $Ranges ) ; 
do a=$(echo  $R | awk -F '_' '{print $2}'| awk -F '-' '{print $1}');
b=$(echo  $R | awk -F '_' '{print $2}' | awk -F '-' '{print $2}');
f=$(echo  $R | awk -F '_' '{print $1}');
if  [[ "$e" == "$f" ]] && (( "$c" == "$b+1")) || (( "$c" == "$b")) ; 
then 
Ranges=$(echo $Ranges | sed 's+\<'$x'\>++g' | sed 's+\<'$R'\>+'$e'_'$a'-'$d'+g')
echo Concatinating $R and $x to $e'_'$a'-'$d
break
fi
done
done 

for z in $(echo $Ranges) ; do 
e=$(echo $z | awk -F '_' '{print $2}'| awk -F '-' '{print $1}')
f=$(echo $z | awk -F '_' '{print $2}'| awk -F '-' '{print $2}')
protocap=$(echo $z | awk -F '_' '{print $1}')
for y in $(echo $Ranges) ; do
a=$(echo $y | awk -F '_' '{print $2}' | awk -F '-' '{print $1}');
b=$(echo $y | awk -F '_' '{print $2}' | awk -F '-' '{print $2}');
c=$(echo $y | awk -F '_' '{print $1}') ;
if [[ "$z" != "$y" ]] && (( "$e" >= "$a")) && (( "$f" <= "$b"))  && [[ "$c" == "$protocap" ]] ; 
then 
echo Removing $z as it is within range $y
Ranges=$(echo $Ranges | sed 's+\<'$z'\>++g')
fi
done
done

echo New Ranges $Ranges
fi

echo "========================================================================================"
echo -e "\033[1;32mAdding below services to Inventory and Rule $i: \033[0m"
echo "========================================================================================"
for x in $(echo -e $flow | sed '/^$/d' | grep \*$i\* | sort -n  | uniq  | awk -F '*' '{print $2"_"$1}'  ) ; 
do 
protocap=$(echo $x | awk -F '_' '{print $1}');
protosmall=$(echo $protocap | tr [:upper:] [:lower:]);
destport=$(echo $x | awk -F '_' '{print $2}');
Test='';
within=0
if [[ "$Ranges" ]];
then
firstnum=$(echo $Ranges | awk '{print $1}' | awk -F '_' '{print $2}' | awk -F '-' '{print $1}')
if [[ ! $(echo $destport | grep "-") ]] && (( "$destport" >= "$firstnum" ))
then
for R in $(echo $Ranges) ; 
do 
a=$(echo $R | awk -F '_' '{print $2}' | awk -F '-' '{print $1}');
b=$(echo $R | awk -F '_' '{print $2}' | awk -F '-' '{print $2}');
c=$(echo $R | awk -F '_' '{print $1}') ;
if (("$destport" <= "$b")) && (("$destport" >= "$a")) && [[ "$c" == "$protocap" ]];
then
echo Ignore Adding $x as it is within Range R_$c"_"$a"-"$b;
within=1 ;
break
fi
done
fi
fi

if [[ ! $(echo $destport | grep "-") ]] && (( "$within" == "0" )) ;
then
Test=$(curl -u $user:$password -k -X PATCH "https://$fqdn/policy/api/v1/infra/services/$x" -s -d '{"display_name": "'$x'","_revision": 0,"service_entries": [{"resource_type": "L4PortSetServiceEntry","display_name": "'$protosmall'-ports","destination_ports": ["'$destport'"],"l4_protocol": "'$protocap'"}]}' --header "Content-Type: application/json" ; )
newservices=$newservices" "\"/infra/services/$x\", ;
if [[ "$Test" ]];
then
echo -e "\033[1;31mCannot get services, something went wrong ! \033[0m"; 
echo -e $Test  ;
exit 1
else
echo Service $x is added ;
fi
fi
done

for x in $(echo $Ranges) ; 
do 
protocap=$(echo $x | awk -F '_' '{print $1}');
protosmall=$(echo $protocap | tr [:upper:] [:lower:]);
destport=$(echo $x | awk -F '_' '{print $2}');
x=R_$x
Test=$(curl -u $user:$password -k -X PATCH "https://$fqdn/policy/api/v1/infra/services/$x" -s -d '{"display_name": "'$x'","_revision": 0,"service_entries": [{"resource_type": "L4PortSetServiceEntry","display_name": "'$protosmall'-ports","destination_ports": ["'$destport'"],"l4_protocol": "'$protocap'"}]}' --header "Content-Type: application/json" ; )
newservices=$newservices" "\"/infra/services/$x\", ;
if [[ "$Test" ]];
then
echo -e "\033[1;31mCannot get services, something went wrong ! \033[0m"; 
echo -e $Test  ;
exit 1
else
echo Service $x is added ;
fi
done
new_service_number=$(echo "$newservices" | sed 's/,//g'  |tr ' ' '\n' |  sort | uniq | grep infra | wc -l  )
services_number=$(echo "$newservices $services" | sed 's/,//g'  |tr ' ' '\n' |  sort | uniq | grep infra | wc -l  ) 
echo -e "Totale of $new_service_number services were added"

if (( "$services_number" <= "$max_num" ))
then
yy=$newservices" "$services
total_service=$(echo $yy | sed 's/,//g' | sed 's/ /, /g' )
services="\"services\" : [$total_service],"
# services="\"services\" : [ \"\/infra\/services\/TCP_65535\" ],"
else
echo -e "\033[1;31mNumber of services has exceeded maximum size $max_num adding, first 120 services \033[0m";
lastservices_count=$(( $services_number-$max_num ))
first120=$(echo -e "$newservices $services" | sed 's/,//g' | tr ' ' '\n' | sort | uniq | grep infra | head -n $max_num |  tr '\n' ' ' | sed 's/ /, /g' )
first120=${first120:0:-2}
lastservices=$(echo -e "$newservices $services" | sed 's/,//g' | tr ' ' '\n' | sort | uniq | grep infra | tail -n $lastservices_count |  tr '\n' ' ' | sed 's/ /, /g' )
lastservices=${lastservices:0:-2}
# echo $lastservices
services="\"services\" : [ $first120 ],"
read -e -i "$new_rule" -p "Please enter the new rule name to add the remaining $lastservices_count services : " input
new_rule="${input:-$new_rule}"
fi

newjson=$(curl -u $user:$password -k -X GET https://$fqdn/policy/api/v1/infra/domains/default/security-policies/$policy/rules/$i  -H "Accept: application/json" -s | sed "s+\"services\" :.*+$services+" )
result=$(curl -u $user:$password -k -X PUT https://$fqdn/policy/api/v1/infra/domains/default/security-policies/$policy/rules/$i -s -d "$newjson" --header "Content-Type: application/json" )



if [[ -z $(echo $result | grep "\"services\" :" ) ]] ; 
then 
echo -e "\033[1;31mCannot get services, something went wrong ! \033[0m"; 
echo -e $result  ;
exit 1 ;
else  
echo "========================================================================================"
echo -e "\033[1;32mNew services associated with rule $i : \033[0m"
echo "========================================================================================"
echo $result | awk -F '"services" : \\[' '{print $2}' | awk -F ']' '{print $1}' | sed 's+/infra/services/++g'
fi



# fi

done 

else 
echo -e "\033[1;31mWrong file name, please add a file ! \033[0m"; 
fi