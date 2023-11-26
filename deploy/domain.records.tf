resource "digitalocean_record" "interintel" {
  domain = "xently.co.ke"
  name   = "interintel"
  type   = "A"
  value  = digitalocean_droplet.server.ipv4_address
}
