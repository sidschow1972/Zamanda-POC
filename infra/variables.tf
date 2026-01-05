variable "admin_username" {
  type    = string
  default = "azureuser"
}

# Put your SSH public key in GitHub Secrets and pass it as a TF_VAR (recommended)
variable "ssh_public_key" {
  type      = string
  sensitive = true
}
variable "admin_password" {
  type      = string
  sensitive = true
  default   = "$Password123"
} 

variable "subscrbiption_id" {
  type = string
}