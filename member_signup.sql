-- 회원가입 / 회원관리용 Supabase SQL
-- 1) Supabase SQL Editor에서 전체 실행
-- 2) Authentication > Providers > Email 에서 Email provider 활성화
-- 3) "Confirm email"을 활성화하는 것을 권장합니다.
--
-- 중요: service_role key는 절대로 HTML/GitHub Pages에 넣지 마세요.
-- publishable key는 브라우저용 공개 키입니다. 실제 보안은 RLS가 담당합니다.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  name text not null,
  phone text not null,
  privacy_consent boolean not null default false,
  privacy_consent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_email_lower_chk check (email = lower(email)),
  constraint profiles_name_chk check (char_length(trim(name)) >= 2),
  constraint profiles_phone_chk check (char_length(regexp_replace(phone, '\D', '', 'g')) >= 8),
  constraint profiles_privacy_consent_chk check (privacy_consent = true)
);

create unique index if not exists profiles_email_unique_idx
  on public.profiles (email);

alter table public.profiles enable row level security;

-- 기존 정책이 있으면 충돌하지 않도록 제거 후 재생성
drop policy if exists "profiles_select_own" on public.profiles;
drop policy if exists "profiles_insert_own" on public.profiles;
drop policy if exists "profiles_update_own" on public.profiles;

create policy "profiles_select_own"
on public.profiles
for select
to authenticated
using (auth.uid() = id);

create policy "profiles_insert_own"
on public.profiles
for insert
to authenticated
with check (auth.uid() = id);

create policy "profiles_update_own"
on public.profiles
for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

-- 회원가입 시 auth.users의 metadata에서 profile 자동 생성
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (
    id, email, name, phone, privacy_consent, privacy_consent_at
  )
  values (
    new.id,
    lower(new.email),
    coalesce(new.raw_user_meta_data->>'name', ''),
    coalesce(new.raw_user_meta_data->>'phone', ''),
    coalesce((new.raw_user_meta_data->>'privacy_consent')::boolean, true),
    now()
  )
  on conflict (id) do update set
    email = excluded.email,
    name = excluded.name,
    phone = excluded.phone,
    updated_at = now();

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- updated_at 자동 갱신
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute procedure public.set_updated_at();

-- 가입자가 자신의 profile을 수정할 수 있도록 하되,
-- 개인정보 동의는 true 상태에서만 유지하도록 제한
revoke all on public.profiles from anon;
grant select, insert, update on public.profiles to authenticated;

-- 권장 Auth 설정:
-- Dashboard > Authentication > Providers > Email
-- Email provider: ON
-- Confirm email: ON
--
-- 참고:
-- auth.users.email 자체가 Supabase Auth에서 고유하게 관리되므로
-- 이메일 중복 가입은 Auth 레벨에서 차단됩니다.
--
-- "임의 이메일"을 브라우저에서 100% 판별하는 것은 불가능합니다.
-- 실제 이메일 소유 여부는 Confirm email을 통해 인증 메일을 수신/클릭하는 방식으로 검증합니다.
