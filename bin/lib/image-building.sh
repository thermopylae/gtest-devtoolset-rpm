# Source this file to get the functions defined below.

SELF_PATH="${BASH_SOURCE}"
SELF_DIR=$(dirname "$SELF_PATH")

TST_DOCKER_REPOSITORY_DIR=$(cd "$SELF_DIR/../.." && pwd)
TST_DOCKERFILE_DIR="$TST_DOCKER_REPOSITORY_DIR/build"

source "$SELF_DIR/ui.sh"


TST_DOCKERFILE_NO_CONTEXT_MARKER='# --\[ TST-Dockerfile: no-context \]--'
TST_DOCKERFILE_CONTEXT_DIR_MARKER='^# --\[ TST-Dockerfile: context-dir=\K.*(?= \]--$)'
TST_DOCKERFILE_REQUIRED_VARS_MARKER='^# --\[ TST-Dockerfile: required-vars=\K.*(?= \]--$)'
TST_DOCKERFILE_REQUIRED_PASSWORD_VARS_MARKER='^# --\[ TST-Dockerfile: required-password-vars=\K.*(?= \]--$)'



tst_docker_build_dockerfile_template()
{
    local DOCKERFILE_TEMPLATE_PATH="$1"
    local IMAGE_TAG="$2"
    # Variable to store the output image ID in:
    local IMAGE_ID_VAR_NAME="$3"
    
    local DOCKERFILE_PATH=$(mktemp "$TST_DOCKERFILE_DIR/Dockerfile.tmp.XXXXX")
    local DOCKER_CONTEXT_ARGUMENT
    local DOCKER_TAG_ARGUMENT
    local DOCKER_WORKING_DIR
    local REQUIRED_VARS
    local VAR
    local ln
    local LAST_LINE

    if [ -n "$IMAGE_TAG" ]; then
        printf -v DOCKER_TAG_ARGUMENT "%q" "$IMAGE_TAG"
        DOCKER_TAG_ARGUMENT="-t $DOCKER_TAG_ARGUMENT"
    fi

    if grep -q -x -e "$TST_DOCKERFILE_NO_CONTEXT_MARKER" "$DOCKERFILE_TEMPLATE_PATH"; then
        DOCKER_CONTEXT_ARGUMENT="-"
    else
        printf -v DOCKER_CONTEXT_ARGUMENT "%q" "$DOCKERFILE_PATH"
        DOCKER_CONTEXT_ARGUMENT="-f $DOCKER_CONTEXT_ARGUMENT ."
    fi

    DOCKER_WORKING_DIR=$(grep -Po -e "$TST_DOCKERFILE_CONTEXT_DIR_MARKER" "$DOCKERFILE_TEMPLATE_PATH")
    if [ -n "$DOCKER_WORKING_DIR" -a "$DOCKER_CONTEXT_ARGUMENT" == "-" ]; then
        tst_docker_warn "Dockerfile species both no context, and context directory: $DOCKERFILE_TEMPLATE_PATH"
    fi
    if [ -z "$DOCKER_WORKING_DIR" ];then
        DOCKER_WORKING_DIR="$TST_DOCKER_REPOSITORY_DIR"
    elif [ "${DOCKER_WORKING_DIR#/}" == "$DOCKER_WORKING_DIR" ]; then
        # Context directories are relative to the repository directory:
        DOCKER_WORKING_DIR="$TST_DOCKER_REPOSITORY_DIR/$DOCKER_WORKING_DIR"
    fi

    REQUIRED_VARS=$(grep -Po -e "$TST_DOCKERFILE_REQUIRED_VARS_MARKER" "$DOCKERFILE_TEMPLATE_PATH")
    for VAR in $REQUIRED_VARS; do
        if [ -z "${!VAR}" ]; then
            if [ -n "$TST_DOCKER_QUIET" ]; then
                tst_docker_err "Required varible $VAR does not have a value while processing $DOCKERFILE_TEMPLATE_PATH"
                exit 1
            else
                tst_docker_read_variable "$VAR" "$VAR"
            fi
        fi
    done

    REQUIRED_VARS=$(grep -Po -e "$TST_DOCKERFILE_REQUIRED_PASSWORD_VARS_MARKER" "$DOCKERFILE_TEMPLATE_PATH")
    for VAR in $REQUIRED_VARS; do
        if [ -z "${!VAR}" ]; then
            if [ -n "$TST_DOCKER_QUIET" ]; then
                tst_docker_err "Required password varible $VAR does not have a value while processing $DOCKERFILE_TEMPLATE_PATH"
                exit 1
            else
                tst_docker_read_variable "$VAR" "$VAR" password
            fi
        fi
    done

    printf -v REDHAT_USERNAME_ESCAPED "%q" "$REDHAT_USERNAME"
    export REDHAT_USERNAME_ESCAPED
    printf -v REDHAT_PASSWORD_ESCAPED "%q" "$REDHAT_PASSWORD"
    export REDHAT_PASSWORD_ESCAPED
    envsubst < "$DOCKERFILE_TEMPLATE_PATH" > "$DOCKERFILE_PATH"

    while read ln; do
        echo "$ln"
        if [ -n "$ln" ]; then
            LAST_LINE="$ln"
        fi
    done < <(
        cd "$DOCKER_WORKING_DIR" || return 1
        docker build --no-cache=true --rm=true \
            $DOCKER_TAG_ARGUMENT \
            $DOCKER_CONTEXT_ARGUMENT \
            <"$DOCKERFILE_PATH"
    )

    rm "$DOCKERFILE_PATH"

    if [ "${LAST_LINE#Successfully built }" == "$LAST_LINE" ]; then
        return 1
    else
        if [ -n "$IMAGE_ID_VAR_NAME" ]; then
            declare -g "$IMAGE_ID_VAR_NAME=${LAST_LINE#Successfully built }"
        fi
    fi
}
