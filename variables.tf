variable "yandex_cloud_oauth_token" {}
variable "cloud_id" {}
variable "folder_id" {}
variable "ssh_public_key" {
  description = "Public SSH key for instance access"
  type        = string
}
