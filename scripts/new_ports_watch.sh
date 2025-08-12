
#!/usr/bin/env bash
# new_ports_watch.sh - Detecta puertos LISTEN nuevos vs baseline y, si hay, dispara captura tcpdump.
# Salida: logs en reports/ y pcaps en captures/

set -euo pipefail

# --- Anclar al repo (aunque lo ejecutes desde otro directorio) ---
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Archivos y rutas ---
STATE_DIR="$REPO_ROOT/.state"
REPORTS_DIR="$REPO_ROOT/reports"
CAPTURES_DIR="$REPO_ROOT/captures"

mkdir -p "$STATE_DIR" "$REPORTS_DIR" "$CAPTURES_DIR"

BASELINE="$STATE_DIR/listen_baseline.txt"
NOW_FILE="$STATE_DIR/listen_now.txt"

# --- Config captura ---
CAPTURE_ON_ALERT=true         # ponlo en false si no quieres capturar
CAPTURE_SECONDS=15            # duración por puerto
CAPTURE_IFACE="any"           # interfaz (puedes poner eth0/wlan0)
ALERT_FILE="$REPORTS_DIR/alerts_$(date +%F).log"   # 1 archivo por día

# --- Dependencias mínimas ---
command -v ss >/dev/null || { echo "Falta 'ss'"; exit 1; }
command -v tcpdump >/dev/null || { echo "Falta 'tcpdump' (sudo apt install tcpdump)"; exit 1; }

# --- Allowlist (ajusta a tus servicios normales) ---
ALLOWLIST=(
  "tcp:0.0.0.0:22"
  "tcp:[::]:22"
)

allow_regex() {
  local joined
  joined="$(printf "%s|" "${ALLOWLIST[@]}")"
  echo "^(${joined%|})$"
}

# --- Snapshot actual normalizado ---
ss -H -tuln | awk '{print $1":"$5}' \
| sed 's/:::*/[::]/' \
| sort -u > "$NOW_FILE"

# --- Crear baseline si no existe ---
if [[ ! -f "$BASELINE" ]]; then
  cp "$NOW_FILE" "$BASELINE"
  echo "[+] Baseline creado en $BASELINE"
  exit 0
fi

# --- Diferencias: NOW - BASELINE ---
NEW_PORTS="$(comm -13 "$BASELINE" "$NOW_FILE")"

# --- Filtrar allowlist ---
REGEX="$(allow_regex)"
FILTERED_NEW="$(echo "$NEW_PORTS" | grep -Ev "$REGEX" || true)"

# --- Si hay novedades, alertar y capturar ---
if [[ -n "$FILTERED_NEW" ]]; then
  {
    echo "==== ALERTA: Puertos nuevos detectados $(date '+%F %T') ===="
    echo "$FILTERED_NEW"
    echo
    echo "[Detalle de procesos]"
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      proto="${line%%:*}"
      addr_port="${line#*:}"
      port="${addr_port##*:}"

      # Detalle del proceso
      ss -lpn "sport = :$port" | sed 's/^/  /'

      # Captura por puerto
      if [[ "$CAPTURE_ON_ALERT" == true ]]; then
        PCAP="$CAPTURES_DIR/alert_port${port}_$(date +%Y%m%d_%H%M%S).pcap"
        echo "  [+] Capturando ${CAPTURE_SECONDS}s de tráfico (iface=$CAPTURE_IFACE, port=$port) -> $PCAP"
        # Nota: puede pedir sudo (tcpdump)
        sudo tcpdump -i "$CAPTURE_IFACE" -s 0 -n "port $port" -w "$PCAP" -G "$CAPTURE_SECONDS" -W 1 >/dev/null 2>&1 || true
        [[ -f "$PCAP" ]] && echo "  [*] PCAP listo: $PCAP" || echo "  [!] No se generó PCAP (revisa permisos/interfaz)."
      fi
    done <<< "$FILTERED_NEW"
    echo "==========================================================="
    echo
  } | tee -a "$ALERT_FILE"

  # Notificación opcional
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "ALERTA: Puertos nuevos" "$(echo "$FILTERED_NEW" | tr '\n' ' ')"
  fi

  # Beep en terminal (opcional)
  printf "\a" || true
else
  echo "[+] Sin cambios respecto al baseline."
fi

# --- No actualizamos baseline automáticamente para no blanquear nada ---
# Si validas que es legítimo, o agrégalo a ALLOWLIST, o:
# cp "$STATE_DIR/listen_now.txt" "$STATE_DIR/listen_baseline.txt"
