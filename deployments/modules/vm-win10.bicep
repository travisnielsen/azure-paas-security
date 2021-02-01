param vmName string

param networkResourceGroupName string
param vnetName string
param subnetName string

param adminUserName string
param adminPassword string {
  secure: true
}

var subscriptionId = subscription().subscriptionId

param windowsOSVersion string {
  default: 'Desktop 10 Pro'
  allowed: [
    'Desktop 10 Pro'
    'Desktop 10 Enterprise'
  ]
  metadata: {
    'description': 'The Windows version for the VM. This will pick a fully patched image of this given Windows version.'
  }
}
param vmSize string {
  default: 'Standard_D2_v3'
  metadata: {
    description: 'Size of the virtual machine.'
  }
}

param location string {
  default: resourceGroup().location
  metadata: {
    description: 'location for all resources'
  }
}

var nicName = '${vmName}-nic'

resource nInter 'Microsoft.Network/networkInterfaces@2020-06-01' = {
  name: nicName
  location: location

  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId(subscriptionId, networkResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)
          }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2020-06-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUserName
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsDesktop'
        offer: 'Windows-10'
        sku: '20h2-pro'
        version: 'latest'
      }
      osDisk: {
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
      dataDisks: [
        {
          diskSizeGB: 1023
          lun: 0
          createOption: 'Empty'
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nInter.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: false
        // storageUri: stg.properties.primaryEndpoints.blob
      }
    }
  }
}

/*
resource aadextension 'Microsoft.Compute/virtualMachines/extensions@2020-06-01' = {
  name: '${vm.name}/AADLoginForWindows'
  location: location
  dependsOn: [
    vm
  ]
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: ''
    autoUpgradeMinorVersion: true

  }
}
*/

output vmId string = vm.id