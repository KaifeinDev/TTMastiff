-- =========================================================
-- TTMastiff 
-- =========================================================

BEGIN;

-- 1. 【暴力清除】
-- 先移除函數 (解決名稱重複問題)
DO $$ 
DECLARE 
  r RECORD;
BEGIN 
  FOR r IN 
    SELECT oid::regprocedure as func_signature 
    FROM pg_proc 
    WHERE proname IN (
      'add_credits', 'pay_for_booking', 'process_refund', 
      'refund_cash_transaction', 'reconcile_transactions',
      'handle_new_transaction_balance', 'handle_refund_balance_deduction',
      'sync_profile_name_to_student', 'is_admin', 'is_staff'
    )
  LOOP 
    EXECUTE 'DROP FUNCTION IF EXISTS ' || r.func_signature || ' CASCADE'; 
  END LOOP; 
END $$;

-- 移除表格
DROP TABLE IF EXISTS public.transactions CASCADE;
DROP TABLE IF EXISTS public.bookings CASCADE;
DROP TABLE IF EXISTS public.sessions CASCADE;
DROP TABLE IF EXISTS public.courses CASCADE;
DROP TABLE IF EXISTS public.students CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;

-- 2. 【重建架構】
-- Profiles (修正：移除 inline references，避免與下方 ALTER TABLE 衝突)
CREATE TABLE public.profiles (
  id uuid not null primary key, -- 這裡不寫 references，由下方 ALTER TABLE 處理
  full_name text,
  phone text,
  credits int default 0,
  role text default 'user',
  referral_source text,
  created_at timestamptz default now(),
  transaction_pin text
);
-- 統一在此設定 FK，確保 ON DELETE CASCADE
ALTER TABLE public.profiles ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- tables
CREATE TABLE public.tables (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,        -- 例如："第1桌", "VIP室", "發球機桌"
    capacity int DEFAULT 2,    -- 建議人數 (僅參考用)
    is_active boolean DEFAULT true, -- 是否啟用 (若桌子壞了可設為 false)
    sort_order int DEFAULT 0,  -- 排序用 (讓第1桌排在第2桌前面)
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    remarks text
);
CREATE INDEX idx_sessions_table_id ON public.sessions(table_id);

-- Students
CREATE TABLE public.students (
  id uuid not null default gen_random_uuid() primary key,
  parent_id uuid not null, -- 修正：移除 inline references
  name text not null,
  avatar_url text,
  birth_date date,
  level text default 'beginner', 
  medical_note text,
  is_primary boolean default false, 
  created_at timestamptz default now(), 
  gender text check (gender in ('male', 'female', 'other')),
  points int NOT NULL default 0
);
ALTER TABLE public.students ADD CONSTRAINT students_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES auth.users(id) ON DELETE CASCADE;
CREATE INDEX idx_students_parent_primary ON public.students(parent_id, is_primary);

-- Courses
CREATE TABLE public.courses (
    id uuid not null default gen_random_uuid() primary key,
    created_at timestamptz default now(),
    title text not null,        
    description text,
    default_start_time time not null, 
    default_end_time time not null,   
    price int default 0,
    category text default 'group',
    image_url text,              
    is_published boolean default true,
    CONSTRAINT check_category CHECK (category in ('group', 'personal', 'rental'))
);
CREATE INDEX idx_courses_is_active ON courses(is_published);

-- Sessions
CREATE TABLE public.sessions (
    id uuid not null default gen_random_uuid() primary key,
    created_at timestamptz default now(),
    course_id uuid not null, -- 修正：移除 inline references
    start_time timestamptz not null,
    end_time timestamptz not null,
    coach_ids uuid[] default '{}',
    location text,                 
    max_capacity int default 4,
    price int,
    table_ids uuid[] default '{}'
);
ALTER TABLE public.sessions ADD CONSTRAINT sessions_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE;

