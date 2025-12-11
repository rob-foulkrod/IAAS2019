# EShopOnWeb Retail on Azure IaaS (Windows Server 2019)

Deploy a classic .NET web application on Azure Virtual Machines running Windows Server 2019 with IIS and SQL Server, demonstrating traditional IaaS architecture patterns and migration scenarios.

💪 This template scenario is part of the larger **[Microsoft Trainer Demo Deploy Catalog](https://aka.ms/trainer-demo-deploy)**.

## 📋 What You'll Deploy

- **2 Windows Server 2019 Virtual Machines** (Web VM and SQL VM)
- **Virtual Network** with 2 subnets (Frontend and Backend)
- **Public IP Address** (Basic SKU) for web access
- **Key Vault** for secure credential storage
- **Log Analytics Workspace** and **Application Insights** for monitoring
- **EShopOnWeb Retail Application** automatically deployed via DSC

**Estimated cost:** $5-8/day (primarily from 2 Standard_D4lds_v5 VMs)

## 🏗️ Architecture

This scenario deploys a traditional 2-tier IaaS architecture:

- **Web VM** (Frontend subnet): Windows Server 2019 with IIS, hosting the .NET application
- **SQL VM** (Backend subnet): Windows Server 2019 with SQL Server 2019 Web edition
- **Public Internet Access** via Basic SKU Public IP (intentionally unsecured for demo purposes)
- **Automated Configuration** using PowerShell DSC extensions

The architecture intentionally includes optimization opportunities (no NSG, Basic Public IP, upgradable disk SKUs) to demonstrate VM best practices and security hardening.

```
Internet
   │
   └──> Public IP (Basic SKU)
           │
           └──> Frontend Subnet (10.0.0.0/24)
                   │
                   └──> Web VM (IIS + .NET App)
                           │
                           └──> Backend Subnet (10.0.1.0/24)
                                   │
                                   └──> SQL VM (SQL Server 2019)
```

## ⏰ Deployment Time

Approximately **15-20 minutes** (includes VM provisioning and DSC configuration)

## ⬇️ Prerequisites

### Tools Required
- [Azure Developer CLI (azd)](https://aka.ms/azd-install) - Auto-installs GitHub CLI and Bicep CLI

### Azure Permissions Required
- **Owner or Contributor** access to Azure Subscription
- Sufficient quota for **Standard_D4lds_v5 VMs** in target region

## 🚀 Deploy in 3 Steps

1. **Initialize from template**
```bash
azd init -t rob-foulkrod/IAAS2019
```

2. **Deploy to Azure**
```bash
azd up
```

3. **Clean up when done**
```bash
azd down --purge --force
```

⏩ **Note:** `azd down` removes Azure resources but keeps local project files. Use `--purge` to also delete Key Vault soft-delete protection.

## ✅ Verify Deployment

1. After deployment completes, note the **APP_ENDPOINT** output (e.g., `http://iaas-abc123.eastus.cloudapp.azure.com`)
2. Open the endpoint in your browser
3. **Expected result:** EShopOnWeb retail application homepage displaying products
4. Navigate to Azure Portal → Resource Groups → **rg-{environmentName}**
5. Verify the following resources exist:
   - 2 Virtual Machines (webvm-{env} and sqlvm-{env})
   - 1 Virtual Network with 2 subnets
   - 1 Public IP Address
   - 1 Key Vault
   - 1 Log Analytics Workspace

### Access Virtual Machines

**Admin credentials** are stored in Azure Key Vault:
- Navigate to Key Vault → Secrets
- Retrieve `webVMAdminPassword` and `sqlVMAdminPassword`
- Usernames are also stored as separate secrets

**RDP Access:**
- **Web VM:** Connect directly via the Public IP address
- **SQL VM:** Only accessible via RDP from within the Web VM (no public IP)

## 🎓 What You'll Demonstrate

This scenario is ideal for demonstrating:

### VM Fundamentals (Aligned with AZ-104)
- Azure VM concepts, settings, and monitoring
- VM sizing and cost optimization
- OS disk and data disk management
- VM extensions and automation (DSC)

### Networking (Aligned with AZ-104 & AZ-700)
- Virtual Networks and subnet segmentation
- Public IP addresses (Basic vs. Standard SKU)
- Network Security Groups (NSG) - how to add protection
- Private vs. public IP addressing

### Security Hardening
- Upgrading Public IP from Basic to Standard SKU
- Implementing NSG rules (deny RDP, allow HTTP)
- Network isolation with subnet-level NSGs
- Azure Bastion as RDP replacement (not deployed, but can be added)

### Storage & Disk Management
- Managed Disks (Premium SSD)
- Data disk attachment and configuration
- Disk resizing and SKU changes
- Backup and disaster recovery concepts

### Migration Scenarios
- **Lift-and-shift** from on-premises to Azure IaaS
- **Azure App Service Migration** (Web VM → App Service)
- **Azure SQL Database Migration** (SQL VM → Azure SQL DB)
- Using Azure Migrate and Database Migration Assistant tools

### Comparison Across Architectures
> **Tip:** The same EShopOnWeb application is available in **PaaS, ACI, and AKS scenarios**. This makes it powerful for demonstrating architectural evolution from IaaS → PaaS → Containers → Kubernetes.

## 📚 Demo Guide

A comprehensive demo guide is available at [Demoguide/eshoponweb_iaas2019.md](https://github.com/rob-foulkrod/IAAS2019/blob/main/Demoguide/eshoponweb_iaas2019.md) with step-by-step instructions for:

- **Networking Demo:** Adding NSG rules, upgrading Public IP SKU
- **Storage Demo:** Managing disks and demonstrating migrations
- **VM Optimization:** Resizing, monitoring, and cost management
- **Application Migration:** Moving Web VM to Azure App Service
- **Database Migration:** Migrating SQL VM to Azure SQL Database

## 🔧 What's Automatically Configured

The deployment uses **PowerShell DSC** to automatically:

### Web VM Configuration
- Install IIS with ASP.NET support
- Install .NET 6.0 Hosting Bundle
- Deploy EShopOnWeb application via Web Deploy
- Install management tools (Chrome, Edge, SQL Server Management Studio)
- Configure Windows Firewall

### SQL VM Configuration  
- Install and configure SQL Server 2019 (Web edition)
- Restore EShopOnWeb database from backup
- Configure SQL authentication
- Attach and format data disks

## 🐛 Troubleshooting

**Issue:** Deployment fails with "quota exceeded" error  
**Solution:** Check your subscription's VM quota for Standard_D4lds_v5 in the target region. Request quota increase or change regions.

**Issue:** Web application doesn't load after deployment  
**Solution:** 
1. RDP into Web VM
2. Check IIS status: Open IIS Manager, verify site is started
3. Review DSC logs at `C:\WindowsAzure\Logs\Plugins\Microsoft.Powershell.DSC`

**Issue:** Cannot RDP to Web VM  
**Solution:** Verify Public IP address in Portal matches the one you're connecting to. Check if any corporate firewalls are blocking port 3389.

**Issue:** SQL Server connection fails  
**Solution:** SQL VM has no public IP by design. Connect via RDP to Web VM first, then RDP to SQL VM using private IP (10.0.1.x).

**Logs:** 
- View deployment logs: `azd show`
- VM extension logs: Portal → VM → Extensions + applications → DSC → View detailed status

## 💰 Cost Management

**SKUs deployed:**
- 2x Standard_D4lds_v5 VMs (4 vCPU, 8 GB RAM each)
- Premium SSD Managed Disks (128 GB OS + 2x 1 TB data disks on SQL VM)
- Basic Public IP Address
- Log Analytics Workspace (Pay-as-you-go)

**Estimated cost:** $5-8/day (~$150-240/month if left running)

**Cost-saving tips:**
- **Deallocate VMs** when not in use: `Stop-AzVM -ResourceGroupName <rg-name> -Name <vm-name>` (still incurs disk storage costs but eliminates compute)
- **Run `azd down`** after demos to completely remove resources
- **Right-size VMs:** Standard_D4lds_v5 can be reduced to Standard_D2lds_v5 for basic demos (saving ~40%)


> [!IMPORTANT]  
> This template intentionally uses **Basic Public IP SKU** and **no Network Security Groups**. Always implement proper NSG rules and upgrade to Standard SKU Public IPs for production workloads.

## 🎯 Training Scenarios

### Beginner (AZ-900, AZ-104)
- What is an Azure Virtual Machine?
- Virtual Network basics
- Public vs. Private IPs
- Resource Groups and tagging

### Intermediate (AZ-104, AZ-305)
- VM sizing and cost optimization
- Network Security Groups
- Managed Disks and storage tiers
- Azure Monitor and Log Analytics integration

### Advanced (AZ-305, AZ-700, AZ-500)
- Lift-and-shift migration strategies
- Multi-tier application architecture
- Security hardening and zero trust
- Hybrid connectivity scenarios
- Disaster recovery and backup strategies

### Migration-Focused
- Azure Migrate assessment
- Azure App Service Migration
- Azure Database Migration Service
- Comparing IaaS, PaaS, and Container architectures

## 📖 Additional Resources

- [Azure Virtual Machines Documentation](https://learn.microsoft.com/azure/virtual-machines/)
- [Azure Virtual Network Documentation](https://learn.microsoft.com/azure/virtual-network/)
- [Azure Migrate Overview](https://learn.microsoft.com/azure/migrate/)
- [PowerShell DSC Extension](https://learn.microsoft.com/azure/virtual-machines/extensions/dsc-overview)
- [Public IP SKU comparison](https://learn.microsoft.com/azure/virtual-network/ip-services/public-ip-addresses#sku)

## 💭 Feedback and Contributing

Have ideas for improvements? Found a bug? Please open an issue or submit a pull request in the [GitHub repository](https://github.com/rob-foulkrod/IAAS2019).

For questions or support with the broader Trainer Demo Deploy catalog, visit [aka.ms/trainer-demo-deploy](https://aka.ms/trainer-demo-deploy).
