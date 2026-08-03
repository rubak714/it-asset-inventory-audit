# 🗂️ azure-itam-compliance

IT asset management and compliance auditing across two domains: Azure cloud resources and a physical hardware and network estate.

Both use the same audit pattern. Inventory the assets, check each one against a policy, report what is non-compliant, fix it, and measure tracking accuracy again. Every run writes to one shared log.

- ☁️ Module 1: Azure resource governance (tagging policy on cloud resources)
- 🌐 Module 2: Hardware and network CMDB (switches, routers, firewalls, access points, WLAN controller, servers, laptops, printers) plus a documented LAN, VLAN plan, and Wi-Fi

Region for the cloud module: Germany West Central (DSGVO data residency). The Azure resources it creates (NSGs, VNets, route tables) are free.

## 🚧 Status

Work in progress. Building it up module by module.

- [ ] ☁️ Module 1: Azure resource governance
- [ ] 🌐 Module 2: Hardware and network CMDB
- [ ] 📡 Network documentation and lab build

## 📄 License

MIT. See `LICENSE`.
