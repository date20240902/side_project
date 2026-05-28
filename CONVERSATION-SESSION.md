# 월승치못 — Kakao 개인정보 수집 정책 정리 세션

**Date:** 2026-05-26  
**Topic:** 개인정보 수집 항목 단순화 (프로필사진/이메일 제거, 닉네임+전화번호만)  
**Status:** ✅ 완료

---

## 세션 배경

- 기존 계획: 카카오 로그인으로 프로필사진, 이메일 등을 선택 수집하려 함
- 실제 필요: 닉네임(순위 표시) + 전화번호(경품 발송) **만** 필요
- 변경 이유: 비즈니스 로직 단순화, 심사 진행 중

---

## 주요 결정사항

### 1. 개인정보 수집 항목 재정의

**필수 수집 (카카오 로그인 시):**
- ✅ 닉네임 — 회원 식별, 순위(리더보드) 표시, 닉네임 표시
- ✅ 전화번호 — 경품(치킨 기프티콘) 당첨 시 발송, 본인 확인

**제외 (수집하지 않음):**
- ❌ 프로필 사진
- ❌ 이메일

**근거:** 당첨 시 나중에 전화번호를 달라고 하면 보이스피싱으로 의심받을 수 있으니, 처음부터 받는 게 진입장벽도 낮고 신뢰성도 높음.

---

## 수정된 파일 목록

### 1. `privacy.html` (개인정보 처리방침)
```html
<!-- BEFORE -->
<tr><td>필수</td><td>카카오 닉네임, 프로필 이미지, 이메일, 전화번호</td><td>카카오 로그인 시</td></tr>
<tr><td>자동 생성</td><td>예측 기록, 정답/점수, 접속 일시</td><td>서비스 이용 시</td></tr>

<!-- AFTER -->
<tr><td>필수</td><td>카카오 닉네임</td><td>카카오 로그인 시</td><td>회원 식별, 서비스 내 닉네임 표시, 순위 표기</td></tr>
<tr><td>필수</td><td>전화번호</td><td>카카오 로그인 시</td><td>경품(기프티콘) 발송, 본인 확인</td></tr>
<tr><td>자동 생성</td><td>예측 기록, 정답/점수, 접속 일시</td><td>서비스 이용 시</td><td>예측 결과 관리, 순위 산정</td></tr>
```

**변경사항:**
- 프로필 이미지, 이메일 제거
- 전화번호를 "경품 당첨 시"에서 "카카오 로그인 시"로 변경
- 수집 목적(目的) 컬럼 추가

### 2. `terms.html` (이용약관)
```html
<!-- BEFORE -->
<li>당첨자에게는 카카오톡 기프티콘으로 경품을 발송하며, 기프티콘 발송을 위해 전화번호를 요청합니다.</li>

<!-- AFTER -->
<li>당첨자에게는 카카오톡 기프티콘으로 경품을 발송하며, 가입 시 수집한 전화번호를 이용합니다.</li>
```

### 3. `signup-scenario.html` (회원가입 시나리오 — Kakao 심사용)
```html
<!-- 수집 항목 테이블 -->
<tr><td>닉네임</td><td class="req">필수</td><td>회원 식별, 서비스 내 닉네임 표시, 순위(리더보드) 표기</td></tr>
<tr><td>전화번호</td><td class="req">필수</td><td>경품(치킨 기프티콘) 당첨 시 발송, 본인 확인</td></tr>

<!-- 제거됨 -->
<!-- 프로필 사진 (선택) -->
<!-- 카카오계정(이메일) (선택) -->
<!-- 경품 발송 시 추가 정보 수집 섹션 제거 (이미 로그인 시 수집하므로) -->
```

### 4. `preview.html` (사전예약 랜딩)

**FAQ 수정:**
```html
<!-- BEFORE -->
<div class="faq-q">개인정보 어디까지 받나요?</div>
<div class="faq-a">본 서비스 로그인 시 카카오 닉네임을 받아요. 경품 당첨 시에만 치킨 기프티콘 발송을 위해 전화번호를 요청합니다...</div>

<!-- AFTER -->
<div class="faq-q">개인정보 어디까지 받나요?</div>
<div class="faq-a">본 서비스 로그인 시 카카오 닉네임과 전화번호를 받아요. 닉네임은 순위 표기에, 전화번호는 경품(치킨 기프티콘) 발송에 사용합니다...</div>
```

