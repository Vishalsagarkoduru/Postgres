#creation of resource group
resource "azurerm_resource_group" "rg" {
  name     = "myresourcegroup.eh"
  location = "East US2"
}
# Creation Vitual Network along with the address space
resource "azurerm_virtual_network" "vnet" {
  name                = "myeventhubvnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

# Creation of Subnet for the postgres server.
resource "azurerm_subnet" "subnet" {
  name                 = "myeventhubsubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.3.0/24"]
  service_endpoints    = ["Microsoft.Storage"]
  
}

# Creation of Private DNS zone. 

resource "azurerm_private_dns_zone" "dnszone" {
  name                = "example.myeventhub.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
}

# Creation of Virtual network link. 

resource "azurerm_private_dns_zone_virtual_network_link" "vnetlink" {
  name                  = "myeventhubVnetZone.com"
  private_dns_zone_name = azurerm_private_dns_zone.dnszone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  resource_group_name   = azurerm_resource_group.rg.name
}

#creation of Manages a Redis Enterprise Cluster.
resource "azurerm_redis_enterprise_cluster" "example" {
  name                = "Sampledemocache"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  
  sku_name = "Enterprise_E20-4"
}
resource "azurerm_private_endpoint" "acre" {
  name                = "redisdns"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet.id

  private_service_connection {
    name                           = "Redis.sc"
    private_connection_resource_id = azurerm_redis_enterprise_cluster.example.id
    is_manual_connection           = false
    subresource_names              = ["redisEnterprise"]
  }
}

#Creation of Manages a Redis Enterprise Database.
resource "azapi_resource" "symbolicname" {
  type = "Microsoft.Cache/redisEnterprise/databases@2022-01-01"
  name = "default"
  parent_id = azurerm_redis_enterprise_cluster.example.id
  body = jsonencode({
    properties = {
      clientProtocol = "Encrypted"
      clusteringPolicy = "EnterpriseCluster"
      evictionPolicy = "NoEviction"
      geoReplication = {
        groupNickname = "newrcdatabase"
         linkedDatabases = [
          {
            id = "${azurerm_redis_enterprise_cluster.example.id}/databases/default"
          }
        ]
      }
      }
    })
  }
