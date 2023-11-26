resource "null_resource" "on-server-created-or-upload-files-changed" {
  depends_on = [
    digitalocean_record.interintel,
    digitalocean_droplet.server,
  ]

  triggers = {
    server-id                   = digitalocean_droplet.server.id,
    on-auth-credentials-changed = sha256(var.access_token),
    server-product-name         = var.product_name,
    server-configuration-files-hash = sha1(join("", [
      for f in fileset("${path.module}/server-configurations/", "**") :
      filesha1("${path.module}/server-configurations/${f}")
    ]))
  }

  provisioner "remote-exec" {
    inline = [
      # Avoid deleting files not uploaded by the file provisioner below
      "rm -f ${local.server_deploy.app_dir}/configure.sh",
    ]
  }

  provisioner "file" {
    source      = "server-configurations/"
    destination = local.server_deploy.app_dir
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ${local.server_deploy.app_dir}/configure.sh",
      format("echo '${var.server_user.password}' | sudo -S /bin/bash ${local.server_deploy.app_dir}/configure.sh %s", join(" ", local.server_deploy.script_options)),
    ]
  }

  connection {
    agent       = false
    user        = var.server_user.name
    host        = local.public_ips.server
    port        = var.ssh.port
    private_key = var.ssh.private_key
  }
}

resource "null_resource" "on-server-image-updated" {
  depends_on = [
    null_resource.on-server-created-or-upload-files-changed,
  ]

  triggers = {
    on-server-created-or-upload-files-changed-id = null_resource.on-server-created-or-upload-files-changed.id,
    server-docker-image-reference                = sha1(local.server_docker_image),
    on-ssl-server-changed                        = lower(var.letsencrypt_server)
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ${local.server_deploy.app_dir}/configure.sh",
      format("echo '${var.server_user.password}' | sudo -S /bin/bash ${local.server_deploy.app_dir}/configure.sh %s", join(" ", local.server_deploy.script_options)),
    ]

    connection {
      agent       = false
      user        = var.server_user.name
      host        = local.public_ips.server
      port        = var.ssh.port
      private_key = var.ssh.private_key
    }
  }
}