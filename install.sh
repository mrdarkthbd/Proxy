#!/bin/bash

# Verificar se o proxy já está instalado
if [ -f /usr/bin/proxy ]; then
    echo "The proxy is already installed. Skipping the installation."
else
# Função para instalar o proxy
    install_proxy() {
        echo "Installing the proxy..."
        {
            rm -f /usr/bin/proxy
            curl -s -L -o /usr/bin/proxy https://raw.githubusercontent.com/mrdarkthbd/proxy/main/proxy
            chmod +x /usr/bin/proxy
        } > /dev/null 2>&1
        echo "Proxy installed successfully."
    }
    
# Instalar o proxy
    install_proxy
fi

# Desinstalar o proxy
uninstall_proxy() {
    echo -e "\nUninstalling the proxy..."
    
    # Encontra e remove todos os arquivos de serviço do proxy
    service_files=$(find /etc/systemd/system -name 'proxy-*.service')
    for service_file in $service_files; do
        service_name=$(basename "$service_file")
        service_name=${service_name%.service}
        
        # Verifica se o serviço está ativo antes de tentar parar e desabilitar
        if  systemctl is-active "$service_name" &> /dev/null; then
            systemctl stop "$service_name"
            systemctl disable "$service_name"
        fi
        
        rm -f "$service_file"
        echo "Serviço $service_name parado e arquivo de serviço removido: $service_file"
    done
    
    # Remove o arquivo binário do proxy
    rm -f /usr/bin/proxy
    
    echo "Proxy uninstalled successfully."
}

# Mostrar portas em uso
show_ports_in_use() {
    local ports_in_use=$(systemctl list-units --all --plain --no-legend | grep -oE 'proxy-[0-9]+' | cut -d'-' -f2)
    if [ -n "$ports_in_use" ]; then
        ports_in_use=$(echo "$ports_in_use" | tr '\n' ' ')
        echo -e "\033[1;34m║\033[1;32mIN use:\033[1;33m $(printf '%-21s' "$ports_in_use")\033[1;34m║\033[0m"
        echo -e "\033[1;34m║═════════════════════════════║\033[0m"
    fi
}

# Configurar e iniciar o serviço
configure_and_start_service() {
    read -p "WHICH PORT DO YOU WANT TO ACTIVATE? (--port): " PORT
    read -p "Do you want to use HTTP(H) ou HTTPS(S)? [H/S]: " HTTP_OR_HTTPS
    CERT_PATH="/root/cert.pem"  # Caminho padrão para o certificado
    RESPONSE=""
    
    if [[ $HTTP_OR_HTTPS == "H" || $HTTP_OR_HTTPS == "h" ]]; then
        read -p "Add Your Proxy Banner (--response): " RESPONSE
    fi
    
    read -p "You want to use SSH only (Y/N)? [Y/N]: " SSH_ONLY
    read -p "Enter the buffer size (recommended 32768) (--buffer-size): " BUFFER_SIZE
    read -p "type it the number of workers (recommended 2500) (--workers): " WORKERS

    # Defina as opções de comando
    OPTIONS="--port $PORT"
    
    if [[ $HTTP_OR_HTTPS == "S" || $HTTP_OR_HTTPS == "s" ]]; then
        OPTIONS="$OPTIONS --https --cert $CERT_PATH"
    else
        OPTIONS="$OPTIONS --http"
    fi
    
    if [[ $SSH_ONLY == "Y" || $SSH_ONLY == "y" ]]; then
        OPTIONS="$OPTIONS --ssh-only"
    fi
    
    # Crie o arquivo de serviço
    SERVICE_FILE="/etc/systemd/system/proxy-$PORT.service"
    echo "[Unit]" > "$SERVICE_FILE"
    echo "Description=Proxy Service on Port $PORT" >> "$SERVICE_FILE"
    echo "After=network.target" >> "$SERVICE_FILE"
    echo "" >> "$SERVICE_FILE"
    echo "[Service]" >> "$SERVICE_FILE"
    echo "Type=simple" >> "$SERVICE_FILE"
    echo "User=root" >> "$SERVICE_FILE"
    echo "WorkingDirectory=/root" >> "$SERVICE_FILE"
    echo "ExecStart=/usr/bin/proxy $OPTIONS --buffer-size $BUFFER_SIZE --workers $WORKERS --response $RESPONSE" >> "$SERVICE_FILE"
    echo "Restart=always" >> "$SERVICE_FILE"
    echo "" >> "$SERVICE_FILE"
    echo "[Install]" >> "$SERVICE_FILE"
    echo "WantedBy=multi-user.target" >> "$SERVICE_FILE"
    
    # Recarregue o systemd
    systemctl daemon-reload
    
    # Inicie o serviço e configure o início automático
    systemctl start proxy-$PORT
    systemctl enable proxy-$PORT
    
    echo "O serviço do proxy na porta $PORT foi configurado e iniciado automaticamente."
}

