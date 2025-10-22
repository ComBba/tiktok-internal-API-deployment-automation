# TikTok Internal APIs - Deployment Automation

Automated deployment system for TikTok Internal API services (User Posts, User Info, Search Users, Post Detail).

## 🎯 Overview

This repository provides a complete automation solution for deploying 4 independent TikTok Internal API services to a new server with a single command.

### Services Included

| Service | Port | Purpose |
|---------|------|---------|
| **User Info** | 8082 | TikTok user information provider |
| **User Posts** | 8083 | TikTok user posts data provider (MongoDB cached) |
| **Search Users** | 8084 | CAPTCHA-free user discovery service |
| **Post Detail** | 8085 | TikTok post detail with 4-tier fallback |

## 🚀 Quick Start

### ⭐ All-in-One Deployment (Recommended)

```bash
# 1. Clone this repository
git clone https://github.com/ComBba/tiktok-internal-API-deployment-automation.git
cd tiktok-internal-API-deployment-automation

# 2. Run all-in-one deployment
./start.sh

# That's it! The script will guide you through all steps:
#   ✓ Bootstrap (Docker, Git installation)
#   ✓ GitHub authentication
#   ✓ Clone repositories
#   ✓ Configure environment
#   ✓ Deploy services
#   ✓ Health check
```

### Manual Step-by-Step Deployment

```bash
# 1. Clone this repository
git clone https://github.com/ComBba/tiktok-internal-API-deployment-automation.git
cd tiktok-internal-API-deployment-automation

# 2. Run bootstrap (installs Docker, Git, etc.)
./bootstrap.sh

# 3. Set up GitHub authentication
./setup-github.sh

# 4. Clone all service repositories
./clone-repositories.sh --parallel

# 5. Configure and deploy all services
./deploy-services.sh --setup-env
./deploy-services.sh --parallel

# 6. Check service health
./health-check.sh
```

## 📋 Prerequisites

- **Operating System**: Ubuntu 20.04+ / Debian 10+ / macOS 11+
- **User Permissions**: sudo access (Linux) or admin access (macOS)
- **Network**: Ports 8082-8085 available (customizable)
- **GitHub Access**: SSH key or Personal Access Token
- **macOS**: Homebrew, Docker CLI, Docker Compose, and Colima auto-install via bootstrap.sh
- **MongoDB**: MongoDB Atlas URI and credentials ready

## 📁 Repository Structure

**After cloning this repo and running deployment:**
```
your-workspace/
├── tiktok-internal-API-deployment-automation/  # This repository
│   ├── bootstrap.sh              # Server initialization
│   ├── setup-github.sh           # GitHub authentication setup
│   ├── clone-repositories.sh     # Repository cloning
│   ├── deploy-services.sh        # Service deployment
│   ├── health-check.sh           # Health monitoring
│   ├── start.sh                  # All-in-one deployment
│   ├── config/
│   │   ├── repositories.conf     # Repository list
│   │   ├── services.conf         # Service configuration
│   │   ├── .env.common.template  # Common environment variables
│   │   ├── .env.production.template
│   │   └── .env.test.template
│   └── README.md                 # This file
│
├── tiktok-user-posts/           # Service 1 (cloned here)
├── tiktok-user-info/            # Service 2 (cloned here)
├── tiktok-post-detail/          # Service 3 (cloned here)
└── tiktok-search-users/         # Service 4 (cloned here)
```

**Note**: Services are cloned to the **parent directory** of this repo, not inside it.

## 🛠️ Script Documentation

### 1. bootstrap.sh - Server Initialization

Prepares a new server with all required dependencies.

**Features:**
- Installs Docker & Docker Compose
- Installs Git and essential tools
- Configures firewall (ports 8082-8085)
- Sets up directory structure

**Usage:**
```bash
# Interactive mode
./bootstrap.sh

# Dry run (preview changes)
./bootstrap.sh --dry-run
```

**What it installs:**
- **Linux**: Docker CE, Docker Compose, Git, curl, wget, jq, net-tools
- **macOS**: Homebrew (if needed), Docker CLI, Docker Compose, Colima, Git (Xcode CLI Tools), curl, wget, jq

### 2. setup-github.sh - GitHub Authentication

Configures GitHub authentication for cloning private repositories.

**Features:**
- SSH key generation and setup
- Personal Access Token (PAT) configuration
- Git global configuration
- SSH config automation

