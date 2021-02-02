# Infrastructure

## Deploy Security Baseline

TBD

## Prepare the parameters file

In the `deployments` directory, create a new file called `application.params.json` and place the following contents into the file:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
      "appPrefix": { "value": "paasdemo" },
      "vmAdminUserName": { "value": "paasadmin" },
      "vmAdminPwd": { "value": "" },
      "sqlAdminLoginName": { "value": "" },
      "sqlAdminObjectId": { "value": "" },
      "tags": {
        "value": {
          "appId": "paasdemo",
          "costCenter": "abc123"
        }
      }
    }
  }
```

Update the following values:

- `vmAdminPwd`: Set this to a random password
- `sqlAdminLoginName`: Set this to the name of an AAD user or group
- `sqlAdminObjectId`: Use the following Azure CLI command to find the object ID of the user of group:

```bash
az ad user show --id <sqlAdminLoginName> --query objectId --out tsv
```

## Deploy Network and Application Infrastructure

```bash
az login
bicep build network.bicep
az deployment sub create --name networkdeployment --location centralus --template-file network.json --parameters appPrefix=paasdemo
```

Next, run the following command to deploy the Function Premium instance:

```bash
bicep build application.bicep
az deployment sub create --name appdeployment --location centralus --template-file application.json --parameters application.params.json
```

## Deploy Application Code

Because the Function App has been deployed with a Private Link, the Function code must be deployed from within the applicaiton (spoke) virtual network. From the virtual machine deployed to the Utility subnet, nagiavte to the location where you cloned the Git repoistory and run the following command from the `function` directory:

```bash
func azure functionapp publish [function_app_name] --typescript
```
