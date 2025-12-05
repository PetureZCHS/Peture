-- ============================================================
-- Supabase 数据库表结构 SQL 脚本（支持 LeanCloud 认证）
-- 使用 CREATE TABLE IF NOT EXISTS，不会删除现有表
-- ============================================================
-- 
-- 此脚本适用于：
-- 1. 数据库还没有创建表
-- 2. 想保留现有表结构（如果表已存在）
-- 
-- 如果需要重新创建表结构，请使用 supabase_migration_to_leancloud.sql
-- ============================================================

-- 启用 UUID 扩展
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 1. 用户信息表 (users_profiles)
-- 支持 LeanCloud 用户 ID（TEXT 类型）
-- ============================================================
CREATE TABLE IF NOT EXISTS users_profiles (
  id TEXT PRIMARY KEY, -- 改为 TEXT 以支持 LeanCloud objectId
  nickname TEXT,
  avatar_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 创建更新时间触发器
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_profiles_updated_at
  BEFORE UPDATE ON users_profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 2. 宠物信息表 (pets)
-- 支持 LeanCloud 用户 ID（TEXT 类型）
-- ============================================================
CREATE TABLE IF NOT EXISTS pets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id TEXT NOT NULL REFERENCES users_profiles(id) ON DELETE CASCADE, -- 改为 TEXT 类型
  type TEXT NOT NULL,
  name TEXT NOT NULL,
  age TEXT NOT NULL,
  gender TEXT NOT NULL,
  breed TEXT NOT NULL,
  avatar TEXT, -- 宠物头像路径
  birth_date TEXT, -- 出生日期 (ISO 8601 格式)
  neuter_status TEXT, -- 绝育状态: '已绝育' 或 '未绝育'
  weight REAL, -- 体重 (kg)
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_pets_user_id ON pets(user_id);
CREATE INDEX IF NOT EXISTS idx_pets_type ON pets(type);

-- 创建更新时间触发器
CREATE TRIGGER update_pets_updated_at
  BEFORE UPDATE ON pets
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 3. 医疗记录表 (medical_records)
-- ============================================================
CREATE TABLE IF NOT EXISTS medical_records (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pet_id UUID NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users_profiles(id) ON DELETE CASCADE, -- 改为 TEXT 类型
  date TEXT NOT NULL,
  description TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_medical_records_pet_id ON medical_records(pet_id);
CREATE INDEX IF NOT EXISTS idx_medical_records_user_id ON medical_records(user_id);
CREATE INDEX IF NOT EXISTS idx_medical_records_date ON medical_records(date);

-- 创建更新时间触发器
CREATE TRIGGER update_medical_records_updated_at
  BEFORE UPDATE ON medical_records
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 4. 体重记录表 (weight_records)
-- ============================================================
CREATE TABLE IF NOT EXISTS weight_records (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pet_id UUID NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users_profiles(id) ON DELETE CASCADE, -- 改为 TEXT 类型
  date TEXT NOT NULL,
  weight REAL NOT NULL,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_weight_records_pet_id ON weight_records(pet_id);
CREATE INDEX IF NOT EXISTS idx_weight_records_user_id ON weight_records(user_id);
CREATE INDEX IF NOT EXISTS idx_weight_records_date ON weight_records(date);

-- 创建更新时间触发器
CREATE TRIGGER update_weight_records_updated_at
  BEFORE UPDATE ON weight_records
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 5. 疫苗记录表 (vaccine_records)
-- ============================================================
CREATE TABLE IF NOT EXISTS vaccine_records (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pet_id UUID NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users_profiles(id) ON DELETE CASCADE, -- 改为 TEXT 类型
  date TEXT NOT NULL,
  type TEXT NOT NULL,
  name TEXT NOT NULL,
  next_due_date TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_vaccine_records_pet_id ON vaccine_records(pet_id);
CREATE INDEX IF NOT EXISTS idx_vaccine_records_user_id ON vaccine_records(user_id);
CREATE INDEX IF NOT EXISTS idx_vaccine_records_date ON vaccine_records(date);

-- 创建更新时间触发器
CREATE TRIGGER update_vaccine_records_updated_at
  BEFORE UPDATE ON vaccine_records
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 6. 每日提醒表 (daily_reminders)
-- ============================================================
CREATE TABLE IF NOT EXISTS daily_reminders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pet_id UUID REFERENCES pets(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users_profiles(id) ON DELETE CASCADE, -- 改为 TEXT 类型
  time TEXT NOT NULL,
  task TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_daily_reminders_pet_id ON daily_reminders(pet_id);
CREATE INDEX IF NOT EXISTS idx_daily_reminders_user_id ON daily_reminders(user_id);

-- 创建更新时间触发器
CREATE TRIGGER update_daily_reminders_updated_at
  BEFORE UPDATE ON daily_reminders
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 7. 对话记录表 (conversations)
-- ============================================================
CREATE TABLE IF NOT EXISTS conversations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id TEXT NOT NULL REFERENCES users_profiles(id) ON DELETE CASCADE, -- 改为 TEXT 类型
  question TEXT NOT NULL,
  answer TEXT NOT NULL,
  timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
  is_pinned BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_conversations_user_id ON conversations(user_id);
CREATE INDEX IF NOT EXISTS idx_conversations_timestamp ON conversations(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_conversations_is_pinned ON conversations(is_pinned);

-- 创建更新时间触发器
CREATE TRIGGER update_conversations_updated_at
  BEFORE UPDATE ON conversations
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 8. 宠物日记表 (pet_diaries)
-- ============================================================
CREATE TABLE IF NOT EXISTS pet_diaries (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id TEXT NOT NULL REFERENCES users_profiles(id) ON DELETE CASCADE, -- 改为 TEXT 类型
  original_text TEXT NOT NULL,
  content TEXT NOT NULL,
  style TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_pet_diaries_user_id ON pet_diaries(user_id);
CREATE INDEX IF NOT EXISTS idx_pet_diaries_created_at ON pet_diaries(created_at DESC);

-- 创建更新时间触发器
CREATE TRIGGER update_pet_diaries_updated_at
  BEFORE UPDATE ON pet_diaries
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 9. 聊天消息表 (chat_messages) - 可选，如果需要的话
-- ============================================================
CREATE TABLE IF NOT EXISTS chat_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users_profiles(id) ON DELETE CASCADE, -- 改为 TEXT 类型
  text TEXT NOT NULL,
  is_user BOOLEAN NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_chat_messages_conversation_id ON chat_messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_user_id ON chat_messages(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at ON chat_messages(created_at ASC);

-- ============================================================
-- 10. 统一消费记录表 (unified_expenses)
-- ============================================================
CREATE TABLE IF NOT EXISTS unified_expenses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id TEXT NOT NULL REFERENCES users_profiles(id) ON DELETE CASCADE,
  amount REAL NOT NULL,
  category TEXT NOT NULL,
  expense_type TEXT NOT NULL, -- 'one-off' or 'recurring'
  date TEXT NOT NULL, -- yyyy-MM-dd
  pet_id UUID REFERENCES pets(id) ON DELETE SET NULL,
  pet_name TEXT,
  note TEXT,
  photo_path TEXT,
  item_name TEXT,
  estimated_end_date TEXT,
  item_type TEXT, -- 'consumable' or 'durable'
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_unified_expenses_user_id ON unified_expenses(user_id);
CREATE INDEX IF NOT EXISTS idx_unified_expenses_date ON unified_expenses(date);
CREATE INDEX IF NOT EXISTS idx_unified_expenses_expense_type ON unified_expenses(expense_type);

CREATE TRIGGER update_unified_expenses_updated_at
  BEFORE UPDATE ON unified_expenses
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 11. 日常消费品记录表 (daily_cost_items)
-- ============================================================
CREATE TABLE IF NOT EXISTS daily_cost_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id TEXT NOT NULL REFERENCES users_profiles(id) ON DELETE CASCADE,
  item_name TEXT NOT NULL,
  total_price REAL NOT NULL,
  purchase_date TEXT NOT NULL,
  finish_date TEXT,
  pet_id UUID REFERENCES pets(id) ON DELETE SET NULL,
  pet_name TEXT,
  image_path TEXT,
  note TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_daily_cost_items_user_id ON daily_cost_items(user_id);
CREATE INDEX IF NOT EXISTS idx_daily_cost_items_purchase_date ON daily_cost_items(purchase_date);

CREATE TRIGGER update_daily_cost_items_updated_at
  BEFORE UPDATE ON daily_cost_items
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 12. 健身记录表 (fitness_records)
-- ============================================================
CREATE TABLE IF NOT EXISTS fitness_records (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id TEXT NOT NULL REFERENCES users_profiles(id) ON DELETE CASCADE,
  course_id TEXT NOT NULL,
  course_name TEXT NOT NULL,
  completed_at TEXT NOT NULL,
  duration_minutes INTEGER NOT NULL,
  calories_burned INTEGER NOT NULL,
  pet_calories_burned INTEGER NOT NULL,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fitness_records_user_id ON fitness_records(user_id);
CREATE INDEX IF NOT EXISTS idx_fitness_records_completed_at ON fitness_records(completed_at);

CREATE TRIGGER update_fitness_records_updated_at
  BEFORE UPDATE ON fitness_records
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 13. 健康计划表 (health_plans)
-- ============================================================
CREATE TABLE IF NOT EXISTS health_plans (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id TEXT NOT NULL REFERENCES users_profiles(id) ON DELETE CASCADE,
  pet_id UUID REFERENCES pets(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  description TEXT,
  start_date TEXT NOT NULL,
  end_date TEXT NOT NULL,
  is_completed BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_health_plans_user_id ON health_plans(user_id);
CREATE INDEX IF NOT EXISTS idx_health_plans_pet_id ON health_plans(pet_id);

CREATE TRIGGER update_health_plans_updated_at
  BEFORE UPDATE ON health_plans
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 14. 宠物护照表 (pet_passports) 与成就表 (pet_passport_achievements)
-- ============================================================
CREATE TABLE IF NOT EXISTS pet_passports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id TEXT NOT NULL REFERENCES users_profiles(id) ON DELETE CASCADE,
  pet_id UUID NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
  photo_path TEXT,
  owner_name TEXT,
  adoption_date TEXT,
  mbti_type TEXT,
  mbti_description TEXT,
  interest_tags TEXT,
  bio TEXT,
  friend_count INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE (user_id, pet_id)
);

CREATE INDEX IF NOT EXISTS idx_pet_passports_user_id ON pet_passports(user_id);
CREATE INDEX IF NOT EXISTS idx_pet_passports_pet_id ON pet_passports(pet_id);

CREATE TRIGGER update_pet_passports_updated_at
  BEFORE UPDATE ON pet_passports
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TABLE IF NOT EXISTS pet_passport_achievements (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  passport_id UUID NOT NULL REFERENCES pet_passports(id) ON DELETE CASCADE,
  achievement_id TEXT NOT NULL,
  achievement_name TEXT NOT NULL,
  achievement_description TEXT NOT NULL,
  icon_name TEXT NOT NULL,
  category TEXT NOT NULL,
  unlocked_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_pet_passport_achievements_passport_id
  ON pet_passport_achievements(passport_id);

-- ============================================================
-- Row Level Security (RLS) 策略
-- 确保用户只能访问自己的数据
-- ============================================================

-- 启用 RLS
ALTER TABLE users_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE pets ENABLE ROW LEVEL SECURITY;
ALTER TABLE medical_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE weight_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE vaccine_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_reminders ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE pet_diaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE unified_expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_cost_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE fitness_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE health_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE pet_passports ENABLE ROW LEVEL SECURITY;
ALTER TABLE pet_passport_achievements ENABLE ROW LEVEL SECURITY;

-- 注意：由于使用 LeanCloud 认证，我们需要创建一个函数来获取当前用户 ID
-- 这个函数将从应用程序传递的 user_id 参数中获取，而不是从 auth.uid()
-- 或者，我们可以使用 Service Role Key 来绕过 RLS（不推荐用于生产环境）

-- 临时方案：允许所有操作（仅用于开发测试）
-- 生产环境应该使用更安全的方案，比如：
-- 1. 在 Supabase 中创建用户映射表
-- 2. 使用 Supabase Edge Functions 验证 LeanCloud session token
-- 3. 或者完全迁移到 Supabase Auth

-- 用户资料表策略（允许所有操作，因为已经通过 LeanCloud 认证）
CREATE POLICY "Allow all operations on users_profiles"
  ON users_profiles FOR ALL
  USING (true)
  WITH CHECK (true);

-- 宠物表策略
CREATE POLICY "Users can view own pets"
  ON pets FOR SELECT
  USING (true); -- 暂时允许所有查看，实际应该通过应用层控制

CREATE POLICY "Users can insert own pets"
  ON pets FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Users can update own pets"
  ON pets FOR UPDATE
  USING (true);

CREATE POLICY "Users can delete own pets"
  ON pets FOR DELETE
  USING (true);

-- 医疗记录表策略
CREATE POLICY "Users can view own medical records"
  ON medical_records FOR SELECT
  USING (true);

CREATE POLICY "Users can insert own medical records"
  ON medical_records FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Users can update own medical records"
  ON medical_records FOR UPDATE
  USING (true);

CREATE POLICY "Users can delete own medical records"
  ON medical_records FOR DELETE
  USING (true);

-- 体重记录表策略
CREATE POLICY "Users can view own weight records"
  ON weight_records FOR SELECT
  USING (true);

CREATE POLICY "Users can insert own weight records"
  ON weight_records FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Users can update own weight records"
  ON weight_records FOR UPDATE
  USING (true);

CREATE POLICY "Users can delete own weight records"
  ON weight_records FOR DELETE
  USING (true);

-- 疫苗记录表策略
CREATE POLICY "Users can view own vaccine records"
  ON vaccine_records FOR SELECT
  USING (true);

CREATE POLICY "Users can insert own vaccine records"
  ON vaccine_records FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Users can update own vaccine records"
  ON vaccine_records FOR UPDATE
  USING (true);

CREATE POLICY "Users can delete own vaccine records"
  ON vaccine_records FOR DELETE
  USING (true);

-- 每日提醒表策略
CREATE POLICY "Users can view own daily reminders"
  ON daily_reminders FOR SELECT
  USING (true);

CREATE POLICY "Users can insert own daily reminders"
  ON daily_reminders FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Users can update own daily reminders"
  ON daily_reminders FOR UPDATE
  USING (true);

CREATE POLICY "Users can delete own daily reminders"
  ON daily_reminders FOR DELETE
  USING (true);

-- 对话记录表策略
CREATE POLICY "Users can view own conversations"
  ON conversations FOR SELECT
  USING (true);

CREATE POLICY "Users can insert own conversations"
  ON conversations FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Users can update own conversations"
  ON conversations FOR UPDATE
  USING (true);

CREATE POLICY "Users can delete own conversations"
  ON conversations FOR DELETE
  USING (true);

-- 宠物日记表策略
CREATE POLICY "Users can view own pet diaries"
  ON pet_diaries FOR SELECT
  USING (true);

CREATE POLICY "Users can insert own pet diaries"
  ON pet_diaries FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Users can update own pet diaries"
  ON pet_diaries FOR UPDATE
  USING (true);

CREATE POLICY "Users can delete own pet diaries"
  ON pet_diaries FOR DELETE
  USING (true);

-- 聊天消息表策略
CREATE POLICY "Users can view own chat messages"
  ON chat_messages FOR SELECT
  USING (true);

CREATE POLICY "Users can insert own chat messages"
  ON chat_messages FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Users can update own chat messages"
  ON chat_messages FOR UPDATE
  USING (true);

CREATE POLICY "Users can delete own chat messages"
  ON chat_messages FOR DELETE
  USING (true);

-- 统一消费记录表策略
CREATE POLICY "Users can view own unified expenses"
  ON unified_expenses FOR SELECT
  USING (true);

CREATE POLICY "Users can insert own unified expenses"
  ON unified_expenses FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Users can update own unified expenses"
  ON unified_expenses FOR UPDATE
  USING (true);

CREATE POLICY "Users can delete own unified expenses"
  ON unified_expenses FOR DELETE
  USING (true);

-- 日常消费品记录表策略
CREATE POLICY "Users can view own daily cost items"
  ON daily_cost_items FOR SELECT
  USING (true);

CREATE POLICY "Users can insert own daily cost items"
  ON daily_cost_items FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Users can update own daily cost items"
  ON daily_cost_items FOR UPDATE
  USING (true);

CREATE POLICY "Users can delete own daily cost items"
  ON daily_cost_items FOR DELETE
  USING (true);

-- 健身记录表策略
CREATE POLICY "Users can view own fitness records"
  ON fitness_records FOR SELECT
  USING (true);

CREATE POLICY "Users can insert own fitness records"
  ON fitness_records FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Users can update own fitness records"
  ON fitness_records FOR UPDATE
  USING (true);

CREATE POLICY "Users can delete own fitness records"
  ON fitness_records FOR DELETE
  USING (true);

-- 健康计划表策略
CREATE POLICY "Users can view own health plans"
  ON health_plans FOR SELECT
  USING (true);

CREATE POLICY "Users can insert own health plans"
  ON health_plans FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Users can update own health plans"
  ON health_plans FOR UPDATE
  USING (true);

CREATE POLICY "Users can delete own health plans"
  ON health_plans FOR DELETE
  USING (true);

-- 宠物护照表策略
CREATE POLICY "Users can view own pet passports"
  ON pet_passports FOR SELECT
  USING (true);

CREATE POLICY "Users can insert own pet passports"
  ON pet_passports FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Users can update own pet passports"
  ON pet_passports FOR UPDATE
  USING (true);

CREATE POLICY "Users can delete own pet passports"
  ON pet_passports FOR DELETE
  USING (true);

-- 宠物护照成就表策略
CREATE POLICY "Users can view own pet passport achievements"
  ON pet_passport_achievements FOR SELECT
  USING (true);

CREATE POLICY "Users can insert own pet passport achievements"
  ON pet_passport_achievements FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Users can update own pet passport achievements"
  ON pet_passport_achievements FOR UPDATE
  USING (true);

CREATE POLICY "Users can delete own pet passport achievements"
  ON pet_passport_achievements FOR DELETE
  USING (true);

