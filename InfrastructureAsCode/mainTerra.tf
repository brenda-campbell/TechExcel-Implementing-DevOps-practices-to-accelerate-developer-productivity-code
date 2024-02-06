variable "environment" {
  description = "Environment of the web app"
  type        = string
  default     = "dev"
}

data "azurerm_resource_group" "current" {}

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
    tier = "Standard"
    size = local.sku
  }
}

resource "azurerm_app_service" "app_service_app" {
  name                = local.webAppName
  location            = data.azurerm_resource_group.current.location
  resource_group_name = data.azurerm_resource_group.current.name
  app_service_plan_id = azurerm_app_service_plan.app_service_plan.id
  https_only          = true
  client_aff
