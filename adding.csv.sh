#!/bin/bash
fqdn="192.168.0.42"
user="admin"
password="VMware1!VMware1!"
file=$1
dummyport=TCP_65535
newservices=''
services=''
flow=""
max_num=128
rule_list="CATCH_APP_TO_INET CATCH_CLOSE_TO_NEAR CATCH_ENI_TO_CLOSE CATCH_INTEGR_APP_TO_EXTRA CATCH_INTEGR_APP_TO_INTRA CATCH_INTEGR_EXTRA_TO_APP CATCH_INTEGR_INTRA_TO_APP CATCH_INTRA_APP CATCH_INTRA_CLOSE CATCH_INTRA_FAR CATCH_INTRA_NEAR CATCH_NEAR_TO_FAR"
getting_services_return=''
cleanup_of_ranges_return=''
checking_related_services_return=''

adding_services_to_inventory(){
local protosmall=$(echo $2 | tr [:upper:] [:lower:]);
local Test=$(curl -u $user:$password -k -X PATCH "https://$fqdn/policy/api/v1/infra/services/$1" -s -d '{"display_name": "'$1'","_revision": 0,"service_entries": [{"resource_type": "L4PortSetServiceEntry","display_name": "'$protosmall'-ports","destination_ports": ["'$3'"],"l4_protocol": "'$2'"}]}' --header "Content-Type: application/json" ; )
newservices=$newservices" "\"/infra/services/$1\", ;
if [[ "$Test" ]];
then
echo -e "\033[1;31mCannot get services, something went wrong ! \033[0m"; 
echo -e $Test  ;
exit 1
else
echo Service $1 is added ;
fi
}


