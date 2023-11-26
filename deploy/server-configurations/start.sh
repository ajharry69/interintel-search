#!/usr/bin/env bash

set -e

# Source: https://stackoverflow.com/a/630387/6239635
relative_path="$(dirname -- "${BASH_SOURCE[0]}")"
path="$(cd -- "$relative_path" && pwd)"

source "$path/prerequisites.sh"

product_name=$(option_passed --product --require-value)
if [ -z "$product_name" ] || [ "$product_name" == "0" ]; then
  product_name="interintel"
fi

docker_image=$(option_passed --docker-image --require-value)
if [ -z "$docker_image" ] || [ "$docker_image" == "0" ]; then
  docker_image="$product_name:${VERSION:-latest}"
fi

version=$(python3 -c "x = '$docker_image'; xs = x.rsplit(':', 1); v = 'latest' if len(xs) < 2 else xs[1]; print(v)")
environment=$(python3 -c "x = '$version'; xs = x.split('-', 1); e = 'production' if len(xs) < 2 else xs[1]; print(e)")

mkdir -p "/repos/$product_name/${environment}/"
environment_file="/repos/$product_name/${environment}/.env"

function create_environment_file() {
  #  local domain
  #  domain="https://interintel.xently.co.ke"

  local user
  user=$(logname 2>/dev/null || echo "$SUDO_USER")

  local database_name
  database_name="xently_${product_name}_${environment}"

  local database_user_password
  database_user_password=$(option_passed --database-user-password --require-value)
  if [ -z "$database_user_password" ] || [ "$database_user_password" == "0" ]; then
    echo -e "${DANGER}Please specify a database password to use for $WARNING'$user'$DANGER using $WARNING--database-user-password=<database-user-password>${DANGER} option.$NEUTRAL" >&2
    exit 1
  fi

  secret_key_file="/repos/$product_name/.secret_key"
  if ! [ -f $secret_key_file ]; then
    openssl rand --base64 150 | tee -a $secret_key_file &>/dev/null
  fi

  echo_warning "Environment variable file not found! Creating..."
  cat >"$environment_file" <<EOF
SECRET_KEY=$(cat "$secret_key_file")
DB_NAME=$database_name
DB_USER=$user
DB_PASSWORD=$database_user_password
EOF
}

if ! [ -f "$environment_file" ]; then
  create_environment_file
fi

container_name="${product_name}-${environment}-web"
temporary_container_name="$container_name.$(date +'%s')"

echo_warning "Updating '$container_name' to version '$version' in '$environment'..."

if ! docker rename "$container_name" "$temporary_container_name"; then
  echo_warning "Could not rename '$container_name' container"
else
  echo_success "Renamed container '$container_name' to '$temporary_container_name'"
fi

docker run --detach \
  --network host \
  --name "$container_name" \
  --restart unless-stopped \
  --user root \
  --env-file "$environment_file" \
  --volume /repos/"$product_name"/public:/app/public \
  --volume /sites/.logs:/app/logs \
  "$docker_image"

docker exec "$container_name" ./manage.py migrate --noinput

docker exec "$container_name" ./manage.py collectstatic --noinput --verbosity 0

echo_warning "Stopping old container '$container_name'..."
docker stop "$temporary_container_name" || true

echo_warning "Removing old container '$container_name'..."
docker rm "$temporary_container_name" || true

echo_warning "Cleaning up unused data..."
docker system prune --all --force

echo_success "Successfully updated container '$container_name' to version '$version'."