**Usage:**
```bash
# Interactive mode (choose SSH or PAT)
./setup-github.sh

# SSH key method (automatic)
./setup-github.sh --method ssh

# Personal Access Token method
./setup-github.sh --method pat

# Specify email for SSH key
./setup-github.sh --method ssh --email your@email.com
```

**SSH Method (Recommended):**
1. Generates SSH key
2. Displays public key for GitHub
3. Configures SSH automatically
4. Tests connection

**PAT Method:**
1. Guides to GitHub token creation
2. Configures Git credential helper
3. Tests API access

### 3. clone-repositories.sh - Repository Cloning

Clones all service repositories based on `config/repositories.conf`.

**Features:**
- Parallel cloning for speed
- Branch checkout automation
- Verification of cloned repositories
- Force mode for re-cloning

**Usage:**
```bash
# Sequential cloning
./clone-repositories.sh

# Parallel cloning (faster)
./clone-repositories.sh --parallel

# Force re-clone existing directories
./clone-repositories.sh --force

# Parallel + Force
./clone-repositories.sh --parallel --force
```

**Configuration:**
Edit `config/repositories.conf`:
```
# Format: REPO_URL BRANCH TARGET_DIR
# Paths are relative to parent directory
git@github.com:ComBba/tiktok-user-posts.git main ../tiktok-user-posts
```

### 4. deploy-services.sh - Service Deployment

Deploys all services with Docker Compose.

**Features:**
- Parallel deployment option
- Individual service deployment
- Environment variable validation
- Automatic health check waiting
- Service start/stop/restart
- **Configuration cache** - Resume interrupted setup
- **Custom ports** - Configure ports interactively
- **macOS/Linux compatible** - Auto-detects docker-compose v1/v2

**Usage:**
```bash
# Interactive setup (first time - with cache support)
./deploy-services.sh --setup-env

# Deploy all services (sequential)
./deploy-services.sh

# Deploy all services (parallel - faster)
./deploy-services.sh --parallel

# Deploy specific service
./deploy-services.sh --service user-posts

# Stop all services
./deploy-services.sh --stop

# Restart specific service
./deploy-services.sh --restart user-info
```

**Cache Feature:**
If interrupted during setup, the script saves your inputs to `.deployment_cache`:
- Environment type (production/test)
- MongoDB URI and database
- API keys
- Port configurations

On next run, you can:
1. Resume from cache (use previous values)
2. Start fresh (clear and re-enter)
3. View cached values before deciding

**Configuration:**
Edit `config/services.conf`:
```
# Format: SERVICE_NAME PORT DIRECTORY HEALTH_ENDPOINT
user-info 8082 /home/user/github/tiktok-user-info /health
```

### 5. health-check.sh - Health Monitoring

Monitors the health of all services.

**Features:**
- HTTP endpoint checks
- Port listening verification
- Docker container status
- Service uptime tracking
- JSON output support
- Watch mode for continuous monitoring

**Usage:**
```bash
# Check all services (human-readable)
./health-check.sh

# JSON output (for automation)
./health-check.sh --json

# Watch mode (continuous monitoring)
./health-check.sh --watch

# Custom refresh interval (default: 5s)
./health-check.sh --watch --interval 10

# Check specific service
./health-check.sh --service user-posts
```

**Output Example:**
```
✅ user-info (port: 8082)
   Status: healthy
   Container: running
   Port: listening
   HTTP: healthy
   Uptime: 2h 15m

✅ user-posts (port: 8083)
   Status: healthy
   Container: running
   Port: listening
   HTTP: healthy
   Uptime: 2h 15m
```

## ⚙️ Configuration

### Repositories Configuration

Edit `config/repositories.conf` to customize repositories:

```bash
# Format: REPO_URL BRANCH TARGET_DIR
# Services are cloned to parent directory (relative paths)
git@github.com:ComBba/tiktok-user-posts.git main ../tiktok-user-posts
git@github.com:ComBba/tiktok-user-info.git main ../tiktok-user-info
git@github.com:ComBba/tiktok-post-detail.git main ../tiktok-post-detail
git@github.com:ComBba/tiktok-search-users.git main ../tiktok-search-users
```

### Services Configuration

Edit `config/services.conf` to customize services:

