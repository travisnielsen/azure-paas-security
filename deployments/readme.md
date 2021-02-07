# Infrastructure

## Deploy Security Baseline

TBD

## Deploy Core Infrastructure

In the `deployments` directory, create a new file called `core.params.json` and place the following contents into the file:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
      "appPrefix": { "value": "contoso" },
      "vmAdminUserName": { "value": "contosoadmin" },
      "vmAdminPwd": { "value": "" },
      "tags": {
        "value": {
          "appId": "contoso",
          "costCenter": "abc123"
        }
      }
    }
  }
```

Update the following values:

- `vmAdminPwd`: Set this to a random password

```bash
az login
bicep build core.bicep
az deployment sub create --name core --location centralus --template-file core.json --parameters appPrefix=contoso
```

## Deploy Data Infrastructure

In the `deployments` directory, create a new file called `data.params.json` and place the following contents into the file:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
      "appPrefix": { "value": "contoso" },
      "sqlAdminLoginName": { "value": "" },
      "sqlAdminLoginPwd": { "value": "" },
      "sqlAdminObjectId": { "value": "" },
      "tags": {
        "value": {
          "appId": "contoso",
          "costCenter": "abc123"
        }
      }
    }
}
```

Update the following values:

- `sqlAdminLoginName`: Set this to the name of an AAD user or group
- `sqlAdminLoginPwd`: Set this to a random password
- `sqlAdminObjectId`: Use the following Azure CLI command to find the object ID of the user of group:

  ```bash
  az ad user show --id <sqlAdminLoginName> --query objectId --out tsv
  ```

Next, run the following command to deploy the data tier:

```bash
bicep build data.bicep
az group create --name contoso-data --location centralus
az deployment group create --resource-group contoso-data --name datatier --template-file data.json --parameters data.params.json
```

## Deploy Application Code

Because the Function App has been deployed with a Private Link, the Function code must be deployed from within the applicaiton (spoke) virtual network. From the virtual machine deployed to the Utility subnet, nagiavte to the location where you cloned the Git repoistory and run the following command from the `function` directory:

```bash
func azure functionapp publish [function_app_name] --typescript
```
