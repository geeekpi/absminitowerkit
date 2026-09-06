#!/usr/bin/env bash
#
# GeeekPi / 52Pi ABS Mini Tower Kit installer
# Raspberry Pi OS Trixie 64-bit
#
# Installs:
#   - SSD1306 128x64 I2C OLED status display
#   - rpi_ws281x mood-light binary
#   - systemd services for OLED + RGB LEDs
#
# Tested with:
#   - Raspberry Pi 4
#   - Raspberry Pi OS Trixie arm64
#
# This is a cleaned-up Trixie-compatible replacement for the
# original Bookworm-oriented OEM installer.
#

set -Eeuo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

OLED_I2C_BUS=1
OLED_I2C_ADDRESS="0x3c"

INSTALL_DIR="/usr/local/lib/minitower"
MOODLIGHT_BIN="/usr/local/bin/minitower-moodlight"

OLED_SERVICE="/etc/systemd/system/minitower_oled.service"
MOODLIGHT_SERVICE="/etc/systemd/system/minitower_moodlight.service"

WS281X_REPO="https://github.com/jgarff/rpi_ws281x.git"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

log() {
    printf '\n\033[1;36m==> %s\033[0m\n' "$*"
}

ok() {
    printf '\033[1;32m[OK]\033[0m %s\n' "$*"
}

warn() {
    printf '\033[1;33m[WARN]\033[0m %s\n' "$*" >&2
}

die() {
    printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2
    exit 1
}

# Re-run as root if necessary.
if [[ $EUID -ne 0 ]]; then
    exec sudo --preserve-env=PATH "$0" "$@"
fi

# Determine the normal user that invoked sudo.
TARGET_USER="${SUDO_USER:-}"

if [[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]]; then
    TARGET_USER="$(
        awk -F: \
            '$3 >= 1000 && $3 < 65534 && $7 !~ /(nologin|false)$/ {
                print $1
                exit
            }' \
            /etc/passwd
    )"
fi

[[ -n "$TARGET_USER" ]] ||
    die "Could not determine the normal user account."

TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

[[ -d "$TARGET_HOME" ]] ||
    die "Home directory for $TARGET_USER does not exist."

# ---------------------------------------------------------------------------
# Sanity checks
# ---------------------------------------------------------------------------

log "Checking system"

[[ -r /etc/os-release ]] ||
    die "/etc/os-release is missing."

# shellcheck disable=SC1091
source /etc/os-release

CODENAME="${VERSION_CODENAME:-unknown}"
ARCH="$(dpkg --print-architecture 2>/dev/null || uname -m)"
MODEL="$(tr -d '\0' </proc/device-tree/model 2>/dev/null || true)"

printf 'OS codename : %s\n' "$CODENAME"
printf 'Architecture: %s\n' "$ARCH"
printf 'Model       : %s\n' "${MODEL:-unknown}"
printf 'User        : %s\n' "$TARGET_USER"

[[ "$CODENAME" == "trixie" ]] ||
    die "This installer is intended for Raspberry Pi OS Trixie; detected '$CODENAME'."

[[ "$ARCH" == "arm64" ]] ||
    die "This installer expects an arm64 userland; detected '$ARCH'."

[[ "$MODEL" == *"Raspberry Pi"* ]] ||
    die "This does not appear to be a Raspberry Pi."

ok "Raspberry Pi OS Trixie arm64 detected"

# ---------------------------------------------------------------------------
# Packages
# ---------------------------------------------------------------------------

log "Installing dependencies"

export DEBIAN_FRONTEND=noninteractive

apt-get update

apt-get install -y \
    build-essential \
    cmake \
    git \
    i2c-tools \
    python3 \
    python3-pil \
    python3-psutil \
    python3-luma.oled \
    fonts-dejavu-core

ok "Dependencies installed"

# ---------------------------------------------------------------------------
# User permissions
# ---------------------------------------------------------------------------

log "Configuring GPIO/I2C permissions for $TARGET_USER"

GROUPS_TO_ADD=()

getent group gpio >/dev/null 2>&1 &&
    GROUPS_TO_ADD+=("gpio")

getent group i2c >/dev/null 2>&1 &&
    GROUPS_TO_ADD+=("i2c")

