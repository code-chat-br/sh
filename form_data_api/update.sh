#!/bin/bash

whiptail --title "CODECHAT API - FORM-DATA" --msgbox "Pressione ENTER para iniciar a atualização:" --fb 10 50

# Acessando diretório do projeto e atualizando o código.
cd ~/Projects/form-data-api
git pull origin main

cd ~/Projects

# Carregando credenciais
source ~/Projects/credencials.sh

sudo docker buildx create --name codechat --use

# Buildando a imagem
sudo docker buildx build \
  --build-arg AUTHENTICATION_GLOBAL_AUTH_TOKEN=$AUTHENTICATION_GLOBAL_AUTH_TOKEN \
  --build-arg MONGO_INITDB_ROOT_PASSWORD=$MONGO_INITDB_ROOT_PASSWORD \
  --build-arg RABBITMQ_DEFAULT_PASS=$RABBITMQ_DEFAULT_PASS \
  -t $IMAGE_NAME_INPUT --load ~/Projects/form-data-api

# Lista todos os containers cujo nome contém 'api-'
containers=$(docker ps --filter "name=api-" --format "{{.Names}}")

# Verifica se algum container foi encontrado
if [ -z "$containers" ]; then
  echo "Nenhum container com 'api-' no nome foi encontrado."
  kill -INT $$
fi

# Reinicia cada container encontrado
for container in $containers; do
  echo "Reiniciando container: $container"
  docker restart "$container"
done

echo "Todos os containers foram reiniciados."