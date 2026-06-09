// ticket-ocr: Scan betting ticket image via Qwen-VL (通义千问)
// Supports multiple tickets in a single image
// Uses Alibaba DashScope API

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'

const DASHSCOPE_URL = 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions'

interface OcrTicket {
  match_name: string | null
  play_type: string
  bet_selection: string
  odds: number | null
  stake: number | null
  category: string
  bet_type: string
  legs: Array<{ match_name: string; odds: number }> | null
  raw_text: string
}

serve(async (req) => {
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

    const apiKey = Deno.env.get('DASHSCOPE_API_KEY')
    if (!apiKey) {
      return jsonResponse({ error: 'OCR 服务未配置' }, 500)
    }

    const imageUrl = image_base64
      ? `data:image/jpeg;base64,${image_base64}`
      : image_url

    const response = await fetch(DASHSCOPE_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: 'qwen-vl-max',
        messages: [
          {
            role: 'user',
            content: [
              { type: 'image_url', image_url: { url: imageUrl } },
              {
                type: 'text',
                text: `这是一张体育投注票据图片。图片中可能包含一张或多张投注票据。请识别图片中的所有票据，为每张票据提取以下信息。

返回 JSON 数组格式（即使只有一张票也用数组）：

[
  {
    "match_name": "比赛名称，如 皇马 vs 巴萨（串关则填 null）",
    "play_type": "玩法：独赢/让球/大小分/波胆/半全场",
    "bet_selection": "投注方向，如：主胜/客胜/平局/大2.5/小2.5/让球主胜/让球客胜/比分2:1等具体投注选择",
    "odds": 1.85,
    "stake": 500,
    "category": "football",
    "bet_type": "single/parlay",
    "legs": null,
    "raw_text": "该票据上的原始文字"
  }
]

如果是串关（parlay），legs 格式为：
[{"match_name": "比赛1", "odds": 1.85}, {"match_name": "比赛2", "odds": 2.10}]

只返回纯 JSON 数组，不要 markdown 代码块或其他文字。无法识别的字段填 null。请仔细区分每张独立的票据。`,
              },
            ],
          },
        ],
      }),
    })

    if (!response.ok) {
      const errorText = await response.text()
      console.error('DashScope API error:', errorText)
      return jsonResponse({ error: 'OCR 识别失败，请重试' }, 502)
    }

    const data = await response.json()
    const textContent = data.choices?.[0]?.message?.content ?? ''

    // Parse JSON array from response
    const jsonMatch = textContent.match(/\[[\s\S]*\]/)
    if (!jsonMatch) {
      return jsonResponse({ error: '无法解析票据信息' }, 422)
    }

    const results: OcrTicket[] = JSON.parse(jsonMatch[0])

    // Validate each result
    for (const r of results) {
      if (r.odds !== null && (r.odds <= 0 || r.odds > 1000)) {
        r.odds = null
      }
      if (!r.play_type) r.play_type = ''
      if (!r.bet_selection) r.bet_selection = ''
      if (!r.category) r.category = 'football'
      if (!r.bet_type) r.bet_type = 'single'
    }

    return jsonResponse({ data: results })
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
