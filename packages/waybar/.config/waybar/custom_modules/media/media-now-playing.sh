#!/usr/bin/env bash
# 滚动歌名 - 歌手（waybar: custom/media-now-playing, return-type: json）
#
# 设计要点（都是为了把占用压下去）:
#   1. 单个常驻 playerctl --follow：歌名/状态变化靠 D-Bus 推送，主路径 0 轮询、0 fork
#   2. 用 bash 内置 `read -t` 当帧定时器，不 fork sleep
#   3. 文本装得下窗口时"没变不打印"→ 静止状态下 waybar 一次重绘都没有
#   4. trap 收尸：playerctl 忽略 SIGPIPE，脚本被单独杀掉时必须主动带走它，
#      否则每次都留一个 7MB 的孤儿（player.sh 漏 35 个就是这么来的）
#   5. 播放器存在性看门狗：--follow 在播放器消失时既不推空行也不退出（实测
#      playerctl 2.4.1 永远阻塞），text 会卡在上一首、模块不消失。所以每
#      PROBE_TICKS 个超时 tick 主动 metadata 查一次（同格式、含 status）：
#      没人 → 清空隐藏（和 media-time.sh 的 1s 轮询同节奏消失）；有人但
#      follow 没接上 → 直接取来显示（兜住重新出现时 follow 可能不推的场景）。
#      代价是空闲时 1 次 fork/秒，与 media-time.sh 同量级。
#   6. 暂停识别：格式带 {{status}}，播放/暂停切换 playerctl 会推送（实测，
#      不需要额外轮询）；就算漏推，看门狗 1s 查询也会同步。非 Playing →
#      冻结滚动（定格在歌名开头）+ class=paused → CSS 换灰，与
#      media-time.sh 的 class 同步切换，一眼区分暂停。
#   7. 输出 JSON（config: "return-type": "json"）:
#        {"text":"<帧>","class":"playing"|"paused"}  显示
#        {"text":""}                                 无播放器 → 隐藏
#      歌名里的 " 和 \ 转义，控制字符直接剔除，保证 waybar 的 JSON 解析不抛异常。
#
# 固定宽度:
#   每帧都精确输出 COLS 个"显示列"（等宽字体下 1 列 = 1 个 ASCII 字符宽，
#   汉字/全角占 2 列）。末尾不足补空格 → 滚到歌名尾部时模块不再缩水，
#   中英文歌名切换时宽度也一致。
set -u

COLS=${COLS:-16}       # 每帧固定列数（显示宽度，汉字算 2 列）
DELAY=${DELAY:-0.5}    # 帧间隔（秒）——只在真的需要滚动时才生效
GAP=${GAP:-8}          # 首尾衔接的空格数（列）
# 看门狗探测节奏：每 N 个超时 tick 查一次播放器（DELAY=0.5 → 2 tick ≈ 1s，
# 与 media-time.sh 的轮询同频，两个模块差不多同时消失/出现/换色）
PROBE_TICKS=${PROBE_TICKS:-2}
# 播放器优先级（可覆盖，测试时可 PLAYERS=vlc 换播放器）
PLAYERS=${PLAYERS:-musicfox,playerctld}
# --follow 与看门狗查询共用同一格式：状态前缀 + 歌名 - 歌手
FMT='{{status}}|{{title}} - {{artist}}'

# --player musicfox,playerctld: 钉住音乐播放器。不指定时 playerctl 会选"最近活跃"的,
# 浏览器放个视频就会把歌名框抢走(拿到空 title / 显示视频进度), musicfox 不在时回退 playerctld。
coproc SRC { exec playerctl --player "$PLAYERS" --follow metadata --format "$FMT"; }

cleanup() { [ -n "${SRC_PID:-}" ] && kill "$SRC_PID" 2>/dev/null; return 0; }
trap cleanup EXIT
trap 'cleanup; exit 0' INT TERM HUP

# 单字符显示宽度：全角(汉字/全角标点/假名/谚文等)=2，其余=1。
# printf -v 是 shell 内建，不产生 fork。
cw() {
    local cp
    printf -v cp '%d' "'$1"
    if (( (cp >= 0x1100 && cp <= 0x115f) || cp == 0x2329 || cp == 0x232a ||
          (cp >= 0x2e80 && cp <= 0x303e) || (cp >= 0x3041 && cp <= 0x33ff) ||
          (cp >= 0x3400 && cp <= 0x4dbf) || (cp >= 0x4e00 && cp <= 0x9fff) ||
          (cp >= 0xa000 && cp <= 0xa4cf) || (cp >= 0xac00 && cp <= 0xd7a3) ||
          (cp >= 0xf900 && cp <= 0xfaff) || (cp >= 0xfe30 && cp <= 0xfe6f) ||
          (cp >= 0xff00 && cp <= 0xff60) || (cp >= 0xffe0 && cp <= 0xff60) ||
          (cp >= 0x1f300 && cp <= 0x1f9ff) || (cp >= 0x20000 && cp <= 0x3fffd) )); then
        CW=2
    else
        CW=1
    fi
}

