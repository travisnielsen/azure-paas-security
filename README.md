# Azure PaaS Reference Design

This reference design implements a hub-and-spoke networking model with all data plane operations happening within VNets through the use of Private Link. This design establishes a clear network perimeter and includes centralized control of all ingress and egress traffic by way of Azure Firewall deployed in the hub VNet. Many aspects of this design are enforced via Azure Policy to ensure a seucre baseline is maintained.

<img src="images/diagram-network.png" alt="Network diagram"/>

## Deployment

This reference environment includes two main areas that are deployed in the target subscription.

* [Azure Policies](policies/readme.md) - Ensure a conssitent security baseline is maintained
* [Azure Infrastructure](deployments/readme.md) - Represents the solution design
* [Azure Monitoring](monitoring/readme.md) - Contains information about what's being monitored

Navigate to each link before for instructiosn on how these assets are be deployed.

### CI-CD Workflow

Deployments of each components utlizied in this solution can be deployed & tested with the process of chatOps. The full process is as follows:

1. Developer creates a feature branch for changes to code, and pushes changes to the branch.
1. When the developer is ready, a PR is created to merge the changes into main.
1. A team member will review the changes.
1. If changes are approved, an issue comment `/deploy:{component}` is issued. This triggers a GitHub action to:
   - compile and unit test the code (if any)
   - provision resources in Azure
1. After deployment to a motified component is complete you can trigger other components for testing.
1. The PR is then merged to main to complete the loop.

### ChatOps
The messages that are issues must be on a single line and have the following syntax:

|Message|Parameters|Notes|Example|
|---|---|---|---|
|`/deploy:{component}`| `component` = `policies`, `monitoring`, or `infra` | Deploys the component separately | `/deploy:monitoring`