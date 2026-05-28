-- ============================================================
-- signups에 전화번호 컬럼 추가
-- 적용: Supabase SQL Editor에 붙여넣고 실행
-- 흐름: 카카오 로그인(전화번호 필수 동의) 직후, 클라이언트가
--       provider_token으로 https://kapi.kakao.com/v2/user/me 를 호출해
--       kakao_account.phone_number 를 받아 본인 signups 행에 저장한다.
-- 형식: '01012345678' 로 정규화하여 저장
-- 권한: 기존 signups update RLS(자기 행 수정)로 그대로 동작 (별도 정책 불필요)
-- ============================================================

alter table public.signups add column if not exists phone text;
