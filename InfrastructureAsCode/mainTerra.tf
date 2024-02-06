variable "environment" {
  description = "Environment of the web app"
  type        = string
  default     = "dev"
}

provider "azurerm" {
  features {}
}

data "azurerm_resource_group" "current" {
 name = "MY_TEST_RG"
}

locals {
  webAppName         = "${random_string.rs.result}-${var.environment}"
  appServicePlanName = "${random_string.rs.result}-mpnp-asp"
  logAnalyticsName   = "${random_string.rs.result}-mpnp-la"
  appInsightsName    = "${random_string.rs.result}-mpnp-ai"
  sku                = "S1"
  registryName       = "${random_string.rs.result}mpnpreg"
  registrySku        = "Standard"
  imageName          = "techboost/dotnetcoreapp"
  startupCommand     = ""
}

resource "random_string" "rs" {
  length  = 8
  special = false
}

resource "azurerm_log_analytics_workspace" "log_analytics" {
  name                = local.logAnalyticsName
  location            = data.azurerm_resource_group.current.location
  resource_group_name = data.azurerm_resource_group.current.name
  sku                 = "PerGB2018"
  retention_in_days   = 90
  daily_quota_gb      = 1
}

resource "azurerm_application_insights" "app_insights" {
  name                = local.appInsightsName
  location            = data.azurerm_resource_group.current.location
  resource_group_name = data.azurerm_resource_group.current.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.log_analytics.id
}

resource "azurerm_container_registry" "container_registry" {
  name                = local.registryName
  location            = data.azurerm_resource_group.current.location
  resource_group_name = data.azurerm_resource_group.current.name
  sku                 = local.registrySku
  admin_enabled       = true
}

resource "azurerm_app_service_plan" "app_service_plan" {
  name                = local.appServicePlanName
  location            = data.azurerm_resource_group.current.location
  resource_group_name = data.azurerm_resource_group.current.name
  kind                = "linux"
  reserved            = true
  sku {
    tier = "Free"
    size = local.sku
  }
}

resource "azurerm_app_service" "app_service_app" {
  name                = local.webAppName
  location            = data.azurerm_resource_group.current.location
  resource_group_name = data.azurerm_resource_group.current.name
  app_service_plan_id = azurerm_app_service_plan.app_service_plan.id
  https_only          = true
  client_affinity_enabled = false

  site_config {
    linux_fx_version = "DOCKER|${azurerm_container_registry.container_registry.login_server}/${local.imageName}"
    http2_enabled    = true
    min_tls_version  = "1.2"
    app_command_line = local.startupCommand
  }

  app_settings = {
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
    "DOCKER_REGISTRY_SERVER_URL"          = "https://${azurerm_container_registry.container_registry.login_server}"
    "DOCKER_REGISTRY_SERVER_USERNAME"     = azurerm_container_registry.container_registry.admin_username
    "DOCKER_REGISTRY_SERVER_PASSWORD"     = azurerm_container_registry.container_registry.admin_password
    "APPINSIGHTS_INSTRUMENTATIONKEY"      = azurerm_application_insights.app_insights.instrumentation_key
  }
}

output "application_name" {
  value = azurerm_app_service.app_service_app.name
}

output "application_url" {
  value = azurerm_app_service.app_service_app.default_site_hostname
}

output "container_registry_name" {
  value = azurerm_container_registry.container_registry.name
}