```bash
# Format: SERVICE_NAME PORT DIRECTORY HEALTH_ENDPOINT
# Services are in parent directory (relative paths)
user-info 8082 ../tiktok-user-info /health
user-posts 8083 ../tiktok-user-posts /health
search-users 8084 ../tiktok-search-users /health
post-detail 8085 ../tiktok-post-detail /health
```

### Environment Variables

Three template files are provided:

**1. .env.common.template** - Shared settings
```bash
PORT=XXXX                                    # Service-specific port
MONGO_URI=mongodb+srv://username:password@cluster.mongodb.net/
MONGO_DB=YOUR_DATABASE_NAME
INTERNAL_API_KEY=YOUR_INTERNAL_API_KEY_HERE
API_MASTER_KEY=YOUR_INTERNAL_API_KEY_HERE   # Same as INTERNAL_API_KEY
GLOBAL_RPS=20                               # Rate limiting
LOG_LEVEL=info
```

**2. .env.production.template** - Production settings
```bash
PORT=XXXX
ENVIRONMENT=production
MONGO_DB=production_database
LOG_LEVEL=info
LOG_FORMAT=json
```

**3. .env.test.template** - Test settings
```bash
PORT=XXXX
ENVIRONMENT=test
MONGO_DB=test_database
LOG_LEVEL=debug
DEBUG=true
```

**Interactive Setup** (Recommended):
```bash
./deploy-services.sh --setup-env
# Prompts for all required values
# Saves to cache for easy resume
# Creates .env files in all service directories
```

**Manual Setup:**
1. Copy the appropriate template to each service directory as `.env`
2. Replace `XXXX` with actual port numbers (8002-8005 or custom)
3. Update MongoDB URI and database name
4. Set API keys (same value for all services)
5. Never commit `.env` files to Git (already in .gitignore)

## 🔐 Security Best Practices

### Environment Variables
- ✅ Never commit `.env` files
- ✅ Use `.env.example` or templates only
- ✅ Rotate API keys regularly
- ✅ Use different keys for production/test

### GitHub Authentication
- ✅ Use SSH keys for servers (preferred)
- ✅ Use read-only PAT if SSH not possible
- ✅ Restrict PAT to specific repositories
- ✅ Rotate PAT periodically

### Firewall
- ✅ Only open required ports (8082-8085)
- ✅ Configure UFW/iptables
- ✅ Use VPN or IP whitelist for production

## 📊 Monitoring

### Real-Time Monitoring

```bash
# Watch mode - continuous monitoring
./health-check.sh --watch

# Custom refresh interval
./health-check.sh --watch --interval 10
```

### JSON Output for Integration

```bash
# JSON output
./health-check.sh --json

# Pipe to jq for filtering
./health-check.sh --json | jq '.[] | select(.status=="unhealthy")'
```

### Docker Logs

```bash
# View logs for specific service
cd ../tiktok-user-posts
docker-compose logs -f

# Follow logs for all services (from deployment-automation directory)
for dir in ../tiktok-*/; do
  echo "=== $(basename $dir) ==="
  cd "$dir" && docker-compose logs --tail=50
done
```

## 🐛 Troubleshooting

### macOS-Specific Issues

**Problem:** `docker-compose: command not found`
```bash
# Solution: Install docker-compose via Homebrew
brew install docker-compose

# Verify installation
docker-compose --version

# If bootstrap.sh was run before, re-run it
./bootstrap.sh
```

**Problem:** `docker: unknown command: docker compose`
```bash
# Solution: Colima doesn't support docker compose plugin
# Use standalone docker-compose (installed via Homebrew)
brew install docker-compose

# Script auto-detects and uses docker-compose
```

**Problem:** Colima not running
```bash
# Check Colima status
colima status

# Start Colima
colima start

# Restart Colima if needed
colima restart
```

**Problem:** sed errors with special characters in API keys
```bash
# This is already fixed in the script
# API keys with / = + characters are now handled correctly
# If you see sed errors, pull latest changes:
git pull origin main
```

### Bootstrap Issues

**Problem:** Docker installation fails
```bash
# Linux: Manual Docker installation
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# macOS: Ensure Homebrew is installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install docker docker-compose colima
```

**Problem:** Permission denied
```bash
# Solution: Log out and back in to activate docker group
newgrp docker
```

### GitHub Authentication Issues

**Problem:** SSH connection fails
```bash
# Solution: Test SSH connection
ssh -T git@github.com

# Check SSH key
cat ~/.ssh/id_rsa_github.pub

# Re-add key to GitHub
```