**OAuth Scope 수정:**
```javascript
/* BEFORE */
options: { scopes: 'profile_nickname', redirectTo: window.location.origin + '/preview' }

/* AFTER */
options: { scopes: 'profile_nickname phone_number', redirectTo: window.location.origin + '/preview' }
```

### 5. `index.html` (게임 본체)

**OAuth Scope 수정:**
```javascript
/* BEFORE */
options: { scopes: 'profile_nickname plusfriends', redirectTo: ... }

/* AFTER */
options: { scopes: 'profile_nickname phone_number plusfriends', redirectTo: ... }
```

> **Note:** `plusfriends` 유지 — 카카오톡 채널 추가 여부 확인용 (개인정보 동의항목과 별개)

### 6. `worldcup-mockup.html` (옛날 목업)

```html
<!-- BEFORE -->
프로필 닉네임 · 프로필 이미지만 가져옵니다.

<!-- AFTER -->
닉네임 · 전화번호만 가져옵니다.
```

---

## Kakao 콘솔 설정 체크리스트

### 1️⃣ 동의항목 설정 (필수)

**위치:** 제품 설정 → 카카오 로그인 → 동의항목

| 항목 | 상태 | 동의 유형 | 수집 목적 |
|------|------|----------|----------|
| 닉네임 (profile_nickname) | ✅ 활성 | 필수 동의 | 회원 식별, 서비스 내 닉네임 표시, 순위 표기 |
| 전화번호 (phone_number) | ⏳ 심사 중 | 필수 동의 | 경품(치킨 기프티콘) 당첨 시 발송, 본인 확인 |
| 프로필 사진 (profile_image) | 🔲 사용 안 함으로 변경 | — | — |
| 카카오계정(이메일) (account_email) | 🔲 사용 안 함으로 변경 | — | — |

### 2️⃣ Redirect URI 설정 (긴급)

**위치:** 제품 설정 → 카카오 로그인 → 웹 → 플랫폼 키

**현재 에러:** KOE006 (Redirect URI 미등록)

```
https://mgmaibrwapphvgafzdon.supabase.co/auth/v1/callback
```

↑ 이 주소를 Redirect URI 목록에 추가해야 함

---

## 에러 이력

### KOE205 (동의항목 미설정)
- **원인:** account_email, profile_image, profile_nickname이 카카오 콘솔에서 "사용 안 함" 상태였음
- **해결:** 닉네임은 활성화, 전화번호 심사 신청, 프로필사진/이메일은 "사용 안 함" 유지

### KOE006 (Redirect URI 미등록)
- **원인:** Supabase callback URL이 카카오 콘솔 플랫폼 키에 등록되지 않음
- **해결:** Redirect URI 목록에 `https://mgmaibrwapphvgafzdon.supabase.co/auth/v1/callback` 추가

---

## Git 커밋 이력

| Commit | Message |
|--------|---------|
| 68f6514 | Add Kakao signup scenario page for biz app review |
| f888a78 | Update personal data collection to nickname + phone-on-win |
| 7dbf541 | Revise: collect nickname + phone at login (not on win) |
| a230a9c | Collect only nickname + phone (drop profile image, email) |

---

## 다음 단계

### 즉시 필요 (코드 배포됨)
1. ✅ 카카오 콘솔 동의항목 설정 정리
   - 닉네임: 필수 동의 (이미 활성)
   - 전화번호: 필수 동의 (심사 진행 중 — 승인 대기)
   - 프로필사진: **사용 안 함으로 변경**
   - 이메일: **사용 안 함으로 변경**

2. ✅ Redirect URI 등록
   - 플랫폼 키 설정에서 Supabase callback URL 추가

### 전화번호 심사 승인 후
3. 사전예약 페이지(preview.html)에서 Kakao 로그인 테스트
4. 완료 모달 동작 확인 (채널 추가/공유/다음에 버튼)
5. 카카오톡 채널 추가 후 푸시 수신 테스트

### 게임 오픈 전
6. 테스트 모드(`#test-join`) 제거
7. 데모 문제들을 본선 문제로 교체
8. 순위 및 경품 로직 최종 검증

---

## 참고 문서

- **개인정보 처리방침:** https://wsmot.vercel.app/privacy
- **이용약관:** https://wsmot.vercel.app/terms
- **회원가입 시나리오:** https://wsmot.vercel.app/signup-scenario
- **사전예약 랜딩:** https://wsmot.vercel.app/preview
- **게임 본체:** https://wsmot.vercel.app/

---

**Session End Time:** 2026-05-26
