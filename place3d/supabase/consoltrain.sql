-- 방과후 콘솔 아카데미 — 팀 공유(리더보드/집계) 스키마 · Supabase
-- 적용: Supabase 대시보드 SQL Editor에 붙여넣기 실행, 또는 supabase db 로 마이그레이션.
-- 보안: RLS 활성 + anon insert/select 허용 (공개 교육 리더보드 — 민감정보 없음).
--        publishable key(sb_publishable_...)로 브라우저에서 접근. service_role 키는 절대 노출 금지.

-- 1) 체험 과제 제출(train.html) — 기대 마진/별점/통과율
create table if not exists public.consol_submissions (
  id         bigint generated always as identity primary key,
  trainee    text not null check (char_length(trainee) between 1 and 20),
  case_idx   int  not null check (case_idx between 0 and 20),
  margin     int  not null,
  stars      real not null,
  pass       int  not null check (pass between 0 and 100),
  created_at timestamptz not null default now()
);

-- 2) 판단 케이스 응시(casestudy.html) — 정오답 로그
create table if not exists public.consol_attempts (
  id         bigint generated always as identity primary key,
  trainee    text not null check (char_length(trainee) between 1 and 20),
  case_id    text not null check (char_length(case_id) <= 40),
  correct    boolean not null,
  created_at timestamptz not null default now()
);

alter table public.consol_submissions enable row level security;
alter table public.consol_attempts   enable row level security;

-- anon/authenticated 삽입·조회 허용 (공개 리더보드 용도)
create policy "insert submissions" on public.consol_submissions
  for insert to anon, authenticated with check (true);
create policy "select submissions" on public.consol_submissions
  for select to anon, authenticated using (true);
create policy "insert attempts" on public.consol_attempts
  for insert to anon, authenticated with check (true);
create policy "select attempts" on public.consol_attempts
  for select to anon, authenticated using (true);

-- 케이스별 최고기록 리더보드 뷰 (security_invoker: 호출자 권한으로 base RLS 적용)
create or replace view public.consol_leaderboard
  with (security_invoker = true) as
select case_idx,
       trainee,
       max(margin) as best_margin,
       max(stars)  as best_stars,
       max(pass)   as best_pass,
       count(*)    as tries
from public.consol_submissions
group by case_idx, trainee;

-- Data API 노출을 위한 명시적 GRANT (신규 테이블 자동 노출 안 될 수 있음)
grant select, insert on public.consol_submissions to anon, authenticated;
grant select, insert on public.consol_attempts   to anon, authenticated;
grant select        on public.consol_leaderboard to anon, authenticated;

-- 정답률 집계(선택): 케이스별 응시/정답
create or replace view public.consol_case_stats
  with (security_invoker = true) as
select case_id,
       count(*) as attempts,
       count(*) filter (where correct) as corrects,
       round(100.0 * count(*) filter (where correct) / nullif(count(*),0), 1) as accuracy_pct
from public.consol_attempts
group by case_id;
grant select on public.consol_case_stats to anon, authenticated;
