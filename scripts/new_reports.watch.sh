#!/usr/bin/env bash
# Detecta puertos en LISTEN nuevos respecto a un baseline y alerta.
# Guarda hallazgos en reports/ y mantiene baseline en .state/

set -euo pipefail

BASELINE=".state/listen_baseline.txt"
NOW_FILE=".state/listen_now.txt"
ALERT_FILE="reports/alerts_$(date +%Y%m%d_%H%M%S).log"

# Puertos permitidos (whitelist). Edita según tu host.
# Formato: PROTO:IP:PORT (tal como lo saca ss -H)
ALLOWLIST=(
  "tcp:0.0.0.0:22"
  "tcp:[::]:22"
  # añade aquí tus servicios habituales (por ej. 80/443 si corres un web)
)

# Función: volcar ALLOWLIST a un regex para filtrar
allow_regex() {
  local joined
  joined="$(printf "%s|" "${ALLOWLIST[@]}")"
  echo "^(${joined%|})$"
}

# 1) Obtener snapshot actual de LISTEN (normalizado)
ss -H -tuln | awk '{print $1":"$5}' \
| sed 's/:::*/[::]/' \
| sort -u > "$NOW_FILE"

# 2) Si no hay baseline, crearlo y salir
if [[ ! -f "$BASELINE" ]]; then
  mkdir -p "$(dirname "$BASELINE")"
  cp "$NOW_FILE" "$BASELINE"
  echo "[+] Baseline creado en $BASELINE"
  exit 0
fi

# 3) Calcular "nuevos" = NOW - BASELINE
NEW_PORTS="$(comm -13 "$BASELINE" "$NOW_FILE")"

# 4) Filtrar por allowlist
REGEX="$(allow_regex)"
FILTERED_NEW="$(echo "$NEW_PORTS" | grep -Ev "$REGEX" || true)"

if [[ -n "$FILTERED_NEW" ]]; then
  mkdir -p reports
  {
    echo "==== ALERTA: Puertos nuevos detectados $(date '+%F %T') ===="
    echo "$FILTERED_NEW"
    echo
    echo "[Detalle de procesos]"
    # Para cada línea PROTO:IP:PORT obtener el proceso
    while IFS= read -r line; do
      proto="${line%%:*}"
      addr_port="${line#*:}"
      port="${addr_port##*:}"
      # Mostrar procesos asociados a ese puerto
      ss -lpn "sport = :$port" | sed 's/^/  /'
    done <<< "$FILTERED_NEW"
    echo "==========================================================="
  } | tee -a "$ALERT_FILE"

  # Aviso visual (si tienes entorno gráfico)
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "ALERTA: Puertos nuevos" "$(echo "$FILTERED_NEW" | tr '\n' ' ')"
  fi

  # (Opcional) Alarma sonora en terminal
  printf "\a"
else
  echo "[+] Sin cambios respecto al baseline."
fi

# 5) Actualizar baseline (opcional):
#    Si quieres que cada ejecución “aprenda” los cambios, descomenta:
# cp "$NOW_FILE" "$BASELINE"
