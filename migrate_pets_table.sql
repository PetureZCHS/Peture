-- 宠物信息表字段扩展迁移脚本
-- 添加缺失的字段：avatar, birth_date, neuter_status, weight

-- 添加头像字段
ALTER TABLE pets ADD COLUMN IF NOT EXISTS avatar TEXT;

-- 添加出生日期字段
ALTER TABLE pets ADD COLUMN IF NOT EXISTS birth_date TEXT;

-- 添加绝育状态字段
ALTER TABLE pets ADD COLUMN IF NOT EXISTS neuter_status TEXT;

-- 添加体重字段
ALTER TABLE pets ADD COLUMN IF NOT EXISTS weight REAL;

-- 添加注释
COMMENT ON COLUMN pets.avatar IS '宠物头像文件路径';
COMMENT ON COLUMN pets.birth_date IS '宠物出生日期，ISO 8601格式';
COMMENT ON COLUMN pets.neuter_status IS '绝育状态：已绝育/未绝育';
COMMENT ON COLUMN pets.weight IS '宠物体重，单位kg';