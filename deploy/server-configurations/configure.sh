#!/bin/bash -u

set -e

set -o pipefail

# Source: https://stackoverflow.com/a/630387/6239635
relative_path="$(dirname -- "${BASH_SOURCE[0]}")"
path="$(cd -- "$relative_path" && pwd)"

prerequisites="$path/prerequisites.sh"
if ! [ -x "$prerequisites" ]; then
  echo "'$prerequisites' not executable. Making it executable..."
  chmod +x "$prerequisites"
fi

source "$path/prerequisites.sh"

DEBIAN_FRONTEND=noninteractive
export DEBIAN_FRONTEND

sudo timedatectl set-timezone UTC

sudo NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive apt update -qq >/dev/null
sudo NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive apt -qq -y --no-install-recommends install apt-transport-https

product_name=$(option_passed --product --require-value)
if [ -z "$product_name" ] || [ "$product_name" == "0" ]; then
  echo -e "${DANGER}Please specify a product name using $WARNING--product=<name>${DANGER} option.$NEUTRAL" >&2
  exit 1
fi

docker_image=$(option_passed --docker-image --require-value)
if [ -z "$docker_image" ] || [ "$docker_image" == "0" ]; then
  docker_image="$product_name:${VERSION:-latest}"
fi

version=$(python3 -c "x = '$docker_image'; xs = x.rsplit(':', 1); v = 'latest' if len(xs) < 2 else xs[1]; print(v)")
environment=$(python3 -c "x = '$version'; xs = x.split('-', 1); e = 'production' if len(xs) < 2 else xs[1]; print(e)")

new_server_configurations_repo_directory="/repos/configurations/"
old_server_configurations_repo_directory="/repos/$product_name/configurations/"

function move_server_configuration_repository() {
  echo_warning "Moving server configurations from '$old_server_configurations_repo_directory' => '$new_server_configurations_repo_directory'..."
  mv "$old_server_configurations_repo_directory" /repos/
}

if ! [ -d "$new_server_configurations_repo_directory" ]; then
  move_server_configuration_repository
elif [ -d "$old_server_configurations_repo_directory" ] && [ -d "$new_server_configurations_repo_directory" ]; then
  echo_warning "Replacing old server configurations..."
  rm -Rf "$new_server_configurations_repo_directory"
  move_server_configuration_repository
else
  echo_warning "Moving server configurations from '$old_server_configurations_repo_directory' => '$new_server_configurations_repo_directory' appears unnecessary!"
fi

function configure_unattended_upgrades() {
  echo_warning "Configuring unattended upgrades..."
  sudo NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive apt install -y unattended-upgrades

  echo_warning "Copying desired unattended upgrades configurations..."
  sudo cp "${new_server_configurations_repo_directory}etc/apt/apt.conf.d/52unattended-upgrades-local" /etc/apt/apt.conf.d/52unattended-upgrades-local

  echo_warning "Removing default unattended upgrades configuration..."
  sudo rm --force /etc/cron.daily/apt-compat

  echo_warning "Configuring unattended upgrades cronjob..."
  echo '30 1 * * *   root    test -x /usr/sbin/anacron || ( cd / && /usr/lib/apt/apt.systemd.daily )' | sudo tee -a /etc/crontab
}

if ! sudo unattended-upgrades --dry-run &>/dev/null; then
  configure_unattended_upgrades
fi

user=$(logname 2>/dev/null || echo "$SUDO_USER")
echo_warning "Continuing with user as '$user'..."

database_name="xently_${product_name}_${environment}"
database_user_password=$(option_passed --database-user-password --require-value)
if [ -z "$database_user_password" ] || [ "$database_user_password" == "0" ]; then
  echo -e "${DANGER}Please specify a database password to use for $WARNING'$user'$DANGER using $WARNING--database-user-password=<database-user-password>${DANGER} option.$NEUTRAL" >&2
  exit 1
fi

