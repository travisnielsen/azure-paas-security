# Infrastructure

## Deploy network and compute resources

```bash
az login
bicep build network.bicep
az deployment sub create --name test --location centralus --template-file network.json
```

Next, run the following command to deploy the Function Premium instance:

```bash
bicep build functionapp.bicep
az group create --name func-rg --location "centralus"
az deployment group create -g func-rg --name funcdeploy1 -f functionapp.json
```