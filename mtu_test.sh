#!/bin/bash

# Tanzimat pishfarz
INTERFACE="${INTERFACE:-eth0}"
TARGET_IP="${TARGET_IP:-8.8.8.8}"
PING_COUNT="${PING_COUNT:-10}"

# File khoroji baraye zakhire natayej
OUTPUT_FILE="mtu_test_results.txt"
TEMP_DIR="mtu_temp"
MAX_CONCURRENT=5  # Tedad test-haye hamzaman
LOCK_FILE="$TEMP_DIR/lock"

# Tabe baraye set kardan MTU ba khatayabi
set_mtu() {
    local mtu=$1
    echo "Dar hal set kardan MTU $mtu rooye $INTERFACE..."
    if ip link set dev "$INTERFACE" mtu "$mtu"; then
        echo "MTU $mtu ba movaffaghiat set shod."
    else
        echo "Error: Set kardan MTU $mtu ba moghiyyat roobroo shod!"
        exit 1
    fi
}

# Tabe baraye nasb package-ha
install_packages() {
    local packages=("bc" "iputils-ping" "gawk" "grep" "coreutils")
    local missing=()
    for pkg in "${packages[@]}"; do
        if ! dpkg -l "$pkg" > /dev/null 2>&1; then
            missing+=("$pkg")
        fi
    done
    if [ ${#missing[@]} -gt 0 ]; then
        echo "Nasad package-haye: ${missing[*]}"
        apt-get update
        for pkg in "${packages[@]}"; do
            apt-get install -y "$pkg"
            if [ $? -ne 0 ]; then
                echo "Error: Nasb $pkg ba moghiyyat roobroo shod!"
                exit 1
            fi
        done
        echo "Tamam package-ha ba movaffaghiat nasb shod."
    fi
}

# Trap baraye set kardan MTU 1420 dar moghiyyat ya cancel
trap 'echo "Moghiyyat ya cancel shod. Set kardan MTU be 1420..."; ip link set dev "$INTERFACE" mtu 1420; rm -rf "$TEMP_DIR"; exit 1' INT TERM EXIT

# Check kardan va nasb package-ha
install_packages

# Check kardan vojood interface
if ! ip link show "$INTERFACE" > /dev/null 2>&1; then
    echo "Error: Interface $INTERFACE vojood nadarad!"
    exit 1
fi

# Check kardan PING_COUNT
if [ "$PING_COUNT" -lt 1 ]; then
    echo "Error: Tedad packet-ha bayad az 1 bishtar bashad!"
    exit 1
fi

# Check kardan etesal be TARGET_IP
if ! ping -c 1 "$TARGET_IP" > /dev/null 2>&1; then
    echo "Error: Nemitavan be $TARGET_IP ping kard! Etesal shabake ra check konid."
    exit 1
fi

# Set kardan MTU be 1500 ghabl az shoroo test
set_mtu 1500

# Pak kardan file ghabli va sakht directory moaghat
> "$OUTPUT_FILE"
mkdir -p "$TEMP_DIR"
: > "$LOCK_FILE"

# Tabe baraye test ping ba MTU moshakhas
test_mtu() {
    local mtu=$1
    local temp_file="$TEMP_DIR/mtu_${mtu}_$$.tmp"  # Estefade az PID baraye jologiri az tadakhol

    # Anjam test ping ba tedad packet moshakhas va timeout
    ping -c "$PING_COUNT" -W 2 -M do -s $((mtu - 28)) "$TARGET_IP" > "$temp_file" 2>/dev/null

    if [ $? -eq 0 ]; then
        # Check kardan vojood file va khali naboodan
        if [ ! -s "$temp_file" ]; then
            flock -x "$LOCK_FILE" echo "MTU $mtu: Khata - File khoroji khali ast"
            echo "$mtu failed 100 0" >> "$OUTPUT_FILE"
            rm -f "$temp_file"
            return
        fi

        # Estekhraj etelaat az khoroji ping
        local stats
        stats=$(tail -n 1 "$temp_file" | grep -o '[0-9.]\+/[0-9.]\+/[0-9.]\+/[0-9.]\+' || echo "0/0/0/0")
        if [ "$stats" = "0/0/0/0" ]; then
            flock -x "$LOCK_FILE" echo "MTU $mtu: Khata - Amare ping peyda nashod"
            echo "$mtu failed 100 0" >> "$OUTPUT_FILE"
            rm -f "$temp_file"
            return
        fi

        local avg_time min_time max_time loss
        avg_time=$(echo "$stats" | cut -d '/' -f 2)
        min_time=$(echo "$stats" | cut -d '/' -f 1)
        max_time=$(echo "$stats" | cut -d '/' -f 3)
        loss=$(grep -o "[0-9]\+% packet loss" "$temp_file" | cut -d '%' -f 1 || echo "100")

        # Mohasebe jitter
        local jitter
        jitter=$(echo "$max_time - $min_time" | bc 2>/dev/null || echo "0")

        # Nemayesh natayej ba lock baraye jologiri az tadakhol
        flock -x "$LOCK_FILE" echo "MTU $mtu: Miyangin ping=$avg_time ms, Packet Loss=$loss%, Jitter=$jitter ms"

        # Zakhire natayej baraye tahlil
        echo "$mtu $avg_time $loss $jitter" >> "$OUTPUT_FILE"
    else
        flock -x "$LOCK_FILE" echo "MTU $mtu: Test namovaffagh"
        echo "$mtu failed 100 0" >> "$OUTPUT_FILE"
    fi

    rm -f "$temp_file"
}

# Saderat tabe baraye estefade dar parallel processing
export -f test_mtu
export OUTPUT_FILE TEMP_DIR TARGET_IP PING_COUNT LOCK_FILE

echo "Shoroo test MTU baraye IP $TARGET_IP ba $PING_COUNT packet..."

# Halqe baraye test MTU-ha az 1476 ta 1420 (parallel)
for ((mtu=1476; mtu>=1420; mtu--)); do
    while [ $(jobs -r | wc -l) -ge $MAX_CONCURRENT ]; do
        sleep 0.1
    done
    timeout 10 bash -c "test_mtu $mtu" &
done

wait

# Hazf trap EXIT ta MTU 1420 faghat dar moghiyyat ya cancel set beshe
trap - EXIT

echo -e "\nTest-ha kamel shod. Dar hal tahlil natayej...\n"

# Peyda kardan behtarin MTU ba dar nazar gereftan Packet Loss, Jitter, Ping
best_mtu=$(cat "$OUTPUT_FILE" | grep -v "failed" | sort -k3 -n -k4 -n -k2 -n | head -n 1)

if [ -n "$best_mtu" ]; then
    mtu_value=$(echo "$best_mtu" | awk '{print $1}')
    ping_time=$(echo "$best_mtu" | awk '{print $2}')
    loss=$(echo "$best_mtu" | awk '{print $3}')
    jitter=$(echo "$best_mtu" | awk '{print $4}')
    echo "Behtarin MTU: $mtu_value"
    echo "  Miyangin ping: $ping_time millisecond"
    echo "  Packet Loss: $loss%"
    echo "  Jitter: $jitter millisecond"

    # Set kardan MTU be gheymat behtarin
    set_mtu "$mtu_value"
else
    echo "Hich MTU movaffaghi peyda nashod. Set kardan MTU be 1420..."
    set_mtu 1420
fi

rm -rf "$TEMP_DIR"
echo "Natayej kamel dar file $OUTPUT_FILE zakhire shode ast"
