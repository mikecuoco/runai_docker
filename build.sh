#!/bin/bash
# Simplified Docker build script
set -e

# Configuration
DOCKER_IMAGES_FILE="docker_images.txt"
TAG="latest"
REGISTRY="mcuoco/"
PUSH=false
LOAD=false
BUILD_ALL=false
TARGET_IMAGE=""

show_help() {
    cat << EOF
Usage: $0 [OPTIONS] [IMAGE_NAME]

Build Docker images defined in $DOCKER_IMAGES_FILE

OPTIONS:
    --all        Build all images
    --push       Push to registry after build
    --load       Load image locally
    --tag TAG    Set image tag (default: latest)
    --list       List available images
    -h, --help   Show this help

EXAMPLES:
    $0 --all                    # Build all images
    $0 mamba-gvl               # Build specific image
    $0 --load mamba-gvl-micro  # Build and load locally
    $0 --push --tag v1.0 --all # Build and push all

EOF
}

list_images() {
    if [[ ! -f "$DOCKER_IMAGES_FILE" ]]; then
        echo "Error: Docker images file not found: $DOCKER_IMAGES_FILE"
        exit 1
    fi
    
    echo "Available images:"
    while IFS=$'\t' read -r image_name dockerfile_path options || [[ -n "$image_name" ]]; do
        [[ "$image_name" =~ ^#.*$ ]] && continue
        [[ -z "$image_name" ]] && continue
        echo "  • $image_name ($dockerfile_path)"
    done < "$DOCKER_IMAGES_FILE"
}

build_image() {
    local image_name="$1"
    local dockerfile_path="$2"
    local options="$3"
    
    echo "Building $image_name..."
    
    # Determine build context
    local build_context="."
    if [[ "$options" != *"base_directory_build"* ]]; then
        build_context="$(dirname "$dockerfile_path")"
    fi
    
    # Build command
    local full_image_name="${REGISTRY}${image_name}:${TAG}"
    local build_cmd="docker build -t $full_image_name -f $dockerfile_path $build_context"
    
    echo "Running: $build_cmd"
    eval "$build_cmd"
    
    if [[ "$LOAD" == true ]]; then
        echo "Loading $full_image_name to local Docker..."
    fi
    
    if [[ "$PUSH" == true ]]; then
        echo "Pushing $full_image_name..."
        docker push "$full_image_name"
    fi
    
    echo "✅ Built: $full_image_name"
}

# Parse arguments
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
        --list)
            list_images
            exit 0
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

# Check docker images file exists
if [[ ! -f "$DOCKER_IMAGES_FILE" ]]; then
    echo "Error: Docker images file not found: $DOCKER_IMAGES_FILE"
    exit 1
fi

# Main build logic
if [[ "$BUILD_ALL" == true ]]; then
    echo "Building all images from $DOCKER_IMAGES_FILE"
    
    while IFS=$'\t' read -r image_name dockerfile_path options || [[ -n "$image_name" ]]; do
        [[ "$image_name" =~ ^#.*$ ]] && continue
        [[ -z "$image_name" ]] && continue
        
        build_image "$image_name" "$dockerfile_path" "$options"
        echo ""
    done < "$DOCKER_IMAGES_FILE"
    
    echo "🎉 All images built successfully!"
else
    if [[ -z "$TARGET_IMAGE" ]]; then
        echo "Error: No image specified. Use --all or specify an image name."
        show_help
        exit 1
    fi
    
    # Build specific image
    echo "Building specific image: $TARGET_IMAGE"
    
    found=false
    while IFS=$'\t' read -r image_name dockerfile_path options || [[ -n "$image_name" ]]; do
        [[ "$image_name" =~ ^#.*$ ]] && continue
        [[ -z "$image_name" ]] && continue
        
        if [[ "$image_name" == "$TARGET_IMAGE" ]]; then
            build_image "$image_name" "$dockerfile_path" "$options"
            found=true
            break
        fi
    done < "$DOCKER_IMAGES_FILE"
    
    if [[ "$found" == false ]]; then
        echo "Error: Image '$TARGET_IMAGE' not found in $DOCKER_IMAGES_FILE"
        echo "Available images:"
        list_images
        exit 1
    fi
fi