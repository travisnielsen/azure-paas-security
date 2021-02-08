#! /bin/bash

function remove-ResourceGroup {
    exists=$(az group exists --name $1)

    if [ "$exists" = true ] 
        then 
            echo 'Group' $1 'exists - removing...'
            az group delete --name $1 --yes --no-wait
        else echo 'Group' $1 'does not exist - I guess I''ll do nothing...'
    fi
}

if [ -z "$1" ]
    then echo 'No scope provided. Nothing to do. :('
    else 
        if [ "$1" = "all" ]
            then 
                remove-ResourceGroup paasdemo-util 
                remove-ResourceGroup paasdemo-app
                remove-ResourceGroup paasdemo-data
                remove-ResourceGroup paasdemo-network
            else 
                remove-ResourceGroup $1
        fi
fi