**Problem:** PAT authentication fails
```bash
# Solution: Verify token has correct permissions
# Required scopes: repo (full control of private repositories)
```

### Deployment Issues

**Problem:** Service fails to start
```bash
# Check logs
cd ../SERVICE_DIR
docker-compose logs

# Check .env file
cat .env

# Verify port availability
netstat -tuln | grep PORT
```

**Problem:** Health check fails
```bash
# Test endpoint manually
curl http://localhost:8082/health

# Check container status
docker ps -a

# Check Docker logs
docker logs CONTAINER_NAME
```

### Service-Specific Issues

**Problem:** MongoDB connection fails
```bash
# Verify MongoDB URI in .env
# Test connection with mongosh
mongosh "mongodb+srv://..."
```

**Problem:** Port already in use
```bash
# Find process using port
sudo lsof -i :8082

# Kill process
sudo kill -9 PID
```

## 🔄 Maintenance

### Updating Services

```bash
# Pull latest changes
cd ../tiktok-user-posts
git pull origin main

# Rebuild and restart
docker-compose down
docker-compose build
docker-compose up -d
```

### Automated Updates (Future)

```bash
# Update all services (planned)
./update-services.sh --all
```

### Backup

```bash
# Backup .env files (from parent directory)
cd .. && tar -czf env-backup-$(date +%Y%m%d).tar.gz tiktok-*/.env

# Backup logs (from parent directory)
cd .. && tar -czf logs-backup-$(date +%Y%m%d).tar.gz tiktok-*/logs/
```

## 📝 Workflow Examples

### New Server Setup (Complete)

```bash
# 1. Clone deployment automation
git clone https://github.com/ComBba/tiktok-internal-API-deployment-automation.git
cd tiktok-internal-API-deployment-automation

# 2. Initialize server
./bootstrap.sh

# 3. Set up GitHub
./setup-github.sh --method ssh

# 4. Clone all repositories (parallel for speed)
./clone-repositories.sh --parallel

# 5. Deploy all services (parallel)
./deploy-services.sh --parallel

# 6. Verify health
./health-check.sh

# 7. Watch services
./health-check.sh --watch
```

### Deploy Single Service

```bash
# Deploy only user-posts service
./clone-repositories.sh
./deploy-services.sh --service user-posts
./health-check.sh --service user-posts
```

### Production Deployment

```bash
# 1. Clone repositories
./clone-repositories.sh --parallel

# 2. Configure production environment
for dir in ../tiktok-*/; do
  cp config/.env.production.template "$dir/.env"
  # Edit .env with production values
  nano "$dir/.env"
done

# 3. Deploy with verification
./deploy-services.sh --parallel
sleep 30
./health-check.sh

# 4. Continuous monitoring
./health-check.sh --watch --interval 5
```

## 🤝 Contributing

### Adding New Services

1. Add repository to `config/repositories.conf`
2. Add service to `config/services.conf`
3. Test deployment with `--service` flag
4. Update documentation

### Reporting Issues

- Use GitHub Issues
- Include script output
- Include system information
- Include `.env` (without sensitive values)

## 📚 Additional Resources

### Related Repositories
- [tiktok-user-posts](https://github.com/ComBba/tiktok-user-posts)
- [tiktok-user-info](https://github.com/ComBba/tiktok-user-info)
- [tiktok-search-users](https://github.com/ComBba/tiktok-search-users)
- [tiktok-post-detail](https://github.com/ComBba/tiktok-post-detail)

## 📄 License

[Your License Here]

## 👥 Support

- **Issues**: GitHub Issues
- **Email**: support@your-org.com
- **Slack**: #internal-apis

---

**Last Updated:** 2025-10-22
**Version:** 1.1.0

## 📝 Changelog

### Version 1.1.0 (2025-10-22)
- ✅ Added configuration cache for resumable setup
- ✅ macOS full compatibility (bash 3.2, BSD sed, docker-compose)
- ✅ Docker Compose v1/v2 auto-detection
- ✅ Special character handling in API keys (/, =, +)
- ✅ Custom port configuration support
- ✅ Fixed bootstrap.sh to ensure docker-compose installation on macOS
- ❌ Removed RapidAPI configuration (not used by any service)

### Version 1.0.0 (2025-10-21)
- Initial release
- Automated deployment for 4 TikTok Internal API services
- Bootstrap, GitHub setup, clone, deploy, health check scripts
