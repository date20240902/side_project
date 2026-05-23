# 월승치못 — 프로젝트 인수인계 노트

새 세션은 이 파일을 먼저 읽고 이어서 작업하세요.

## 한 줄 소개
월드컵 기간 매일 5문제를 **예측**해서 맞히면 **치킨**을 받는 바이럴 예측 게임.
이름 = **월**드컵 **승**부예측 + **치**킨 이건 **못** 참지.

## 현재 단계
- **사전예약 랜딩 = 완성, 배포됨** → `wsmot.vercel.app` (`index.html`)
- **게임(본 서비스) = 개발 시작 단계** (DB부터)

## 기술 스택 / 배포
- 정적 HTML + **Supabase**(DB·Auth) + **카카오 로그인**(Supabase Auth Kakao provider)
- Vercel 배포: production 브랜치 = `claude/worldcup-project-ideas-Y9mt5` (push 하면 자동 배포)
- Supabase 프로젝트 ref: `mgmaibrwapphvgafzdon`, publishable key는 `index.html`에 인라인
- Supabase **MCP 커넥터 연결됨** → 세션에서 `execute_sql` 등으로 DB 직접 조작 가능
- 내 실행환경은 외부 인터넷 차단(curl로 사이트/Supabase 직접 접근 불가) → Supabase는 MCP로

## 카카오 (중요)
- 로그인 scope = `profile_nickname`만 요청해도 Supabase가 email/image까지 강제 → 동의항목 3개 필요
- **이메일 동의는 비즈앱 필요** → 사용자가 **카카오 비즈니스 채널 심사(영업일 3~5일) 신청함, 대기중**
- 심사 통과 후: developers.kakao 앱에 비즈채널 연결 → 비즈앱 전환 → 동의항목(닉네임/프로필/이메일) ON → 로그인 정상 동작
- 채널 프로필 이미지: `channel-profile.html`

## 게임 규칙 (확정)
- 매일 **5문제** 예측: 경기결과(승/무/패), 손흥민 공격포인트(Y/N), 첫 골 시점(전반/후반), PK 선언(Y/N), 관중 난입(Y/N, 잭팟 ~3%). **매일 바뀜.**
- **치킨 풀**: 기본 1마리 + 참여자 500명당 +1마리
- **그날 당첨**: 그날 최다 정답자 중 추첨 1명(동점이면 추첨) → 치킨. **추첨은 수동.**
- **주간**: 누적 정답 1위에게 추가 치킨, 매주 리셋
- **더블 픽**: 카톡 공유하면 **예측 세트를 한 번 더(2세트)**. 그날 점수 = **두 세트 중 더 잘 맞힌 세트**.
  (주의: `worldcup-mockup.html`은 옛 방식 "한 문제에 답 2개"로 구현돼 있어 → 새 방식으로 재작업 필요)
- 추천인 추적은 **안 함**(공유 행동 자체에 보상)
- 정답률·순위·투표율은 데이터로 자동 계산

## 운영 방식 (하이브리드)
- 문제를 **미리 draft로 다 생성**해두고, 그날 **published로 공개**(MCP로)
- 경기 후 **정답 입력**(MCP/Supabase) → 점수·순위 자동, **추첨만 수동**
- 별도 어드민 UI 없음(v1). Supabase + MCP로 운영

## 파일
- `index.html` — 랜딩(레트로/픽셀, DungGeunMo 폰트, 경기장 히어로 SVG). 실시간 참여자수(signup_count), 카카오 로그인 작동
- `db/schema.sql` — 게임 DB 스키마(questions, predictions, daily/weekly leaderboard, vote_counts). **아직 미적용 → MCP로 적용 필요**
- `worldcup-mockup.html` — 앱 화면 목업(옛 더블픽). 게임 개발 시 참고/재작업
- `channel-profile.html` — 카카오 채널 프로필 이미지
- `retro-sample.html` — 레트로 스타일 샘플(참고용)
- `hush-*.html`, `worldcup-main.html` — 구버전/무관

## 기존 DB (이미 있음)
- `public.signups(id uuid PK→auth.users, nickname, created_at)` + 트리거(가입시 자동 insert)
- `public.signup_count()` 함수 (anon 실행 가능) — 랜딩 카운터용

## 다음 할 일 (로드맵)
1. `db/schema.sql` 적용(MCP) → 점검
2. **오늘의 예측 화면** (5문제 풀기·제출, 더블픽 2세트)
3. **결과 화면** (두 세트 채점 + 더 잘 맞힌 세트 표시)
4. **순위표 / 내 기록**
5. 대회 전체 문제 일괄 생성(draft) + 운영 점검
6. 본선 시작일: 루트(`/`)를 게임으로 전환(랜딩은 `/preview`로) + 재배포
