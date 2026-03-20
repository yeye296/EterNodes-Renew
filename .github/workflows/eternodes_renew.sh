#!/bin/bash
# ===== 个人配置（通过 GitHub Secrets 注入）=====
: "${DISCORD_TOKEN:?请设置 GitHub Secret: DISCORD_TOKEN}"
: "${SESSION_ID:?请设置 GitHub Secret: SESSION_ID}"

# ===== 公共配置 =====
GUILD_ID="1385290648801775798"
CHANNEL_ID="1385925670923931728"
USER_ID="1354113249754222733"
SERVER_VALUE="772"

# ===== 硬编码的指令信息 =====
COMMAND_ID="1408565180815642684"
APPLICATION_ID="1408553460215054438"
VERSION="1469095892438224997"

# ===== 代理配置 =====
if [ -n "$GOST_PROXY" ]; then
  PROXY="-x http://127.0.0.1:8080"
  echo "🛡️ 使用代理模式"
else
  PROXY=""
  echo "🌐 直连模式"
fi

echo "🕐 运行时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "⚡ Eternodes 续期任务"
echo "========================================"

# ===== 生成 nonce =====
NONCE=$(python3 -c "import time; print(str(int((int(time.time()*1000) - 1420070400000) << 22)))")

# ===== 第一步：发送 /server renew =====
echo "🚀 第一步：发送 /server renew ..."
PAYLOAD=$(cat <<EOF
{
  "type": 2,
  "application_id": "${APPLICATION_ID}",
  "guild_id": "${GUILD_ID}",
  "channel_id": "${CHANNEL_ID}",
  "session_id": "${SESSION_ID}",
  "nonce": "${NONCE}",
  "analytics_location": "slash_ui",
  "data": {
    "version": "${VERSION}",
    "id": "${COMMAND_ID}",
    "name": "server",
    "type": 1,
    "options": [{"type": 1, "name": "renew", "options": []}],
    "application_command": {
      "id": "${COMMAND_ID}",
      "type": 1,
      "application_id": "${APPLICATION_ID}",
      "version": "${VERSION}",
      "name": "server",
      "description": "Manage your Pterodactyl servers",
      "dm_permission": true,
      "integration_types": [0]
    },
    "attachments": []
  }
}
EOF
)

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" $PROXY \
  -X POST "https://discord.com/api/v9/interactions" \
  -H "authorization: ${DISCORD_TOKEN}" \
  -H "content-type: application/json" \
  -H "user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36" \
  -H "x-discord-locale: zh-CN" \
  -H "x-discord-timezone: Asia/Shanghai" \
  -H "origin: https://discord.com" \
  -H "referer: https://discord.com/channels/${GUILD_ID}/${CHANNEL_ID}" \
  -d "${PAYLOAD}")

if [ "$HTTP_CODE" != "204" ]; then
  echo "❌ 第一步失败！状态码: ${HTTP_CODE}"
  RESULT="❌ 第一步失败！状态码: ${HTTP_CODE}"
else
  echo "✅ 第一步成功，等待 Bot 回复..."
  sleep 5

  # ===== 第二步：获取 Bot 回复的 message_id 和 custom_id =====
  echo "🔍 获取 Bot 回复消息..."
  MESSAGES=$(curl -s $PROXY \
    "https://discord.com/api/v9/channels/${CHANNEL_ID}/messages?limit=10" \
    -H "authorization: ${DISCORD_TOKEN}" \
    -H "user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36")

  read MESSAGE_ID CUSTOM_ID < <(echo "$MESSAGES" | python3 -c "
import json, sys
msgs = json.load(sys.stdin)
for m in msgs:
    if m.get('application_id') == '${APPLICATION_ID}' and m.get('components'):
        for row in m['components']:
            for comp in row.get('components', []):
                if 'server_renew_select' in comp.get('custom_id', ''):
                    print(m['id'], comp['custom_id'])
                    exit()
print('NOT_FOUND NOT_FOUND')
")

  if [ "$MESSAGE_ID" = "NOT_FOUND" ]; then
    echo "❌ 未找到 Bot 回复消息"
    RESULT="❌ 未找到 Bot 回复消息"
  else
    echo "📌 MESSAGE_ID: $MESSAGE_ID"
    echo "📌 CUSTOM_ID:  $CUSTOM_ID"

    # ===== 第三步：发送选择交互 =====
    NONCE2=$(python3 -c "import time; print(str(int((int(time.time()*1000) - 1420070400000) << 22)))")
    echo "🚀 第二步：选择服务器 ${SERVER_VALUE} ..."

    PAYLOAD2=$(cat <<EOF2
{
  "type": 3,
  "nonce": "${NONCE2}",
  "guild_id": "${GUILD_ID}",
  "channel_id": "${CHANNEL_ID}",
  "message_flags": 0,
  "message_id": "${MESSAGE_ID}",
  "application_id": "${APPLICATION_ID}",
  "session_id": "${SESSION_ID}",
  "data": {
    "component_type": 3,
    "custom_id": "${CUSTOM_ID}",
    "type": 3,
    "values": ["${SERVER_VALUE}"]
  }
}
EOF2
)

    RESPONSE2=$(curl -s -w "\n%{http_code}" $PROXY \
      -X POST "https://discord.com/api/v9/interactions" \
      -H "authorization: ${DISCORD_TOKEN}" \
      -H "content-type: application/json" \
      -H "user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36" \
      -H "x-discord-locale: zh-CN" \
      -H "x-discord-timezone: Asia/Shanghai" \
      -H "origin: https://discord.com" \
      -H "referer: https://discord.com/channels/${GUILD_ID}/${CHANNEL_ID}" \
      -d "${PAYLOAD2}")

    HTTP_CODE2=$(echo "$RESPONSE2" | tail -n1)
    BODY2=$(echo "$RESPONSE2" | head -n-1)

    if [ "$HTTP_CODE2" = "204" ]; then
      echo "✅ 成功！状态码: 204"
      echo "🎉 服务器续期请求已发送！"
      RESULT="✅ 续期成功！"
    else
      echo "❌ 第二步失败！状态码: ${HTTP_CODE2}"
      echo "   响应: ${BODY2}"
      case "$HTTP_CODE2" in
        429) RESULT="❌ 失败！触发频率限制（rate limit）" ;;
        401) RESULT="❌ 失败！Token 失效，需要重新获取" ;;
        403) RESULT="❌ 失败！无权限" ;;
        *)   RESULT="❌ 失败！状态码: ${HTTP_CODE2}" ;;
      esac
    fi
  fi
fi

# ===== TG 通知 =====
if [ -n "$TG_BOT" ]; then
  TG_CHAT_ID=$(echo "$TG_BOT" | cut -d',' -f1)
  TG_TOKEN=$(echo "$TG_BOT" | cut -d',' -f2)
  RUN_TIME=$(date '+%Y-%m-%d %H:%M:%S')"

  MESSAGE="⚡ Eternodes 续期任务
🕐 运行时间: ${RUN_TIME}
📊 续期结果: ${RESULT}"

  curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
    -d chat_id="${TG_CHAT_ID}" \
    -d text="${MESSAGE}" > /dev/null
  echo "📬 TG 通知已发送"
fi

# ===== 最终退出码 =====
if [[ "$RESULT" == ✅* ]]; then
  exit 0
else
  exit 1
fi
