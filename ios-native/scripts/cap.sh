#!/bin/sh
# 화면 캡처: cap.sh <시뮬레이터 UDID> <화면> <시간> <저장 파일> [번들 ID]
# 화면: welcome room read done bible keep calendar settings group / 시간: morning noon rest night
# 디버그 빌드에서만 동작합니다. 듀오 '닫힘'은 simctl이 안쪽 화면(검은 화면)을 찍으므로 Xcode 시뮬레이터에서 직접 저장하세요.
B=${5:-com.chanhoyoo.sarak}
SIMCTL_CHILD_SARAK_SCREEN=$2 SIMCTL_CHILD_SARAK_HOUR=$3 SIMCTL_CHILD_SARAK_DAY=6 xcrun simctl launch --terminate-running-process "$1" "$B" || exit 1
sleep "${WAIT:-12}"
xcrun simctl io "$1" screenshot "$4"
