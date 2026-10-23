#!/usr/bin/env bash
# Extracts every translatable string (i18n/i18nc/xi18nc... calls in QML and C++)
# into po/plasma_applet_org.cesar.plasmacontrolcenter.pot and merges the result
# into every existing po/<lang>/ catalog.
set -euo pipefail
cd "$(dirname "$0")/.."

DOMAIN=plasma_applet_org.cesar.plasmacontrolcenter
POT=po/$DOMAIN.pot

xgettext --from-code=UTF-8 -C -kde -ci18n \
    -ki18n:1 -ki18nc:1c,2 -ki18np:1,2 -ki18ncp:1c,2,3 \
    -kki18n:1 -kki18nc:1c,2 -kki18np:1,2 -kki18ncp:1c,2,3 \
    -kxi18n:1 -kxi18nc:1c,2 -kxi18np:1,2 -kxi18ncp:1c,2,3 \
    -kI18N_NOOP:1 -kI18NC_NOOP:1c,2 \
    --package-name="plasma-control-center" --msgid-bugs-address="https://github.com/cesarconte/plasma-control-center/issues" \
    --add-location=file \
    $(find src -name '*.qml' -o -name '*.cpp' | sort) -o "$POT"

for po in po/*/$DOMAIN.po; do
    [ -f "$po" ] && msgmerge --update --backup=none --quiet "$po" "$POT"
done
echo "Messages extracted to $POT"
