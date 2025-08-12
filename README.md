# Linux Network Lab (SOC mini-lab)

Laboratorio mínimo para practicar **detección y análisis de tráfico** en Linux:
- Detecta **puertos LISTEN nuevos** vs un *baseline*.
- Al alertar, **captura** tráfico automáticamente con `tcpdump`.
- Permite generar tráfico real con un **sitio HTTP** simple (GET/POST).
- Resume capturas con `tshark` a un informe Markdown.

---

## Estructura

linux_network_lab/
├─ scripts/
│ ├─ socket_monitor.sh # snapshot de puertos/sockets
│ ├─ new_ports_watch.sh # alerta y captura automática (tcpdump)
│ └─ summarize_pcap.sh # resumen .md de una pcap (tshark)
├─ site/
│ ├─ index.html # página básica con form
│ └─ cgi-bin/echo.py # CGI que “hace eco” de GET/POST
├─ captures/ # .pcap (ignorado por Git)
├─ reports/ # logs y resúmenes (ignorado por Git)
└─ .state/ # baseline y estado (ignorado por Git)


> Asegúrate de tener un `.gitignore` que incluya:  
> `reports/`, `captures/`, `.state/`, `*.pcap`, `*.log`

---

## Requisitos

- Linux con `iproute2` (`ss`), `tcpdump`, Python 3.
- (Opcional) `tshark` para generar resúmenes:
  ```bash
  sudo apt update && sudo apt install -y tshark

Uso rápido
1) Levantar el sitio de pruebas (HTTP)

Desde site/:

python3 -m http.server 8000 --cgi --bind 0.0.0.0

    Abre en el móvil (misma Wi-Fi): http://IP_DE_TU_PC:8000/

    Interactúa: link “Probar GET” y formulario (POST).

2) Disparar el watcher y capturar

Desde la raíz del repo:

./scripts/new_ports_watch.sh

    Primera ejecución: crea el baseline y sale.

    Con el server en :8000, el watcher alerta y captura ~N s a captures/.

3) Analizar la captura

En consola:

latest=$(ls -t captures/alert_port*.pcap | head -n1)
tcpdump -r "$latest" -nn -c 20

Con tshark (resumen a Markdown):

./scripts/summarize_pcap.sh               # usa la última .pcap
# genera: reports/summary_<nombre>.md

En Wireshark (filtros útiles):

    tcp.port == 8000

    http, http.request, http.response

    ip.addr == IP_DEL_MOVIL && tcp.port == 8000

    Follow → TCP Stream para ver transacciones completas.

Baseline y allowlist

    Baseline: .state/listen_baseline.txt

    Actualizar baseline manualmente (tras validar cambios):

cp .state/listen_now.txt .state/listen_baseline.txt

Ajusta ALLOWLIST en scripts/new_ports_watch.sh para puertos legítimos:

    ALLOWLIST=(
      "tcp:0.0.0.0:22"
      "tcp:[::]:22"
      # añade aquí tus puertos habituales
    )

Configuración del watcher (clave)

Edita en scripts/new_ports_watch.sh:

    CAPTURE_SECONDS=15 (o 20–30 si necesitas más margen)

    CAPTURE_IFACE="any" (o tu interfaz, p. ej. wlan0/eth0)

    Log diario: reports/alerts_YYYY-MM-DD.log

    Consejo: ejecuta sudo -v antes de correr el watcher para evitar prompts de sudo durante la captura, o asigna capabilities a tcpdump:

    sudo setcap cap_net_raw,cap_net_admin=eip "$(which tcpdump)"

Seguridad

    No subas captures/ ni reports/ a Git (pueden contener datos sensibles).

    Si usas ufw:

    sudo ufw allow 8000/tcp
    # al terminar: sudo ufw delete allow 8000/tcp

    Si usas VPN con “Network Lock”, habilita acceso a red local o desconéctala para pruebas LAN.

Flujo típico de práctica

    Levantar servicio de prueba (HTTP 8000).

    Correr watcher → alerta + captura.

    Generar tráfico desde el móvil (GET/POST).

    Analizar .pcap (Wireshark/tshark).

    Generar resumen (summarize_pcap.sh).

    Ajustar allowlist o baseline si corresponde.

Troubleshooting rápido

    El móvil no accede al server:

        Server ligado a todas las interfaces: --bind 0.0.0.0

        IP LAN correcta (ip -br -4 addr)

        ufw allow 8000/tcp (temporal)

        Sin guest Wi-Fi / client isolation

        VPN desactivada o con “Allow LAN”

    La pcap sale vacía:

        Aumenta CAPTURE_SECONDS

        Usa la interfaz correcta (CAPTURE_IFACE="wlan0" si entras por Wi-Fi)

        Interactúa (GET/POST) mientras dura la captura

Comandos de referencia

# Ver puertos en escucha y procesos
ss -tulpen

# Captura en vivo (DNS ejemplo)
sudo tcpdump -i any port 53 -nn

# Logs del watcher
tail -n 100 reports/alerts_$(date +%F).log



### Extras útiles

#### Limpieza y mantenimiento
```bash
# Borrar pcaps de más de 7 días
find captures -type f -name '*.pcap' -mtime +7 -delete

# Borrar resúmenes antiguos (>14 días)
find reports -type f -name 'summary_*.md' -mtime +14 -delete

# Reiniciar baseline (se recrea en la próxima ejecución)
rm -f .state/listen_baseline.txt

# Quitar ficheros generados
rm -f captures/*.pcap reports/alerts_*.log reports/summary_*.md

crontab -e
# Cada 2 minutos, ejecutar el watcher y loguear salida
*/2 * * * * /bin/bash -lc 'cd ~/Cyber/linux_network_lab && ./scripts/new_ports_watch.sh >> reports/watch_cron.log 2>&1'
