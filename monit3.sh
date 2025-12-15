#!/bin/bash

# ============================================
# SYSTEME DE MONITORING SIMPLE
# Auteur : Assistant Bash
# Version : 1.0
# ============================================

# Configuration
LOG_FILE="/var/log/system_monitor.log"
MAX_LOG_SIZE=1048576  # 1 Mo en octets
ALERT_THRESHOLD_CPU=80      # 80%
ALERT_THRESHOLD_MEM=85      # 85%
ALERT_THRESHOLD_DISK=90     # 90%
EMAIL_ADMIN="admin@example.com"  # À configurer

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ============================================
# FONCTIONS DE MONITORING
# ============================================

# Fonction de vérification CPU
check_cpu() {
    echo "=== ANALYSE DU CPU ==="
    
    # Méthode 1: Utilisation moyenne (compatible plupart des systèmes)
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    
    # Méthode alternative si la première ne fonctionne pas
    if [[ -z "$cpu_usage" ]]; then
        cpu_usage=$(vmstat 1 2 | tail -1 | awk '{print 100-$15}')
    fi
    
    echo "Utilisation CPU : ${cpu_usage}%"
    
    # Vérification du seuil d'alerte
    if (( $(echo "$cpu_usage > $ALERT_THRESHOLD_CPU" | bc -l) )); then
        echo -e "${RED}ALERTE: Utilisation CPU élevée!${NC}"
        log_alert "CPU" "$cpu_usage"
        return 1
    elif (( $(echo "$cpu_usage > 70" | bc -l) )); then
        echo -e "${YELLOW}AVERTISSEMENT: CPU modérément élevé${NC}"
        return 2
    else
        echo -e "${GREEN}CPU dans les limites normales${NC}"
        return 0
    fi
}

# Fonction de vérification mémoire
check_memory() {
    echo ""
    echo "=== ANALYSE DE LA MÉMOIRE ==="
    
    # Récupération des statistiques mémoire
    local mem_info=$(free -m | grep Mem)
    local total_mem=$(echo $mem_info | awk '{print $2}')
    local used_mem=$(echo $mem_info | awk '{print $3}')
    local free_mem=$(echo $mem_info | awk '{print $4}')
    local mem_percent=$(echo "scale=2; $used_mem * 100 / $total_mem" | bc)
    
    echo "Mémoire totale : ${total_mem} MB"
    echo "Mémoire utilisée : ${used_mem} MB"
    echo "Mémoire libre : ${free_mem} MB"
    echo "Pourcentage utilisé : ${mem_percent}%"
    
    # Vérification du seuil
    if (( $(echo "$mem_percent > $ALERT_THRESHOLD_MEM" | bc -l) )); then
        echo -e "${RED}ALERTE: Utilisation mémoire élevée!${NC}"
        log_alert "Mémoire" "$mem_percent"
        return 1
    elif (( $(echo "$mem_percent > 75" | bc -l) )); then
        echo -e "${YELLOW}AVERTISSEMENT: Mémoire modérément élevée${NC}"
        return 2
    else
        echo -e "${GREEN}Mémoire dans les limites normales${NC}"
        return 0
    fi
}

# Fonction de vérification espace disque
check_disk() {
    echo ""
    echo "=== ANALYSE DU DISQUE ==="
    local has_alert=0
    
    echo "Partitions principales :"
    echo "-----------------------"
    
    # Analyse des partitions (exclut les systèmes de fichiers temporaires)
    df -h | grep -E '^/dev/(sd|xvd|nvme)' | while read line; do
        local partition=$(echo $line | awk '{print $1}')
        local usage=$(echo $line | awk '{print $5}' | sed 's/%//')
        local available=$(echo $line | awk '{print $4}')
        local mount_point=$(echo $line | awk '{print $6}')
        
        echo "Partition: $partition"
        echo "Point de montage: $mount_point"
        echo "Utilisation: $usage% - Disponible: $available"
        
        if [ "$usage" -ge "$ALERT_THRESHOLD_DISK" ]; then
            echo -e "${RED}ALERTE: Espace disque faible!${NC}"
            log_alert "Disque ($mount_point)" "$usage"
            has_alert=1
        elif [ "$usage" -ge 80 ]; then
            echo -e "${YELLOW}AVERTISSEMENT: Espace disque modérément faible${NC}"
        else
            echo -e "${GREEN}Espace disque OK${NC}"
        fi
        echo ""
    done
    
    return $has_alert
}

