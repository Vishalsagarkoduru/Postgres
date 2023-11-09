#creation of resource group
data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = "briliorg12"
  location = "East US2"
}

# Create a managed identity for encryption key access
resource "azurerm_user_assigned_identity" "userassignedid" {
  location            = "eastus2"
  name                = "brilliomi1221"
  resource_group_name = azurerm_resource_group.rg.name
}
# Creation of keyvault With Key permissions

resource "azurerm_key_vault" "brilliokv" {
  name                       = "brilliokv112"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "premium"
  soft_delete_retention_days = 7
  purge_protection_enabled = true
}
resource "azurerm_key_vault_access_policy" "server" {
  key_vault_id = azurerm_key_vault.brilliokv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.userassignedid.principal_id

  key_permissions = ["Get", "List", "WrapKey", "UnwrapKey", "GetRotationPolicy", "SetRotationPolicy"]
  secret_permissions = ["Get","List",]
}
# Creation Of key in the keyvault. 
resource "azurerm_key_vault_key" "generated" {
  name         = "generatedcertificate"
  key_vault_id = azurerm_key_vault.brilliokv.id
  key_type     = "RSA"
  key_size     = 2048

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]

  rotation_policy {
    automatic {
      time_before_expiry = "P30D"
    }

    expire_after         = "P90D"
    notify_before_expiry = "P29D"
  }
}

#creation of Manages a Redis Enterprise Cluster.
resource "azurerm_redis_enterprise_cluster" "example" {
  name                = "Sampledemocache"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  sku_name = "Enterprise_E20-4"
}
#Creation of Manages a Redis Enterprise Database.
resource "azurerm_redis_enterprise_database" "example" {
  name                = "default"
  resource_group_name = azurerm_resource_group.rg.name
  cluster_id        = azurerm_redis_enterprise_cluster.example.id
  client_protocol   = "Encrypted"
  clustering_policy = "EnterpriseCluster"
  eviction_policy   = "NoEviction"
  port              = 10000

 identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.userassignedid.id]  
  }
  customer_managed_key {
    key_vault_key_id                    = azurerm_key_vault_key.generated.id
    primary_user_assigned_identity_id   = azurerm_user_assigned_identity.userassignedid.id
  }
  linked_database_id = [
    "${azurerm_redis_enterprise_cluster.example.id}/databases/default",
  ]
}
/*
    customer_managed_key {
    key_vault_key_id                    = azurerm_key_vault_key.generated.id
    primary_user_assigned_identity_id   = azurerm_user_assigned_identity.userassignedid.id
    }
    */