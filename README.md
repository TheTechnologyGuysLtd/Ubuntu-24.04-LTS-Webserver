# LAMP Stack Installer — Ubuntu 24.04 LTS

Automated bash script to deploy a full production-ready LAMP stack on a fresh Ubuntu 24.04 LTS server.

**Installs:** Apache 2 · PHP 8.3 · MySQL 8.0 · phpMyAdmin · Let's Encrypt SSL (Certbot) · UFW Firewall

---

## Requirements

| Requirement | Detail |
|---|---|
| OS | Ubuntu 24.04 LTS (fresh install recommended) |
| Access | Root or `sudo` |
| DNS | Domain A record must point to your server's IP before running |
| Ports | 22 (SSH), 80 (HTTP), 443 (HTTPS) open on your host/cloud firewall |

---

## Quick Start

```bash
# 1. Download the script
wget https://thetechguys.site/install-webserver.sh

# 2. Make it executable
chmod +x install-webserver.sh

# 3. Run as root
sudo bash install-webserver.sh
```

You will be prompted to enter the following before installation begins:

| Prompt | Example |
|---|---|
| Domain name | `example.com` |
| Domain alias | `www.example.com` |
| Admin email | `webmaster@example.com` |
| Database name | `myapp_db` |
| Database username | `myapp_user` |
| Database password | *(hidden input)* |

---

## What Gets Installed

### Apache 2
- Virtual host pre-configured for your domain
- Modules enabled: `mod_rewrite`, `mod_ssl`, `mod_headers`
- Directory listing disabled
- HTTP security headers set out of the box:
  - `X-Frame-Options: SAMEORIGIN`
  - `X-Content-Type-Options: nosniff`
  - `Referrer-Policy: strict-origin-when-cross-origin`

### PHP 8.3
Installed via the [Ondřej Surý PPA](https://launchpad.net/~ondrej/+archive/ubuntu/php) for the latest stable builds.

Extensions included:

```
php8.3-common   php8.3-mysql    php8.3-curl     php8.3-zip
php8.3-cgi      php8.3-opcache  php8.3-mbstring php8.3-xml
php8.3-bcmath   php8.3-gd       php8.3-intl     php8.3-readline
```

### MySQL 8.0
- Database, user, and privileges created automatically
- Database user restricted to `localhost` (not exposed to the internet)
- Hardened automatically (equivalent of `mysql_secure_installation`):
  - Anonymous users removed
  - Remote root login disabled
  - Test database dropped

### phpMyAdmin
- Installed and linked to Apache
- Accessible at `https://yourdomain.com/phpmyadmin`

### Let's Encrypt SSL
- Free SSL certificate issued via Certbot
- Apache configured to redirect all HTTP traffic to HTTPS automatically
- Auto-renewal handled by the system `certbot` timer

### UFW Firewall
| Rule | Port | Reason |
|---|---|---|
| OpenSSH | 22 | Remote access |
| Apache Full | 80, 443 | Web traffic |
| MySQL | 3306 | **Blocked** — localhost only |

---

## File Locations

| Item | Path |
|---|---|
| Web root | `/var/www/html/public` |
| Apache config | `/etc/apache2/sites-available/000-default.conf` |
| PHP config | `/etc/php/8.3/apache2/php.ini` |
| MySQL data | `/var/lib/mysql` |
| Apache logs | `/var/log/apache2/` |
| Install summary | `/root/.server-info.txt` |

> **Security:** The install summary file at `/root/.server-info.txt` contains your database credentials. Record its contents and delete the file immediately after installation.
>
> ```bash
> cat /root/.server-info.txt   # View credentials
> rm /root/.server-info.txt    # Then delete
> ```

---

## After Installation

### Deploy your application
Place your application files in `/var/www/html/public`. Set correct ownership so Apache can serve them:

```bash
chown -R www-data:www-data /var/www/html/public
chmod -R 755 /var/www/html/public
```

### Renew SSL manually (if needed)
Certbot auto-renews via a systemd timer, but you can trigger it manually:

```bash
sudo certbot renew --dry-run   # Test renewal
sudo certbot renew             # Force renewal
```

### Add a new domain later
```bash
sudo certbot --apache -d newdomain.com -d www.newdomain.com
```

### Check service status
```bash
systemctl status apache2
systemctl status mysql
ufw status
```

---

## Troubleshooting

**Certbot fails during install**
DNS is likely not yet pointing to your server. Complete the install, wait for DNS to propagate, then run:
```bash
sudo certbot --apache -d yourdomain.com -d www.yourdomain.com
```

**Apache config test fails**
```bash
sudo apache2ctl configtest    # Check for syntax errors
sudo journalctl -xe           # View detailed logs
```

**Cannot connect to MySQL**
```bash
sudo mysql -u root            # Test root access
sudo systemctl status mysql   # Check if service is running
```

**phpMyAdmin returns 404**
```bash
sudo ln -s /usr/share/phpmyadmin /var/www/html/public/phpmyadmin
sudo systemctl restart apache2
```

---

## Security Recommendations

After installation, consider these additional hardening steps:

- [ ] Delete `/root/.server-info.txt` after noting your credentials
- [ ] Disable root SSH login — edit `/etc/ssh/sshd_config`, set `PermitRootLogin no`
- [ ] Set up SSH key authentication and disable password login
- [ ] Install and configure [Fail2Ban](https://github.com/fail2ban/fail2ban) to block brute-force attempts
- [ ] Set up automated backups for `/var/www/html` and your MySQL database
- [ ] Review and tighten `php.ini` settings for production (`display_errors = Off`, etc.)

---

## Author

**The Technology Guys Ltd**
- Website: [https://thetechguys.site](https://thetechguys.site)
- Email: support@thetechguys.site

---

## Licence

MIT — free to use, modify, and distribute. No warranty provided. Always test on a non-production server first.
