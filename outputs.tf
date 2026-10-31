output "dotnet_root" {
  description = "Directory of the installed .NET SDK on each host, by host name."
  value       = { for name in keys(var.hosts) : name => local.home }
}
