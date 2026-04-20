#!/bin/bash
# 考研倒计时脚本 (适用于2027考研)

# ------------------------------
# 配置区 (请根据实际情况修改)
# ------------------------------

# 2027考研初试预计时间 (以当年教育部公布为准，通常为12月倒数第二个周末)
# 这里以2026年12月19日为基准推测 (实际请关注官方通知)
TARGET_DATE="2026-12-18 08:30"  # 格式：年-月-日 时:分
TARGET_TIMESTAMP=$(date -d "$TARGET_DATE" +%s 2>/dev/null)

# 检查日期是否有效
if [ $? -ne 0 ] || [ -z "$TARGET_TIMESTAMP" ]; then
    echo "错误：目标日期格式无效，请检查脚本中的 TARGET_DATE 变量。"
    echo "示例：TARGET_DATE=\"2027-12-18 08:30\""
    exit 1
fi

# ------------------------------
# 函数：打印彩色输出 (ANSI颜色)
# ------------------------------
color_print() {
    local color_code="$1"
    local text="$2"
    echo -e "\033[${color_code}m${text}\033[0m"
}

# ------------------------------
# 主函数
# ------------------------------
main() {
    clear
    color_print "36" "========================================="
    color_print "33" "       2027 考研倒计时       "
    color_print "36" "========================================="
    echo ""

    # 当前时间戳
    local now_timestamp=$(date +%s)
    local now_date=$(date "+%Y-%m-%d %H:%M:%S")

    # 计算剩余秒数
    local diff_seconds=$((TARGET_TIMESTAMP - now_timestamp))

    # 如果已过目标时间，给出提示
    if [ $diff_seconds -lt 0 ]; then
        color_print "31" "⚠️  目标时间已过，请更新 TARGET_DATE！"
        exit 1
    fi

    # 转换为天、时、分、秒
    local days=$((diff_seconds / 86400))
    local hours=$(( (diff_seconds % 86400) / 3600 ))
    local minutes=$(( (diff_seconds % 3600) / 60 ))
    local seconds=$((diff_seconds % 60))

    # 计算周数（约）
    local weeks=$((days / 7))
    local remaining_days=$((days % 7))

    # ------------------------------
    # 输出详细信息
    # ------------------------------
    color_print "32" "📅 当前时间   ：$now_date"
    color_print "35" "🎯 考研目标   ：$TARGET_DATE"
    color_print "36" "⏳ 剩余时间   ：$days 天 $hours 小时 $minutes 分 $seconds 秒"
    color_print "33" "📆 折合为     ：$weeks 周 $remaining_days 天 (约)"
    echo ""

    # ------------------------------
    # 阶段提示 (按考研常规节奏)
    # ------------------------------
    color_print "34" "🗓️  考研阶段参考 (可根据剩余天数调整)："
    if [ $days -gt 270 ]; then
        echo "   🌱 基础夯实期 (>270天)  ：数学/英语/408 第一轮"
    elif [ $days -gt 180 ]; then
        echo "   📚 强化突破期 (180~270天)：数学强化、专业课二轮、政治启动"
    elif [ $days -gt 90 ]; then
        echo "   ✍️  真题提升期 (90~180天) ：刷真题、总结错题、英语作文"
    elif [ $days -gt 30 ]; then
        echo "   🚀 冲刺模考期 (30~90天)  ：全真模拟、背诵政治大题"
    else
        echo "   🔥 最后冲刺期 (<30天)    ：调整心态、查漏补缺"
    fi

    color_print "32" "==================================================="
}

# 执行主函数
main
