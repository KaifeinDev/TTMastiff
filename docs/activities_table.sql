-- 活動管理表
CREATE TABLE IF NOT EXISTS activities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  image TEXT, -- base64 編碼的圖片
  type TEXT NOT NULL CHECK (type IN ('carousel', 'recent')), -- 輪播或近期活動
  "order" INTEGER NOT NULL DEFAULT 0, -- 顯示順序
  status TEXT NOT NULL DEFAULT 'inactive' CHECK (status IN ('active', 'inactive')), -- 上架中或已下架
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ
);

-- 建立索引以提升查詢效能
CREATE INDEX IF NOT EXISTS idx_activities_type_status ON activities(type, status);
CREATE INDEX IF NOT EXISTS idx_activities_order ON activities("order");

-- 建立更新時間的觸發器
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_activities_updated_at
  BEFORE UPDATE ON activities
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- 啟用 Row Level Security (RLS)
ALTER TABLE activities ENABLE ROW LEVEL SECURITY;

-- 政策 1: 所有人都可以讀取上架中的活動（前台顯示用）
CREATE POLICY "任何人都可以讀取上架中的活動"
  ON activities
  FOR SELECT
  USING (status = 'active');

-- 政策 2: 管理員和教練可以讀取所有活動（後台管理用）
CREATE POLICY "管理員和教練可以讀取所有活動"
  ON activities
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'coach')
    )
  );

-- 政策 3: 管理員和教練可以新增活動
CREATE POLICY "管理員和教練可以新增活動"
  ON activities
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'coach')
    )
  );

-- 政策 4: 管理員和教練可以更新活動
CREATE POLICY "管理員和教練可以更新活動"
  ON activities
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'coach')
    )
  );

-- 政策 5: 管理員和教練可以刪除活動
CREATE POLICY "管理員和教練可以刪除活動"
  ON activities
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'coach')
    )
  );
