#!/bin/bash

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour afficher le menu
afficher_menu() {
    clear
    echo -e "${BLUE}=================================${NC}"
    echo -e "${BLUE}    GESTIONNAIRE RÉSEAU          ${NC}"
    echo -e "${BLUE}=================================${NC}"
    echo -e "1. Vérifier la connectivité réseau"
    echo -e "2. Tester une adresse IP"
    echo -e "3. Surveiller les interfaces réseau"
    echo -e "4. Analyser les ports locaux"
    echo -e "5. Tester la résolution DNS"
    echo -e "6. Informations réseau complètes"
    echo -e "7. Quitter"
    echo -e "${BLUE}=================================${NC}"
}

# Fonction pour vérifier la connectivité
verifier_connectivite() {
    echo -e "\n${YELLOW}[1] VÉRIFICATION DE CONNECTIVITÉ${NC}"
    echo -e "${BLUE}---------------------------------${NC}"
    
    # Test de connexion Internet
    echo -e "Test de connexion Internet..."
    
    # Essayer plusieurs méthodes
    if ping -c 3 8.8.8.8 > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Connectivité vers 8.8.8.8 (Google DNS) : OK${NC}"
    else
        echo -e "${RED}✗ Connectivité vers 8.8.8.8 : ÉCHEC${NC}"
    fi
    
    if ping -c 3 google.com > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Résolution DNS et connexion : OK${NC}"
    else
        echo -e "${RED}✗ Résolution DNS : ÉCHEC${NC}"
    fi
    
    # Test de latence
    echo -e "\nTest de latence vers 8.8.8.8 :"
    ping -c 4 8.8.8.8 | tail -2
    
    read -p "Appuyez sur Entrée pour continuer..."
}

# Fonction pour tester une adresse IP
tester_ip() {
    echo -e "\n${YELLOW}[2] TEST D'ADRESSE IP${NC}"
    echo -e "${BLUE}---------------------------------${NC}"
    
    read -p "Entrez l'adresse IP à tester : " ip_address
    
    if [[ -z "$ip_address" ]]; then
        echo -e "${RED}Aucune adresse IP fournie.${NC}"
        read -p "Appuyez sur Entrée pour continuer..."
        return
    fi
    
    # Validation basique de l'adresse IP
    if [[ ! $ip_address =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}Format d'adresse IP invalide.${NC}"
        read -p "Appuyez sur Entrée pour continuer..."
        return
    fi
    
    echo -e "\nTest de l'adresse IP: $ip_address"
    echo -e "${BLUE}---------------------------------${NC}"
    
    # Test de ping
    echo -e "Envoi de 4 paquets ICMP..."
    if ping -c 4 $ip_address > /dev/null 2>&1; then
        echo -e "${GREEN}✓ L'adresse $ip_address répond au ping${NC}"
        
        # Afficher les statistiques détaillées
        echo -e "\nStatistiques détaillées :"
        ping -c 4 $ip_address | tail -3
        
        # Tenter une résolution DNS inverse
        echo -e "\nTentative de résolution DNS inverse..."
        host_result=$(host $ip_address 2>/dev/null)
        if [[ $? -eq 0 ]]; then
            echo -e "Nom d'hôte : $host_result"
        fi
    else
        echo -e "${RED}✗ L'adresse $ip_address ne répond pas${NC}"
        
        # Vérifier si c'est une adresse locale
        if [[ $ip_address =~ ^(10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.) ]]; then
            echo -e "${YELLOW}Note : Cette adresse appartient à une plage privée (RFC 1918)${NC}"
        fi
    fi
    
    # Test de ports communs (optionnel)
    echo -e "\n${YELLOW}Voulez-vous tester des ports TCP? (o/n)${NC}"
    read -n 1 -r test_ports
    echo
    
    if [[ $test_ports =~ ^[OoYy]$ ]]; then
        echo -e "Test des ports communs (cela peut prendre quelques secondes)..."
        
        ports=(22 80 443 21 25 53)
        for port in "${ports[@]}"; do
            timeout 2 bash -c "echo > /dev/tcp/$ip_address/$port" 2>/dev/null
            if [[ $? -eq 0 ]]; then
                case $port in
                    22) service="SSH";;
                    80) service="HTTP";;
                    443) service="HTTPS";;
                    21) service="FTP";;
                    25) service="SMTP";;
                    53) service="DNS";;
                    *) service="Inconnu";;
                esac
                echo -e "${GREEN}  Port $port ($service) : OUVERT${NC}"
            else
                echo -e "${RED}  Port $port : FERMÉ${NC}"
            fi
        done
    fi
    
    read -p "Appuyez sur Entrée pour continuer..."
}

