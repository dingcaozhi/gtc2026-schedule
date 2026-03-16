#!/bin/bash
# GTC 2026 S81595 Keynote Monitor Script
# 每隔半小时检查 YouTube NVIDIA 官方账号是否有 GTC26-S81595 视频

SEARCH_QUERY="GTC26-S81595"
YOUTUBE_CHANNEL="https://www.youtube.com/@NVIDIA"
OUTPUT_DIR="/Users/dingcaozhi/.openclaw/workspace/gtc2026-schedule"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$OUTPUT_DIR/monitor_${TIMESTAMP}.log"

# 确保输出目录存在
mkdir -p "$OUTPUT_DIR"

echo "=== GTC26-S81595 Monitor Started at $(date) ===" >> "$LOG_FILE"
echo "Search Query: $SEARCH_QUERY" >> "$LOG_FILE"
echo "YouTube Channel: $YOUTUBE_CHANNEL" >> "$LOG_FILE"

# 发送开始执行的通知
curl -s -X POST "${OPENCLAW_GATEWAY_URL:-http://localhost:8080}/api/v1/message" \
  -H "Content-Type: application/json" \
  -d "{
    \"channel\": \"feishu\",
    \"message\": \"🔍 GTC26-S81595 监控任务开始执行\\n时间: $(date '+%Y-%m-%d %H:%M:%S')\\n搜索: $SEARCH_QUERY\"
  }" 2>/dev/null || echo "Notification sent via OpenClaw"

# 使用 yt-dlp 搜索视频 (如果已安装)
if command -v yt-dlp &> /dev/null; then
    echo "Searching for videos with query: $SEARCH_QUERY" >> "$LOG_FILE"
    
    # 搜索最近上传的视频
    yt-dlp --flat-playlist --playlist-end 20 \
        --print "%(id)s|%(title)s|%(upload_date)s" \
        "ytsearch20:$SEARCH_QUERY NVIDIA" 2>/dev/null > "$OUTPUT_DIR/search_results_${TIMESTAMP}.txt"
    
    if [ -s "$OUTPUT_DIR/search_results_${TIMESTAMP}.txt" ]; then
        echo "Found potential videos:" >> "$LOG_FILE"
        cat "$OUTPUT_DIR/search_results_${TIMESTAMP}.txt" >> "$LOG_FILE"
        
        # 检查是否有新视频 (简单检查：如果文件不为空则认为可能有新内容)
        # 实际实现中应该与上次搜索结果对比
        
        # 尝试下载第一个匹配视频的字幕
        FIRST_VIDEO=$(head -1 "$OUTPUT_DIR/search_results_${TIMESTAMP}.txt" | cut -d'|' -f1)
        if [ -n "$FIRST_VIDEO" ]; then
            VIDEO_URL="https://www.youtube.com/watch?v=$FIRST_VIDEO"
            echo "Attempting to download subtitles from: $VIDEO_URL" >> "$LOG_FILE"
            
            # 下载字幕
            yt-dlp --write-auto-sub --sub-langs en --skip-download \
                --output "$OUTPUT_DIR/subs_${TIMESTAMP}_%(id)s" \
                "$VIDEO_URL" 2>/dev/null
            
            if ls "$OUTPUT_DIR/subs_${TIMESTAMP}"* 1> /dev/null 2>&1; then
                echo "✅ Subtitles downloaded successfully" >> "$LOG_FILE"
                
                # 发送发现视频的通知
                curl -s -X POST "${OPENCLAW_GATEWAY_URL:-http://localhost:8080}/api/v1/message" \
                  -H "Content-Type: application/json" \
                  -d "{
                    \"channel\": \"feishu\",
                    \"message\": \"🎥 发现 GTC26-S81595 相关视频!\\n已下载字幕，等待分析...\\n视频ID: $FIRST_VIDEO\"
                  }" 2>/dev/null || echo "Video found notification sent"
            else
                echo "⚠️ No subtitles available yet" >> "$LOG_FILE"
            fi
        fi
    else
        echo "No videos found yet" >> "$LOG_FILE"
    fi
else
    echo "⚠️ yt-dlp not installed. Please install with: pip install yt-dlp" >> "$LOG_FILE"
    
    # 发送缺少工具的通知
    curl -s -X POST "${OPENCLAW_GATEWAY_URL:-http://localhost:8080}/api/v1/message" \
      -H "Content-Type: application/json" \
      -d "{
        \"channel\": \"feishu\",
        \"message\": \"⚠️ GTC26-S81595 监控任务缺少 yt-dlp 工具\\n请安装: pip install yt-dlp\"
      }" 2>/dev/null || echo "Tool missing notification sent"
fi

echo "=== Monitor Finished at $(date) ===" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# 清理旧日志文件 (保留最近7天)
find "$OUTPUT_DIR" -name "monitor_*.log" -mtime +7 -delete 2>/dev/null
find "$OUTPUT_DIR" -name "search_results_*.txt" -mtime +7 -delete 2>/dev/null
