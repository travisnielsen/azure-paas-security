# Infrastructure

## Deploy Security Baseline

TBD

## Deploy Network and Application Infrastructure

```bash
az login
bicep build network.bicep
az deployment sub create --name networkdeployment --location centralus --template-file network.json --parameters appPrefix=paasdemo
```

Next, run the following command to deploy the Function Premium instance:

```bash
bicep build application.bicep
az deployment sub create --name appdeployment --location centralus --template-file application.json --parameters appPrefix=paasdemo vmAdminUserName=paasadmin vmAdminPwd=[your_password_here]
```

## Deploy Application Code

Because the Function App has been deployed with a Private Link, the Function code must be deployed from within the applicaiton (spoke) virtual network. From the virtual machine deployed to the Utility subnet, nagiavte to the location where you cloned the Git repoistory and run the following command from the `function` directory:

```bash
func azure functionapp publish [function_app_name] --typescript
```