# Fonction pour surveiller les interfaces réseau
surveiller_interfaces() {
    echo -e "\n${YELLOW}[3] ÉTAT DES INTERFACES RÉSEAU${NC}"
    echo -e "${BLUE}---------------------------------${NC}"
    
    # Obtenir la liste des interfaces
    echo -e "${YELLOW}Interfaces réseau disponibles :${NC}"
    echo -e "${BLUE}---------------------------------${NC}"
    
    # Utiliser ip addr si disponible, sinon ifconfig
    if command -v ip > /dev/null 2>&1; then
        interfaces=$(ip -o link show | awk -F': ' '{print $2}')
    else
        interfaces=$(ifconfig -a | grep -o '^[a-zA-Z0-9]*' | tr '\n' ' ')
    fi
    
    # Afficher les interfaces
    count=1
    declare -a interface_list
    for iface in $interfaces; do
        if [[ $iface != "lo" ]]; then
            echo -e "$count. $iface"
            interface_list[$count]=$iface
            ((count++))
        fi
    done
    
    echo -e "\n${YELLOW}Informations détaillées :${NC}"
    echo -e "${BLUE}---------------------------------${NC}"
    
    # Afficher toutes les interfaces avec ip addr
    if command -v ip > /dev/null 2>&1; then
        ip -c addr show
    else
        ifconfig -a
    fi
    
    echo -e "\n${YELLOW}Statistiques des interfaces :${NC}"
    echo -e "${BLUE}---------------------------------${NC}"
    
    if command -v ip > /dev/null 2>&1; then
        ip -s link show
    else
        netstat -i
    fi
    
    # Option pour surveiller une interface spécifique
    echo -e "\n${YELLOW}Surveiller une interface spécifique ? (o/n)${NC}"
    read -n 1 -r monitor_choice
    echo
    
    if [[ $monitor_choice =~ ^[OoYy]$ ]] && [ ${#interface_list[@]} -gt 0 ]; then
        echo -e "\nSélectionnez une interface :"
        select iface in "${interface_list[@]}"; do
            if [[ -n "$iface" ]]; then
                echo -e "\n${YELLOW}Surveillance de l'interface $iface (Ctrl+C pour arrêter)${NC}"
                echo -e "${BLUE}---------------------------------${NC}"
                
                if command -v iftop > /dev/null 2>&1; then
                    echo -e "Utilisation de iftop pour le trafic en temps réel..."
                    sudo iftop -i $iface
                elif command -v nload > /dev/null 2>&1; then
                    echo -e "Utilisation de nload pour le trafic en temps réel..."
                    nload $iface
                else
                    echo -e "${YELLOW}iftop ou nload non installés. Installation recommandée.${NC}"
                    echo -e "Installation : sudo apt-get install iftop ou sudo yum install iftop"
                fi
                break
            fi
        done
    fi
    
    read -p "Appuyez sur Entrée pour continuer..."
}

# Fonction pour analyser les ports locaux
analyser_ports() {
    echo -e "\n${YELLOW}[4] ANALYSE DES PORTS LOCAUX${NC}"
    echo -e "${BLUE}---------------------------------${NC}"
    
    echo -e "${YELLOW}Ports en écoute localement :${NC}"
    
    if command -v ss > /dev/null 2>&1; then
        ss -tulpn | head -20
    elif command -v netstat > /dev/null 2>&1; then
        netstat -tulpn | head -20
    else
        echo -e "${RED}ss ou netstat non disponibles${NC}"
    fi
    
    echo -e "\n${YELLOW}Connexions établies :${NC}"
    
    if command -v ss > /dev/null 2>&1; then
        ss -tupn | head -20
    elif command -v netstat > /dev/null 2>&1; then
        netstat -tupn | head -20
    fi
    
    read -p "Appuyez sur Entrée pour continuer..."
}

# Fonction pour tester la résolution DNS
tester_dns() {
    echo -e "\n${YELLOW}[5] TEST DE RÉSOLUTION DNS${NC}"
    echo -e "${BLUE}---------------------------------${NC}"
    
    # Vérifier les serveurs DNS configurés
    echo -e "${YELLOW}Serveurs DNS configurés :${NC}"
    if [[ -f /etc/resolv.conf ]]; then
        grep -E '^nameserver' /etc/resolv.conf | awk '{print "  " $2}'
    fi
    
    # Tester la résolution
    echo -e "\n${YELLOW}Test de résolution DNS :${NC}"
    
    domains=("google.com" "github.com" "localhost" "example.com")
    for domain in "${domains[@]}"; do
        if host $domain > /dev/null 2>&1; then
            echo -e "${GREEN}✓ $domain : Résolu avec succès${NC}"
        else
            echo -e "${RED}✗ $domain : Échec de résolution${NC}"
        fi
    done
    
    # Test DNS inverse
    echo -e "\n${YELLOW}Test DNS inverse (pour 8.8.8.8) :${NC}"
    if host 8.8.8.8 > /dev/null 2>&1; then
        echo -e "${GREEN}✓ DNS inverse fonctionnel${NC}"
    else
        echo -e "${YELLOW}⚠ DNS inverse limité${NC}"
    fi
    
    read -p "Appuyez sur Entrée pour continuer..."
}

# Fonction pour informations complètes
info_completes() {
    echo -e "\n${YELLOW}[6] INFORMATIONS RÉSEAU COMPLÈTES${NC}"
    echo -e "${BLUE}---------------------------------${NC}"
    
    # Adresse IP publique
    echo -e "${YELLOW}Adresse IP publique :${NC}"
    curl -s ifconfig.me 2>/dev/null || echo "Non disponible"
    
    # Informations système
    echo -e "\n${YELLOW}Informations système réseau :${NC}"
    if command -v ip > /dev/null 2>&1; then
        echo -e "${BLUE}Adresses IP :${NC}"
        ip addr show | grep -E 'inet '
        
        echo -e "\n${BLUE}Table de routage :${NC}"
        ip route show | head -10
    fi
    
    # Informations sur la carte réseau
    echo -e "\n${YELLOW}Cartes réseau :${NC}"
    if command -v lshw > /dev/null 2>&1; then
        sudo lshw -class network 2>/dev/null | grep -E '(description|produit|fabriquant|logique)' | head -20
    else
        echo -e "Installez lshw pour plus d'informations : sudo apt-get install lshw"
    fi
    
    read -p "Appuyez sur Entrée pour continuer..."
}

# Vérifier les dépendances
verifier_dependances() {
    local missing=0
    
    # Vérifier les commandes essentielles
    commands=("ping" "grep" "awk")
    
    for cmd in "${commands[@]}"; do
        if ! command -v $cmd > /dev/null 2>&1; then
            echo -e "${RED}✗ $cmd n'est pas installé${NC}"
            missing=1
        fi
    done
    
    return $missing
}

# Point d'entrée principal
main() {
    # Vérifier les dépendances
    if ! verifier_dependances; then
        echo -e "${RED}Certaines dépendances sont manquantes.${NC}"
        read -p "Continuer quand même ? (o/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[OoYy]$ ]]; then
            exit 1
        fi
    fi
    
    # Message de bienvenue
    echo -e "${GREEN}Gestionnaire Réseau - Version 1.0${NC}"
    echo -e "${YELLOW}Appuyez sur Ctrl+C à tout moment pour quitter${NC}"
    sleep 2
    
    # Boucle principale
    while true; do
        afficher_menu
        read -p "Sélectionnez une option [1-7] : " choix
        
        case $choix in
            1) verifier_connectivite ;;
            2) tester_ip ;;
            3) surveiller_interfaces ;;
            4) analyser_ports ;;
            5) tester_dns ;;
            6) info_completes ;;
            7) 
                echo -e "${GREEN}Au revoir !${NC}"
                exit 0
                ;;
            *) 
                echo -e "${RED}Option invalide${NC}"
                sleep 1
                ;;
        esac
    done
}

# Gérer l'interruption Ctrl+C
trap 'echo -e "\n${RED}Interruption du programme${NC}"; exit 0' INT

# Démarrer le programme
main