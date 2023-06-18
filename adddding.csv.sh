#!/bin/bash
file=$1
dummyport=TCP_65535
newservices=''
services=''
max_num=128
rule_list="CATCH_APP_TO_INET CATCH_CLOSE_TO_NEAR CATCH_ENI_TO_CLOSE CATCH_INTEGR_APP_TO_EXTRA CATCH_INTEGR_APP_TO_INTRA CATCH_INTEGR_EXTRA_TO_APP CATCH_INTEGR_INTRA_TO_APP CATCH_INTRA_APP CATCH_INTRA_CLOSE CATCH_INTRA_FAR CATCH_INTRA_NEAR CATCH_NEAR_TO_FAR"
getting_services_return=''
cleanup_of_ranges_return=''
checking_related_services_return=''
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
                echo Removing $z as it is within range $y &
                Range=$(echo $Range | sed 's+\<'$z'\>++g')
                break
            fi
        done
    done
    cleanup_of_ranges_return=$Range
}

policy=$(echo $file | awk -F '/' '{print $NF}' | awk -F '-' '{print $3}' | awk -F '.' '{print $1}' )
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
    Rules=$i
    error=0
    range_error=''
    Ranges=$(cat $file |  grep -v "name,Protocol,Port" |  awk -F ']' '{print $2}' | grep CATCH_ | sed 's/CATCH_//g' | grep -w $i | grep "[0-9]-[0-9]" |  awk -F ',' '{print $3"_"$2}' | sort -n | uniq  |  awk -F '_' '{print $2"_"$1}' ) ;
    original_range=$Ranges
    if [[ "$Ranges" ]];
    then
    echo "========================================================================================"
    echo -e "\033[1;32mChecking if there are Ranges of services to be concatinated: \033[0m"
    echo "========================================================================================"
    echo New ranges $Ranges 

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
        if  [[ "$e" == "$f" ]] &&  (( "$c" == "$b+1")) || (( "$c" == "$b"))  ; 
        then 
        Ranges=$(echo $Ranges | sed 's+\<'$x'\>++g' | sed 's+\<'$R'\>+'$e'_'$a'-'$d'+g')
        echo Concatinating $R and $x to $e'_'$a'-'$d
        if [[ "$e" != "$f" ]]
        then
        echo -e "\033[1;31mError here \033[0m";
        error=1
        range_error=$range_error" "$e'_'$a'-'$d
        break
        fi
        fi
        done
    done 
    Ranges=$Ranges" "$old_ranges
    Ranges=$(echo -e $Ranges | tr ' ' '\n' | awk -F '_' '{print $2"_"$1}' | sort -n | uniq | awk -F '_' '{print $2"_"$1}' |  tr '\n' ' ')
    cleanup_of_ranges "$Ranges"
    Ranges=$cleanup_of_ranges_return
    echo New Ranges after concatination $Ranges
    if [[ "$error" == 1 ]]
    then
    echo policy $policy >> error.txt
    echo rule $i >> error.txt
    echo incorrect ranges $range_error >> error.txt
    echo original ranges $original_range >> error.txt
    echo file $file>> error.txt
    fi
    fi
done