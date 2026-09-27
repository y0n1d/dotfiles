#! /bin/bash

command -v cava &>/dev/null || exit 1

bar="▁▂▃▄▅▆▇█"
dict="s/;//g;"

# creating "dictionary" to replace char with bar
i=0
while [ "$i" -lt "${#bar}" ]
do
    dict="${dict}s/$i/${bar:$i:1}/g;"
    i=$((i + 1))
done

# write cava config (per-user runtime file, never a fixed shared /tmp name)
config_file="${XDG_RUNTIME_DIR:-/tmp}/waybar-cava-config-$UID"
cat > "$config_file" <<'EOF'
[general]
bars = 18
framerate = 30

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
EOF

# read stdout from cava
cava -p "$config_file" | while IFS= read -r line; do
    echo "$line" | sed "$dict"
done
