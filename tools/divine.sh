#!/usr/bin/env bash
# Divinity pack CLI (lslib "Divine", built natively on Linux — see docs/lua-modding.md)
# Usage: tools/divine.sh --action=list FILE.pak
#        tools/divine.sh --action=extract --extract-output=DIR FILE.pak
#        tools/divine.sh --action=package --package-version=V3 --package-root=DIR --package-output=OUT.pak
exec dotnet "$(dirname "$(readlink -f "$0")")/divine-cli/Divine.dll" "$@"
