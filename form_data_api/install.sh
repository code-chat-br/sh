#!/bin/bash
whiptail --title "CODECHAT API - FORM-DATA" --msgbox "Pressione ENTER para iniciar a instalação:" --fb 10 50

echo ""
echo " ██████╗ ██████╗ ██████╗ ███████╗ ██████╗██╗  ██╗ █████╗ ████████╗     █████╗ ██████╗ ██╗
██╔════╝██╔═══██╗██╔══██╗██╔════╝██╔════╝██║  ██║██╔══██╗╚══██╔══╝    ██╔══██╗██╔══██╗██║
██║     ██║   ██║██║  ██║█████╗  ██║     ███████║███████║   ██║       ███████║██████╔╝██║
██║     ██║   ██║██║  ██║██╔══╝  ██║     ██╔══██║██╔══██║   ██║       ██╔══██║██╔═══╝ ██║
╚██████╗╚██████╔╝██████╔╝███████╗╚██████╗██║  ██║██║  ██║   ██║       ██║  ██║██║     ██║
 ╚═════╝ ╚═════╝ ╚═════╝ ╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝       ╚═╝  ╚═╝╚═╝     ╚═╝"

 echo "███████╗ ██████╗ ██████╗ ███╗   ███╗      ██████╗  █████╗ ████████╗ █████╗ 
██╔════╝██╔═══██╗██╔══██╗████╗ ████║      ██╔══██╗██╔══██╗╚══██╔══╝██╔══██╗
█████╗  ██║   ██║██████╔╝██╔████╔██║█████╗██║  ██║███████║   ██║   ███████║
██╔══╝  ██║   ██║██╔══██╗██║╚██╔╝██║╚════╝██║  ██║██╔══██║   ██║   ██╔══██║
██║     ╚██████╔╝██║  ██║██║ ╚═╝ ██║      ██████╔╝██║  ██║   ██║   ██║  ██║
╚═╝      ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝      ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝"
echo ""

sudo apt update -y
sudo apy upgrade -y

if ! command -v wget &> /dev/null
then
    echo "wget não encontrado, instalando..."
    sudo apt-get install wget -y
fi

echo "Instalando o Docker"
wget -qO- https://get.docker.com -O get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ${USER}
sudo systemctl restart docker
echo ""

echo "Criando rede para os containers se comunicarem"
sudo docker network create api_network -d bridge
echo ""

echo "Verificando se o traefik já está instalado..."
if sudo docker ps -a --format '{{.Names}}' | grep -Eq "^traefik\$"; then
    echo "Traefik já está instalado e em execução."
else
    echo "Instalando o Traefik"

    read -p "Digite o seu email para a configuração do proxy: " email
    if [[ -z "$email" ]]; then
        echo -e "\nErro: O email não pode estar vazio. O processo foi interrompido."
        exit 1
    fi

    echo "Criando volume"
    sudo docker volume create traefik_certificates

    echo "Criando pasta para os logs"
    sudo mkdir -p /var/docker/logs/traefik:

    sudo docker run -d \
        --name traefik \
        --network api_network \
        -p 80:80 \
        -p 8080:8080 \
        -p 443:443 \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v traefik_certificates:/certificates \
        -v /var/docker/logs/traefik:/var/log/traefik \
        --restart always \
        traefik:v3.1.0 \
        --api.insecure=true \
        --global.checkNewVersion=true \
        --global.sendAnonymousUsage=true \
        --entryPoints.web_secure.address=:443 \
        --entryPoints.web_secure.http.tls=true \
        --entryPoints.web.address=:80 \
        --log.level=DEBUG \
        --log.filePath=/var/log/traefik/traefik.log \
        --log.format=json \
        --log.maxSize=100 \
        --log.maxAge=7 \
        --accessLog.filePath=/var/log/traefik/access.log \
        --accessLog.bufferingSize=100 \
        --accessLog.format=json \
        --api.dashboard=true \
        --providers.docker.endpoint=unix:///var/run/docker.sock \
        --providers.docker.exposedByDefault=false \
        --providers.docker.network=api_network \
        --providers.docker.watch=true \
        --certificatesResolvers.letsencrypt_resolver.acme.email=$email \
        --certificatesResolvers.letsencrypt_resolver.acme.httpChallenge.entryPoint=web \
        --certificatesResolvers.letsencrypt_resolver.acme.tlsChallenge=true \
        --certificatesResolvers.letsencrypt_resolver.acme.storage=/etc/traefik/letsencrypt/acme.json

fi

