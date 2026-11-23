#!/usr/bin/env bash
# Runs inside android-emulator-runner once the emulator is up: checks that
# blocked hosts are unreachable, applies the persona's phone settings,
# installs the app and hands the emulator to Claude Code. The agent's output
# goes to results/ (encrypted later), never to the public log.
set -uo pipefail
adb wait-for-device
mkdir -p "results/$PERSONA"
# 1. Blocked hosts must not resolve to a real IP from inside the emulator
for h in $BLOCK_HOSTS; do
  ip=$(adb shell ping -c 1 -W 2 "$h" 2>&1 | head -1 | grep -oE '\(([0-9]{1,3}\.){3}[0-9]{1,3}\)' | tr -d '()')
  case "$ip" in ""|0.0.0.0|127.*) ;; *) echo "$h reachable from the emulator ($ip): aborting"; exit 1 ;; esac
done
# 2. Phone language (the emulator boots in en-US; google_apis images allow adb root)
if [ "$(adb shell getprop persist.sys.locale | tr -d '\r')" != "$LOCALE" ]; then
  adb root >/dev/null 2>&1; sleep 3; adb wait-for-device
  adb shell "setprop persist.sys.locale $LOCALE; setprop ctl.restart zygote"; sleep 10; adb wait-for-device
  for i in $(seq 1 60); do [ "$(adb shell getprop sys.boot_completed | tr -d '\r')" = 1 ] && break; sleep 3; done
fi
# 3. App + persona settings. The package inside the APK wins over app_id
# (which may be the iOS bundle id)
if [ -n "${WEB_URL:-}" ]; then
  # A website (web_url input): no app. The phone's own browser opens it, marked as a test
  # visit (?qa=phone-<persona>) so the site keeps it out of its visitor figures.
  case "$WEB_URL" in *\?*) URL="$WEB_URL&qa=phone-$PERSONA" ;; *) URL="$WEB_URL?qa=phone-$PERSONA" ;; esac
  if adb shell pm list packages com.android.chrome | tr -d '\r' | grep -qx 'package:com.android.chrome'; then
    APP_ID=com.android.chrome
    # Chrome without its first-run screens (it reads this file when it is the debug app)
    adb shell 'echo "_ --disable-fre --no-default-browser-check --no-first-run" > /data/local/tmp/chrome-command-line'
    adb shell am set-debug-app --persistent com.android.chrome >/dev/null 2>&1
  else
    APP_ID=""   # no Chrome on this image: the phone's default browser
    echo "Chrome is not on this emulator image: the default browser opens the site"
  fi
  export APP_ID
  adb shell settings put system font_scale "${FONT_SCALE:-1.0}"   # Chrome scales page text with it
  [ "${THEME:-light}" = dark ] && adb shell cmd uimode night yes
  adb emu geo fix "${GEO#*,}" "${GEO%,*}" >/dev/null 2>&1   # longitude first
  adb shell "am start -a android.intent.action.VIEW -d '$URL' ${APP_ID:+-p $APP_ID}" >/dev/null 2>&1
  adb logcat -c; sleep 10
else
AAPT2=$(ls "${ANDROID_HOME:-/usr/local/lib/android/sdk}"/build-tools/*/aapt2 2>/dev/null | sort -V | tail -1)
PKG=$([ -n "$AAPT2" ] && "$AAPT2" dump packagename app.apk 2>/dev/null | tr -d '\r')
if [ -n "$PKG" ] && [ "$PKG" != "$APP_ID" ]; then echo "Package read from the APK (differs from app_id)"; APP_ID=$PKG; fi
export APP_ID
adb install -r -g app.apk || adb install -r app.apk
adb shell settings put system font_scale "${FONT_SCALE:-1.0}"
[ "${THEME:-light}" = dark ] && adb shell cmd uimode night yes
adb emu geo fix "${GEO#*,}" "${GEO%,*}" >/dev/null 2>&1   # longitude first
adb shell monkey -p "$APP_ID" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
adb logcat -c; sleep 5
fi
# 4. Optional screen recording, kept in results/ (encrypted like the rest)
REC=""
if [ "${RECORD_VIDEO:-false}" = true ]; then
  adb shell settings put system show_touches 1
  SZ=$(adb shell wm size | grep -oE '[0-9]+x[0-9]+' | tail -1); W=${SZ%x*}; H=${SZ#*x}
  RW=$((W * 2 / 3 / 16 * 16)); RH=$((H * RW / W / 16 * 16))   # 2/3 size, multiples of 16 for the encoder
  rm -f /tmp/stop-rec
  # screenrecord stops at 180 s: chain files until the agent is done
  ( i=0; opt="--size ${RW}x${RH}"
    while [ ! -f /tmp/stop-rec ] && [ $i -lt 40 ]; do
      i=$((i + 1)); t0=$(date +%s)
      adb shell screenrecord $opt --bit-rate 4000000 --time-limit 180 "/sdcard/rec_$(printf %02d $i).mp4"
      [ $(($(date +%s) - t0)) -lt 3 ] && opt=""   # size refused: native size
    done ) &
  REC=$!
fi
# 5. The agent: only the listed tools, nothing else (another model API if llm_base_url is set)
source scripts/llm_env.sh || exit 1
claude -p "Read $BRIEF and personas.json, then do the mission until the final report. PERSONA=$PERSONA PLATFORM=android APP_ID=$APP_ID. Device: ${DEVICE}, font scale x${FONT_SCALE:-1.0}, theme ${THEME:-light}, language $LOCALE. Report anything that does not fit this screen (cut text, off-screen buttons, broken layout).${URL:+ The site under test: $URL (its browser is open on it).}" \
  --model "${MODEL:-sonnet}" --max-turns 400 --output-format json \
  --allowedTools "Bash(adb:*),Bash(python3 scripts/android/screen.py:*),Bash(python3 scripts/android/type.py:*),Bash(sleep:*),Bash(ls:*),Bash(cat:*),Bash(mkdir:*),Read,Write,Edit" \
  > results/agent-output.json 2> results/agent-errors.txt
CODE=$?
python3 scripts/agent_status.py results/agent-output.json results/agent-errors.txt "$PERSONA" || true
if [ -n "$REC" ]; then
  touch /tmp/stop-rec; adb shell pkill -INT screenrecord; sleep 4; kill "$REC" 2>/dev/null
  mkdir -p "results/$PERSONA/video"
  for f in $(adb shell ls /sdcard/ | tr -d '\r' | grep '^rec_'); do adb pull "/sdcard/$f" "results/$PERSONA/video/" >/dev/null 2>&1; done
fi
echo "Agent finished (exit $CODE), $(ls "results/$PERSONA" | wc -l) files"
