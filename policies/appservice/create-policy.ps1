$MGMT_GROUP="trniel"
az policy definition create --name 'network-appsvc-acl' `
--display-name 'App Service: Enforce only explicit network allow (including scm urls)' `
--description 'Enforces App Service instances are in a private configuration with network-level access only to approved IP addresses and Azure subnets'    `
--mode Indexed  `
--rules network-appsvc-acl.json   `
 --params policy-params.json   `
--management-group $MGMT_GROUP