# Fonction vérification processus
check_processes() {
    echo ""
    echo "=== PROCESSUS CRITIQUES ==="
    
    # Liste des processus essentiels à vérifier
    local critical_processes=("sshd" "nginx" "mysql" "postgresql" "docker")
    local missing_processes=()
    
    for process in "${critical_processes[@]}"; do
        if pgrep -x "$process" >/dev/null; then
            echo -e "${GREEN}[OK]${NC} $process est en cours d'exécution"
        else
            echo -e "${RED}[ABSENT]${NC} $process n'est pas en cours d'exécution"
            missing_processes+=("$process")
        fi
    done
    
    if [ ${#missing_processes[@]} -gt 0 ]; then
        log_alert "Processus manquants" "${missing_processes[*]}"
        return 1
    fi
    
    # Top 5 des processus consommateurs de mémoire
    echo ""
    echo "Top 5 processus par utilisation mémoire:"
    ps aux --sort=-%mem | head -6 | awk 'NR>1{print $4"% - " $11}'
    
    return 0
}

# ============================================
# FONCTIONS UTILITAIRES
# ============================================

# Journalisation des alertes
log_alert() {
    local component=$1
    local value=$2
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    echo "[$timestamp] ALERTE: $component - Valeur: $value" >> "$LOG_FILE"
}

# Rotation des logs
rotate_logs() {
    if [ -f "$LOG_FILE" ]; then
        local log_size=$(stat -c%s "$LOG_FILE" 2>/dev/null || stat -f%z "$LOG_FILE")
        
        if [ "$log_size" -gt "$MAX_LOG_SIZE" ]; then
            mv "$LOG_FILE" "${LOG_FILE}.$(date +%Y%m%d_%H%M%S)"
            echo "Logs rotated: $LOG_FILE" > "$LOG_FILE"
        fi
    fi
}

# Génération de rapport
generate_report() {
    local report_file="/tmp/system_report_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=== RAPPORT DE SURVEILLANCE SYSTÈME ==="
        echo "Date: $(date)"
        echo "Hostname: $(hostname)"
        echo ""
        check_cpu | tail -5
        echo ""
        check_memory | tail -6
        echo ""
        check_disk
    } > "$report_file"
    
    echo "Rapport généré: $report_file"
}

# Affichage aide
show_help() {
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  -h, --help      Affiche ce message d'aide"
    echo "  -r, --report    Génère un rapport détaillé"
    echo "  -s, --simple    Mode simple (affiche seulement les alertes)"
    echo "  -c, --continuous [INTERVAL]  Mode continu avec intervalle en secondes"
    echo ""
    echo "Exemples:"
    echo "  $0              Exécute une vérification complète"
    echo "  $0 --simple     Mode minimaliste"
    echo "  $0 --continuous 60  Vérification toutes les 60 secondes"
}

# ============================================
# FONCTION PRINCIPALE
# ============================================

main() {
    local mode="normal"
    local interval=60
    
    # Vérification des dépendances
    if ! command -v bc &> /dev/null; then
        echo "Erreur: 'bc' n'est pas installé. Installez-le avec:"
        echo "  Ubuntu/Debian: sudo apt-get install bc"
        echo "  RHEL/CentOS: sudo yum install bc"
        exit 1
    fi
    
    # Rotation des logs
    rotate_logs
    
    # Traitement des arguments
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -r|--report)
            generate_report
            exit 0
            ;;
        -s|--simple)
            mode="simple"
            ;;
        -c|--continuous)
            mode="continuous"
            if [ -n "$2" ] && [[ "$2" =~ ^[0-9]+$ ]]; then
                interval=$2
            fi
            ;;
    esac
    
    # Exécution du monitoring
    if [ "$mode" = "continuous" ]; then
        echo "Démarrage du monitoring en continu (intervalle: ${interval}s)"
        echo "Appuyez sur Ctrl+C pour arrêter"
        echo ""
        
        while true; do
            echo "=== $(date) ==="
            check_cpu > /dev/null 2>&1
            check_memory > /dev/null 2>&1
            check_disk > /dev/null 2>&1
            echo "----------------"
            sleep $interval
        done
    else
        if [ "$mode" = "simple" ]; then
            # Mode simple: seulement les alertes
            check_cpu | grep -E "ALERTE|AVERTISSEMENT"
            check_memory | grep -E "ALERTE|AVERTISSEMENT"
            check_disk | grep -E "ALERTE|AVERTISSEMENT"
        else
            # Mode normal complet
            echo "Démarrage du monitoring système..."
            echo "Date: $(date)"
            echo "Hostname: $(hostname)"
            echo ""
            
            check_cpu
            check_memory
            check_disk
            check_processes
            
            echo ""
            echo "Monitoring terminé. Vérifiez $LOG_FILE pour les alertes."
        fi
    fi
}

# ============================================
# EXÉCUTION
# ============================================

# Point d'entrée principal
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi