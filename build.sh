#!/bin/sh
# 一条命令编译 hap。按你机器的路径改下面三个变量即可。
set -e
export DEVECO_SDK_HOME="${DEVECO_SDK_HOME:-/home/dsh/dsh-stack/deps/ohos/sdk}"
export JAVA_HOME="${JAVA_HOME:-/home/dsh/dsh-stack/deps/jdk/jdk-17.0.21+9}"
export PATH="$JAVA_HOME/bin:/home/dsh/dsh-stack/node/bin:$PATH"
MODE="${1:-release}"
./hvigorw assembleHap -p product=default -p buildMode="$MODE" --no-daemon
echo
echo "产物：entry/build/default/outputs/default/entry-default-unsigned.hap"
