#! /bin/bash

source "$(dirname "$0")/lib/image-building.sh"

SELF_NAME=$(basename "$0")
SELF_DIR=$(dirname "$0")

GTEST_VERSION=1.8.0
DEVTOOLSET_VERSION=2
USE_DOCKER=yes
if [ -f /etc/system-release ] && grep -q "Red Hat Enterprise Linux" /etc/os-release
then
    INHERIT_HOST_SUBSCRIPTION="yes"
else
    INHERIT_HOST_SUBSCRIPTION=""
fi

show_help()
{
    cat <<HELP
$SELF_NAME [-g <version>] [-t <version>] [-d <boolean>] [-s <boolean>] [-h]

    -g|--gtest-version <version>
        GoogleTest version to download and package.  E.g., to package gtest
        1.8.0 use \`--gtest-version=1.8.0\`.
    -t|--devtoolset-version <version>
        The devtoolset version the RPM is targetting.  E.g., to build for
        devtoolset-2 use \`--devtoolset-version=2\`.
    -d|--use-docker <boolean>
        Whether to use Docker for building the RPM.  E.g., set
        \`--use-docker=yes\` if you want to build an RPM for a distribution
        different from the one you're running on.
    -s|--inherit-host-subscription <boolean>
        Whether to inherit the Yum repository subscription of the host OS.
        This only works if you're running RHEL as the host OS.  If you're not
        inheriting a subscription, you'll need a Red Hat username and password
        for a registered user that has a Rad Hat repository subscription.
    -h|--help
        Display this help message and exit.
HELP
}

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -g|--gtest-version)
            GTEST_VERSION="$2"
            shift
            ;;
        --gtest-version=*)
            GTEST_VERSION="${1#*=}"
            ;;
        -t|--devtoolset-version)
            DEVTOOLSET_VERSION="$2"
            shift
            ;;
        --devtoolset-version=*)
            DEVTOOLSET_VERSION="${1#*=}"
            ;;
        -d|--use-docker)
            if is_string_value_false "$2"; then
                USE_DOCKER=""
            else
                USE_DOCKER="yes"
            fi
            shift
            ;;
        --use-docker=*)
            if is_string_value_false "${1#*=}"; then
                USE_DOCKER=""
            else
                USE_DOCKER="yes"
            fi
            ;;
        -s|--inherit-host-subscription)
            if is_string_value_false "$2"; then
                INHERIT_HOST_SUBSCRIPTION=""
            else
                INHERIT_HOST_SUBSCRIPTION="yes"
            fi
            shift
            ;;
        --inherit-host-subscription=*)
            if is_string_value_false "${1#*=}"; then
                INHERIT_HOST_SUBSCRIPTION=""
            else
                INHERIT_HOST_SUBSCRIPTION="yes"
            fi
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unrecognized command-line argument: $1" >&2
            exit 1
            ;;
    esac
    shift
done

# Download the googletest source:
(
    cd "$SELF_DIR/../build/SOURCES"
    wget -c https://github.com/google/googletest/archive/release-${GTEST_VERSION}.tar.gz || exit 1
)

# Expand spec template for the build we're doing:
SPEC_NAME="gtest-devtoolset${DEVTOOLSET_VERSION}-${GTEST_VERSION}.spec"

export GTEST_VERSION
export DEVTOOLSET_VERSION
envsubst '$GTEST_VERSION,$DEVTOOLSET_VERSION' \
         < "$SELF_DIR/../rpm-template/gtest.spec.template" \
         > "$SELF_DIR/../build/SPECS/$SPEC_NAME"

# Build the RPM:
if [ -z "$USE_DOCKER" ]; then
    (
        cd "$SELF_DIR/../build" && \
        source /opt/rh/devtoolset-2/enable && \
        rpmbuild -v -bb --clean SPECS/gtest-devtoolset${DEVTOOLSET_VERSION}-${GTEST_VERSION}.spec
    )
else
    if [ -z "$INHERIT_HOST_SUBSCRIPTION" ]; then
        DOCKER_TEMPLATE_NAME="Dockerfile.rhel-6.template"
    else
        DOCKER_TEMPLATE_NAME="Dockerfile.rhel-6-inherit-host-subscription.template"
    fi
    IMAGE_ID=""
    tst_docker_build_dockerfile_template \
        "$SELF_DIR/../docker/$DOCKER_TEMPLATE_NAME" \
        "" \
        IMAGE_ID || exit 1

    CONTAINER_ID=$(docker create "$IMAGE_ID") || exit 1    
    docker cp "$CONTAINER_ID:/root/rpmbuild/RPMS" "$SELF_DIR/../build/" || exit 1
    docker rm -v "$CONTAINER_ID" || exit 1
    docker rmi -f "$IMAGE_ID"
fi
