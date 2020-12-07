# Infrastructure

## Deploy Security Baseline

TBD

## Deploy Network and Application

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