if ((${#GROUPS_TO_ADD[@]})); then
    GROUP_LIST="$(IFS=,; echo "${GROUPS_TO_ADD[*]}")"

    usermod -aG "$GROUP_LIST" "$TARGET_USER"

    ok "Added $TARGET_USER to: $GROUP_LIST"
else
    warn "gpio/i2c groups were not found."
    warn "Services run as root, so this is not fatal."
fi

# ---------------------------------------------------------------------------
# Enable I2C
# ---------------------------------------------------------------------------

log "Enabling I2C"

BOOT_CONFIG="/boot/firmware/config.txt"

[[ -f "$BOOT_CONFIG" ]] ||
    die "$BOOT_CONFIG does not exist."

# Remove any existing active i2c_arm setting to avoid duplicates.
sed -i -E \
    '/^[[:space:]]*dtparam=i2c_arm=/d' \
    "$BOOT_CONFIG"

cat >>"$BOOT_CONFIG" <<'EOF'

# GeeekPi / 52Pi Mini Tower OLED
dtparam=i2c_arm=on
EOF

ok "I2C enabled in $BOOT_CONFIG"

# Try to make the I2C character device available immediately if possible.
modprobe i2c-dev 2>/dev/null || true

# ---------------------------------------------------------------------------
# Build rpi_ws281x moodlight
# ---------------------------------------------------------------------------

log "Building rpi_ws281x moodlight"

BUILD_ROOT="$(mktemp -d /tmp/minitower-ws281x.XXXXXX)"

cleanup() {
    rm -rf "$BUILD_ROOT"
}

trap cleanup EXIT

git clone \
    --depth=1 \
    "$WS281X_REPO" \
    "$BUILD_ROOT/rpi_ws281x"

cmake \
    -S "$BUILD_ROOT/rpi_ws281x" \
    -B "$BUILD_ROOT/rpi_ws281x/build" \
    -D BUILD_SHARED=OFF \
    -D BUILD_TEST=ON

cmake \
    --build "$BUILD_ROOT/rpi_ws281x/build" \
    --parallel "$(nproc)"

[[ -x "$BUILD_ROOT/rpi_ws281x/build/test" ]] ||
    die "rpi_ws281x test binary was not produced."

install \
    -m 0755 \
    "$BUILD_ROOT/rpi_ws281x/build/test" \
    "$MOODLIGHT_BIN"

ok "Moodlight installed as $MOODLIGHT_BIN"

# ---------------------------------------------------------------------------
# OLED status program
# ---------------------------------------------------------------------------

log "Installing OLED status display"

install -d -m 0755 "$INSTALL_DIR"

cat >"$INSTALL_DIR/sysinfo.py" <<'PYEOF'
#!/usr/bin/env python3

import os
import socket
import time

import psutil
from PIL import ImageFont
from luma.core.interface.serial import i2c
from luma.core.render import canvas
from luma.oled.device import ssd1306


I2C_PORT = 1
I2C_ADDRESS = 0x3C
REFRESH_SECONDS = 5


def bytes2human(value):
    units = ("B", "K", "M", "G", "T", "P")

    value = float(value)

    for unit in units:
        if value < 1024.0 or unit == units[-1]:
            if unit == "B":
                return f"{int(value)}{unit}"

            if value >= 100:
                return f"{value:.0f}{unit}"

            if value >= 10:
                return f"{value:.1f}{unit}"

            return f"{value:.2f}{unit}"

        value /= 1024.0


def get_default_interface():
    """
    Return the interface associated with the IPv4 default route.

    Falls back to the first active non-loopback interface.
    """

    try:
        with open("/proc/net/route", "r", encoding="utf-8") as routes:
            next(routes, None)

            for line in routes:
                fields = line.split()

                if len(fields) < 4:
                    continue

                iface = fields[0]
                destination = fields[1]
                flags = int(fields[3], 16)

                if destination == "00000000" and flags & 0x2:
                    return iface

    except (OSError, ValueError):
        pass

    stats = psutil.net_if_stats()

    for iface, info in stats.items():
        if iface != "lo" and info.isup:
            return iface

    return None


def get_ipv4_address(iface):
    if not iface:
        return "no network"

    try:
        addresses = psutil.net_if_addrs().get(iface, [])

        for address in addresses:
            if address.family == socket.AF_INET:
                return address.address

    except Exception:
        pass

    return "no IPv4"


def load_line():
    load1, load5, load15 = os.getloadavg()
    return f"Ld:{load1:.1f} {load5:.1f} {load15:.1f}"


def memory_line():
    usage = psutil.virtual_memory()
    return f"Mem:{bytes2human(usage.used)} {usage.percent:.0f}%"


def disk_line():
    usage = psutil.disk_usage("/")
    return f"SD:{bytes2human(usage.used)} {usage.percent:.0f}%"


def network_line(iface):
    if not iface:
        return "Net: unavailable"

    counters = psutil.net_io_counters(pernic=True).get(iface)

    if counters is None:
        return f"{iface}: unavailable"

    return (
        f"{iface}:T{bytes2human(counters.bytes_sent)} "
        f"R{bytes2human(counters.bytes_recv)}"
    )


def ip_line(iface):
    return f"IP:{get_ipv4_address(iface)}"


def load_font():
    candidates = (
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    )

    for path in candidates:
        try:
            return ImageFont.truetype(path, 10)
        except OSError:
            pass

    return ImageFont.load_default()


def main():
    serial = i2c(
        port=I2C_PORT,
        address=I2C_ADDRESS,
    )

    device = ssd1306(
        serial,
        width=128,
        height=64,
        rotate=0,
    )

    font = load_font()

    while True:
        iface = get_default_interface()

        lines = (
            load_line(),
            memory_line(),
            disk_line(),
            network_line(iface),
            ip_line(iface),
        )

        with canvas(device) as draw:
            for index, line in enumerate(lines):
                draw.text(
                    (0, index * 12),
                    line,
                    font=font,
                    fill="white",
                )

        time.sleep(REFRESH_SECONDS)


if __name__ == "__main__":
    main()
PYEOF

chmod 0755 "$INSTALL_DIR/sysinfo.py"

ok "OLED status program installed"

# ---------------------------------------------------------------------------
# systemd: moodlight
# ---------------------------------------------------------------------------

log "Installing moodlight systemd service"

cat >"$MOODLIGHT_SERVICE" <<EOF
[Unit]
Description=GeeekPi Mini Tower moodlight
After=local-fs.target

[Service]
Type=simple
User=root
ExecStart=$MOODLIGHT_BIN
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

chmod 0644 "$MOODLIGHT_SERVICE"

# ---------------------------------------------------------------------------
# systemd: OLED
# ---------------------------------------------------------------------------

log "Installing OLED systemd service"

cat >"$OLED_SERVICE" <<EOF
[Unit]
Description=GeeekPi Mini Tower OLED status display
After=local-fs.target systemd-modules-load.service

[Service]
Type=simple
User=root

# /dev/i2c-1 may appear slightly after systemd begins starting services.
#
# Do NOT use:
#
#     ConditionPathExists=/dev/i2c-$OLED_I2C_BUS
#
# because systemd evaluates the condition only once. If the I2C device
# has not appeared yet, the service is skipped permanently for that boot.
#
# Instead, wait for the device for up to 30 seconds.
ExecStartPre=/bin/bash -c 'for i in {1..30}; do [ -e /dev/i2c-$OLED_I2C_BUS ] && exit 0; sleep 1; done; echo "/dev/i2c-$OLED_I2C_BUS did not appear" >&2; exit 1'

ExecStart=/usr/bin/python3 $INSTALL_DIR/sysinfo.py

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

chmod 0644 "$OLED_SERVICE"

# ---------------------------------------------------------------------------
# Enable services
# ---------------------------------------------------------------------------

log "Enabling services"

systemctl daemon-reload

systemctl enable minitower_moodlight.service
systemctl enable minitower_oled.service

# Moodlight should generally work immediately.
if systemctl restart minitower_moodlight.service; then
    ok "Moodlight service started"
else
    warn "Moodlight service failed to start."
    warn "Check:"
    warn "  journalctl -u minitower_moodlight.service -b"
fi

# OLED may work immediately if I2C was already enabled.
if [[ -e "/dev/i2c-$OLED_I2C_BUS" ]]; then
    if systemctl restart minitower_oled.service; then
        ok "OLED service started"
    else
        warn "OLED service failed to start."
        warn "Check:"
        warn "  journalctl -u minitower_oled.service -b"
    fi
else
    warn "/dev/i2c-$OLED_I2C_BUS does not currently exist."
    warn "The OLED service will wait for it during the next boot."
fi

# ---------------------------------------------------------------------------
# Diagnostics
# ---------------------------------------------------------------------------

log "Installation summary"

echo
echo "Target user:       $TARGET_USER"
echo "OLED controller:   SSD1306"
echo "OLED dimensions:   128x64"
echo "OLED I2C bus:      $OLED_I2C_BUS"
echo "OLED I2C address:  $OLED_I2C_ADDRESS"
echo "OLED program:      $INSTALL_DIR/sysinfo.py"
echo "Moodlight binary:  $MOODLIGHT_BIN"
echo

echo "Installed services:"
echo
echo "  minitower_moodlight.service"
echo "  minitower_oled.service"
echo

echo "After reboot, verify I2C with:"
echo
echo "  sudo i2cdetect -y $OLED_I2C_BUS"
echo
echo "The OLED should appear as:"
echo
echo "  $OLED_I2C_ADDRESS"
echo

echo "Service diagnostics:"
echo
echo "  systemctl status minitower_oled.service --no-pager -l"
echo "  journalctl -u minitower_oled.service -b --no-pager"
echo
echo "  systemctl status minitower_moodlight.service --no-pager -l"
echo "  journalctl -u minitower_moodlight.service -b --no-pager"
echo

echo "Run the OLED program manually with:"
echo
echo "  sudo systemctl stop minitower_oled.service"
echo "  sudo /usr/bin/python3 $INSTALL_DIR/sysinfo.py"
echo

ok "GeeekPi Mini Tower installation complete"

echo
echo "A reboot is recommended to ensure I2C is initialized:"
echo
echo "  sudo reboot"
echo