-- Bookings
CREATE TABLE public.bookings (
    id uuid not null default gen_random_uuid() primary key,
    created_at timestamptz default now(),
    user_id uuid, -- 修正：移除 inline references
    student_id uuid, -- 修正：移除 inline references
    session_id uuid, -- 修正：移除 inline references
    price_snapshot int not null default 0,                 
    status text default 'confirmed',                       
    attendance_status text default 'pending',
    updated_at timestamptz,
    guest_name text,  -- 散客姓名 (僅在 user_id 為散客帳號時有值)
    guest_phone text -- 散客電話
);
-- 統一在此設定 FK
ALTER TABLE public.bookings ADD CONSTRAINT bookings_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.bookings ADD CONSTRAINT bookings_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;
ALTER TABLE public.bookings ADD CONSTRAINT bookings_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.sessions(id) ON DELETE CASCADE;
ALTER TABLE public.bookings ADD CONSTRAINT unique_student_session UNIQUE (student_id, session_id);

-- Transactions (保持完整結構)
CREATE TABLE public.transactions (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at timestamptz DEFAULT now(),
    user_id uuid NOT NULL, -- 修正
    type text NOT NULL,
    amount int NOT NULL,
    description text,
    related_booking_id uuid, -- 修正
    performed_by uuid, -- 修正
    is_reconciled boolean DEFAULT false,
    reconciled_at timestamptz,
    reconciled_by uuid, -- 修正
    metadata JSONB DEFAULT '{}'::jsonb,
    status text DEFAULT 'valid',
    updated_at timestamptz,
    payment_method text DEFAULT 'credit',
    CONSTRAINT check_payment_method CHECK (payment_method IN ('credit', 'cash', 'transfer', 'other'))
);

-- 員工詳細資料表
CREATE TABLE public.staff_details (
  id uuid REFERENCES public.profiles(id) PRIMARY KEY, -- 與 profiles 1對1
  coach_hourly_rate int DEFAULT 0,    -- 教練時薪
  desk_hourly_rate int DEFAULT 180,   -- 櫃檯時薪 (預設)
  bank_account text,                  -- 銀行帳號
  onboard_date date,                  -- 入職日
  status text DEFAULT 'active',       -- active (在職), resigned (離職)
  updated_at timestamptz DEFAULT now()
);

-- 排班表
CREATE TABLE public.work_shifts (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  staff_id uuid REFERENCES public.profiles(id) NOT NULL,
  start_time timestamptz NOT NULL,
  end_time timestamptz NOT NULL,
  note text, -- 備註
  created_at timestamptz DEFAULT now()
);

-- 薪資單表
CREATE TABLE public.payrolls (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  staff_id uuid REFERENCES public.profiles(id) NOT NULL,
  year int NOT NULL,
  month int NOT NULL,
  
  -- 鎖定當下的數據 Snapshot
  total_coach_hours numeric(10, 2) DEFAULT 0,
  coach_hourly_rate int DEFAULT 0,
  total_desk_hours numeric(10, 2) DEFAULT 0,
  desk_hourly_rate int DEFAULT 0,
  adjustment_hours numeric(10, 2) DEFAULT 0,
  
  -- 調整項
  bonus int DEFAULT 0,       -- 加項
  deduction int DEFAULT 0,   -- 減項
  note text,                 -- 備註 (例如：全勤獎金)
  
  total_amount int NOT NULL, -- 實發總額
  status text DEFAULT 'pending', -- pending (未發), paid (已發)
  paid_at timestamptz,
  
  created_at timestamptz DEFAULT now(),
  UNIQUE(staff_id, year, month) -- 確保每人每月只有一張單
);


-- FK Constraints
ALTER TABLE public.transactions ADD CONSTRAINT transactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.transactions ADD CONSTRAINT transactions_related_booking_id_fkey FOREIGN KEY (related_booking_id) REFERENCES public.bookings(id) ON DELETE SET NULL;
ALTER TABLE public.transactions ADD CONSTRAINT transactions_performed_by_fkey FOREIGN KEY (performed_by) REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.transactions ADD CONSTRAINT transactions_reconciled_by_fkey FOREIGN KEY (reconciled_by) REFERENCES public.profiles(id) ON DELETE SET NULL;

-- Indexes
CREATE INDEX idx_transactions_reconciled ON public.transactions(is_reconciled);
CREATE INDEX idx_transactions_performed_by ON public.transactions(performed_by);
CREATE INDEX idx_transactions_user_id ON public.transactions(user_id);
CREATE INDEX idx_transactions_metadata ON public.transactions USING GIN (metadata);
CREATE INDEX idx_transactions_status ON transactions(status);
CREATE INDEX idx_transactions_type ON transactions(type);

