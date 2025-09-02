# RunAI Development Environment

This repository contains Docker images and configurations for RunAI development environments with GPU support, SSH access, and Jupyter Lab.

**🔒 All images use conda-lock by default for completely reproducible builds.**

## 🏗️ Project Structure

```
runai/
├── shared/                          # Shared resources for all images
│   ├── environments/
│   │   ├── gvl.yml                 # Common conda environment
│   ├── scripts/
│   │   ├── setup-dotfiles.sh       # Dotfiles setup script
│   │   └── generate-lockfiles.sh   # Conda-lock generation script
│   └── configs/                    # Shared configuration files
├── mamba-gvl/                      # Jupyter base image variant
│   └── Dockerfile
├── mamba-gvl-micro/                # Micromamba base image variant  
│   └── Dockerfile
├── docker_images.txt               # Build configuration
├── build.sh                       # General build script
└── README.md
```

## 🚀 Quick Start

### List Available Images
```bash
./build.sh --list
```

### Build a Specific Image
```bash
# Build the jupyter-based image (lockfiles auto-generated)
./build.sh mamba-gvl

# Build the micromamba-based image (lockfiles auto-generated)
./build.sh mamba-gvl-micro
```

### Build All Images
```bash
./build.sh --all
```

### Build and Load Locally
```bash
./build.sh --load mamba-gvl
```

### Build and Push to Registry
```bash
./build.sh --push --tag v1.0 --all
```

## 🔒 Reproducible Builds with Conda-Lock

