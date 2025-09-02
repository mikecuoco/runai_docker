#!/bin/bash

# General Docker build script for multiple images
# Based on patterns from mruffalo/multi-docker-build and MCLD/buildscript
set -e  # Exit on any error
set -o pipefail  # Fail pipelines if any command fails

# Default configuration
DOCKER_IMAGES_FILE="docker_images.txt"
TAG="latest"
PLATFORMS="linux/amd64"
REGISTRY="mcuoco/"  # Default registry prefix
BUILDER_NAME="mamba-gvl-builder"

# Runtime flags
PUSH=false
LOAD=false
PLATFORM="linux/amd64"
BUILD_ALL=false
TARGET_IMAGE=""
DRY_RUN=false
BUILD_ARGS=()  # Array to hold build args
SECRET_USER_PASSWORD_FILE=""  # optional path to password file for BuildKit

# Logging
SAVE_LOGS=true
LOG_DIR="build-logs"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[BUILD]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

show_help() {
    cat << EOF
Usage: $0 [OPTIONS] [IMAGE_NAME]

Build Docker images defined in $DOCKER_IMAGES_FILE
All images use conda-lock by default for reproducible builds.

OPTIONS:
    --all               Build all images in sequence
    --push              Push to registry after build
    --load              Load image to local Docker (single-platform only)
    --tag TAG           Set image tag (default: latest)
    --registry REG      Set registry prefix (default: mcuoco/)
    --platform PLAT     Set build platform(s), comma-separated. Supported: linux/amd64, linux/arm64
    --build-arg KEY=VAL Pass build argument to docker build (can be used multiple times)
    --dry-run           Show what would be built without executing
    --secret-pass FILE  Path to file containing user password (BuildKit secret)
    --log-dir DIR       Directory for build logs (default: build-logs)
    --no-logs           Do not save logs to files
    --list              List available images
    -h, --help          Show this help message

ARGUMENTS:
    IMAGE_NAME          Name of specific image to build (from $DOCKER_IMAGES_FILE)

EXAMPLES:
    $0 --all                           # Build all images
    $0 mamba-gvl                       # Build specific image
    $0 --load mamba-gvl-micro          # Build and load locally
    $0 --push --tag v1.0 --all         # Build and push all with tag
    $0 --platform linux/amd64,linux/arm64 --push mamba-gvl # Multi-arch build
    $0 --build-arg FOO=bar mamba-gvl   # Pass build arg to docker build
    $0 --list                          # Show available images

LOCKFILES:
    To use conda-lock for reproducible builds, generate lockfiles manually:
    ./scripts/generate-lockfiles.sh environments/gvl.yml

EOF
}