echo "Verificando se o RabbitMQ já está instalado..."
if sudo docker ps -a --format '{{.Names}}' | grep -Eq "^rabbitmq\$"; then
    echo "RabbitMQ já está instalado e em execução."
else
    echo "Instalando o RabbitMQ"
    echo "Criando volume"

    # Gerando password
    RABBITMQ_DEFAULT_PASS=$(date +%s | sha256sum | base64 | head -c 32)

    sudo docker pull rabbitmq:4.0.0-rc.1-management
    sudo docker volume create rabbitmq_data

    sudo docker run -d \
        --name rabbitmq \
        --hostname rabbitmq \
        --network api_network \
        -p 5672:5672 \
        -p 15672:15672 \
        -v rabbitmq_data:/var/lib/rabbitmq/ \
        -e RABBITMQ_ERLANG_COOKIE="WwTp38wHvD523l6TE4fd4DfsWdwgfr56r8wet" \
        -e RABBITMQ_DEFAULT_VHOST="vhost_codechat_formdata" \
        -e RABBITMQ_DEFAULT_USER="root" \
        -e RABBITMQ_DEFAULT_PASS="$RABBITMQ_DEFAULT_PASS" \
        --restart always \
        rabbitmq:4.0.0-rc.1-management rabbitmq-server

    echo "┌─────────────────────────────────────────┐"
    echo "│ RABBITMQ                                │"
    echo "├─────────────────────────────────────────┤"
    echo "│ User: root                              │"
    echo "│ Pass: $RABBITMQ_DEFAULT_PASS            │"
    echo "└─────────────────────────────────────────┘"
    echo ""
fi

echo ""
echo "Verificando se o MongoDB já está instalado..."
if sudo docker ps -a --format '{{.Names}}' | grep -Eq "^mongo_server\$"; then
    echo "RabbitMQ já está instalado e em execução."
else
  echo "Instando o MongoDb"
  echo "Criando volume"

  # Gerando password
  MONGO_INITDB_ROOT_PASSWORD=$(date +%s | sha256sum | base64 | head -c 32)

  sudo docker pull mongo:4
  sudo docker volume create mongo_data

  sudo docker run -d \
    --name mongo_server \
    --network api_network \
    -p 27017:27017 \
    -v mongo_data:/data/db \
    -e MONGO_INITDB_ROOT_USERNAME=root \
    -e MONGO_INITDB_ROOT_PASSWORD=$MONGO_INITDB_ROOT_PASSWORD \
    --restart always \
    mongo:4

  echo "┌─────────────────────────────────────────┐"
  echo "│ MONGO DB                                │"
  echo "├─────────────────────────────────────────┤"
  echo "│ User: root                              │"
  echo "│ Pass: $MONGO_INITDB_ROOT_PASSWORD  │"
  echo "└─────────────────────────────────────────┘"
  echo ""
fi

echo ""
echo "Criando pasta do projeto"
if [ ! -d ~/Projects ]; then
    mkdir ~/Projects
fi

echo "Instalando o git"
sudo apt install git -y

while true; do
    if [ -d ~/Projects/form-data-api ]; then
        # Verifica se o diretório está vazio
        if [ "$(ls -A ~/Projects/form-data-api)" ]; then
            echo "O diretório '~/Projects/form-data-api' já existe e não está vazio. Tentando atualizar com git pull..."
            cd ~/Projects/form-data-api
            git pull
            if [ $? -eq 0 ]; then
                echo "Repositório atualizado com sucesso!"
                break
            else
                echo "Falha ao atualizar o repositório. Por favor, verifique suas credenciais."
            fi
        else
            echo "O diretório '~/Projects/form-data-api' está vazio. Tentando clonar o repositório..."
            git clone https://github.com/code-chat-br/form-data-api ~/Projects/form-data-api
            if [ $? -eq 0 ]; then
                echo "Repositório clonado com sucesso!"
                break
            else
                echo "Falha ao clonar o repositório. Por favor, verifique suas credenciais."
            fi
        fi
    else
        echo "Clonando o repositório..."
        git clone https://github.com/code-chat-br/form-data-api ~/Projects/form-data-api
        if [ $? -eq 0 ]; then
            echo "Repositório clonado com sucesso!"
            break
        else
            echo "Falha ao clonar o repositório. Por favor, verifique suas credenciais."
        fi
    fi

    read -p "Deseja tentar novamente? (s/n): " retry
    if [ "$retry" != "s" ]; then
        echo "Interrompendo o script."
        kill -INT $$
    fi
done
cd ~/Projects

