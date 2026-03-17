#!/bin/bash
# =============================================================================
#  Full LAMP Stack Installer — Ubuntu 24.04 LTS
#  Apache 2 · PHP 8.3 · MySQL 8.0 · phpMyAdmin · Let's Encrypt (Certbot)
#
#  Author:  The Technology Guys Ltd
#  Website: https://thetechguys.site
#  Email:   support@thetechguys.site
# =============================================================================

set -euo pipefail   # Exit on error, undefined vars, and pipe failures

# ── Colour helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── Root check ────────────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && error "This script must be run as root. Try: sudo bash $0"

# ── Banner ────────────────────────────────────────────────────────────────────
echo -e "${BOLD}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║       LAMP Stack Installer — Ubuntu 24.04 LTS            ║"
echo "║  Apache · PHP 8.3 · MySQL 8.0 · phpMyAdmin · Certbot     ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
sleep 2

# ── Gather configuration ──────────────────────────────────────────────────────
read -rp "$(echo -e "${BOLD}Domain name${NC} (e.g. example.com): ")"          ServerName
read -rp "$(echo -e "${BOLD}Domain alias${NC} (e.g. www.example.com): ")"     ServerAlias
read -rp "$(echo -e "${BOLD}Admin email${NC} (e.g. webmaster@example.com): ")" ServerAdmin
read -rp "$(echo -e "${BOLD}Database name${NC}: ")"                            dbname
read -rp "$(echo -e "${BOLD}Database username${NC}: ")"                        dbuser
read -rsp "$(echo -e "${BOLD}Database password${NC}: ")"                       dbpass
echo

# Basic validation
[[ -z "$ServerName" || -z "$dbname" || -z "$dbuser" || -z "$dbpass" ]] \
    && error "All fields are required."

# ── 1. System update ──────────────────────────────────────────────────────────
info "Updating system packages..."
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get -y -qq upgrade
success "System updated."

# ── 2. Add Ondřej Surý PPA for latest PHP ────────────────────────────────────
info "Adding PHP 8.3 repository..."
apt-get -y -qq install software-properties-common ca-certificates lsb-release apt-transport-https
LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php > /dev/null 2>&1
LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/apache2 > /dev/null 2>&1
apt-get update -qq
success "Repositories added."

# ── 3. Apache ─────────────────────────────────────────────────────────────────
info "Installing Apache 2..."
apt-get -y -qq install apache2

a2enmod headers rewrite ssl > /dev/null 2>&1
systemctl enable --now apache2
success "Apache installed and enabled."

# ── 4. PHP 8.3 ────────────────────────────────────────────────────────────────
info "Installing PHP 8.3 and extensions..."
apt-get -y -qq install \
    php8.3 \
    php8.3-common \
    php8.3-cli \
    php8.3-mysql \
    php8.3-curl \
    php8.3-zip \
    php8.3-cgi \
    php8.3-opcache \
    php8.3-mbstring \
    php8.3-xml \
    php8.3-bcmath \
    php8.3-gd \
    php8.3-intl \
    php8.3-readline \
    libapache2-mod-php8.3

a2enmod php8.3 > /dev/null 2>&1
success "PHP 8.3 installed."

# ── 5. Apache virtual host ────────────────────────────────────────────────────
info "Configuring Apache virtual host..."

mkdir -p /var/www/html/public

cat > /etc/apache2/sites-available/000-default.conf <<VHOST
<VirtualHost *:80>
    ServerAdmin   ${ServerAdmin}
    ServerName    ${ServerName}
    ServerAlias   ${ServerAlias}
    DocumentRoot  /var/www/html/public

    ErrorLog  \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined

    <Directory /var/www/html/public>
        Options       -Indexes +FollowSymLinks
        AllowOverride All
        Require       all granted
    </Directory>

    # Security headers
    Header always set X-Frame-Options        "SAMEORIGIN"
    Header always set X-Content-Type-Options "nosniff"
    Header always set Referrer-Policy        "strict-origin-when-cross-origin"
</VirtualHost>
VHOST

a2ensite 000-default.conf > /dev/null 2>&1
apache2ctl configtest
success "Virtual host configured."

# ── 6. MySQL 8.0 ─────────────────────────────────────────────────────────────
info "Installing MySQL 8.0..."
DEBIAN_FRONTEND=noninteractive apt-get -y -qq install mysql-server

systemctl enable --now mysql

