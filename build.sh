#!/bin/bash
# Simplified Docker build script
set -e

# Configuration
TAG="latest"
REGISTRY="mcuoco/"
PUSH=false
LOAD=false
TARGET_IMAGE=""
PLATFORM="linux/amd64"
BUILD_ARGS=()
ENV_FILE_ARG=""

show_help() {
    cat << EOF
Usage: $0 [OPTIONS] [TARGET_STAGE]

Build a single image from the root Dockerfile, targeting a specific stage.

OPTIONS:
    --push       Push to registry after build
    --load       Load image locally
    --tag TAG    Set image tag (default: latest)
    --platform PLAT[,PLAT]  Set platform(s), e.g. linux/amd64 or linux/amd64,linux/arm64
    --build-arg KEY=VAL     Pass build-arg to docker build (repeatable)
    --env-file FILE         Convenience: sets build-arg ENVIRONMENT_FILE=FILE
    -h, --help   Show this help

EXAMPLES:
    $0 mamba-gvl-micro                        # Build specific Dockerfile stage
    $0 --load mamba-gvl-micro                 # Build and load locally
    $0 --push --tag v1.0 mamba-gvl            # Build and push with tag
    $0 --platform linux/amd64,linux/arm64 \
       --push mamba-gvl-micro                 # Multi-arch build
    $0 --env-file environments/gvl.yml mamba-gvl # Use specific env file

EOF
}

build_image() {
    local image_name="$1"
    
    echo "Building $image_name..."
    
    # Build command
    local full_image_name="${REGISTRY}${image_name}:${TAG}"
    local build_cmd="docker buildx build --platform $PLATFORM -t $full_image_name -f Dockerfile"

    # Target the stage named after the image
    build_cmd+=" --target ${image_name}"
    
    # Append build args
    for arg in "${BUILD_ARGS[@]}"; do
        build_cmd+=" --build-arg ${arg}"
    done
    
    # Env file convenience
    if [[ -n "$ENV_FILE_ARG" ]]; then
        build_cmd+=" --build-arg ENVIRONMENT_FILE=${ENV_FILE_ARG}"
    fi
    
    # Load or push behavior
    if [[ "$PUSH" == true ]]; then
        build_cmd+=" --push"
    elif [[ "$LOAD" == true ]]; then
        # buildx: use --load only for single-platform builds
        if [[ "$PLATFORM" == *","* ]]; then
            echo "Error: --load cannot be used with multiple platforms" >&2
            return 1
        fi
        build_cmd+=" --load"
    fi
    
    build_cmd+=" ."
    
    echo "Running: $build_cmd"
    eval "$build_cmd"
    
    if [[ "$LOAD" == true ]]; then
        echo "Loading $full_image_name to local Docker..."
    fi
    
    # Pushing handled by buildx when --push is used
    
    echo "✅ Built: $full_image_name"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
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
        --platform)
            if [[ -z "$2" ]]; then
                echo "Error: Missing argument for --platform" >&2
                exit 1
            fi
            PLATFORM="$2"
            shift 2
            ;;
        --build-arg)
            if [[ -z "$2" ]]; then
                echo "Error: Missing argument for --build-arg" >&2
                exit 1
            fi
            BUILD_ARGS+=("$2")
            shift 2
            ;;
        --env-file)
            if [[ -z "$2" ]]; then
                echo "Error: Missing argument for --env-file" >&2
                exit 1
            fi
            ENV_FILE_ARG="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            TARGET_IMAGE="$1"
            shift
            ;;
    esac
done

if [[ -z "$TARGET_IMAGE" ]]; then
    echo "No target stage specified; defaulting to 'mamba-gvl-micro'"
    TARGET_IMAGE="mamba-gvl-micro"
fi

echo "Building target stage: $TARGET_IMAGE"
build_image "$TARGET_IMAGE"