list_images() {
    if [[ ! -f "$DOCKER_IMAGES_FILE" ]]; then
        error "Docker images file not found: $DOCKER_IMAGES_FILE"
        exit 1
    fi
    
    info "Available images in $DOCKER_IMAGES_FILE:"
    echo ""
    while IFS=$'\t' read -r image_name dockerfile_path options || [[ -n "$image_name" ]]; do
        # Skip comments and empty lines
        [[ "$image_name" =~ ^#.*$ ]] && continue
        [[ -z "$image_name" ]] && continue
        
        echo "  • $image_name"
        echo "    Dockerfile: $dockerfile_path"
        if [[ -n "$options" ]]; then
            echo "    Options: $options"
        fi
        echo ""
    done < "$DOCKER_IMAGES_FILE"
}

build_image() {
    local image_name="$1"
    local dockerfile_path="$2"
    local options="$3"
    
    log "Building image: $image_name"
    info "Dockerfile: $dockerfile_path"
    if [[ -n "$options" ]]; then
        info "Options: $options"
    fi
    
    # Check if dockerfile exists
    if [[ ! -f "$dockerfile_path" ]]; then
        error "Dockerfile not found: $dockerfile_path"
        return 1
    fi
    
    # Construct full image name
    local full_image_name="${REGISTRY}${image_name}:${TAG}"
    
    # Disallow --load with multi-platform builds
    if [[ "$LOAD" == true && "$PLATFORM" == *","* ]]; then
        error "--load cannot be used with multiple platforms. Use --push or specify a single platform."
        return 1
    fi

    # Determine build context
    local build_context="."
    local dockerfile_flag="$dockerfile_path"
    
    if [[ "$options" == *"base_directory_build"* ]]; then
        build_context="."
        dockerfile_flag="$dockerfile_path"
        info "Building from repository root"
    else
        build_context="$(dirname "$dockerfile_path")"
        dockerfile_flag="$(basename "$dockerfile_path")"
        info "Building from directory: $build_context"
    fi
    
    # Build command
    local build_args=(
        "buildx" "build"
        "--platform" "$PLATFORM"
        "--tag" "$full_image_name"
        "--file" "$dockerfile_flag"
    )
    
    # Add push or load flag
    if [[ "$PUSH" == true ]]; then
        build_args+=("--push")
        info "Will push to registry after build"
    elif [[ "$LOAD" == true ]]; then
        build_args+=("--load")
        info "Will load to local Docker after build"
    fi
    
    # Add standard build arguments
    build_args+=("--build-arg" "BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')")
    
    # If building from stack, and a target is given via options (image name), set target
    if [[ "$dockerfile_path" == Dockerfile* ]]; then
        build_args+=("--target" "$image_name")
    fi

    # Add user-supplied build args
    for arg in "${BUILD_ARGS[@]}"; do
        build_args+=("--build-arg" "$arg")
    done

    # Add BuildKit secrets
    if [[ -n "$SECRET_USER_PASSWORD_FILE" ]]; then
        build_args+=("--secret" "id=user_password,src=${SECRET_USER_PASSWORD_FILE}")
    fi

    # Add build context
    build_args+=("$build_context")
    
    if [[ "$DRY_RUN" == true ]]; then
        warn "DRY RUN MODE: docker ${build_args[*]}"
        return 0
    fi
    
    # Execute build (with optional logging)
    log "Running: docker ${build_args[*]}"

    if [[ "$SAVE_LOGS" == true ]]; then
        mkdir -p "$LOG_DIR"
        local ts
        ts=$(date -u +'%Y%m%dT%H%M%SZ')
        local safe_platform
        safe_platform=${PLATFORM//\//-}
        safe_platform=${safe_platform//,/_}
        local log_file="${LOG_DIR}/${image_name}_${TAG}_${safe_platform}_${ts}.log"
        info "Saving build log to: $log_file"

        {
            echo "================ BUILD START $(date -u +'%Y-%m-%dT%H:%M:%SZ') ================"
            echo "Image:       $full_image_name"
            echo "Platform:    $PLATFORM"
            echo "Dockerfile:  $dockerfile_path"
            echo "Context:     $build_context"
            echo "Builder:     $BUILDER_NAME"
            echo "Command:     docker ${build_args[*]}"
            echo "==============================================================="
        } | tee -a "$log_file" >/dev/null

        docker "${build_args[@]}" 2>&1 | tee -a "$log_file"
        local status=${PIPESTATUS[0]}

        echo "================= BUILD END $(date -u +'%Y-%m-%dT%H:%M:%SZ') =================" | tee -a "$log_file" >/dev/null

        if [[ $status -ne 0 ]]; then
            error "Build failed for $full_image_name (status $status). See log: $log_file"
            return $status
        fi
    else
        docker "${build_args[@]}"
    fi

    log "✅ Successfully built: $full_image_name"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            BUILD_ALL=true
            shift
            ;;
        --push)
            PUSH=true
            shift
            ;;
        --load)
            LOAD=true
            shift
            ;;
        --tag)
            TAG="$2"
            shift 2
            ;;
        --registry)
            REGISTRY="$2"
            shift 2
            ;;
        --platform)
            if [[ -z "$2" ]]; then
                error "Missing argument for --platform"
                show_help
                exit 1
            fi
            platform_input="$2"
            IFS=',' read -r -a platform_list <<< "$platform_input"
            valid=true
            for plat in "${platform_list[@]}"; do
                case "$plat" in
                    linux/amd64|linux/arm64)
                        ;;
                    *)
                        valid=false
                        ;;
                esac
            done
            if [[ "$valid" == false ]]; then
                error "Unsupported platform(s): $2"
                echo "Supported platforms: linux/amd64, linux/arm64 (comma-separated allowed)"
                exit 1
            fi
            PLATFORM="$platform_input"
            shift 2
            ;;
        --build-arg)
            if [[ -z "$2" ]]; then
                error "Missing argument for --build-arg"
                show_help
                exit 1
            fi
            BUILD_ARGS+=("$2")
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --log-dir)
            if [[ -z "$2" ]]; then
                error "Missing argument for --log-dir"
                show_help
                exit 1
            fi
            LOG_DIR="$2"
            shift 2
            ;;
        --no-logs)
            SAVE_LOGS=false
            shift
            ;;
        --secret-pass)
            if [[ -z "$2" ]]; then
                error "Missing argument for --secret-pass"
                show_help
                exit 1
            fi
            SECRET_USER_PASSWORD_FILE="$2"
            shift 2
            ;;  
        --list)
            list_images
            exit 0
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            error "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            if [[ -z "$TARGET_IMAGE" ]]; then
                TARGET_IMAGE="$1"
            else
                error "Multiple image names specified: $TARGET_IMAGE and $1"
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate arguments
if [[ "$BUILD_ALL" == true && -n "$TARGET_IMAGE" ]]; then
    error "Cannot specify both --all and a specific image name"
    exit 1
