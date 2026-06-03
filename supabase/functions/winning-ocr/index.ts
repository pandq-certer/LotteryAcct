// winning-ocr: Scan winning ticket / result to determine bet outcome
// Uses Claude Vision API to verify match results

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'

const CLAUDE_API_URL = 'https://api.anthropic.com/v1/messages'

interface WinningResult {
  match_name: string
  is_won: boolean
  result_score: string | null
  confidence: number
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
    const { image_url, image_base64, match_name, play_type } = await req.json()

    if (!image_url && !image_base64) {
      return jsonResponse({ error: '请提供 image_url 或 image_base64' }, 400)
    }

    const apiKey = Deno.env.get('CLAUDE_API_KEY')
    if (!apiKey) {
      return jsonResponse({ error: 'OCR 服务未配置' }, 500)
    }

    const imageContent = image_base64
      ? {
          type: 'image',
          source: { type: 'base64', media_type: 'image/jpeg', data: image_base64 },
        }
      : {
          type: 'image',
          source: { type: 'url', url: image_url },
        }

    const contextHint = match_name
      ? `\n\n参考信息：比赛 ${match_name}，玩法 ${play_type || '未知'}`
      : ''

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
        max_tokens: 512,
        messages: [
          {
            role: 'user',
            content: [
              imageContent,
              {
                type: 'text',
                text: `这是一张比赛结果/中奖票据的图片。请判断该投注是否获胜，以 JSON 格式返回：${contextHint}

{
  "match_name": "比赛名称",
  "is_won": true,
  "result_score": "2:1",
  "confidence": 0.9,
  "raw_text": "图片上的原始文字"
}

confidence 为 0-1 的置信度。只返回 JSON。`,
              },
            ],
          },
        ],
      }),
    })

    if (!response.ok) {
      console.error('Claude API error:', await response.text())
      return jsonResponse({ error: '识别失败，请重试' }, 502)
    }

    const data = await response.json()
    const textContent = data.content?.[0]?.text ?? ''

    const jsonMatch = textContent.match(/\{[\s\S]*\}/)
    if (!jsonMatch) {
      return jsonResponse({ error: '无法解析结果信息' }, 422)
    }

    const result: WinningResult = JSON.parse(jsonMatch[0])

    return jsonResponse({ data: result })
  } catch (err) {
    console.error('winning-ocr error:', err)
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
