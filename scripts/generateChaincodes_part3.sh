#!/bin/bash
# generateChaincodes_part3.sh
#
# هر 9 قراردادی که این اسکریپت قبلاً می‌ساخت، مکان‌محور است و حالا
# generateChaincodes_spatial.sh نسخه‌ای می‌سازد که واقعاً عملیات شبکه انجام
# می‌دهد: انتخاب سلول سرویس‌دهنده، محاسبه SINR، کنترل پذیرش و حسابداری بار.
#
# این فایل به همان اسکریپت واگذار می‌کند تا حلقه README —
#   for f in generateChaincodes_part*.sh; do ./"$f"; done
# — همچنان کار کند و مهم نباشد چه چیزی زودتر اجرا شده است. نسخه قدیمی
# قراردادها دیگر تولید نمی‌شود؛ اگر مستقیم اجرایش کنید نسخه جدید را
# بازنویسی می‌کرد.
#
# نسخه قدیمی در تاریخچه گیت باقی است.

set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPATIAL="$DIR/generateChaincodes_spatial.sh"

if [ ! -f "$SPATIAL" ]; then
    echo "generateChaincodes_spatial.sh کنار این فایل نیست." >&2
    echo "بدون آن، این 9 قرارداد ساخته نمی‌شوند." >&2
    exit 1
fi

echo "part3 → واگذاری به generateChaincodes_spatial.sh (9 قرارداد مکانی)"

exec bash "$SPATIAL" \
    LocationBasedCongestion \
    LocationBasedDynamicRouting \
    LocationBasedAntennaConfig \
    LocationBasedSignalQuality \
    LocationBasedNetworkHealth \
    LocationBasedPowerManagement \
    LocationBasedChannelAllocation \
    LocationBasedSessionManagement \
    LocationBasedIoTConnection
