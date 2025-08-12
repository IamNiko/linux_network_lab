#!/usr/bin/env bash
# summarize_pcap.sh - Crea un resumen Markdown de una captura .pcap en reports/
# Uso: ./scripts/summarize_pcap.sh [ruta_al_pcap]
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPORTS_DIR="$REPO_ROOT/reports"
CAPTURES_DIR="$REPO_ROOT/captures"

mkdir -p "$REPORTS_DIR"

command -v tshark >/dev/null || { echo "[!] Requiere tshark (sudo apt install tshark)"; exit 1; }

PCAP="${1:-}"
if [[ -z "${PCAP}" ]]; then
  PCAP="$(ls -t "$CAPTURES_DIR"/*.pcap 2>/dev/null | head -n1 || true)"
  [[ -z "$PCAP" ]] && { echo "[!] No hay PCAP en $CAPTURES_DIR"; exit 1; }
fi
[[ -f "$PCAP" ]] || { echo "[!] No existe PCAP: $PCAP"; exit 1; }

BASENAME="$(basename "$PCAP")"
OUT="$REPORTS_DIR/summary_${BASENAME%.pcap}.md"

# Meta
SIZE_BYTES=$(stat -c%s "$PCAP" 2>/dev/null || stat -f%z "$PCAP")
PKTS=$(tshark -r "$PCAP" -T fields -e frame.number 2>/dev/null | wc -l | awk '{print $1}')

{
  echo "# PCAP Summary — ${BASENAME}"
  echo
  echo "- **File**: $PCAP"
  echo "- **Size**: ${SIZE_BYTES} bytes"
  echo "- **Packets**: ${PKTS}"
  echo "- **Generated**: $(date '+%F %T')"
  echo
  echo "## Top IP Endpoints"
  tshark -r "$PCAP" -q -z endpoints,ip 2>/dev/null | sed -n '/IPv4/,/IPv6/p'
  echo
  echo "## TCP Conversations"
  tshark -r "$PCAP" -q -z conv,tcp 2>/dev/null | sed -n '/<->/,/^$/p'
  echo
  echo "## HTTP Requests (src_ip method host uri)"
  tshark -r "$PCAP" -Y http.request -T fields -e ip.src -e http.request.method -e http.host -e http.request.uri 2>/dev/null | head -n 200 | sed 's/^/ - /'
  echo
  echo "## HTTP Responses (dst_ip code phrase)"
  tshark -r "$PCAP" -Y http.response -T fields -e ip.dst -e http.response.code -e http.response.phrase 2>/dev/null | head -n 200 | sed 's/^/ - /'
  echo
  echo "## HTTP POST bodies (form data)"
  tshark -r "$PCAP" -Y "http.request.method == POST" -T fields -e http.file_data 2>/dev/null | head -n 50 | sed 's/^/ - /'
  echo
  echo "## User-Agents detectados"
  tshark -r "$PCAP" -Y http.request -T fields -e http.user_agent 2>/dev/null | sort | uniq -c | sort -nr | sed 's/^/ - /'
  echo
  echo "## Notas"
  echo "- Ver también en Wireshark: filtros \`http\`, \`http.request\`, \`http.response\`, \`tcp.port == 8000\`."
  echo "- Follow → TCP Stream para ver las transacciones completas."
} > "$OUT"

echo "[+] Resumen generado en: $OUT"