-- ==========================================
-- 3. Triggers & Functions (保持不變，因為邏輯是對的)
-- ==========================================

-- (A) 同步名字
CREATE OR REPLACE FUNCTION public.sync_profile_name_to_student()
RETURNS trigger AS $$
BEGIN
  UPDATE public.students
  SET name = new.full_name
  WHERE parent_id = new.id AND is_primary = true;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_profile_updated_sync_name
  AFTER UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.sync_profile_name_to_student();

-- (B) 權限 Helper
CREATE OR REPLACE FUNCTION is_admin()
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin');
END;
$$;

CREATE OR REPLACE FUNCTION public.is_staff()
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'coach'));
END;
$$;

-- (C) 自動計算餘額 Trigger 1 (New Transaction)
CREATE OR REPLACE FUNCTION handle_new_transaction_balance()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'valid' THEN
    UPDATE profiles
    SET credits = credits + NEW.amount
    WHERE id = NEW.user_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_transaction_created
AFTER INSERT ON transactions
FOR EACH ROW
EXECUTE FUNCTION handle_new_transaction_balance();

-- (D) 自動計算餘額 Trigger 2 (Refunded Topup)
CREATE OR REPLACE FUNCTION handle_refund_balance_deduction()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'refunded' AND OLD.status = 'valid' AND NEW.type = 'topup' THEN
    UPDATE profiles
    SET credits = credits - NEW.amount 
    WHERE id = NEW.user_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_transaction_refund
AFTER UPDATE ON transactions
FOR EACH ROW
EXECUTE FUNCTION handle_refund_balance_deduction();

-- ==========================================
-- 4. 業務邏輯函數
-- ==========================================

-- (1) 儲值
CREATE OR REPLACE FUNCTION add_credits(
  target_user_id uuid,
  amount_to_add int,
  description_text text,
  input_pin text
) RETURNS int LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  current_user_role text;
  stored_pin text;
  new_balance int;
  initiator_id uuid := auth.uid();
BEGIN
  SELECT role, transaction_pin INTO current_user_role, stored_pin FROM profiles WHERE id = initiator_id;
  
  IF current_user_role NOT IN ('admin', 'coach') THEN RAISE EXCEPTION 'Access Denied'; END IF;
  IF stored_pin IS NULL OR stored_pin != input_pin THEN RAISE EXCEPTION 'Security Error: PIN 錯誤'; END IF;

  INSERT INTO transactions (user_id, type, amount, description, created_at, performed_by)
  VALUES (target_user_id, 'topup', amount_to_add, description_text, now(), initiator_id);

  SELECT credits INTO new_balance FROM profiles WHERE id = target_user_id;
  RETURN new_balance;
END;
$$;

-- (2) 扣款 (報名)
CREATE OR REPLACE FUNCTION pay_for_booking(
  target_user_id uuid,
  cost_amount int,
  booking_uuid uuid,
  course_name text,
  session_info text,
  student_name text,
  student_id uuid
) RETURNS int LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  current_balance int;
  new_balance int;
  current_user_role text;
  initiator_id uuid := auth.uid();
BEGIN
  SELECT role INTO current_user_role FROM profiles WHERE id = initiator_id;
  
  IF current_user_role NOT IN ('admin', 'coach') AND initiator_id != target_user_id THEN
     RAISE EXCEPTION 'Access Denied';
  END IF;

  SELECT credits INTO current_balance FROM profiles WHERE id = target_user_id FOR UPDATE;
  IF (current_balance IS NULL OR current_balance < cost_amount) THEN
    RAISE EXCEPTION 'Insufficient Funds';
  END IF;

  INSERT INTO transactions (
    user_id, type, amount, description, related_booking_id, created_at, performed_by, metadata
  ) VALUES (
    target_user_id, 'payment', -cost_amount, '報名課程: ' || course_name, booking_uuid, now(), initiator_id,
    json_build_object('course_name', course_name, 'student_name', student_name, 'student_id', student_id, 'session_info', session_info, 'type', 'booking_payment')
  );

  SELECT credits INTO new_balance FROM profiles WHERE id = target_user_id;
  RETURN new_balance;
