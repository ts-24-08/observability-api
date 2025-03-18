#!/bin/bash

# Monitoring Stack Installer für Multipass
# Installiert Prometheus, Node Exporter, Alertmanager und Grafana

set -e

# Farbcodes für bessere Lesbarkeit
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Konfigurierbare Variablen
VM_NAME="monitoring"
VM_CPU=2
VM_MEM=4G
VM_DISK=20G
UBUNTU_VERSION="24.04"
PROMETHEUS_VERSION="3.2.1"
NODE_EXPORTER_VERSION="1.9.0"
ALERTMANAGER_VERSION="0.28.1"
GRAFANA_VERSION="11.5.2"

# Architektur erkennen
if [[ "$(uname -m)" == "arm64" ]] || [[ "$(uname -m)" == "aarch64" ]]; then
    ARCH="arm64"
    echo -e "${YELLOW}ARM64-Architektur erkannt (Apple Silicon M1/M2).${NC}"
else
    ARCH="amd64"
    echo -e "${YELLOW}AMD64-Architektur erkannt (Intel/AMD).${NC}"
fi

echo -e "${GREEN}=== Multipass Monitoring Stack Installer ===${NC}"
echo "Dieses Script installiert folgende Komponenten:"
echo "- Ubuntu ${UBUNTU_VERSION} in einer Multipass VM"
echo "- Prometheus ${PROMETHEUS_VERSION}"
echo "- Node Exporter ${NODE_EXPORTER_VERSION}"
echo "- Alertmanager ${ALERTMANAGER_VERSION}"
echo "- Grafana ${GRAFANA_VERSION}"
echo ""

# Prüfen, ob Multipass installiert ist
if ! command -v multipass &> /dev/null; then
    echo -e "${YELLOW}Multipass ist nicht installiert. Bitte installiere Multipass zuerst.${NC}"
    exit 1
fi

# Prüfen, ob die VM bereits existiert (exakte Übereinstimmung)
if multipass list | awk '{print $1}' | grep -q "^${VM_NAME}$"; then
    echo -e "${YELLOW}Eine VM mit dem Namen '${VM_NAME}' existiert bereits.${NC}"
    read -p "Möchtest du fortfahren und die bestehende VM überschreiben? (j/n): " confirm
    if [[ $confirm != "j" && $confirm != "J" ]]; then
        echo "Installation abgebrochen."
        exit 0
    fi
    echo "Lösche bestehende VM..."
    multipass delete ${VM_NAME}
    multipass purge
fi

echo -e "${GREEN}=== Erstelle neue Multipass VM mit Ubuntu ${UBUNTU_VERSION} ===${NC}"
multipass launch --name ${VM_NAME} --cpus ${VM_CPU} --memory ${VM_MEM} --disk ${VM_DISK} ${UBUNTU_VERSION}

# Warte einen Moment, bis die VM vollständig gestartet ist
sleep 5

echo -e "${GREEN}=== Prepare Installation Script ===${NC}"
# Erstelle ein temporäres Script für die Installation
cat > /tmp/monitoring_install.sh << 'EOF'
#!/bin/bash
set -e

# Farbcodes für bessere Lesbarkeit
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variablen werden ersetzt
PROMETHEUS_VERSION="%PROMETHEUS_VERSION%"
NODE_EXPORTER_VERSION="%NODE_EXPORTER_VERSION%"
ALERTMANAGER_VERSION="%ALERTMANAGER_VERSION%"
GRAFANA_VERSION="%GRAFANA_VERSION%"
ARCH="%ARCH%"

echo -e "${GREEN}=== System Update ===${NC}"
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget unzip apt-transport-https software-properties-common gnupg

# Verzeichnisse erstellen
echo -e "${GREEN}=== Erstelle Verzeichnisse ===${NC}"
sudo mkdir -p /etc/prometheus
sudo mkdir -p /var/lib/prometheus
sudo mkdir -p /etc/alertmanager
sudo mkdir -p /var/lib/alertmanager
sudo mkdir -p /etc/prometheus/rules
sudo mkdir -p /etc/prometheus/files_sd

# Benutzer erstellen
echo -e "${GREEN}=== Erstelle Systembenutzer ===${NC}"
sudo useradd --system --no-create-home --shell /bin/false prometheus || true
sudo useradd --system --no-create-home --shell /bin/false node_exporter || true
sudo useradd --system --no-create-home --shell /bin/false alertmanager || true

