-- ==============================================================================
-- SUPABASE DATABASE SCHEMA FOR HABIT & FINANCE TRACKER
-- Execute these SQL statements in your Supabase SQL Editor (https://supabase.com)
-- ==============================================================================

-- 1. Profiles Table (Linked with Supabase Auth & Super Admin Dashboard)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    email TEXT,
    phone TEXT DEFAULT '',
    role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'disabled')),
    last_login_at TIMESTAMPTZ,
    avatar_url TEXT,
    subscription_expires_at TIMESTAMPTZ,
    payment_status TEXT DEFAULT 'none',
    payment_proof_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- App Settings (Payment Gateway Credentials & QR Code)
CREATE TABLE IF NOT EXISTS public.app_settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow anon read/write app_settings" ON public.app_settings;
CREATE POLICY "Allow anon read/write app_settings" ON public.app_settings FOR ALL USING (true) WITH CHECK (true);

-- 2. Habits Table
CREATE TABLE IF NOT EXISTS public.habits (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    icon TEXT,
    icon_code_point INT DEFAULT 58826,
    color_value INT NOT NULL DEFAULT 4287661441,
    category TEXT NOT NULL DEFAULT 'General',
    target_days_per_week INT NOT NULL DEFAULT 7,
    completed_dates TEXT[] DEFAULT '{}',
    notes_json JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Financial Transactions Table
CREATE TABLE IF NOT EXISTS public.financial_transactions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    title TEXT NOT NULL,
    amount NUMERIC(12, 2) NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
    payment_method TEXT NOT NULL CHECK (payment_method IN ('cash', 'bank')),
    bank_account_id TEXT,
    category TEXT NOT NULL,
    date TIMESTAMPTZ NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Bank Accounts Table
CREATE TABLE IF NOT EXISTS public.bank_accounts (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    name TEXT NOT NULL,
    account_number_last4 TEXT NOT NULL,
    initial_balance NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Debts & Receivables Table
CREATE TABLE IF NOT EXISTS public.debts (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    person_name TEXT NOT NULL,
    amount NUMERIC(12, 2) NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('owe', 'receivable')),
    due_date TIMESTAMPTZ,
    notes TEXT,
    is_settled BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Custom Categories Table
CREATE TABLE IF NOT EXISTS public.custom_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    category_name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, category_name)
);

-- Row Level Security (RLS) Policies
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.habits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.financial_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bank_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.debts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.custom_categories ENABLE ROW LEVEL SECURITY;

-- Permissive policies for client app synchronization
DROP POLICY IF EXISTS "Allow anon read/write profiles" ON public.profiles;
CREATE POLICY "Allow anon read/write profiles" ON public.profiles FOR ALL USING (true);

DROP POLICY IF EXISTS "Allow anon read/write habits" ON public.habits;
CREATE POLICY "Allow anon read/write habits" ON public.habits FOR ALL USING (true);

DROP POLICY IF EXISTS "Allow anon read/write transactions" ON public.financial_transactions;
CREATE POLICY "Allow anon read/write transactions" ON public.financial_transactions FOR ALL USING (true);

DROP POLICY IF EXISTS "Allow anon read/write bank_accounts" ON public.bank_accounts;
CREATE POLICY "Allow anon read/write bank_accounts" ON public.bank_accounts FOR ALL USING (true);

DROP POLICY IF EXISTS "Allow anon read/write debts" ON public.debts;
CREATE POLICY "Allow anon read/write debts" ON public.debts FOR ALL USING (true);

DROP POLICY IF EXISTS "Allow anon read/write custom_categories" ON public.custom_categories;
CREATE POLICY "Allow anon read/write custom_categories" ON public.custom_categories FOR ALL USING (true);

-- Enable Supabase Realtime for instant multi-browser synchronization
ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles, public.habits, public.financial_transactions, public.bank_accounts, public.debts, public.custom_categories;
ALTER TABLE public.habits REPLICA IDENTITY FULL;
ALTER TABLE public.financial_transactions REPLICA IDENTITY FULL;
ALTER TABLE public.bank_accounts REPLICA IDENTITY FULL;
ALTER TABLE public.debts REPLICA IDENTITY FULL;
ALTER TABLE public.profiles REPLICA IDENTITY FULL;
ALTER TABLE public.custom_categories REPLICA IDENTITY FULL;
