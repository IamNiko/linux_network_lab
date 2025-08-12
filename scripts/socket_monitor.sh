#!/bin/bash
# socket_monitor.sh - Monitorea puertos en escucha y conexiones activas
# Guarda el resultado en reports/sockets_YYYYMMDD_HHMM.txt

OUTPUT="reports/sockets_$(date +%Y%m%d_%H%M).txt"

echo "[+] Generando reporte de sockets en $OUTPUT"
ss -tulpen > "$OUTPUT"

echo "[+] Primeras 10 líneas del reporte:"
head "$OUTPUT"