# ---------- PROMETHEUS INSTALLATION ----------
echo -e "${GREEN}=== Installiere Prometheus ${PROMETHEUS_VERSION} für ${ARCH} ===${NC}"
wget https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-${ARCH}.tar.gz
tar xvfz prometheus-${PROMETHEUS_VERSION}.linux-${ARCH}.tar.gz
sudo cp prometheus-${PROMETHEUS_VERSION}.linux-${ARCH}/prometheus /usr/local/bin/
sudo cp prometheus-${PROMETHEUS_VERSION}.linux-${ARCH}/promtool /usr/local/bin/
rm -rf prometheus-${PROMETHEUS_VERSION}.linux-${ARCH}*

# Prometheus Konfiguration
cat > /tmp/prometheus.yml << 'EOPROMSYD'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - localhost:9093

rule_files:
  - "/etc/prometheus/rules/*.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']
EOPROMSYD

sudo mv /tmp/prometheus.yml /etc/prometheus/prometheus.yml
sudo chown prometheus:prometheus /etc/prometheus/prometheus.yml

# HTTP Error Rate Rule
cat > /tmp/http_errors.yml << 'EOALERTRULE'
groups:
- name: http_errors
  rules:
  - alert: HighErrorRate
    expr: sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) > 0.05
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "Hohe HTTP Error Rate"
      description: "Die HTTP Error Rate liegt bei {{ $value | humanizePercentage }} in den letzten 5 Minuten (Schwellwert: 5%)."
EOALERTRULE

sudo mv /tmp/http_errors.yml /etc/prometheus/rules/http_errors.yml
sudo chown prometheus:prometheus /etc/prometheus/rules/http_errors.yml

# Prometheus Systemd Service
cat > /tmp/prometheus.service << 'EOPROMSERVICE'
[Unit]
Description=Prometheus
Documentation=https://prometheus.io/docs/introduction/overview/
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file=/etc/prometheus/prometheus.yml \
    --storage.tsdb.path=/var/lib/prometheus/ \

[Install]
WantedBy=multi-user.target
EOPROMSERVICE

sudo mv /tmp/prometheus.service /etc/systemd/system/prometheus.service
sudo chown root:root /etc/systemd/system/prometheus.service
sudo chmod 644 /etc/systemd/system/prometheus.service

# Berechtigungen setzen
sudo chown -R prometheus:prometheus /var/lib/prometheus/
sudo chown -R prometheus:prometheus /etc/prometheus/

# ---------- NODE EXPORTER INSTALLATION ----------
echo -e "${GREEN}=== Installiere Node Exporter ${NODE_EXPORTER_VERSION} für ${ARCH} ===${NC}"
wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}.tar.gz
tar xvfz node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}.tar.gz
sudo cp node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}/node_exporter /usr/local/bin/
rm -rf node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}*

# Node Exporter Systemd Service
cat > /tmp/node_exporter.service << 'EONODEXSERVICE'
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EONODEXSERVICE

sudo mv /tmp/node_exporter.service /etc/systemd/system/node_exporter.service
sudo chown root:root /etc/systemd/system/node_exporter.service
sudo chmod 644 /etc/systemd/system/node_exporter.service

# ---------- ALERTMANAGER INSTALLATION ----------
echo -e "${GREEN}=== Installiere Alertmanager ${ALERTMANAGER_VERSION} für ${ARCH} ===${NC}"
wget https://github.com/prometheus/alertmanager/releases/download/v${ALERTMANAGER_VERSION}/alertmanager-${ALERTMANAGER_VERSION}.linux-${ARCH}.tar.gz
tar xvfz alertmanager-${ALERTMANAGER_VERSION}.linux-${ARCH}.tar.gz
sudo cp alertmanager-${ALERTMANAGER_VERSION}.linux-${ARCH}/alertmanager /usr/local/bin/
sudo cp alertmanager-${ALERTMANAGER_VERSION}.linux-${ARCH}/amtool /usr/local/bin/
rm -rf alertmanager-${ALERTMANAGER_VERSION}.linux-${ARCH}*

# Alertmanager Konfiguration
cat > /tmp/alertmanager.yml << 'EOALERTMANAGER'
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  receiver: 'default-receiver'

receivers:
- name: 'default-receiver'
  # Hier könntest du später Slack, Email etc. konfigurieren

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'instance']
EOALERTMANAGER

sudo mv /tmp/alertmanager.yml /etc/alertmanager/alertmanager.yml
sudo chown alertmanager:alertmanager /etc/alertmanager/alertmanager.yml

# Alertmanager Systemd Service
cat > /tmp/alertmanager.service << 'EOALERTSERVICE'
[Unit]
Description=Alertmanager
Documentation=https://prometheus.io/docs/alerting/alertmanager/
After=network-online.target

[Service]
User=alertmanager
Group=alertmanager
Type=simple
ExecStart=/usr/local/bin/alertmanager \
    --config.file=/etc/alertmanager/alertmanager.yml \
    --storage.path=/var/lib/alertmanager/