# Create DB, user (localhost only — no public exposure)
mysql --defaults-extra-file=/dev/null -u root <<SQL
CREATE DATABASE IF NOT EXISTS \`${dbname}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${dbuser}'@'localhost' IDENTIFIED BY '${dbpass}';
GRANT ALL PRIVILEGES ON \`${dbname}\`.* TO '${dbuser}'@'localhost';
FLUSH PRIVILEGES;
SQL

# Harden MySQL (non-interactive equivalent of mysql_secure_installation)
mysql --defaults-extra-file=/dev/null -u root <<SQL
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost','127.0.0.1','::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
SQL

success "MySQL installed and hardened."

# ── 7. phpMyAdmin ─────────────────────────────────────────────────────────────
info "Installing phpMyAdmin..."
# Preseed answers to avoid interactive prompts
debconf-set-selections <<PRESEED
phpmyadmin phpmyadmin/dbconfig-install       boolean true
phpmyadmin phpmyadmin/app-password-confirm   password ${dbpass}
phpmyadmin phpmyadmin/mysql/admin-pass       password
phpmyadmin phpmyadmin/mysql/app-pass         password ${dbpass}
phpmyadmin phpmyadmin/reconfigure-webserver  multiselect apache2
PRESEED

DEBIAN_FRONTEND=noninteractive apt-get -y -qq install phpmyadmin
success "phpMyAdmin installed."

# ── 8. UFW Firewall ───────────────────────────────────────────────────────────
info "Configuring UFW firewall..."
apt-get -y -qq install ufw

ufw default deny incoming > /dev/null 2>&1
ufw default allow outgoing > /dev/null 2>&1
ufw allow OpenSSH    > /dev/null 2>&1   # SSH (port 22)
ufw allow 'Apache Full' > /dev/null 2>&1  # HTTP + HTTPS
# NOTE: MySQL port (3306) is intentionally NOT opened — DB is localhost-only.

echo "y" | ufw enable > /dev/null 2>&1
ufw status
success "Firewall configured (HTTP, HTTPS, SSH allowed; MySQL kept localhost-only)."

# ── 9. Let's Encrypt SSL ──────────────────────────────────────────────────────
info "Installing Certbot and obtaining SSL certificate..."
apt-get -y -qq install certbot python3-certbot-apache

certbot --apache \
    --agree-tos \
    --redirect \
    --email "${ServerAdmin}" \
    --domains "${ServerName},${ServerAlias}" \
    --non-interactive \
    || warn "Certbot failed — DNS may not be pointing to this server yet. Run manually later:
    certbot --apache -d ${ServerName} -d ${ServerAlias}"

success "SSL configuration complete."

# ── 10. Final service restart ─────────────────────────────────────────────────
info "Restarting services..."
systemctl restart apache2
systemctl restart mysql
success "Services restarted."

# ── 11. Write info file (root-readable only) ──────────────────────────────────
INFO_FILE="/root/.server-info.txt"
cat > "${INFO_FILE}" <<INFO
# =============================================================
#  Server Setup Summary — $(date)
# =============================================================
#  IMPORTANT: Delete this file after recording the details.
#  Location: ${INFO_FILE}
# =============================================================

Domain:       ${ServerName}
Alias:        ${ServerAlias}
Admin email:  ${ServerAdmin}
Document root: /var/www/html/public
phpMyAdmin:   https://${ServerName}/phpmyadmin

--- MySQL ---
Database:  ${dbname}
Username:  ${dbuser}
Password:  ${dbpass}
Host:      localhost (not exposed externally)

--- Installed stack ---
OS:        Ubuntu 24.04 LTS
Apache:    $(apache2 -v 2>/dev/null | head -1)
PHP:       $(php8.3 -r 'echo PHP_VERSION;' 2>/dev/null)
MySQL:     $(mysql --version 2>/dev/null)
Certbot:   $(certbot --version 2>/dev/null)

Extensions: php8.3-common php8.3-mysql php8.3-curl php8.3-zip php8.3-cgi
            php8.3-opcache php8.3-mbstring php8.3-xml php8.3-bcmath php8.3-gd
            php8.3-intl php8.3-readline
INFO

chmod 600 "${INFO_FILE}"

# ── Done ──────────────────────────────────────────────────────────────────────
echo
echo -e "${GREEN}${BOLD}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║              Installation Complete!                      ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  ${BOLD}Site:${NC}       https://${ServerName}"
echo -e "  ${BOLD}phpMyAdmin:${NC} https://${ServerName}/phpmyadmin"
echo -e "  ${BOLD}Web root:${NC}   /var/www/html/public"
echo -e "  ${BOLD}Info file:${NC}  ${INFO_FILE} ${RED}(delete after noting credentials!)${NC}"
echo

exit 0