# 剔除控制字符（0x00-0x1F）：JSON 字符串里裸控制符是非法的，
# waybar 的 parseOutputJson 会抛异常（crash 风险），按行读也不会有换行混进来。
sanitize() {
    local s=${1:-} out="" i c cp
    for (( i = 0; i < ${#s}; i++ )); do
        c=${s:i:1}
        if printf -v cp '%d' "'$c" 2>/dev/null && (( cp >= 32 )); then
            out+=$c
        fi
    done
    SAN=$out
}

# JSON 字符串转义：先反斜杠后引号（顺序反了会把转义符再次转义）
json_escape() {
    JE=$1
    JE=${JE//\\/\\\\}
    JE=${JE//\"/\\\"}
}

# 输出一行 JSON。$1=文本  $2=class（空 → 不带 class，用于清空隐藏）
emit() {
    json_escape "$1"
    if [ -n "$2" ]; then
        printf '{"text":"%s","class":"%s"}\n' "$JE" "$2"
    else
        printf '{"text":"%s"}\n' "$JE"
    fi
}

fd=${SRC[0]}
raw=""          # 最近一次收到的原始行（status|text），用于去重
status=""       # Playing / Paused / Stopped
text=""
full=""
n=0            # full 的字符数
tot=0          # full 的显示列数
off=0          # 当前帧起始字符下标（环形）
changed=1
probe_tick=0   # 超时 tick 计数，攒够 PROBE_TICKS 就查一次播放器
cls=paused     # 最近一次出帧的 class（跟随 status）

# 文本变化时重建滚动带（full = 歌名 + 衔接空格）并统计总列数
rebuild() {
    full="$text$(printf '%*s' "$GAP" '')"
    n=${#full}
    tot=0
    local i
    for (( i = 0; i < n; i++ )); do
        cw "${full:i:1}"
        tot=$(( tot + CW ))
    done
    off=0
}

# 环形取满 COLS 列的一帧；末尾不够补空格 → 恒定宽度
frame() {
    local i=$off acc=0 iter=0 ch out=""
    while (( acc < COLS && iter < n )); do
        (( i >= n )) && i=0
        ch=${full:i:1}
        cw "$ch"
        # 放不下就留位给空格补齐（避免 CJK 超出 1 列）
        (( acc + CW > COLS )) && break
        out+=$ch
        acc=$(( acc + CW ))
        i=$(( i + 1 ))
        iter=$(( iter + 1 ))
    done
    while (( acc < COLS )); do out+=' '; acc=$(( acc + 1 )); done
    emit "$out" "$cls"
}

# 解析一行 "状态|歌名 - 歌手"（--follow 推送与看门狗查询共用）。
# raw 没变就不动 → changed 保持 0 → 不出帧、零重绘。
set_state() {
    [ "$1" = "$raw" ] && return 0
    raw=$1
    if [ -n "$1" ]; then
        if [ "${1#*|}" != "$1" ]; then   # 有 "状态|" 前缀
            status=${1%%|*}
            text=${1#*|}
        else                             # 防御：格式异常按原样显示
            status="Playing"
            text=$1
        fi
        sanitize "$text"
        text=$SAN
    else
        status=""
        text=""
    fi
    changed=1
    [ -n "${text// }" ] && rebuild        # 空白文本不算有内容，不建滚动带
    return 0
}

while :; do
    if read -r -t "$DELAY" -u "$fd" line; then
        set_state "$line"
    else
        rc=$?
        [ "$rc" -eq 1 ] && exit 0   # EOF：playerctl 退出 → 交给 waybar restart-interval 重启

        # 看门狗：--follow 在播放器消失时不推空行也不退出，只能自己查。
        # 无播放器/无元数据 → 清空；有但与 raw 不同 → 直接刷新
        # （兜住 --follow 漏推/没接上的场景）。与 media-time.sh 同频 ≈1s。
        probe_tick=$(( probe_tick + 1 ))
        if [ "$probe_tick" -ge "$PROBE_TICKS" ]; then
            probe_tick=0
            set_state "$(playerctl --player "$PLAYERS" metadata --format "$FMT" 2>/dev/null)"
        fi
    fi

    if [ "$status" = "Playing" ]; then cls=playing; else cls=paused; fi

    if [ -z "${text// }" ]; then
        # 没有播放器/元数据为空 → 空文本让 waybar 隐藏（注意空白字符也算空）
        if [ "$changed" -eq 1 ]; then emit "" ""; changed=0; fi
        continue
    fi

    if [ "$tot" -le "$COLS" ] || [ "$status" != "Playing" ]; then
        # 装得下 或 非播放中（暂停/停止）：静态显示，只有内容/状态变了才出帧
        # （waybar 零重绘）。暂停时定格在歌名开头、不出新帧即停止滚动，
        # 配合 class=paused 让 CSS 变灰。末尾同样补空格到 COLS 列保证宽度。
        [ "$changed" -eq 1 ] || continue
        off=0
        frame
        changed=0
    else
        # 播放中且装不下：每 0.5s 环形滚动一帧，宽度恒定
        frame
        off=$(( (off + 1) % n ))
    fi
done
