-- ============================================================
-- 월승치못 게임 DB 스키마 (1차)
-- 적용: Supabase MCP(execute_sql) 또는 Supabase SQL Editor에 붙여넣기
-- 기존: public.signups(id -> auth.users, nickname), public.signup_count() 는 이미 존재
-- 설계 결정:
--   * 더블픽 = 예측 세트 2개(set_no 1,2). 그날 점수 = 더 잘 맞힌 세트
--   * 문제는 미리 draft 로 만들어두고, 그날 published 로 공개
--   * 점수/순위/투표율은 자동 계산. 당첨 추첨은 수동
-- ============================================================

-- 1) 문제 (매일 5개)
create table if not exists public.questions (
  id          bigint generated always as identity primary key,
  match_date  date    not null,
  order_no    int     not null check (order_no between 1 and 5),
  text        text    not null,
  options     text[]  not null,                 -- 예: {'승','무','패'}
  correct     text,                              -- 채점 전엔 null
  status      text    not null default 'draft' check (status in ('draft','published')),
  lock_at     timestamptz,                       -- 투표 마감(킥오프). null이면 마감 없음
  created_at  timestamptz default now(),
  unique (match_date, order_no)
);
alter table public.questions enable row level security;

drop policy if exists "read published questions" on public.questions;
create policy "read published questions" on public.questions
  for select to anon, authenticated
  using (status = 'published');

-- 2) 예측 (유저 x 문제 x 세트)
create table if not exists public.predictions (
  id           bigint generated always as identity primary key,
  user_id      uuid    not null references auth.users on delete cascade,
  question_id  bigint  not null references public.questions on delete cascade,
  set_no       int     not null default 1 check (set_no in (1,2)),
  choice       text    not null,
  created_at   timestamptz default now(),
  unique (user_id, question_id, set_no)
);
alter table public.predictions enable row level security;

drop policy if exists "own predictions select" on public.predictions;
create policy "own predictions select" on public.predictions
  for select to authenticated using (auth.uid() = user_id);

-- 마감(lock_at) 후 또는 미공개 문제엔 insert/update 불가 (공정성)
drop policy if exists "own predictions insert" on public.predictions;
create policy "own predictions insert" on public.predictions
  for insert to authenticated with check (
    auth.uid() = user_id
    and exists (select 1 from public.questions q
                where q.id = question_id and q.status = 'published'
                  and (q.lock_at is null or now() < q.lock_at)));

-- 예측은 1회 제출, 수정 불가 → update 정책 없음(insert만 허용)

-- 3) 그날 점수 = 두 세트 중 더 잘 맞힌 세트의 정답 수 (내부 뷰)
--    security_invoker: 직접 조회 시 RLS 적용(자기 것만), 순위표 함수 안에선 definer 권한으로 전체 집계
create or replace view public.daily_scores with (security_invoker = on) as
select user_id, match_date, max(correct_count) as score
from (
  select p.user_id, q.match_date, p.set_no,
         count(*) filter (where q.correct is not null and p.choice = q.correct) as correct_count
  from public.predictions p
  join public.questions q on q.id = p.question_id
  group by p.user_id, q.match_date, p.set_no
) s
group by user_id, match_date;

-- 본인 기록 조회용(security_invoker라 RLS로 자기 행만 보임)
grant select on public.daily_scores to authenticated;

-- 닉네임 마스킹(공개 화면용): 앞 1글자 + 최대 *** . 본인 행은 호출부에서 원본 사용
create or replace function public.mask_nick(n text) returns text
language sql immutable set search_path = '' as $$
  select case
    when n is null or n = '' then '익명'
    when char_length(n) <= 1 then n
    else left(n, 1) || repeat('*', least(char_length(n) - 1, 3))
  end
$$;

-- 4) 오늘 순위표 (정답 많은 순) - 본인은 원본 닉, 타인은 마스킹
create or replace function public.daily_leaderboard(p_match_date date, p_limit int default 50)
returns table (user_id uuid, nickname text, score bigint)
language sql security definer set search_path = public as $$
  select d.user_id,
         case when d.user_id = auth.uid() then s.nickname else public.mask_nick(s.nickname) end,
         d.score
  from public.daily_scores d
  left join public.signups s on s.id = d.user_id
  where d.match_date = p_match_date
  order by d.score desc nulls last
  limit p_limit
$$;
grant execute on function public.daily_leaderboard(date, int) to anon, authenticated;

-- 5) 주간 누적 순위표 (주: 월요일 시작)
create or replace function public.weekly_leaderboard(p_week_start date, p_limit int default 50)
returns table (user_id uuid, nickname text, total bigint)
language sql security definer set search_path = public as $$
  select d.user_id,
         case when d.user_id = auth.uid() then s.nickname else public.mask_nick(s.nickname) end,
         sum(d.score)::bigint
  from public.daily_scores d
  left join public.signups s on s.id = d.user_id
  where date_trunc('week', d.match_date)::date = p_week_start
  group by d.user_id, s.nickname
  order by 3 desc nulls last
  limit p_limit
$$;
grant execute on function public.weekly_leaderboard(date, int) to anon, authenticated;

-- 6) 실시간 투표율 (모든 세트 합산, 개별 예측은 노출 안 함)
create or replace function public.vote_counts(p_match_date date)
returns table (question_id bigint, choice text, votes bigint)
language sql security definer set search_path = public as $$
  select p.question_id, p.choice, count(*)::bigint
  from public.predictions p
  join public.questions q on q.id = p.question_id
  where q.match_date = p_match_date
  group by p.question_id, p.choice
$$;
grant execute on function public.vote_counts(date) to anon, authenticated;

-- 7) 당첨자 (추첨은 수동: 운영자가 insert)
create table if not exists public.winners (
  id           bigint generated always as identity primary key,
  win_date     date    not null,
  kind         text    not null default 'daily' check (kind in ('daily','weekly')),
  user_id      uuid    references auth.users on delete set null,
  display_name text,                                  -- 계정 없는 과거 당첨자 표기용(마스킹된 값 권장)
  prize        text    not null default '치킨 1마리',
  score        int,
  created_at   timestamptz default now()
);
alter table public.winners enable row level security;
-- 정책 없음: recent_winners(definer)로만 노출. 원본 user_id는 클라이언트에 안 나감

-- 지난 당첨자(공개): 본인은 원본, 타인은 마스킹, 계정없으면 display_name
create or replace function public.recent_winners(p_limit int default 20)
returns table (win_date date, kind text, nickname text, prize text, score int)
language sql security definer set search_path = public as $$
  select w.win_date, w.kind,
         case
           when w.user_id is null then coalesce(w.display_name, '익명')
           when w.user_id = auth.uid() then s.nickname
           else public.mask_nick(s.nickname)
         end,
         w.prize, w.score
  from public.winners w
  left join public.signups s on s.id = w.user_id
  order by w.win_date desc, w.kind
  limit p_limit
$$;
grant execute on function public.recent_winners(int) to anon, authenticated;
