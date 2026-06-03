#!/bin/bash
# LotteryAcct 开发运行脚本
# 用法: ./run.sh [设备ID]
# 示例: ./run.sh          (默认设备)
#        ./run.sh chrome   (Web)

flutter run \
  --dart-define=SUPABASE_URL=https://qdlslssvkjkgikdjfcuk.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFkbHNsc3N2a2prZ2lrZGpmY3VrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA0NTAzMDksImV4cCI6MjA5NjAyNjMwOX0.YayStJn-wEbOdcpFToCPQa10XYNzhDQjwUMCaz3KoFY \
  "$@"
