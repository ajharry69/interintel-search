locals {
  public_ips = {
    server = digitalocean_droplet.server.ipv4_address
  }
  server_docker_image = "${var.app_docker_image.name}:${var.app_docker_image.tag}"
  server_deploy = {
    app_dir = "/repos/${var.product_name}"
    script_options = [
      "--product='${var.product_name}'",
      "--letsencrypt-email='${var.letsencrypt_email}'",
      "--letsencrypt-server='${var.letsencrypt_server}'",
      "--database-user-password='${var.database_user_password}'",
      "--docker-image='ajharry69/${local.server_docker_image}'",
      "--domains='${join(";", var.domains)}'",
    ]
  }
}