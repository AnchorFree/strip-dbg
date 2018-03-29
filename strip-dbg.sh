#!/bin/bash
set -e
set -u

BINARY="$1"
BINARY_NAME="$(basename ${BINARY})"

DAEMON_NAME="$2"

function upload_binary {

    http_code=$(curl \
        -H "X-DAEMON: ${DAEMON_NAME}" \
        -u ${SYMBOLS_UPLOAD_USER}:${SYMBOLS_UPLOAD_PASSWORD} \
        -F "file=@$BINARY;filename=$BINARY_NAME" \
        --write-out "%{http_code}" \
        --output /dev/null \
        -- ${SYMBOLS_UPLOAD_URI} 2>/dev/null || true)

    if [ "x$http_code" != "x200" ]; then
        echo "Uploading symbols is failed, HTTP code: $http_code"
        exit 1
    fi
}

# check if a default build-id is present
if ! objdump -s -j .note.gnu.build-id $BINARY | grep -q .note.gnu.build-id; then
    echo "$BINARY doesn't contain .note.gnu.build-id"
    exit 1
fi


if [ ! -z ${AF_BUILD_ID:-} ]; then

    if ! command -v curl >/dev/null 2>&1; then
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update && apt-get install -y curl
        elif command -v yum >/dev/null 2>&1; then
            yum install -y curl
        else
            echo "Unknown OS"
            exit 1
        fi
    fi

    echo ${AF_BUILD_ID} > /af_build_id
    objcopy --add-section .af-build-id=/af_build_id --set-section-flags .mydata=noload,readonly "$BINARY"

    if [ ! -z ${GIT_COMMIT:-} ]; then
        echo ${GIT_COMMIT} > /git_commit
        objcopy --add-section .git-commit=/git_commit --set-section-flags .mydata=noload,readonly "$BINARY"
    fi

    upload_binary
else
    echo "skip uploading to server"
fi

PARAM3=${3:-remove-dbg}

if [ "x$PARAM3" != "xkeep-dbg" ]; then
    strip --strip-unneeded "$BINARY"
fi
