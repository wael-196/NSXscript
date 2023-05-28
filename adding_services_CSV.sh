#!/bin/bash
fqdn="192.168.0.42"
user="admin"
password="VMware1!VMware1!"
file=$1
dummyport=TCP_65535
newservices=''
services=''
flow=""
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
for t in $(echo $rule); do flow=$protocap"*"$destport"*"$t"*""\n"$flow ; done 
done
echo -e $flow 
echo "========================================================================================" ;
echo -e "\033[1;32mNon Zero Rules: \033[0m" ;
echo "========================================================================================" ;
echo -e $flow | sed '/^$/d' | awk -F '*' '{print $3}' | sort -n | uniq

for i in $(echo -e $flow | sed '/^$/d' | awk -F '*' '{print $3}' | sort -n | uniq ); 
do echo "========================================================================================" ;
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
echo "========================================================================================"
echo -e "\033[1;32mAdding below services to Inventory and Rule $i: \033[0m"
echo "========================================================================================"
Ranges=$(echo -e $flow | sed '/^$/d' | grep \*$i\* | grep "[0-9]-[0-9]" | awk -F '*' '{print $1"_"$2}' | sort -n | uniq) ;
if [[ "$Ranges" ]];
then
echo "========================================================================================"
echo -e "\033[1;32mChecking if there are Ranges of services to be concatinated: \033[0m"
echo "========================================================================================"
echo Ranges found $Ranges
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
Ranges=$(echo $Ranges | sed 's+'$x'++' | sed 's+'$R'+'$e'_'$a'-'$d'+')
echo Concatinating $R and $x
break
fi
done
done 
fi
wael=$(echo -e $flow | sed '/^$/d' | grep \*$i\* | awk -F '*' '{print $1"_"$2}' | sort -n | uniq )
echo wael $wael 
ecit 1
for x in $(echo -e $flow | sed '/^$/d' | grep \*$i\* | awk -F '*' '{print $1"_"$2}' | sort -n | uniq ) ; 
do 
echo $x
protocap=$(echo $x | awk -F '_' '{print $1}');
protosmall=$(echo $protocap | tr [:upper:] [:lower:]);
destport=$(echo $x | awk -F '_' '{print $2}');
e=$(echo $destport | awk -F '-' '{print $1}')
f=$(echo $destport | awk -F '-' '{print $2}')
Test='';
within=0
if [[ "$Ranges" ]];
then
for R in $(echo $Ranges) ; 
do 
a=$(echo $R | awk -F '_' '{print $2}' | awk -F '-' '{print $1}');
b=$(echo $R | awk -F '_' '{print $2}' | awk -F '-' '{print $2}');
c=$(echo $R | awk -F '_' '{print $1}') ;
# echo $a , $b , $c , $e , $f , $protocap
if [[ ! $(echo $x | grep "-") ]] && (("$destport" <= "$b")) && (("$destport" >= "$a")) && [[ "$c" == "$protocap" ]];
then
echo Ignore Adding $x as it is within Range $c"_"$a"-"$b;
within=1 ;
break
fi
done
fi

if [[ ! $(echo $x | grep "-") ]] && (( "$within" == "0" )) ;
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

if [[ "$Ranges" ]];
then
within=0
for z in $(echo $Ranges) ; do 
e=$(echo $z | awk -F '_' '{print $2}'| awk -F '-' '{print $1}')
f=$(echo $z | awk -F '_' '{print $2}'| awk -F '-' '{print $2}')
protocap=$(echo $z | awk -F '_' '{print $1}')
destport=$(echo $z | awk -F '_' '{print $2}')
protosmall=$(echo $protocap | tr [:upper:] [:lower:] )
for y in $(echo $Ranges) ; do
a=$(echo $y | awk -F '_' '{print $2}' | awk -F '-' '{print $1}');
b=$(echo $y | awk -F '_' '{print $2}' | awk -F '-' '{print $2}');
c=$(echo $y | awk -F '_' '{print $1}') ;

if  (( "$f" < "$b")) && (( "$e" > "$a")) && [[ "$c" == "$protocap" ]] ; 
then 
echo Ignore Adding R_$z as it is within Range $c"_"$a"-"$b;
within=1 ;
break
elif (( "$f" <= "$b")) && (( "$e" > "$a")) && [[ "$c" == "$protocap" ]] ; 
then 
echo Ignore Adding R_$z as it is within Range $c"_"$a"-"$b;
within=1 ;
break
elif (( "$f" < "$b")) && (( "$e" >= "$a")) && [[ "$c" == "$protocap" ]] ; 
then 
echo Ignore Adding R_$z as it is within Range $c"_"$a"-"$b;
within=1 ;
break
fi
done

if (( "$within" == "0" ));
then
z=R_$z;
Test=$(curl -u $user:$password -k -X PATCH "https://$fqdn/policy/api/v1/infra/services/$z" -s -d '{"display_name": "'$z'","_revision": 0,"service_entries": [{"resource_type": "L4PortSetServiceEntry","display_name": "'$protosmall'-ports","destination_ports": ["'$destport'"],"l4_protocol": "'$protocap'"}]}' --header "Content-Type: application/json" ; )
newservices=$newservices" "\"/infra/services/$z\", ;
if [[ "$Test" ]];
then
echo -e "\033[1;31mCannot get services, something went wrong ! \033[0m"; 
echo -e $Test  ;
exit 1
else
echo Service $z is added ;
fi
fi

done
fi



if [ "$services" == "  " ] ; 
then
newservices=${newservices:0:-1} ; 
fi
services="\"services\" : [$newservices $services],"
newjson=$(curl -u $user:$password -k -X GET https://$fqdn/policy/api/v1/infra/domains/default/security-policies/$policy/rules/$i  -H "Accept: application/json" -s | sed "s+\"services\" :.*+$services+" )
result=$(curl -u $user:$password -k -X PUT https://$fqdn/policy/api/v1/infra/domains/default/security-policies/$policy/rules/$i -s -d "$newjson" --header "Content-Type: application/json" )
echo $newjson
if [[ -z $(echo $result | grep "\"services\" :" ) ]] ; 
then 
echo -e "\033[1;31mCannot get services, something went wrong ! \033[0m"; 
echo -e $result  ffff ;
exit 1 ;
else  
echo "========================================================================================"
echo -e "\033[1;32mNew services associated with rule $i : \033[0m"
echo "========================================================================================"
echo $result | awk -F '"services" : \\[' '{print $2}' | awk -F ']' '{print $1}' | sed 's+/infra/services/++g'
fi
done 
else 
echo -e "\033[1;31mWrong file name, please add a file ! \033[0m"; 
fi