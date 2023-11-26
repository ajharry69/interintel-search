resource "digitalocean_droplet" "server" {
  image      = var.server.image
  name       = var.server.name
  region     = var.server.region
  size       = var.server.size
  monitoring = true
  tags       = var.server.tags
  ssh_keys = concat([
    "b5:34:33:a3:b3:8c:52:4d:1d:14:43:0c:5a:ab:eb:a9",
    "53:cd:75:ce:9a:6d:5b:38:eb:30:7e:9e:84:48:27:6a",
  ], tolist(var.server.ssh_keys))

  provisioner "file" {
    source      = "server-configurations/configure-ssh.sh"
    destination = "/etc/configure-ssh.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "groupadd -f www-data && useradd --create-home --shell /bin/bash -p $(perl -e 'print crypt($ARGV[0], \"password\")' '${var.server_user.password}') -g www-data --group sudo ${var.server_user.name}",
      "rsync --archive --chown='${var.server_user.name}:www-data' ~/.ssh /home/${var.server_user.name}",
      "mkdir -p ${local.server_deploy.app_dir}/ && chown -R ${var.server_user.name}:www-data /repos/",
      "mkdir -p /sites/.logs/ && chown -R ${var.server_user.name}:www-data /sites/",
      "mv /etc/configure-ssh.sh ${local.server_deploy.app_dir}/configure-ssh.sh && chown ${var.server_user.name}:www-data ${local.server_deploy.app_dir}/configure-ssh.sh",
      "chmod +x ${local.server_deploy.app_dir}/configure-ssh.sh",
      "SSH_PORT=${var.ssh.port} /bin/bash ${local.server_deploy.app_dir}/configure-ssh.sh",
      "ufw allow ${var.ssh.port}/tcp && ufw allow http && ufw allow https && ufw --force enable",
    ]
  }

  connection {
    agent       = false
    user        = "root"
    host        = self.ipv4_address
    private_key = var.ssh.private_key
  }
}