END;
$$;

-- (3) 課程取消退點 (Credit Refund)
CREATE OR REPLACE FUNCTION process_refund(
  target_user_id uuid,
  amount_to_refund int,
  booking_uuid uuid,
  course_name text,
  session_info text,
  student_name text,
  student_id uuid,
  refund_reason text DEFAULT '預約取消' -- 🔥 新增此參數，預設為一般取消
) RETURNS int LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  initiator_id uuid := auth.uid();
  new_balance int;
  net_amount int;         -- 目前此 booking 的淨交易金額 (payment 為負、refund 為正)
  effective_refund int;   -- 本次實際可退的金額
BEGIN
  -- 計算目前此 booking 的淨額：
  -- payment 為負數、refund_credit 為正數。
  SELECT COALESCE(SUM(amount), 0) INTO net_amount
  FROM public.transactions
  WHERE related_booking_id = booking_uuid
    AND status = 'valid';

  -- 若 net_amount >= 0，表示此 booking 目前沒有尚未退款的扣款金額，
  -- 可能已全額退完或根本沒扣款；此時不再新增退款交易，避免重複退費。
  IF net_amount >= 0 THEN
    SELECT credits INTO new_balance
    FROM public.profiles
    WHERE id = target_user_id;

    RETURN new_balance;
  END IF;

  -- 本次最多只能退到 net_amount 回 0，不允許超退。
  -- 例如：net_amount = -250，amount_to_refund=500 時，最多只退 250。
  effective_refund := LEAST(amount_to_refund, -net_amount);

  -- 若計算後無需退款（理論上不會發生，但保險起見），直接回傳目前餘額。
  IF effective_refund <= 0 THEN
    SELECT credits INTO new_balance
    FROM public.profiles
    WHERE id = target_user_id;

    RETURN new_balance;
  END IF;

  INSERT INTO transactions (
    user_id, 
    type, 
    amount, 
    related_booking_id, 
    created_at, 
    performed_by, 
    description, 
    metadata
  ) VALUES (
    target_user_id, 
    'refund_credit', 
    effective_refund, 
    booking_uuid, 
    now(), 
    initiator_id,
    -- description 改由參數組合
    refund_reason || ': ' || course_name, 
    -- metadata 也記錄具體原因
    json_build_object(
      'course_name', course_name, 
      'student_name', student_name, 
      'student_id', student_id, 
      'session_info', session_info, 
      'refund_reason', refund_reason,
      'type', 'refund_credit'
    )
  );

  -- 餘額更新交由 on_transaction_created Trigger 處理，
  -- 這裡僅回傳最新餘額。
  SELECT credits INTO new_balance FROM profiles WHERE id = target_user_id;
  
  RETURN new_balance;
END;
$$;