adding_services(){
    newjson=$(curl -u $user:$password -k -X GET https://$fqdn/policy/api/v1/infra/domains/default/security-policies/$policy/rules/$1  -H "Accept: application/json" -s | sed "s+\"services\" :.*+$2+" )
    result=$(curl -u $user:$password -k -X PUT https://$fqdn/policy/api/v1/infra/domains/default/security-policies/$policy/rules/$1 -s -d "$newjson" --header "Content-Type: application/json" )
    echo "========================================================================================"
    echo -e "\033[1;32mNew services associated with rule $1 : \033[0m"
    echo "========================================================================================"
    if [[ -z $(echo $result | grep "\"services\" :" ) ]] ; 
    then 
    echo -e "\033[1;31mCannot get services, please make sure that the new rule is already created \033[0m"; 
    echo -e $result  ;
    exit 1 ;
    else  
    echo $result | awk -F '"services" : \\[' '{print $2}' | awk -F ']' '{print $1}' | sed 's+/infra/services/++g'
    fi
}

getting_services(){
    local x=$(curl -u $user:$password -k -X GET https://$fqdn/policy/api/v1/infra/domains/default/security-policies/$policy/rules/$1 -s )
    if [[ -z $(echo $x | grep "\"services\" :" ) ]] ; 
    then 
        echo -e "\033[1;31mCannot get services, something went wrong ! \033[0m"; 
        echo -e $x  ;
        exit 1 ;
    else  
        echo "========================================================================================" ;
        echo -e "\033[1;32mOld services associated with rule $1 (ignoring $dummyport) :\033[0m" ;
        echo "========================================================================================" ;
        getting_services_return=$(echo $x | awk -F '"services" : \\[' '{print $2}' | awk -F ']' '{print $1}'| sed 's+"/infra/services/'$dummyport'",++' | sed 's+"/infra/services/'$dummyport'"++')
        echo -e $getting_services_return | sed 's+/infra/services/++g'
fi

}


cleanup_of_ranges(){
    local Range=$1
    for z in $(echo $Range) ; do 
        local e=$(echo $z | awk -F '_' '{print $2}'| awk -F '-' '{print $1}')
        local f=$(echo $z | awk -F '_' '{print $2}'| awk -F '-' '{print $2}')
        local protocap=$(echo $z | awk -F '_' '{print $1}')
        for y in $(echo $Range) ; do
            local a=$(echo $y | awk -F '_' '{print $2}' | awk -F '-' '{print $1}');
            local b=$(echo $y | awk -F '_' '{print $2}' | awk -F '-' '{print $2}');
            local c=$(echo $y | awk -F '_' '{print $1}') ;
            if [[ "$z" != "$y" ]] && (( "$e" >= "$a")) && (( "$f" <= "$b"))  && [[ "$c" == "$protocap" ]] ; 
            then 
                echo Removing $z as it is within range $y
                Range=$(echo $Range | sed 's+\<'$z'\>++g')
                break
            fi
        done
    done
    cleanup_of_ranges_return=$Range
}


checking_related_services(){

    checking_related_services_return=$( curl -u $user:$password -k -X GET https://$fqdn/policy/api/v1/infra/domains/default/security-policies/$policy/rules/ -s | grep "\"id\"" | awk -F ': "' '{print $2}' | awk -F '",' '{print $1}' | grep -w "$1"-"[0-9]\|$1"_"[0-9]" | sort )
}

if [[ "$file" ]];
then 
policy=$(echo $file | awk -F '-' '{print $3}' | awk -F '.' '{print $1}' )
policy=default-layer3-section
echo "========================================================================================"
echo -e "Working on firewall policy $policy : "
echo "========================================================================================"
non_zero_list=''

#getting list of non zero rules 

for i in $(echo $rule_list )
do if [[ $(grep -w $i $file) ]]; then non_zero_list="$non_zero_list $i" ; fi
done 
echo "========================================================================================" ;
echo -e "\033[1;32mNon Zero Rules: \033[0m" ;
echo "========================================================================================" ;
echo -e $non_zero_list | sed 's/CATCH_//g' | tr ' ' '\n'

# working on rules 

for i in $(echo $non_zero_list |  sed 's/CATCH_//g' ); 
do 
echo "========================================================================================" ;
echo -e "\033[1;32mWorking on rule $i :\033[0m" ;
echo "========================================================================================" ;
services=''
newservices=''
checking_related_services "$i"
if [[ "$checking_related_services_return" ]]
then 
echo Found related rules $checking_related_services_return
fi
Rules=$i" "$checking_related_services_return

for l in $(echo $Rules)
do
getting_services "$l"
services=$services" "$getting_services_return
done

old_ranges=$(echo -e $services | sed 's+/infra/services/++g' | sed 's+,++g' | sed 's+"++g' | sed 's+R_++g' | tr ' ' '\n' | grep "[0-9]-[0-9]" | tr '\n' ' '   )

Ranges=$(cat $file |  grep -v "name,Protocol,Port" |  awk -F ']' '{print $2}' | grep CATCH_ | sed 's/CATCH_//g' | grep -w $i | grep "[0-9]-[0-9]" |  awk -F ',' '{print $3"_"$2}' | sort -n | uniq  |  awk -F '_' '{print $2"_"$1}' ) ;
if [[ "$Ranges" ]] || [ "$old_ranges" ];
then
echo "========================================================================================"
echo -e "\033[1;32mChecking if there are Ranges of services to be concatinated: \033[0m"
echo "========================================================================================"
echo New ranges $Ranges 
echo Old ranges $old_ranges

#cleanup before concatination of ranges 
cleanup_of_ranges "$Ranges"
Ranges=$cleanup_of_ranges_return



#concatination of ranges 

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

# adding old ranges at this stage along with new ranges 
#another cleanup after concatination of ranges 

Ranges=$Ranges" "$old_ranges
Ranges=$(echo -e $Ranges | tr ' ' '\n' | awk -F '_' '{print $2"_"$1}' | sort -n | uniq | awk -F '_' '{print $2"_"$1}' |  tr '\n' ' ')
cleanup_of_ranges "$Ranges"
Ranges=$cleanup_of_ranges_return

echo New Ranges after concatination $Ranges
fi


#adding services to inventory 

echo "========================================================================================"
echo -e "\033[1;32mAdding below services to Inventory and Rule $i: \033[0m"
echo "========================================================================================"
for x in $(cat $file |  grep -v "name,Protocol,Port" |  awk -F ']' '{print $2}' | grep CATCH_ | sed 's/CATCH_//g' | grep -w $i   |  awk -F ',' '{print $3"_"$2}' | sort -n | uniq  |  awk -F '_' '{print $2"_"$1}' ) ; 
do 
protocap=$(echo $x | awk -F '_' '{print $1}');
destport=$(echo $x | awk -F '_' '{print $2}');
Test='';
within=0
if [[ "$Ranges" ]];
then
firstnum=$(echo $Ranges | awk '{print $1}' | awk -F '_' '{print $2}' | awk -F '-' '{print $1}')
if [[ ! $(echo $destport | grep "-") ]] && (( "$destport" >= "$firstnum" ))
then
for R in $(echo $Ranges)
do 
a=$(echo $R | awk -F '_' '{print $2}' | awk -F '-' '{print $1}') &
b=$(echo $R | awk -F '_' '{print $2}' | awk -F '-' '{print $2}') &
c=$(echo $R | awk -F '_' '{print $1}') &
if (("$destport" <= "$b")) && (("$destport" >= "$a")) && [[ "$c" == "$protocap" ]] 
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
adding_services_to_inventory "$x" "$protocap" "$destport"
fi
done

for x in $(echo $Ranges) ; 
do 
protocap=$(echo $x | awk -F '_' '{print $1}');
destport=$(echo $x | awk -F '_' '{print $2}');
x=R_$x
adding_services_to_inventory "$x" "$protocap" "$destport"
done

new_service_number=$(echo "$newservices" | sed 's/,//g'  |tr ' ' '\n' |  sort | uniq | grep infra | wc -l  )
services_number=$(echo "$newservices $services" | sed 's/,//g'  |tr ' ' '\n' |  sort | uniq | grep infra | wc -l  ) 
echo -e "Total of $new_service_number services were added"
#adding services to rules

iterations=$(( $services_number / $max_num ))
iterations=$(($iterations + 1 ))
lastservices_count=$(( $services_number % $max_num ))
lowest=1
highest=0
for ((f=1;f<=$iterations;f++)) do 
if [[ "$f" == "$iterations" ]]
then
    highest=$(($highest + $lastservices_count))
else
    highest=$(($highest + $max_num))
fi
if (( "$lowest" <= "$highest" ))
then
    total_service=$(echo -e "$newservices $services" | sed 's/,//g' | tr ' ' '\n' | sort | uniq | grep infra | sed -n ''$lowest','$highest'p' | tr '\n' ' ' | sed 's/ /, /g')
    total_service=${total_service:0:-2}
    services2="\"services\" : [ $total_service ],"
    if (( "$f" > 1 )) 
    then
        echo -e "\033[1;31mNumber of services has exceeded maximum size $max_num \033[0m";
        read -e -i "$new_rule" -p "Please enter the new rule name to add services from $lowest to $highest, please make sure that the new rule is already created : " input
        new_rule="${input:-$new_rule}"
        i=$new_rule
        getting_services "$i"
    fi
    adding_services "$i" "$services2"
    lowest=$(($lowest + $max_num)) 
fi
done
done 
else 
echo -e "\033[1;31mWrong file name, please add a file ! \033[0m"; 
fi

