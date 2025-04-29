#!/bin/bash

# Tanzimat pishfarz
INTERFACE="${INTERFACE:-eth0}"
TARGET_IP="${TARGET_IP:-8.8.8.8}"
PING_COUNT="${PING_COUNT:-10}"

# File khoroji baraye zakhire natayej
OUTPUT_FILE="mtu_test_results.txt"
TEMP_DIR="mtu_temp"
MAX_CONCURRENT=5

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

# Pak kardan file ghabli va sakht directory moaghat
> "$OUTPUT_FILE"
mkdir -p "$TEMP_DIR"

# Tabe baraye test ping ba MTU moshakhas
test_mtu() {
    local mtu=$1
    local temp_file="$TEMP_DIR/mtu_${mtu}_$$.tmp"  # Estefade az PID baraye jologiri az tadakhol

    # Debug: Namayesh dastor ping
    echo "Debug: Running ping -c $PING_COUNT -M do -s $((mtu - 28)) $TARGET_IP"

    # Anjam test ping ba tedad packet moshakhas
    ping -c "$PING_COUNT" -M do -s $((mtu - 28)) "$TARGET_IP" > "$temp_file" 2>/dev/null

    if [ $? -eq 0 ]; then
        # Check kardan vojood file va khali naboodan
        if [ ! -s "$temp_file" ]; then
            echo "MTU $mtu: Khata - File khoroji khali ast"
            echo "$mtu failed 100 0" >> "$OUTPUT_FILE"
            rm -f "$temp_file"
            return
        fi

        # Estekhraj etelaat az khoroji ping
        local stats
        stats=$(tail -n 1 "$temp_file" | grep -o '[0-9.]\+/[0-9.]\+/[0-9.]\+/[0-9.]\+' || echo "0/0/0/0")
        if [ "$stats" = "0/0/0/0" ]; then
            echo "MTU $mtu: Khata - Amare ping peyda nashod"
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

        # Nemayesh zende natayej
        echo "MTU $mtu: Miyangin ping=$avg_time ms, Packet Loss=$loss%, Jitter=$jitter ms"

        # Zakhire natayej
        echo "$mtu $avg_time $loss $jitter" >> "$OUTPUT_FILE"
    else
        echo "MTU $mtu: Test namovaffagh"
        echo "$mtu failed 100 0" >> "$OUTPUT_FILE"
    fi

    # Pak kardan file moaghat
    rm -f "$temp_file"
}

# Saderat tabe baraye estefade dar parallel processing
export -f test_mtu
export OUTPUT_FILE TEMP_DIR TARGET_IP PING_COUNT

echo "Shoroo test MTU baraye IP $TARGET_IP ba $PING_COUNT packet..."

# Halqe baraye test MTU-ha az 1475 ta 1420
for ((mtu=1475; mtu>=1420; mtu--)); do
    while [ $(jobs -r | wc -l) -ge $MAX_CONCURRENT ]; do
        sleep 0.1
    done
    test_mtu $mtu &
done

wait

echo -e "\nTest-ha kamel shod. Dar hal tahlil natayej...\n"

# Peyda kardan behtarin MTU
best_mtu=$(cat "$OUTPUT_FILE" | grep -v "failed" | sort -k3 -n -k2 -n -k4 -n | head -n 1)

if [ -n "$best_mtu" ]; then
    mtu_value=$(echo "$best_mtu" | awk '{print $1}')
    ping_time=$(echo "$best_mtu" | awk '{print $2}')
    loss=$(echo "$best_mtu" | awk '{print $3}')
    jitter=$(echo "$best_mtu" | awk '{print $4}')
    echo "Behtarin MTU: $mtu_value"
    echo "  Miyangin ping: $ping_time millisecond"
    echo "  Packet Loss: $loss%"
    echo "  Jitter: $jitter millisecond"

    # Set kardan MTU rooye interface
    echo "Dar hal set kardan MTU $mtu_value rooye interface $INTERFACE..."
    if ip link set dev "$INTERFACE" mtu "$mtu_value"; then
        echo "MTU ba movaffaghiat rooye $INTERFACE set shod."
    else
        echo "Error: Set kardan MTU rooye $INTERFACE ba moghiyyat roobroo shod!"
    fi
else
    echo "Hich MTU movaffaghi peyda nashod. Lotfan etesal shabake ro check konid."
fi

# Pak kardan directory moaghat
rm -rf "$TEMP_DIR"
echo "Natayej kamel dar file $OUTPUT_FILE zakhire shode ast"