-- (4) 現金儲值作廢 (Cash Refund)
CREATE OR REPLACE FUNCTION refund_cash_transaction(
  target_transaction_id uuid,
  refund_reason text
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  origin_txn record;
  current_user_balance int;
BEGIN
  SELECT * INTO origin_txn FROM transactions WHERE id = target_transaction_id;
  IF origin_txn IS NULL THEN RAISE EXCEPTION '找不到交易'; END IF;
  IF origin_txn.type != 'topup' THEN RAISE EXCEPTION '此功能僅限作廢現金儲值 (Topup)'; END IF;
  IF origin_txn.status = 'refunded' THEN RAISE EXCEPTION '此交易已作廢過'; END IF;

  SELECT credits INTO current_user_balance FROM profiles WHERE id = origin_txn.user_id;
  IF current_user_balance < origin_txn.amount THEN
     RAISE EXCEPTION '用戶餘額不足，無法作廢此儲值紀錄';
  END IF;

  UPDATE transactions
  SET status = 'refunded',
      updated_at = now(),
      metadata = jsonb_set(metadata, '{refund_reason}', to_jsonb(refund_reason))
  WHERE id = target_transaction_id;
END;
$$;

-- (5) 對帳
CREATE OR REPLACE FUNCTION reconcile_transactions(transaction_ids uuid[]) 
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin') THEN
    RAISE EXCEPTION 'Access Denied';
  END IF;

  UPDATE transactions
  SET is_reconciled = true, reconciled_at = now(), reconciled_by = auth.uid()
  WHERE id = ANY(transaction_ids) AND is_reconciled = false;
END;
$$;

-- ==========================================
-- 5. RLS Policies
-- ==========================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tables ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

-- Profiles
CREATE POLICY "Staff Read All Profiles" ON public.profiles FOR SELECT USING (public.is_staff() OR auth.uid() = id);
CREATE POLICY "User Own Profile" ON public.profiles FOR ALL USING (auth.uid() = id);
CREATE POLICY "Admin Write Profiles" ON public.profiles FOR UPDATE USING (public.is_admin());
CREATE POLICY "Only owner and admin can see PIN" ON profiles FOR SELECT USING (auth.uid() = id OR is_admin());

-- Tables
CREATE POLICY "Allow public read access" ON public.tables FOR SELECT USING (true);
CREATE POLICY "Allow authenticated insert/update" ON public.tables FOR ALL USING (auth.role() = 'authenticated');

-- Students
CREATE POLICY "Staff Read All Students" ON public.students FOR SELECT USING (public.is_staff() OR auth.uid() = parent_id);
CREATE POLICY "User Own Students" ON public.students FOR ALL USING (auth.uid() = parent_id);
CREATE POLICY "Admin Write Students" ON public.students FOR ALL USING (public.is_admin());

-- Courses & Sessions
CREATE POLICY "Public Read Courses" ON public.courses FOR SELECT USING (true);
CREATE POLICY "Admin Write Courses" ON public.courses FOR ALL USING (public.is_admin());
CREATE POLICY "Public Read Sessions" ON public.sessions FOR SELECT USING (true);
CREATE POLICY "Admin Write Sessions" ON public.sessions FOR ALL USING (public.is_admin());

-- Bookings
CREATE POLICY "Staff Read All Bookings" ON public.bookings FOR SELECT USING (public.is_staff() OR auth.uid() = user_id);
CREATE POLICY "User Own Bookings" ON public.bookings FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Admin Write Bookings" ON public.bookings FOR ALL USING (public.is_admin());
-- 允許 Staff (教練/櫃檯) 修改訂單
CREATE POLICY "Staff Update Bookings" ON public.bookings FOR UPDATE USING (public.is_staff());
-- 允許 Staff 幫別人新增報名的權限
CREATE POLICY "Staff Insert Bookings" ON public.bookings 
FOR INSERT 
WITH CHECK (public.is_staff());

-- Transactions
CREATE POLICY "Staff Read All Transactions" ON public.transactions FOR SELECT USING (public.is_staff());
CREATE POLICY "User Own Transactions" ON public.transactions FOR SELECT USING (auth.uid() = user_id);
-- 2. 設定「新增」權限：允許所有員工 (Staff & Admin)
-- 這樣教練/櫃檯才能幫散客開單
CREATE POLICY "Staff Insert Transactions"ON public.transactions FOR INSERT TO authenticated WITH CHECK (public.is_staff()); 
-- 註: 通常 is_staff() 的邏輯會包含 admin，如果不包含，這裡要改成 (is_staff() OR is_admin())

-- 3. 設定「修改/核銷」權限：只允許老闆 (Admin)
-- 只有老闆可以改 status 或 is_reconciled
CREATE POLICY "Admin Update Transactions" ON public.transactions FOR UPDATE TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

-- staff_details
ALTER TABLE public.staff_details ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admin Full Access" ON public.staff_details FOR ALL USING (public.is_admin());
CREATE POLICY "Staff Read Own" ON public.staff_details FOR SELECT USING (auth.uid() = id);

-- work_shifts
ALTER TABLE public.work_shifts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admin Full Access" ON public.work_shifts FOR ALL USING (public.is_admin());
CREATE POLICY "Staff Read Own" ON public.work_shifts FOR SELECT USING (auth.uid() = staff_id);

-- payrolls
ALTER TABLE public.payrolls ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admin Full Access" ON public.payrolls FOR ALL USING (public.is_admin());
CREATE POLICY "Staff Read Own" ON public.payrolls FOR SELECT USING (auth.uid() = staff_id);

COMMIT;