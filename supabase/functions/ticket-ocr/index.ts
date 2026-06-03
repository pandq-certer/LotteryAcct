// ticket-ocr: Scan betting ticket image and extract bet details
// Uses Claude Vision API to parse ticket information

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'

const CLAUDE_API_URL = 'https://api.anthropic.com/v1/messages'

interface OcrResult {
  match_name: string | null
  play_type: string
  odds: number | null
  stake: number | null
  category: string
  bet_type: string
  legs: Array<{
    match_name: string
    odds: number
  }> | null
  raw_text: string
}

serve(async (req) => {
  // CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    })
  }

  try {
    const { image_url, image_base64 } = await req.json()

    if (!image_url && !image_base64) {
      return jsonResponse({ error: '请提供 image_url 或 image_base64' }, 400)
    }

    const apiKey = Deno.env.get('CLAUDE_API_KEY')
    if (!apiKey) {
      return jsonResponse({ error: 'OCR 服务未配置' }, 500)
    }

    // Build image content block
    const imageContent = image_base64
      ? {
          type: 'image',
          source: {
            type: 'base64',
            media_type: 'image/jpeg',
            data: image_base64,
          },
        }
      : {
          type: 'image',
          source: {
            type: 'url',
            url: image_url,
          },
        }

    const response = await fetch(CLAUDE_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'anthropic-dangerous-direct-browser-access': 'true',
      },
      body: JSON.stringify({
        model: 'claude-sonnet-4-6',
        max_tokens: 1024,
        messages: [
          {
            role: 'user',
            content: [
              imageContent,
              {
                type: 'text',
                text: `这是一张体育投注票据图片。请提取以下信息并以 JSON 格式返回：

{
  "match_name": "比赛名称，如 皇马 vs 巴萨（串关则填 null）",
  "play_type": "玩法：独赢/让球/大小分/波胆/半全场",
  "odds": 1.85,
  "stake": 500,
  "category": "football/basketball/tennis/other",
  "bet_type": "single/parlay",
  "legs": null,
  "raw_text": "票据上的原始文字"
}

如果是串关（parlay），legs 格式为：
[{"match_name": "比赛1", "odds": 1.85}, {"match_name": "比赛2", "odds": 2.10}]

只返回 JSON，不要其他文字。无法识别的字段填 null。`,
              },
            ],
          },
        ],
      }),
    })

    if (!response.ok) {
      const errorText = await response.text()
      console.error('Claude API error:', errorText)
      return jsonResponse({ error: 'OCR 识别失败，请重试' }, 502)
    }

    const data = await response.json()
    const textContent = data.content?.[0]?.text ?? ''

    // Parse JSON from Claude response
    const jsonMatch = textContent.match(/\{[\s\S]*\}/)
    if (!jsonMatch) {
      return jsonResponse({ error: '无法解析票据信息' }, 422)
    }

    const result: OcrResult = JSON.parse(jsonMatch[0])

    // Validate odds
    if (result.odds !== null && (result.odds <= 0 || result.odds > 1000)) {
      result.odds = null
    }

    return jsonResponse({ data: result })
  } catch (err) {
    console.error('ticket-ocr error:', err)
    return jsonResponse({ error: '服务器错误' }, 500)
  }
})

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    },
  })
}
