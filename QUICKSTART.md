# Quick Start Guide

Single-page deployment guide for new servers.

## 📋 Prerequisites

- Ubuntu 20.04+ / Debian 10+ / macOS 11+
- sudo access (Linux) or admin access (macOS)
- GitHub account with repository access
- Internet connection (Homebrew auto-installs on macOS)

## ⭐ All-in-One Deployment (Easiest)

```bash
# Clone deployment scripts
git clone https://github.com/ComBba/tiktok-internal-API-deployment-automation.git
cd tiktok-internal-API-deployment-automation

# Run all-in-one deployment
./start.sh

# Follow the interactive prompts - Done in 15-20 minutes!
```

**What it does:**
1. ✅ Installs Docker & Git
2. ✅ Sets up GitHub authentication
3. ✅ Clones all 4 services
4. ✅ Configures environment & ports
5. ✅ Deploys all services
6. ✅ Runs health check

**Skip already-done steps:**
```bash
# If Docker already installed
./start.sh --skip-bootstrap

# If GitHub already configured
./start.sh --skip-bootstrap --skip-github

# If repos already cloned
./start.sh --skip-bootstrap --skip-github --skip-clone
```

---

## 🚀 Manual 5-Step Deployment (Advanced)

### Step 1: Initial Setup (5 min)

```bash
# Download and run bootstrap
./bootstrap.sh

# What it does:
# ✓ Installs Docker & Docker Compose
# ✓ Installs Git
# ✓ Opens ports 8082-8085
```

### Step 2: GitHub Authentication (2 min)

```bash
# Option A: SSH Key (Recommended)
./setup-github.sh --method ssh
# → Follow prompts to add key to GitHub

# Option B: Personal Access Token
./setup-github.sh --method pat
# → Enter your GitHub token
```

### Step 3: Clone & Deploy (10 min)

```bash
# Clone all 4 services
./clone-repositories.sh --parallel

# Configure environment (Interactive)
./deploy-services.sh --setup-env
# → Select: 1 (Production) or 2 (Test)
# → Enter MongoDB URI (or press Enter for default)
# → Enter MongoDB Database (or press Enter for default)
# → Enter Internal API Key (or press Enter for default)
# → Enter RapidAPI Key (required)
# → Configure ports for each service:
#     User Info API [default: 8082]: (Enter custom port or press Enter)
#     User Posts API [default: 8083]: (Enter custom port or press Enter)
#     Search Users API [default: 8084]: (Enter custom port or press Enter)
#     Post Detail API [default: 8085]: (Enter custom port or press Enter)

# Deploy services
./deploy-services.sh --parallel
```

### Step 4: Verify (1 min)

```bash
# Check all services
./health-check.sh

# Watch live status
./health-check.sh --watch
```

## 📝 Expected Output

```
✅ user-info (port: 8082)
   Status: healthy
   Container: running
   Port: listening
   HTTP: healthy
   Uptime: 2m

✅ user-posts (port: 8083)
   Status: healthy
   ...

✅ search-users (port: 8084)
   Status: healthy
   ...

✅ post-detail (port: 8085)
   Status: healthy
   ...
```

## 🔧 Common Issues

### Issue: Repository clone fails
```bash
# Solution: Check GitHub authentication
ssh -T git@github.com
# Should show: "successfully authenticated"
```

### Issue: Service won't start
```bash
# Solution: Check .env file exists
ls ../tiktok-user-posts/.env
# If missing, run: ./deploy-services.sh --setup-env
```

### Issue: Health check fails
```bash
# Solution: Check Docker logs
cd ../SERVICE_NAME
docker-compose logs
```

## 📚 Get Help

```bash
# Show help for any script
./start.sh --help                  # All-in-one deployment
./bootstrap.sh --help
./setup-github.sh --help
./clone-repositories.sh --help
./deploy-services.sh --help
./health-check.sh --help
```

## 🎯 All-in-One Options

```bash
# Full deployment (first time)
./start.sh

# Skip bootstrap (Docker already installed)
./start.sh --skip-bootstrap

# Skip GitHub setup (already authenticated)
./start.sh --skip-github

# Skip to deployment only
./start.sh --skip-bootstrap --skip-github --skip-clone

# Non-interactive mode (use defaults)
./start.sh --non-interactive

# Sequential mode (slower but safer)
./start.sh --sequential
```

## 🎯 What Gets Deployed

| Service | Port | Purpose |
|---------|------|---------|
| user-info | 8082 | TikTok user information |
| user-posts | 8083 | User posts data (cached) |
| search-users | 8084 | User discovery (no CAPTCHA) |
| post-detail | 8085 | Post details (4-tier fallback) |

## ⚙️ Configuration Files

```bash
config/repositories.conf    # GitHub repository URLs
config/services.conf        # Service ports and paths
config/.env.*.template      # Environment templates
```

## 🔄 Management Commands

```bash
# Stop all services
./deploy-services.sh --stop

# Restart specific service
./deploy-services.sh --restart user-posts

# Reconfigure environment
./deploy-services.sh --setup-env

# Watch service health
./health-check.sh --watch
```

## 📊 Service URLs

After deployment, services are available at:

```
http://localhost:8082/health   # User Info
http://localhost:8083/health   # User Posts
http://localhost:8084/health   # Search Users
http://localhost:8085/health   # Post Detail
```

## 🆘 Emergency Commands

```bash
# Check Docker status
docker ps -a

# Check specific service logs
docker logs -f CONTAINER_NAME

# Restart Docker
sudo systemctl restart docker

# Check port usage
netstat -tuln | grep 808
```

## ✅ Success Checklist

- [ ] Bootstrap completed without errors
- [ ] GitHub authentication working
- [ ] All 4 repositories cloned
- [ ] .env files configured in all services
- [ ] All 4 services deployed
- [ ] Health check shows all healthy
- [ ] Can access all /health endpoints

---

**Total Time:** ~20 minutes
**Services Deployed:** 4
**Ports Used:** 8082, 8083, 8084, 8085
