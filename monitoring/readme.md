# Monitoring

## Enabling Diagnostics

Resource diagnostics settings can be enalbed in scale for the critical resource types. This is powered by a PowerShell script to enable all platform metrics and logs.

You will need to run the `Deploy-AzDiagnostics.ps1` script with along with all appropriate parameters to have diagnostics settings enabled.

> **NOTE**
>
> Currently, diagnostics settings is only supported on the following resource types:
> ```powershell
>$validResourceTypes = @(
>    "Microsoft.Insights/components",
>    "Microsoft.DataFactory/factories",
>    "Microsoft.Network/azureFirewalls",
>    "Microsoft.Sql/servers/databases"
>)
>```
> Other resoruce types will be onboarded at a later date.

### Diagnostics pipeline



---

## Alerts

WIP


## Dashboards

For this POC environemnt, Azure dashbaords are being used for visualization purposes. y. While some resources already come with full felged dashboards upon deployment, others do not. So, are developing custom dashboards using Azure workbooks for resources that do not currenly support this natively.

Here is a list of resources that have bultin dashboard support and do not (custom).

### Custom

| Resource | Workbook features | Location |
| --- | --- | --- |
| Data Factory | Pipeline, activity, trigger runs, Errors | Log Analytics (AzureDataFactoryAnalytics) |
| Azure Firewall |  | Log Analytics (AzureFirewallAnalytics) |

### BuiltIn

| Resource | Workbook features | Location |
| --- | --- | --- |
| Application insights | Availability, Failure, Performance, Usage | Azure monitor |
| Virtual machines | Insights - Performance, Metrics (CPU, Disk, Network | Azure monitor |
| Network | Network health, Connectivity, Traffic | Azure monitor |
| Storage accounts | Transactions, Latency, Client Errors | Azure monitor |
| Log analytics | Workspace usage | Azure monitor |