All Docker images now use [conda-lock](https://conda.github.io/conda-lock/docker/) by default for **completely reproducible builds**:

### Manual Lockfile Generation
```bash
# Generate lockfiles manually for reproducible builds
./shared/scripts/generate-lockfiles.sh shared/environments/gvl.yml

# Then build with lockfile support
./build.sh mamba-gvl
```

### Simple Linux-64 Generation
The lockfile generation script creates linux-64 lockfiles optimized for RunAI deployment:

```bash
# Generate lockfile for the environment
./shared/scripts/generate-lockfiles.sh shared/environments/gvl.yml

# Show help
./shared/scripts/generate-lockfiles.sh --help

# This creates: shared/environments/gvl-linux-64.lock
```

### Why Linux-64 Only?
- **RunAI Target:** All RunAI deployments run on Linux x86_64
- **Simplicity:** Single platform reduces complexity and build time
- **Faster Generation:** No need to solve for multiple platforms
- **Optimized:** Specifically tuned for the deployment environment

### Why Use Lockfiles?
- **Exact Reproducibility:** Package hashes ensure identical builds every time
- **Faster Builds:** No dependency solving during Docker build  
- **Better Security:** Prevents supply chain attacks through dependency drift
- **CI/CD Ready:** Consistent builds across all environments


## 🐳 Available Images

### mamba-gvl
- **Base:** `jupyter/minimal-notebook`
- **Features:** Full Jupyter ecosystem, SSH server, dotfiles
- **Size:** Larger but feature-complete
- **Best for:** Development environments requiring full Jupyter compatibility

### mamba-gvl-micro  
- **Base:** `mambaorg/micromamba:2.3.0`
- **Features:** Lightweight, SSH server, dotfiles
- **Size:** 2x faster builds, smaller images
- **Best for:** Production environments, CI/CD pipelines

Both images now use conda-lock for reproducible builds by default.

## 🔧 Build Script Options

```bash
Usage: ./build.sh [OPTIONS] [IMAGE_NAME]

Build Docker images defined in docker_images.txt
All images use conda-lock by default for reproducible builds.

OPTIONS:
    --all               Build all images in sequence
    --push              Push to registry after build
    --load              Load image to local Docker 
    --tag TAG           Set image tag (default: latest)
    --registry REG      Set registry prefix (default: mcuoco/)
    --dry-run           Show what would be built without executing
    --list              List available images
    -h, --help          Show this help message

EXAMPLES:
    ./build.sh --all                           # Build all images
    ./build.sh mamba-gvl                       # Build specific image
    ./build.sh --load mamba-gvl-micro          # Build and load locally
    ./build.sh --push --tag v1.0 --all        # Build and push all with tag

LOCKFILES:
    To use conda-lock for reproducible builds, generate lockfiles manually:
    
    ./shared/scripts/generate-lockfiles.sh shared/environments/gvl.yml
```

## 📋 Platform Support

Lockfiles are generated specifically for **linux-64** (Linux x86_64) - the target platform for RunAI deployments:

**Target Platform:**
- **linux-64** (Linux x86_64) - Primary and only target for RunAI

**Why Linux-64 Only?**
- **Deployment Focus:** RunAI exclusively runs on Linux x86_64
- **Build Efficiency:** Single platform means faster lockfile generation  
- **Reduced Complexity:** No need to manage multiple platform variants
- **Optimized Performance:** Packages specifically selected for the deployment environment

**Lockfile Location:**
```bash
# Generated lockfile location
shared/environments/gvl-linux-64.lock

# Generated from
shared/environments/gvl.yml
```

## 🖥️ Using with RunAI

### Submit a Workspace
```bash
runai workspace submit my-workspace \
  -i mcuoco/mamba-gvl:latest \
  --preemptible \
  --nfs server=multilabna.salk.edu,path=/iblm_data3,mountpath=/home/jovyan/data3,readwrite
```

### Access Methods

#### 1. SSH Access
```bash
# Port forward SSH
runai workspace port-forward my-workspace --port 2222:22

# Connect via SSH (password: password)
ssh -p 2222 jovyan@localhost
```

#### 2. Jupyter Access  
```bash
# Port forward Jupyter
runai workspace port-forward my-workspace --port 8888:8888

# Open in browser
open http://localhost:8888
```

#### 3. Direct Terminal
```bash
runai workspace bash my-workspace
```

#### 4. VS Code Remote SSH
1. Port forward SSH: `runai workspace port-forward my-workspace --port 2222:22`
2. In VS Code, connect to: `jovyan@127.0.0.1:2222` (password: `password`)

## 🧬 Shared Environment

The `shared/environments/gvl.yml` environment includes:

- **PyTorch ecosystem:** pytorch, torchvision, torchaudio, pytorch-lightning
- **ML/AI libraries:** transformers, datasets, scikit-learn, timm
- **Data processing:** polars, pandas, pysam, pyliftover  
- **Development tools:** jupyter, git, rich, wandb
- **GPU support:** CUDA toolkit and drivers

## 🔄 Development Workflow

### 1. Modify Shared Resources
```bash
# Edit environment
vim shared/environments/gvl.yml

# Update scripts
vim shared/scripts/setup-dotfiles.sh
```

### 2. Build and Test
```bash
# Build with fallback to environment.yml (fast development)
./build.sh --load mamba-gvl

# Generate lockfiles for reproducible builds
./shared/scripts/generate-lockfiles.sh shared/environments/gvl.yml

# Build with lockfiles (reproducible)
./build.sh --load mamba-gvl

# Test with dry run mode
./build.sh --dry-run --all

# Try the example workflow
./examples/lockfile-workflow.sh
```

### 3. Deploy
```bash
# Build and push new version
./build.sh --push --tag v1.1 --all
```

## 📝 Configuration Files

### docker_images.txt
Defines which images to build:
```
# All images use conda-lock by default for reproducible builds
mamba-gvl		mamba-gvl/Dockerfile		base_directory_build,ssh_enabled
mamba-gvl-micro		mamba-gvl-micro/Dockerfile	base_directory_build,ssh_enabled
```

### Shared Scripts
- `setup-dotfiles.sh`: Clones and sets up development dotfiles
- `start-ssh-jupyter.sh`: Intelligent startup script for SSH + Jupyter
- `generate-lockfiles.sh`: Creates linux-64 lockfiles from environment.yml

## 🔍 Troubleshooting

### Lockfile Issues
- **Missing conda-lock**: Install with `pip install conda-lock`
- **Missing lockfile**: Generate with `./shared/scripts/generate-lockfiles.sh shared/environments/gvl.yml`
- **Outdated lockfile**: Regenerate after changing `gvl.yml`
- **Development speed**: Use builds without lockfiles for faster iteration

### SSH Connection Issues
- Ensure port forwarding is active: `runai workspace port-forward workspace-name --port 2222:22`
- Default credentials: username=`jovyan`/`mambauser`, password=`password`
- Check SSH service: `runai workspace bash workspace-name` then `ps aux | grep sshd`

### Build Issues
- Use `--dry-run` to debug build commands
- Check Docker buildx: `docker buildx version`
- Verify shared files exist: `ls shared/environments/`

### Environment Issues
- List environments: `conda env list` or `micromamba env list`
- Check activation: `echo $CONDA_DEFAULT_ENV`

## 🚧 Extending

### Adding New Images
1. Create new Dockerfile in its own directory
2. Use the same lockfile pattern as existing Dockerfiles
3. Add entry to `docker_images.txt`
4. Test with `./build.sh --dry-run new-image-name`

### Modifying Shared Resources
1. Update files in `shared/` directories
2. Generate lockfiles manually when needed for reproducible builds
3. All images automatically use updated shared resources