fi

if [[ "$BUILD_ALL" == false && -z "$TARGET_IMAGE" ]]; then
    error "Must specify either --all or a specific image name"
    show_help
    exit 1
fi

# Ensure buildx is available
if [[ "$DRY_RUN" == false ]]; then
    if ! docker buildx version > /dev/null 2>&1; then
        error "Docker buildx is not available. Please install Docker Desktop or enable buildx."
        exit 1
    fi
    
    # Create and use builder if needed (robust against pre-existing instance)
    if docker buildx inspect "$BUILDER_NAME" > /dev/null 2>&1; then
        info "Using existing builder: $BUILDER_NAME"
        docker buildx use "$BUILDER_NAME"
    else
        log "Creating new buildx builder: $BUILDER_NAME"
        if ! docker buildx create --name "$BUILDER_NAME" --use; then
            warn "Builder '$BUILDER_NAME' appears to already exist. Switching to it."
            docker buildx use "$BUILDER_NAME"
        fi
    fi
fi

# Check if docker images file exists
if [[ ! -f "$DOCKER_IMAGES_FILE" ]]; then
    error "Docker images file not found: $DOCKER_IMAGES_FILE"
    exit 1
fi

# Main build logic
if [[ "$BUILD_ALL" == true ]]; then
    log "Building all images from $DOCKER_IMAGES_FILE"
    
    while IFS=$'\t' read -r image_name dockerfile_path options || [[ -n "$image_name" ]]; do
        # Skip comments and empty lines
        [[ "$image_name" =~ ^#.*$ ]] && continue
        [[ -z "$image_name" ]] && continue
        
        build_image "$image_name" "$dockerfile_path" "$options"
        echo ""
    done < "$DOCKER_IMAGES_FILE"
    
    log "🎉 All images built successfully!"
else
    # Build specific image
    log "Building specific image: $TARGET_IMAGE"
    
    found=false
    while IFS=$'\t' read -r image_name dockerfile_path options || [[ -n "$image_name" ]]; do
        # Skip comments and empty lines
        [[ "$image_name" =~ ^#.*$ ]] && continue
        [[ -z "$image_name" ]] && continue
        
        if [[ "$image_name" == "$TARGET_IMAGE" ]]; then
            found=true
            build_image "$image_name" "$dockerfile_path" "$options"
            break
        fi
    done < "$DOCKER_IMAGES_FILE"
    
    if [[ "$found" == false ]]; then
        error "Image '$TARGET_IMAGE' not found in $DOCKER_IMAGES_FILE"
        echo ""
        list_images
        exit 1
    fi
    
    log "🎉 Image built successfully!"
fi 
