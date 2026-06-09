# LotteryAcct 项目规范

## 项目概述
**彩票记账** — 双人共享的体育投注记录 App。两人共同投注，成本收益平分，所有操作需对方审批。

## 技术栈
| 层 | 技术 |
|---|------|
| 前端 | Flutter 3.44 + Dart 3.12 |
| 状态管理 | Flutter Riverpod |
| 后端 | Supabase (Auth + PostgreSQL + Edge Functions + Realtime + Storage) |
| OCR | 阿里云百炼 Qwen-VL-Plus (`qwen-vl-max`) via DashScope API |
| 图表 | fl_chart |
| 导航 | 底部 NavigationBar (6 tabs) |

## 架构

```
lib/
  main.dart                    # 入口，初始化 Supabase + 中文本地化
  app.dart                     # MaterialApp + 深色主题 + AuthWrapper + 6-Tab 导航
  features/
    auth/                      # 登录/注册页（邮箱密码，Supabase Auth）
    dashboard/                 # 首页：P&L 卡片、7日趋势图、最近投注
      widgets/                 # pnl_card, trend_chart, recent_records
    betting/                   # 添加投注：单关/串关表单、拍照/相册 OCR
    approvals/                 # 审批：待审批列表、同意/拒绝、历史记录
    history/                   # 历史记录：筛选、详情、结算（走审批流）
    analytics/                 # 数据分析：饼图、柱状图、策略热力图
    settings/                  # 设置：个人信息、CSV 导出、退出登录
  shared/
    models/                    # BettingRecord, BetLeg, UserProfile
    providers/                 # betting_provider, approval_provider, auth_provider, error_handler
    services/                  # ocr_service (Qwen-VL via DashScope)
    widgets/                   # loading_indicator, error_banner
```

## 数据库（Supabase PostgreSQL）

### 表
| 表 | 说明 |
|----|------|
| `profiles` | 用户资料，注册自动创建 |
| `betting_records` | 投注记录，含 generated column `potential_return` |
| `bet_legs` | 串关子场次 |
| `approval_requests` | 审批请求（create/settle/delete） |

### 枚举
- `bet_status`: awaiting_approval → pending → won/lost/partial/voided
- `bet_type`: single / parlay
- `bet_category`: football / basketball / tennis / other
- `approval_op`: create / settle / delete
- `approval_status`: pending / approved / rejected

### 视图
- `combined_pnl_summary` — 所有人的合并盈亏汇总（排除 awaiting_approval）
- `user_pnl_summary` — 按用户分组（排除 awaiting_approval）
- `daily_pnl_trend` — 每日盈亏趋势（仅 won/lost）

### RLS 策略
- `betting_records` / `bet_legs`: 所有已登录用户可 CRUD
- `approval_requests`: 所有人可查看/创建，只有非发起人可审批，发起人可取消

### Realtime
- `approval_requests` 表开启了 Supabase Realtime，App 端通过 StreamProvider 监听

### 迁移
```
001_initial_schema.sql        # 建表、视图、RLS
002_fix_daily_pnl_view.sql    # 修复日趋势视图 null 处理
003_shared_data.sql           # 改 RLS 为共享数据模式
004_approval_workflow.sql     # 审批表、枚举、Realtime
005_views_exclude_awaiting.sql # 视图排除 awaiting_approval 状态
```

## 核心业务流程

### 审批流（所有操作需对方同意）
1. A 发起操作（添加投注/结算/删除）→ 记录创建为 `awaiting_approval` + 创建 `approval_requests`
2. B 的 App 通过 Realtime 收到通知，在审批 Tab 看到
3. B 同意 → 执行操作（状态变为 pending / 执行结算 / 执行删除）
4. B 拒绝 → 如果是创建则删除 awaiting_approval 记录
5. P&L 视图只统计非 awaiting_approval 的记录

### OCR 识别
- 图片来源：相机拍照 或 相册选择（底部弹窗选择）
- Edge Function: `supabase/functions/ticket-ocr/index.ts` 调用 DashScope API
- 模型: `qwen-vl-max`，通过 `https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions`
- 环境变量: `DASHSCOPE_API_KEY`（Supabase Secret）
- 串关识别：OCR 返回多 legs 时，替换空的默认 legs，保留手动填写的

## 开发约定

### 不要主动做的事
- **不要主动构建 APK。** 只在用户明确要求时才执行 `flutter build apk`
- **不要主动 push 代码到远程仓库**
- **不要主动生成 release 包**

### 构建和运行
```bash
./run.sh                        # Chrome
./run.sh -d <设备ID>            # 指定设备
flutter build apk --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...  # 构建APK
```

### Supabase CLI
```bash
supabase db push --linked                                    # 推送迁移
supabase migration repair <N> --status reverted --linked     # 修复失败迁移
```

### 已知注意事项
- PostgreSQL 新增 enum 值后不能在同一事务的视图中引用，需拆成两个迁移
- `bet_status` 枚举在 Dart 端用 `awaitingApproval`，数据库用 `awaiting_approval`，通过 `_statusFromDb`/`_statusToDb` 映射
- `initializeDateFormatting('zh_CN')` 必须在 main() 中 runApp 前调用，否则 DateFormat 中文格式会崩溃
- fl_chart 单数据点时 maxY==minY 导致 horizontalInterval=0，需要 clamp
- Supabase 视图默认不开启 RLS，REST API 可直接查询
- 用户在国内，无法访问 Google/Claude API，OCR 使用阿里云 DashScope

## 主题
- 深色主题：背景 `#06090F`，卡片 `#111A2E`，主色绿 `#00E676`
- 字体：SpaceGrotesk（标题）+ NotoSansSC（中文正文），通过 google_fonts 网络加载
- Material Design 3
