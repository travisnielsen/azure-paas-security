# VARIABLES
export MGMT_GROUP=<add_management_group_name_here>

az login

# CREATE POLICIES

az policy definition create --name 'network-internalonly-storage'    \
--display-name 'Storage: Allow only approved internal network access' \
--description 'Enforces Storage Account with a private configuration with network-level access only to approved IP addresses and Azure subnets'    \
--mode Indexed  \
--metadata 'category=security'   \
--rules policies/network-acl-storage.json   \
--params policies/params.json   \
--management-group $MGMT_GROUP

az policy definition create --name 'network-internalonly-keyvault'    \
--display-name 'Key Vault: Allow only approved internal network access' \
--description 'Enforces Key Vault instances with a private configuration with network-level access only to approved IP addresses and Azure subnets'    \
--mode Indexed  \
--metadata 'category=security'   \
--rules policies/network-acl-keyvault.json   \
--params policies/params.json   \
--management-group $MGMT_GROUP

az policy definition create --name 'network-internalonly-eventhub'    \
--display-name 'Event Hub: Allow only approved internal network access' \
--description 'Enforces Event Hubs are in a private configuration with network-level access only to approved IP addresses and Azure subnets'    \
--mode Indexed  \
--metadata 'category=security'   \
--rules policies/network-acl-eventhub.json  \
--params policies/params.json   \
--management-group $MGMT_GROUP

az policy definition create --name 'network-internalonly-cosmosdb'    \
--display-name 'Cosmos DB: Allow only approved internal network access' \
--description 'Enforces Cosmos DB instances are in a private configuration with network-level access only to approved IP addresses and Azure subnets'    \
--mode Indexed  \
--metadata 'category=security'   \
--rules policies/network-acl-cosmosdb.json  \
--params policies/params-cosmosdb.json  \
--management-group $MGMT_GROUP

az policy definition create --name 'network-nsg-enforceOutboundFlows'    \
--display-name 'NSGs: Allow only approved outbound destinations' \
--description 'Requires NSG rules to only allow outbound traffic to approved NSG tags and whitelisted CIDR blocks'    \
--mode All  \
--metadata 'category=security'   \
--rules policies/network-nsg-outboundRules.json  \
--params policies/params-nsg.json  \
--management-group $MGMT_GROUP

az policy definition create --name 'network-nsg-denyAnyOutboundFlows'    \
--display-name 'NSGs: Deny outbound rules with target address of Internet or wildcard.' \
--description 'Prevents creation of NSG rules that have a destination tag of Internet or *'    \
--mode All  \
--metadata 'category=security'   \
--rules policies/network-nsg-denyAnyOutbound.json  \
--management-group $MGMT_GROUP


# CREATE INITIATIVE AND ADD POLICIES
# Currently must be done via the Azure Portal
# For Cosmos DB, add IP addresses per this document to allow Portal access: https://docs.microsoft.com/en-us/azure/cosmos-db/how-to-configure-firewall#allow-requests-from-the-azure-portal


# CREATE ASSIGNMENT TO INITIATIVE

