tfp="azurerm_route_table"
prefixa="rtb"
echo $tfp
if [ "$1" != "" ]; then
    rgsource=$1
else
    echo -n "Enter name of Resource Group [$rgsource] > "
    read response
    if [ -n "$response" ]; then
        rgsource=$response
    fi
fi
azr=`az network route-table list -g $rgsource`
count=`echo $azr | jq '. | length'`
if [ "$count" != "0" ]; then
count=`expr $count - 1`
for i in `seq 0 $count`; do
    name=`echo $azr | jq ".[(${i})].name" | tr -d '"'`
    id=`echo $azr | jq ".[(${i})].id" | tr -d '"'`
    rg=`echo $azr | jq ".[(${i})].resourceGroup" | tr -d '"'`
    routes=`echo $azr | jq ".[(${i})].routes"`
    prefix=`printf "%s_%s" $prefixa $rg`

    printf "resource \"%s\" \"%s__%s\" {\n" $tfp $rg $name > $prefix-$name.tf
    printf "\t name = \"%s\"\n" $name >> $prefix-$name.tf
    printf "\t location = \"\${var.loctarget}\"\n" >> $prefix-$name.tf
    printf "\t resource_group_name = \"%s\"\n" $rg >> $prefix-$name.tf
    #
    # Interate routes
    #
    rcount=`echo $routes | jq '. | length'`
    if [ "$rcount" -gt "0" ]; then
        rcount=`expr $rcount - 1`
        for j in `seq 0 $rcount`; do
            rname=`echo $routes | jq ".[(${j})].name" | tr -d '"'`
            adpr=`echo $routes | jq ".[(${j})].addressPrefix" | tr -d '"'`
            nhtype=`echo $routes | jq ".[(${j})].nextHopType" | tr -d '"'`
            nhaddr=`echo $routes | jq ".[(${j})].nextHopIpAddress" | tr -d '"'`
            printf "\t route { \n" >> $prefix-$name.tf
            printf "\t\t name = \"%s\" \n" $rname >> $prefix-$name.tf
            printf "\t\t address_prefix = \"%s\" \n" $adpr >> $prefix-$name.tf
            printf "\t\t next_hop_type = \"%s\" \n" $nhtype >> $prefix-$name.tf
            if [ "$nhaddr" != "null" ]; then
                printf "\t\t next_hop_in_ip_address = \"%s\" \n" $nhaddr >> $prefix-$name.tf
            fi 
            printf "\t } \n" >> $prefix-$name.tf
        done
    fi
    
    #
    printf "}\n" >> $prefix-$name.tf
    #
    cat $prefix-$name.tf
    statecomm=`printf "terraform state rm %s.%s__%s" $tfp $rg $name`
    eval $statecomm
    evalcomm=`printf "terraform import %s.%s__%s %s" $tfp $rg $name $id`
    eval $evalcomm
    
done
fi