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

- **Operating System**: Ubuntu 20.04+ or Debian 10+
- **User Permissions**: sudo access
- **Network**: Ports 8082-8085 available
- **GitHub Access**: SSH key or Personal Access Token

## 📁 Repository Structure

```
deployment-automation/
├── bootstrap.sh              # Server initialization
├── setup-github.sh           # GitHub authentication setup
├── clone-repositories.sh     # Repository cloning
├── deploy-services.sh        # Service deployment
├── health-check.sh           # Health monitoring
├── config/
│   ├── repositories.conf     # Repository list
│   ├── services.conf         # Service configuration
│   ├── .env.common.template  # Common environment variables
│   ├── .env.production.template
│   └── .env.test.template
└── README.md                 # This file
```

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
- Docker CE (latest)
- Docker Compose
- Git
- curl, wget, jq, net-tools

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
git@github.com:ComBba/tiktok-user-posts.git main $HOME/github/tiktok-user-posts
```

### 4. deploy-services.sh - Service Deployment

Deploys all services with Docker Compose.

**Features:**
- Parallel deployment option
- Individual service deployment
- Environment variable validation
- Automatic health check waiting
- Service start/stop/restart

**Usage:**
```bash
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
git@github.com:ComBba/tiktok-user-posts.git main ~/github/tiktok-user-posts
git@github.com:ComBba/tiktok-user-info.git main ~/github/tiktok-user-info
git@github.com:ComBba/tiktok-post-detail.git main ~/github/tiktok-post-detail
git@github.com:ComBba/tiktok-search-users.git main ~/github/tiktok-search-users
```

### Services Configuration

Edit `config/services.conf` to customize services:

```bash
# Format: SERVICE_NAME PORT DIRECTORY HEALTH_ENDPOINT
user-info 8082 ~/github/tiktok-user-info /health
user-posts 8083 ~/github/tiktok-user-posts /health
search-users 8084 ~/github/tiktok-search-users /health
post-detail 8085 ~/github/tiktok-post-detail /health
```

### Environment Variables

Three template files are provided:

**1. .env.common.template** - Shared settings
```bash
MONGO_URI=mongodb+srv://...
INTERNAL_API_KEY=YOUR_INTERNAL_API_KEY_HERE
```

**2. .env.production.template** - Production settings
```bash
ENVIRONMENT=production
MONGO_DB=production_database
LOG_LEVEL=info
```

**3. .env.test.template** - Test settings
```bash
ENVIRONMENT=test
MONGO_DB=test_database
LOG_LEVEL=debug
DEBUG=true
```

**Usage:**
1. Copy the appropriate template to each service directory as `.env`
2. Customize service-specific values (PORT, etc.)
3. Never commit `.env` files to Git

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
cd ~/github/tiktok-user-posts
docker-compose logs -f

# Follow logs for all services
for dir in ~/github/tiktok-*/; do
  echo "=== $(basename $dir) ==="
  cd "$dir" && docker-compose logs --tail=50
done
```

## 🐛 Troubleshooting

### Bootstrap Issues

**Problem:** Docker installation fails
```bash
# Solution: Manual Docker installation
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
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
cd ~/github/SERVICE_DIR
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
cd ~/github/tiktok-user-posts
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
# Backup .env files
tar -czf env-backup-$(date +%Y%m%d).tar.gz ~/github/*/.env

# Backup logs
tar -czf logs-backup-$(date +%Y%m%d).tar.gz ~/github/*/logs/
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
for dir in ~/github/tiktok-*/; do
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
**Version:** 1.0.0
