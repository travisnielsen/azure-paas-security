# Infrastructure

## Deploy network and compute services

```bash
az login
bicep build network.bicep
az deployment sub create --name test --location centralus --template-file network.json
```
