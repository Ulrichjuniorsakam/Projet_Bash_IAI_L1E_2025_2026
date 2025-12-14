#!/bin/bash

# Jeu du Serpent en Bash
# Utilise les flèches directionnelles pour contrôler le serpent

# Configuration
WIDTH=40
HEIGHT=20
SNAKE_CHAR="█"
FOOD_CHAR="●"
EMPTY_CHAR=" "

# Variables du jeu
declare -a snake_x
declare -a snake_y
score=0
game_over=0
direction="RIGHT"
food_x=0
food_y=0

# Initialisation du terminal
init_terminal() {
    tput civis  # Cache le curseur
    clear
    stty -echo  # Cache l'input
    trap cleanup EXIT
}

# Nettoyage à la sortie
cleanup() {
    tput cnorm  # Affiche le curseur
    stty echo   # Réactive l'input
    clear
}

# Initialise le serpent
init_snake() {
    snake_x[0]=10
    snake_y[0]=10
    snake_x[1]=9
    snake_y[1]=10
    snake_x[2]=8
    snake_y[2]=10
}

# Place la nourriture aléatoirement
place_food() {
    local valid=0
    while [ $valid -eq 0 ]; do
        food_x=$((RANDOM % (WIDTH - 2) + 1))
        food_y=$((RANDOM % (HEIGHT - 2) + 1))
        valid=1
        for i in "${!snake_x[@]}"; do
            if [ ${snake_x[$i]} -eq $food_x ] && [ ${snake_y[$i]} -eq $food_y ]; then
                valid=0
                break
            fi
        done
    done
}

# Dessine le plateau de jeu
draw_board() {
    tput cup 0 0
    
    # Bordure supérieure
    printf "┌"
    for ((i=0; i<WIDTH; i++)); do printf "─"; done
    printf "┐\n"
    
    # Corps du plateau
    for ((y=1; y<=HEIGHT; y++)); do
        printf "│"
        for ((x=1; x<=WIDTH; x++)); do
            local is_snake=0
            for i in "${!snake_x[@]}"; do
                if [ ${snake_x[$i]} -eq $x ] && [ ${snake_y[$i]} -eq $y ]; then
                    printf "$SNAKE_CHAR"
                    is_snake=1
                    break
                fi
            done
            
            if [ $is_snake -eq 0 ]; then
                if [ $food_x -eq $x ] && [ $food_y -eq $y ]; then
                    printf "$FOOD_CHAR"
                else
                    printf "$EMPTY_CHAR"
                fi
            fi
        done
        printf "│\n"
    done
    
    # Bordure inférieure
    printf "└"
    for ((i=0; i<WIDTH; i++)); do printf "─"; done
    printf "┘\n"
    
    printf "Score: %d | Utilisez les flèches pour jouer | Q pour quitter\n" $score
}

# Vérifie les collisions
check_collision() {
    local head_x=${snake_x[0]}
    local head_y=${snake_y[0]}
    
    # Collision avec les murs
    if [ $head_x -le 0 ] || [ $head_x -gt $WIDTH ] || [ $head_y -le 0 ] || [ $head_y -gt $HEIGHT ]; then
        return 1
    fi
    
    # Collision avec soi-même
    for ((i=1; i<${#snake_x[@]}; i++)); do
        if [ ${snake_x[$i]} -eq $head_x ] && [ ${snake_y[$i]} -eq $head_y ]; then
            return 1
        fi
    done
    
    return 0
}

# Déplace le serpent
move_snake() {
    local new_x=${snake_x[0]}
    local new_y=${snake_y[0]}
    
    case $direction in
        UP)    ((new_y--)) ;;
        DOWN)  ((new_y++)) ;;
        LEFT)  ((new_x--)) ;;
        RIGHT) ((new_x++)) ;;
    esac
    
    # Ajoute la nouvelle tête
    snake_x=($new_x "${snake_x[@]}")
    snake_y=($new_y "${snake_y[@]}")
    
    # Vérifie si on mange la nourriture
    if [ $new_x -eq $food_x ] && [ $new_y -eq $food_y ]; then
        ((score+=10))
        place_food
    else
        # Retire la queue si pas de nourriture
        unset snake_x[${#snake_x[@]}-1]
        unset snake_y[${#snake_y[@]}-1]
    fi
    
    check_collision
    return $?
}

# Lit l'input du joueur
read_input() {
    local key
    read -t 0.1 -n 3 key
    
    case $key in
        $'\x1b[A') [ "$direction" != "DOWN" ] && direction="UP" ;;
        $'\x1b[B') [ "$direction" != "UP" ] && direction="DOWN" ;;
        $'\x1b[D') [ "$direction" != "RIGHT" ] && direction="LEFT" ;;
        $'\x1b[C') [ "$direction" != "LEFT" ] && direction="RIGHT" ;;
        q|Q) game_over=1 ;;
    esac
}

# Boucle principale du jeu
main() {
    init_terminal
    init_snake
    place_food
    
    while [ $game_over -eq 0 ]; do
        draw_board
        read_input
        
        if ! move_snake; then
            game_over=1
        fi
        
        sleep 0.1
    done
    
    tput cup $((HEIGHT + 4)) 0
    printf "\n🎮 Game Over! Score final: %d\n\n" $score
    
    read -p "Appuyez sur Entrée pour quitter..."
}

# Lance le jeu
main