function configure_postgres_resources() {
  echo_warning "Creating postgres user '$user' if not exist..."
  if ! sudo su --command "createuser --echo --superuser $user" - postgres &>/dev/null; then
    echo_error "Unable to create postgres user '$user'."
  fi

  echo_warning "Changing password for postgres user '$user'..."
  if ! sudo su --command "psql --command \"ALTER USER $user WITH PASSWORD '$database_user_password';\" postgres" - "$user" &>/dev/null; then
    echo_error "Unable to change password for '$user'."
  fi

  echo_warning "Creating postgres database '$database_name' if not exist..."
  if ! sudo su --command "psql --command 'CREATE DATABASE $database_name;' postgres" - "$user" &>/dev/null; then
    echo_error "Unable to create postgres database '$database_name'."
  fi

  echo "Loading PostGIS extensions into $database_name"

  sudo su --command "psql --command 'CREATE EXTENSION IF NOT EXISTS postgis;' $database_name $user" - "$user"
  sudo su --command "psql --command 'CREATE EXTENSION IF NOT EXISTS postgis_topology;' $database_name $user" - "$user"
  sudo su --command "psql --command '\c' $database_name $user" - "$user"
  sudo su --command "psql --command 'CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;' $database_name $user" - "$user"
  sudo su --command "psql --command 'CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder;' $database_name $user" - "$user"
}

function install_and_configure_postgresql() {
  echo_warning "Postgresql not found! Installing..."
  sudo NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive apt install -y postgresql libpq-dev postgresql-client postgresql-contrib
  sudo NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive apt install -y binutils libproj-dev gdal-bin postgis

  configure_postgres_resources
}

if psql --version &>/dev/null; then
  configure_postgres_resources
else
  install_and_configure_postgresql
fi

function reload_nginx() {
  echo_warning "Reloading nginx..."
  sudo nginx -t
  sudo systemctl reload nginx
}

nginx_config="/repos/$product_name/deploy/nginx-${environment}.conf"

function configure_nginx() {
  local symlinked_nginx_config
  symlinked_nginx_config="/etc/nginx/sites-enabled/${product_name}-${environment}.conf"

  echo_warning "Configuring nginx for '$product_name'..."
  if [ -f "$symlinked_nginx_config" ]; then
    echo_warning "Skipping possible nginx ($symlinked_nginx_config) reconfiguration..."
  else
    sudo ln -s "$nginx_config" "$symlinked_nginx_config"
  fi
}

function install_and_configure_nginx() {
  echo_warning "Nginx not found! Installing..."
  sudo NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive apt install -y nginx

  echo_warning "Configuring default nginx configurations..."
  sudo cp "${new_server_configurations_repo_directory}etc/nginx/nginx.conf" /etc/nginx/nginx.conf
  sudo cp "${new_server_configurations_repo_directory}etc/nginx/sites-enabled/default" /etc/nginx/sites-enabled/default
  reload_nginx

  configure_nginx
}

if ! sudo nginx -v &>/dev/null; then
  install_and_configure_nginx
else
  configure_nginx
fi

if ! sudo certbot --version &>/dev/null; then
  echo_warning "Certbot not found! Installing..."
  sudo snap install --classic certbot
fi

cert_name="${product_name}-${environment}"
dh_pem_file="/sites/.config/$cert_name/ssl/dhparams.pem"

function generate_dhparams() {
  echo_warning "Configuring SSL..."
  mkdir -p "/sites/.config/$cert_name/ssl"
  openssl dhparam -out "$dh_pem_file" 2048
}

if ! [ -f "$dh_pem_file" ]; then
  generate_dhparams
fi

letsencrypt_email=$(option_passed --letsencrypt-email --require-value)
if [ -z "$letsencrypt_email" ] || [ "$letsencrypt_email" == "0" ]; then
  letsencrypt_email="letsencrypt@example.com"
fi

letsencrypt_server=$(option_passed --letsencrypt-server --require-value)
if [ -z "$letsencrypt_server" ] || [ "$letsencrypt_server" == "0" ]; then
  letsencrypt_server="default"
fi

function comment_out_ssl_server_configuration() {
  echo_warning "Commenting out SSL server configuration..."

  sed -i "/^include \/repos\/$product_name\/deploy\/nginx-ssl-server-${environment}\.conf;$/s/^/#/" "$nginx_config"
}

function uncomment_ssl_server_configuration() {
  echo_warning "Uncommenting SSL server configuration..."

  sed -i "/^\#include \/repos\/$product_name\/deploy\/nginx-ssl-server-${environment}\.conf;$/s/^#//g" "$nginx_config"
}

function generate_ssl_certs_if_none_exists() {
  comment_out_ssl_server_configuration
  reload_nginx

  local domains
  domains=$(option_passed --domains --require-value)
  if [ -z "$domains" ] || [ "$domains" == "0" ]; then
    domains=""
  fi

  IFS=";" read -ra domains <<<"$domains"

  for domain in "${domains[@]}"; do
    if [ -z "$domain" ]; then # skip empty domains
      continue
    fi

    local letsencrypt_server_id_file
    letsencrypt_server_id_file="/sites/.letsencrypt-servers-$(echo "$domain" | md5sum | cut -f1 -d" ")"

    if ! [ -f "$letsencrypt_server_id_file" ]; then
      echo_warning "Creating a default memory of the current letsencrypt server..."
      echo "$letsencrypt_server" >"$letsencrypt_server_id_file"
    fi

    local generate_certs
    generate_certs=""
    if ! sudo certbot certificates -d "$domain" | grep "$domain" &>/dev/null; then
      generate_certs="true"
    elif [ "$(cat "$letsencrypt_server_id_file")" != "$letsencrypt_server" ]; then
      generate_certs="true"
      sudo certbot delete \
        --non-interactive \
        --cert-name "$cert_name"
    fi

    if [ -n "$generate_certs" ]; then
      echo
      echo_warning "Certificate not issued to '$domain'. Generating '$letsencrypt_server' certificates..."

      if [ "$letsencrypt_server" == "default" ]; then
        sudo certbot certonly \
          --agree-tos \
          --non-interactive \
          --webroot \
          -w /usr/share/nginx/html \
          -m "$letsencrypt_email" \
          --cert-name "$cert_name" \
          --domain "$domain" || true # the environment may not have been configured
      else
        sudo certbot certonly \
          --agree-tos \
          --non-interactive \
          --webroot \
          -w /usr/share/nginx/html \
          -m "$letsencrypt_email" \
          --cert-name "$cert_name" \
          --domain "$domain" \
          --test-cert || true # the environment may not have been configured
      fi

      echo_warning "Persisting current letsencrypt server..."
      echo "$letsencrypt_server" >"$letsencrypt_server_id_file"
    fi
  done
}

generate_ssl_certs_if_none_exists

uncomment_ssl_server_configuration
reload_nginx

function install_docker() {
  echo_warning "Installing docker..."

  sudo NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive apt -y install ca-certificates curl gnupg

  sudo install -m 0755 -d /etc/apt/keyrings

  if [ -f /etc/apt/keyrings/docker.gpg ]; then
    echo_warning "Removing duplicate docker keyring..."
    sudo rm -f /etc/apt/keyrings/docker.gpg
  fi

  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

  sudo chmod a+r /etc/apt/keyrings/docker.gpg

  version_code=$(. /etc/os-release && echo "$VERSION_CODENAME")

  if [ -f /etc/apt/sources.list.d/docker.list ]; then
    echo_warning "Removing existing docker source list..."
    sudo rm -f /etc/apt/sources.list.d/docker.list
  fi

  echo \
    "deb [arch=\"$(dpkg --print-architecture)\" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    \"$version_code\" stable" |
    sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

  sudo NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive apt update

  sudo NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive apt -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  echo_warning "Configuring rootless docker installation..."

  sudo groupadd -f docker || true

  sudo usermod -aG docker "$user"

  newgrp docker
}

if ! docker --version &>/dev/null; then
  install_docker
fi

start_script="$path/start.sh"
if ! [ -x "$start_script" ]; then
  echo_warning "'$start_script' not executable. Making it executable..."
  chmod +x "$start_script"
fi

sudo su --command "/bin/bash -c \"${start_script} ${*}\"" - "$user"
