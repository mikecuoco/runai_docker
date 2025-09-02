#!/usr/bin/env bash
# Author: Mike Cuoco
# Created on: Jul 27, 2025 at 11:41 AM

# Default values
WORKSPACE_NAME="build-remote"
IMAGE="mcuoco/mamba-gvl-micro:latest"

# Function to display usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Start a RunAI workspace with customizable parameters.

OPTIONS:
    -n, --name NAME           Workspace name (default: build-remote)
    -i, --image IMAGE         Docker image to use (default: mcuoco/mamba-gvl-micro:latest)
    -h, --help                Show this help message

EXAMPLES:
    $0                                    # Use all defaults
    $0 -n my-workspace                    # Custom workspace name
    $0 --image mcuoco/mamba-gvl:latest   # Use different image
    $0 --gpu 2                           # Pass GPU option to runai

AVAILABLE IMAGES:
    mcuoco/mamba-gvl:latest              # Full Jupyter ecosystem
    mcuoco/mamba-gvl-micro:latest        # Lightweight micromamba (default)
    mcuoco/parabricks-gvl:latest         # NVIDIA Parabricks + GVL environment

NOTE: Additional runai options can be passed after the script arguments.
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            WORKSPACE_NAME="$2"
            shift 2
            ;;
        -i|--image)
            IMAGE="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            # Pass through any other arguments to runai
            break
            ;;
    esac
done

# Execute the command
runai workspace submit $WORKSPACE_NAME \
    -i $IMAGE \
    --preemptible \
    --nfs server=multilabna.salk.edu,path=/iblm_data3,mountpath=/data3,readwrite $@
    
sleep 10
watch -n 1 "runai workspace describe $WORKSPACE_NAME"