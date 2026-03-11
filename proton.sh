#!/bin/bash

# ==========================================
# Configuration & Tier Definitions
# ==========================================
t1=(CH IS SE RO DE ES AT GR)
t2=(PT IT IE NL BE LU DK NO FI CZ HU HR MT RS)
# t3=(FR BR CL CO EE LV LT PL HK IN MD MA MK SG SK SL ZA VN)

# Combine only the uncommented arrays
countries=("${t1[@]}" "${t2[@]}")

# ==========================================
# State Variables
# ==========================================
mode="static"         # Default mode
history=()            # Array to store last 3 countries
current_country=""

# ==========================================
# Functions
# ==========================================

# Cleanup function to disconnect VPN on termination
cleanup() {
    echo -e "\n[!] Script terminated. Disconnecting from ProtonVPN..."
    protonvpn disconnect >/dev/null 2>&1
    exit 0
}

# Trap SIGINT (Ctrl+C) and SIGTERM to run cleanup
trap cleanup SIGINT SIGTERM

# Pick a random country ensuring it wasn't used in the last 3 turns
pick_country() {
    local new_country
    local is_duplicate

    while true; do
        # Generate random index
        local idx=$((RANDOM % ${#countries[@]}))
        new_country="${countries[$idx]}"

        # Check against history
        is_duplicate=0
        for hc in "${history[@]}"; do
            if [[ "$hc" == "$new_country" ]]; then
                is_duplicate=1
                break
            fi
        done

        # Break loop if it's a unique country
        if [[ $is_duplicate -eq 0 ]]; then
            break
        fi
    done

    # Update history array
    history+=("$new_country")

    # Ensure history only keeps the last 3 entries
    if [[ ${#history[@]} -gt 3 ]]; then
        history=("${history[@]:1}") # Remove the first element
    fi

    current_country="$new_country"
}

# Connect to the VPN using the CLI
connect_vpn() {
    pick_country
    echo -e "\n[*] -----------------------------------------"
    echo "[*] Connecting to $current_country..."

    # Execute protonvpn command
    protonvpn connect --country "$current_country"

    echo "[*] History of last 3 countries: [ ${history[*]} ]"
    echo "[*] -----------------------------------------"
}

# ==========================================
# Main Execution
# ==========================================

echo "Starting ProtonVPN Auto-Switcher..."
# Disconnect any existing connections first
protonvpn disconnect >/dev/null 2>&1

# Initial Connection
connect_vpn

# Main listener loop
while true; do
    if [[ "$mode" == "rapid" ]]; then
        # Calculate random sleep time between 20 mins (1200s) and 40 mins (2400s)
        sleep_time=$(( RANDOM % 1201 + 1200 ))
        mins=$(( sleep_time / 60 ))

        echo "[RAPID MODE] Next country switch in ~$mins minutes."
        echo "[Controls: 'n' = Next Country | 'p' = Toggle Mode | 'q' = Quit]"

        # read -t times out after $sleep_time seconds.
        # -n 1 takes exactly 1 character. -s hides the input.
        read -t "$sleep_time" -n 1 -s key
        read_status=$?
    else
        echo "[STATIC MODE] Waiting on current country indefinitely."
        echo "[Controls: 'n' = Next Country | 'p' = Toggle Mode | 'q' = Quit]"

        # read blocks indefinitely without -t
        read -n 1 -s key
        read_status=$?
    fi

    # Handle user inputs or timeouts
    if [[ $read_status -gt 128 ]]; then
        # read timed out (Rapid mode trigger)
        echo -e "\n[*] Time is up! Switching countries..."
        protonvpn disconnect >/dev/null 2>&1
        connect_vpn

    else
        # A key was pressed
        case "$key" in
            n|N)
                echo -e "\n[*] 'n' pressed. Forcing switch to new country..."
                protonvpn disconnect >/dev/null 2>&1
                connect_vpn
                ;;
            p|P)
                if [[ "$mode" == "static" ]]; then
                    mode="rapid"
                    echo -e "\n[+] Toggled to RAPID mode."
                else
                    mode="static"
                    echo -e "\n[+] Toggled to STATIC mode."
                fi
                ;;
            q|Q)
                cleanup
                ;;
            *)
                # Ignore other key presses
                ;;
        esac
    fi
done
