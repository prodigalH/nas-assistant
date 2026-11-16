#!/bin/sh
# 一条命令编译 hap。依赖：OpenHarmony SDK 4.1.7.5、hvigor 4.1.2、JDK 17。
set -e
: "${DEVECO_SDK_HOME:?请先 export DEVECO_SDK_HOME=/path/to/sdk（里面应有 11/ets 等目录）}"
MODE="${1:-release}"
sh ./hvigorw assembleHap -p product=default -p buildMode="$MODE" --no-daemon
echo
echo "产物：entry/build/default/outputs/default/entry-default-unsigned.hap"