echo ""
echo "Gerando senha de usuário root da aplicação"
AUTHENTICATION_GLOBAL_AUTH_TOKEN=$(date +%s | sha256sum | base64 | head -c 64)

IMAGE_NAME_INPUT=$(whiptail --title "NOME DA IMAGEM" --inputbox "Digite o nome com o qual dejeja builda a imagem:\n* Formato: repository/tag:version\n* Exemplo: codechat/form-data-api:v1.0.0\n\nDefault: codechat/form-data-api:latest" --fb 15 65 3>&1 1>&2 2>&3)

if [ -z "$IMAGE_NAME_INPUT" ]; then
  IMAGE_NAME_INPUT=codechat/form-data-api:latest
fi


echo ""
echo "Iniciando o build"
echo ""

sudo docker buildx create --name codechat --use

sudo docker buildx build \
  --build-arg AUTHENTICATION_GLOBAL_AUTH_TOKEN=$AUTHENTICATION_GLOBAL_AUTH_TOKEN \
  --build-arg MONGO_INITDB_ROOT_PASSWORD=$MONGO_INITDB_ROOT_PASSWORD \
  --build-arg RABBITMQ_DEFAULT_PASS=$RABBITMQ_DEFAULT_PASS \
  -t $IMAGE_NAME_INPUT --load ~/Projects/form-data-api

echo ""
echo "┌───────────────────────────────────────────┐"
echo "│            IGNORE OS AVISO ACIMA          │"
echo "└───────────────────────────────────────────┘"
echo ""

echo ""
echo "Verificando se o VDM já está instalado..."
if sudo docker ps -a --format '{{.Names}}' | grep -Eq "^codechat_vdm\$"; then
    echo "RabbitMQ já está instalado e em execução."
else
  echo "Instando o VDM"

  docker pull codechat/vdm:latest-slim

  # Gerando password
  VDM_AUTH_TOKEN=$(date +%s | sha256sum | base64 | head -c 32)

  docker run -d \
    --name codechat_vdm \
    --network api_network \
    -p 3000:3000 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -e DOCKER_DEFAULT_IMAGE=$IMAGE_NAME_INPUT \
    -e DOCKER_NETWORK=api_network \
    -e DOCKER_SOCKET=/var/run/docker.sock \
    -e AUTH_TOKEN=$VDM_AUTH_TOKEN \
    -l traefik.enable=true \
    -l traefik.http.routers.codechat_vdm.rule=PathPrefix\(\`\/vdm\`\) \
    -l traefik.http.routers.codechat_vdm.entrypoints=web \
    -l traefik.http.routers.codechat_vdm.service=codechat_vdm \
    -l traefik.http.services.codechat_vdm.loadbalancer.server.port=3000 \
    --restart always \
    codechat/vdm:latest-slim

  echo "┌─────────────────────────────────────────┐"
  echo "│ VDM TOKEN                               │"
  echo "├─────────────────────────────────────────┤"
  echo "│     $VDM_AUTH_TOKEN    │"
  echo "└─────────────────────────────────────────┘"
  echo ""
fi

echo "┌───────────────────────────────────────────┐"
echo "│               Credenciais                 │"
echo "└───────────────────────────────────────────┘"

echo "
export AUTHENTICATION_GLOBAL_AUTH_TOKEN=$AUTHENTICATION_GLOBAL_AUTH_TOKEN
export MONGO_USER=root
export MONGO_INITDB_ROOT_PASSWORD=$MONGO_INITDB_ROOT_PASSWORD
export RABBITMQ_DEFAULT_USER=root
export RABBITMQ_DEFAULT_PASS=$RABBITMQ_DEFAULT_PASS
export IMAGE_NAME_INPUT=$IMAGE_NAME_INPUT
export VDM_AUTH_TOKEN=$VDM_AUTH_TOKEN
" > ~/Projects/credencials.sh

echo "
AUTHENTICATION_GLOBAL_AUTH_TOKEN=$AUTHENTICATION_GLOBAL_AUTH_TOKEN

MONGO_USER=root
MONGO_INITDB_ROOT_PASSWORD=$MONGO_INITDB_ROOT_PASSWORD

RABBITMQ_DEFAULT_USER=root
RABBITMQ_DEFAULT_PASS=$RABBITMQ_DEFAULT_PASS

export VDM_AUTH_TOKEN=$VDM_AUTH_TOKEN
"
echo "Caminho das credênciais: ~/Projects/credencials.sh"
echo ""

rm -rf get-docker.sh
echo ""
echo "┌───────────────────────────────────────────┐"
echo "│         Instalação finalizada             │"
echo "└───────────────────────────────────────────┘"
echo ""