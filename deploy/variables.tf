variable "access_token" {
  # This should ideally be marked as sensitive but doing that causes log redaction which can make debugging difficult.
  type        = string
  description = "Digital ocean access token for API authentication"
}

variable "ssh" {
  sensitive   = true
  type        = object({ port : number, private_key : string })
  description = <<EOT
`.port` - SSH port to be opened in server.
`.private_key` - Private SSH key used by provisioners to connect to server.
EOT
}

variable "server" {
  type = object({
    name : string,
    region : string,
    image : string,
    size : string,
    tags : set(string),
    ssh_keys : set(string),
  })
  default = {
    name     = ""
    region   = "SGP1"
    image    = "ubuntu-22-04-x64"
    size     = "s-1vcpu-1gb"
    tags     = []
    ssh_keys = []
  }
  validation {
    condition     = length(trimspace(var.server.name)) > 0
    error_message = "Server name (`server.name`) must not be blank."
  }
}

variable "domains" {
  type        = set(string)
  default     = ["xently.co.ke"]
  description = "Domains to generate SSL certificates for in the server"
}

variable "product_name" {
  type        = string
  description = "Name of the product that should be created after the server has been provisioned"
}

variable "database_user_password" {
  type        = string
  description = "Database password to use for logged in user"
}

variable "letsencrypt_email" {
  type        = string
  default     = "mitchke@duck.com"
  description = "Email address that will be associated with letsencrypt generated certificates (for `product_name`)"
}

variable "letsencrypt_server" {
  type        = string
  default     = "default"
  description = "Letsencrypt server from where (`product_name`'s) SSL certificate(s) will be generated"
  validation {
    condition     = contains(["default", "staging"], lower(var.letsencrypt_server))
    error_message = "Unrecognized server. Can either be 'default' or 'staging'."
  }
}

variable "app_docker_image" {
  type        = object({ name : string, tag : string })
  description = "Reference to the product's docker image"
  validation {
    condition     = length(trimspace(var.app_docker_image.name)) > 0 || length(trimspace(var.app_docker_image.tag)) > 0
    error_message = "Invalid docker image name or tag."
  }
}

variable "server_user" {
  # This should ideally be marked as sensitive but doing that causes log redaction which can make debugging difficult.
  type    = object({ name : string, password : string })
  default = {
    name     = "xently"
    password = "replace insecure password"
  }
  description = "User(name) and password of non-root user to be created after server is provisioned"
  validation {
    condition     = length(var.server_user.password) > 7
    error_message = "Server users password should be at least 8 characters long."
  }
}