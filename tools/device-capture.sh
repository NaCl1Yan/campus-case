#!/system/bin/sh
# 设备端连续抓帧：snapshot_display 逐帧写 /data/local/tmp/frames
# 用法：sh /data/local/tmp/cap.sh <max_frames> <sleep_seconds>
rm -rf /data/local/tmp/frames
mkdir -p /data/local/tmp/frames
i=1
max=${1:-400}
gap=${2:-0.12}
while [ "$i" -le "$max" ]; do
  n=$i
  if [ "$n" -lt 10 ]; then n="00$n"; elif [ "$n" -lt 100 ]; then n="0$n"; fi
  snapshot_display -f "/data/local/tmp/frames/f$n.jpeg" >/dev/null 2>&1
  sleep "$gap"
  i=$((i+1))
done
echo "done $((i-1)) frames"
