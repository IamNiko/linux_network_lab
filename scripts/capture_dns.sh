
#!/bin/bash
# capture_dns.sh - Captura tráfico DNS durante 15 segundos y guarda en captures/

OUTPUT="captures/dns_$(date +%Y%m%d_%H%M).pcap"

echo "[+] Capturando tráfico DNS durante 15 segundos..."
sudo tcpdump -i any port 53 -n -w "$OUTPUT" -G 15 -W 1

echo "[+] Captura finalizada: $OUTPUT"