[Install]
WantedBy=multi-user.target
EOALERTSERVICE

sudo mv /tmp/alertmanager.service /etc/systemd/system/alertmanager.service
sudo chown root:root /etc/systemd/system/alertmanager.service
sudo chmod 644 /etc/systemd/system/alertmanager.service

# Berechtigungen setzen
sudo chown -R alertmanager:alertmanager /var/lib/alertmanager/
sudo chown -R alertmanager:alertmanager /etc/alertmanager/

# ---------- GRAFANA INSTALLATION ----------
echo -e "${GREEN}=== Installiere Grafana ${GRAFANA_VERSION} ===${NC}"
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list

sudo apt update
sudo apt install -y grafana

# Graphana Service aktivieren
sudo systemctl daemon-reload
sudo systemctl enable grafana-server

# ---------- SERVICES STARTEN ----------
echo -e "${GREEN}=== Starte Services ===${NC}"
sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl enable node_exporter
sudo systemctl enable alertmanager

sudo systemctl start prometheus
sudo systemctl start node_exporter
sudo systemctl start alertmanager
sudo systemctl start grafana-server

# ---------- FERTIG ----------
echo -e "${GREEN}=== Installation abgeschlossen ===${NC}"
echo "Prometheus: http://localhost:9090"
echo "Node Exporter: http://localhost:9100/metrics"
echo "Alertmanager: http://localhost:9093"
echo "Grafana: http://localhost:3000 (admin/admin)"

# Zeige IP-Adresse an
echo -e "${GREEN}=== IP-Adresse der VM ===${NC}"
echo "Die VM ist unter folgender IP-Adresse erreichbar:"
hostname -I | awk '{print $1}'
EOF

# Variablen im Script ersetzen - plattformübergreifend
# Dies funktioniert auf Linux, macOS und Git Bash für Windows
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS verwendet eine andere sed-Syntax
    sed -i '' "s/%PROMETHEUS_VERSION%/${PROMETHEUS_VERSION}/g" /tmp/monitoring_install.sh
    sed -i '' "s/%NODE_EXPORTER_VERSION%/${NODE_EXPORTER_VERSION}/g" /tmp/monitoring_install.sh
    sed -i '' "s/%ALERTMANAGER_VERSION%/${ALERTMANAGER_VERSION}/g" /tmp/monitoring_install.sh
    sed -i '' "s/%GRAFANA_VERSION%/${GRAFANA_VERSION}/g" /tmp/monitoring_install.sh
    sed -i '' "s/%ARCH%/${ARCH}/g" /tmp/monitoring_install.sh
else
    # Linux und Git Bash für Windows
    sed -i "s/%PROMETHEUS_VERSION%/${PROMETHEUS_VERSION}/g" /tmp/monitoring_install.sh
    sed -i "s/%NODE_EXPORTER_VERSION%/${NODE_EXPORTER_VERSION}/g" /tmp/monitoring_install.sh
    sed -i "s/%ALERTMANAGER_VERSION%/${ALERTMANAGER_VERSION}/g" /tmp/monitoring_install.sh
    sed -i "s/%GRAFANA_VERSION%/${GRAFANA_VERSION}/g" /tmp/monitoring_install.sh
    sed -i "s/%ARCH%/${ARCH}/g" /tmp/monitoring_install.sh
fi

# Script in die VM kopieren und ausführen
echo -e "${GREEN}=== Kopiere Installations-Script in die VM ===${NC}"
multipass transfer /tmp/monitoring_install.sh ${VM_NAME}:/home/ubuntu/monitoring_install.sh
multipass exec ${VM_NAME} -- chmod +x /home/ubuntu/monitoring_install.sh

echo -e "${GREEN}=== Führe Installations-Script in der VM aus ===${NC}"
echo "Die Installation kann einige Minuten dauern..."
multipass exec ${VM_NAME} -- /home/ubuntu/monitoring_install.sh

# VM-Info anzeigen
echo -e "${GREEN}=== Installations abgeschlossen ===${NC}"
echo "Zugriff auf die VM:"
echo "  multipass shell ${VM_NAME}"

IP_ADDRESS=$(multipass info ${VM_NAME} | grep IPv4 | awk '{print $2}')
echo -e "${GREEN}=== Monitoring Stack Zugriff ===${NC}"
echo "Prometheus: http://${IP_ADDRESS}:9090"
echo "Node Exporter: http://${IP_ADDRESS}:9100/metrics"
echo "Alertmanager: http://${IP_ADDRESS}:9093"
echo "Grafana: http://${IP_ADDRESS}:3000 (admin/admin)"