# Parar e remover serviços
stop_and_remove_service() {
    read -p "WHICH PORT DO YOU WANT TO REMOVE: " service_number
    
    # Parar o serviço
    systemctl stop proxy-$service_number
    
    # Desabilitar o serviço
    systemctl disable proxy-$service_number
    
    # Encontrar e remover o arquivo do serviço
    service_file=$(find /etc/systemd/system -name "proxy-$service_number.service")
    if [ -f "$service_file" ]; then
        rm "$service_file"
        echo "Arquivo de serviço removido: $service_file"
    else
        echo "Arquivo de serviço não encontrado para o serviço proxy-$service_number."
    fi
    
    echo "Serviço proxy-$service_number parado e removido."
}

# Criar link simbólico para o script do menu
SCRIPT_PATH=$(realpath "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
LINK_NAME="/usr/local/bin/mainproxy"

if [[ ! -f "$LINK_NAME" ]]; then
    ln -s "$SCRIPT_PATH" "$LINK_NAME"
    echo "Link simbólico 'mainproxy' criado. You can run the menu using 'mainproxy'."
else
    echo "Link symbolic 'mainproxy' already exists."
fi


# Menu de gerenciamento
while true; do
    clear
    
    echo -e "\033[1;34m╔═════════════════════════════╗\033[0m"
    echo -e "\033[1;34m║\033[1;41m\033[1;32m      Mod Proxy Menu     \033[0m\033[1;34m║"
    echo -e "\033[1;34m║═════════════════════════════║\033[0m"

    show_ports_in_use
    
    echo -e "\033[1;34m║\033[1;36m[\033[1;32m01\033[1;36m] \033[1;32m• \033[1;31mOPEN PORT           \033[1;34m║"
    echo -e "\033[1;34m║\033[1;36m[\033[1;32m02\033[1;36m] \033[1;32m• \033[1;31mCLOSE PORT          \033[1;34m║"
    echo -e "\033[1;34m║\033[1;36m[\033[1;32m03\033[1;36m] \033[1;32m• \033[1;31mRESET PORT       \033[1;34m║"
    echo -e "\033[1;34m║\033[1;36m[\033[1;32m04\033[1;36m] \033[1;32m• \033[1;31mMONITOR               \033[1;34m║"
    echo -e "\033[1;34m║\033[1;36m[\033[1;32m05\033[1;36m] \033[1;32m• \033[1;31mINSTALLER PORT  \033[1;34m║"
    echo -e "\033[1;34m║\033[1;36m[\033[1;32m06\033[1;36m] \033[1;32m• \033[1;31mUNINSTALL PROXY     \033[1;34m║"
    echo -e "\033[1;34m║\033[1;36m[\033[1;32m07\033[1;36m] \033[1;32m• \033[1;31mEXIT                  \033[1;34m║"
    echo -e "\033[1;34m╚═════════════════════════════╝\033[0m"
   
    read -p "Choose an option: " choice

    case $choice in
        1)
            configure_and_start_service
        ;;
        2)
            stop_and_remove_service
        ;;
        3)
            echo "Serviços em execução:"
            systemctl list-units --type=service --state=running | grep proxy-
            read -p "Enter the number of the service to be restarted: " service_number
            systemctl restart proxy-$service_number
            echo "Serviço proxy-$service_number reiniciado."
        ;;
        4)
            systemctl list-units --type=service --state=running | grep proxy-
        ;;
        5)
            echo "Uninstalling the proxy before reinstalling..."
            uninstall_proxy
            install_proxy
        ;;
        6)
            uninstall_proxy
        ;;
        7)
            echo "Saindo."
            break
        ;;
        *)
            echo "Invalid option. Choose a valid option."
        ;;
    esac
    
    read -p "Press Enter to continue..."
done
