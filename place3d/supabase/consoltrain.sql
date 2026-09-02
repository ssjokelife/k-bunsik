-- 방과후 콘솔 아카데미 — 팀 공유 스키마 (전용 스키마 consoltrain 격리 버전) · Supabase
-- 적용 순서:
--   1) 이 SQL을 Supabase SQL Editor에서 실행 (재실행 안전).
--   2) 대시보드 → Project Settings → API → "Exposed schemas"에 consoltrain 추가(저장).
--   3) academy.html ☁ 설정에 Project URL + publishable key(sb_publishable_...) 입력.
-- 보안: RLS 활성 + anon insert/select (공개 교육 리더보드 — 민감정보 없음). service_role 키 노출 금지.

create schema if not exists consoltrain;
grant usage on schema consoltrain to anon, authenticated;

-- 1) 체험 과제 제출(train.html)
create table if not exists consoltrain.submissions (
  id         bigint generated always as identity primary key,
  trainee    text not null check (char_length(trainee) between 1 and 20),
  case_idx   int  not null check (case_idx between 0 and 20),
  margin     int  not null,
  stars      real not null,
  pass       int  not null check (pass between 0 and 100),
  created_at timestamptz not null default now()
);

-- 2) 판단 케이스 응시(casestudy.html)
create table if not exists consoltrain.attempts (
  id         bigint generated always as identity primary key,
  trainee    text not null check (char_length(trainee) between 1 and 20),
  case_id    text not null check (char_length(case_id) <= 40),
  correct    boolean not null,
  created_at timestamptz not null default now()
);

alter table consoltrain.submissions enable row level security;
alter table consoltrain.attempts    enable row level security;

-- 정책 (재실행 안전: drop 후 create)
drop policy if exists "insert submissions" on consoltrain.submissions;
drop policy if exists "select submissions" on consoltrain.submissions;
drop policy if exists "insert attempts"    on consoltrain.attempts;
drop policy if exists "select attempts"    on consoltrain.attempts;

create policy "insert submissions" on consoltrain.submissions
  for insert to anon, authenticated with check (true);
create policy "select submissions" on consoltrain.submissions
  for select to anon, authenticated using (true);
create policy "insert attempts" on consoltrain.attempts
  for insert to anon, authenticated with check (true);
create policy "select attempts" on consoltrain.attempts
  for select to anon, authenticated using (true);

-- 리더보드 뷰 (security_invoker: 호출자 권한으로 base RLS 적용)
create or replace view consoltrain.leaderboard
  with (security_invoker = true) as
select case_idx,
       trainee,
       max(margin) as best_margin,
       max(stars)  as best_stars,
       max(pass)   as best_pass,
       count(*)    as tries
from consoltrain.submissions
group by case_idx, trainee;

-- 케이스별 정답률
create or replace view consoltrain.case_stats
  with (security_invoker = true) as
select case_id,
       count(*) as attempts,
       count(*) filter (where correct) as corrects,
       round(100.0 * count(*) filter (where correct) / nullif(count(*),0), 1) as accuracy_pct
from consoltrain.attempts
group by case_id;

-- 3) AI 벤치마크 수행 결과 (bench.html) — 전략별·케이스별 성과(기준선/분석용)
create table if not exists consoltrain.ai_runs (
  id         bigint generated always as identity primary key,
  strategy   text not null check (char_length(strategy) <= 20),
  case_idx   int  not null check (case_idx between 0 and 20),
  scenario   text not null default 'base' check (char_length(scenario) <= 20),
  avg_margin real not null,
  avg_stars  real not null,
  pass_rate  int  not null check (pass_rate between 0 and 100),
  n          int  not null,
  created_at timestamptz not null default now()
);
alter table consoltrain.ai_runs enable row level security;
drop policy if exists "insert ai" on consoltrain.ai_runs;
drop policy if exists "select ai" on consoltrain.ai_runs;
create policy "insert ai" on consoltrain.ai_runs for insert to anon, authenticated with check (true);
create policy "select ai" on consoltrain.ai_runs for select to anon, authenticated using (true);

-- 케이스별 AI 최고 기준선(이겨야 할 선) — base 시나리오에서 최고 마진 전략
create or replace view consoltrain.ai_baseline
  with (security_invoker = true) as
select distinct on (case_idx)
       case_idx, strategy, avg_margin, avg_stars, pass_rate
from consoltrain.ai_runs
where scenario = 'base'
order by case_idx, avg_margin desc;

-- Data API 노출용 GRANT
grant select, insert on consoltrain.submissions to anon, authenticated;
grant select, insert on consoltrain.attempts    to anon, authenticated;
grant select, insert on consoltrain.ai_runs      to anon, authenticated;
grant select        on consoltrain.leaderboard  to anon, authenticated;
grant select        on consoltrain.case_stats   to anon, authenticated;
grant select        on consoltrain.ai_baseline  to anon, authenticated;
