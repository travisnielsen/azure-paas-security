# Azure PaaS Reference Design

This reference design implements a hub-and-spoke networking model with all data plane operations happening within VNets through the use of Private Link. This design establishes a clear network perimeter and includes centralized control of all ingress and egress traffic by way of Azure Firewall deployed in the hub VNet. Many aspects of this design are enforced via Azure Policy to ensure a seucre baseline is maintained.

<img src="images/diagram-network.png" alt="Network diagram"/>

## Deployment

This reference environment includes two main areas that are deployed in the target subscription.

* [Azure Policies](policies/readme.md) - Ensure a conssitent security baseline is maintained
* [Azure Infrastructure](deployments/readme.md) - Represents the solution design

Navigate to each link before for instructiosn on how these assets are be deployed.
