# 회원가입 페이지 - Supabase + GitHub Pages

## 포함 파일
- `index.html` : CSS/JS가 모두 포함된 단일 회원가입 페이지
- `member_signup.sql` : Supabase DB/RLS/Trigger 설정
- `README.md` : 설치 및 운영 안내

## 1. Supabase SQL 실행
Supabase Dashboard → SQL Editor에서 `member_signup.sql` 전체를 실행하세요.

이 SQL은:
- `public.profiles` 회원정보 테이블 생성
- 이메일 UNIQUE
- 개인정보 동의 및 동의시각 기록
- RLS 적용
- 로그인한 회원이 자신의 정보만 조회/수정
- Supabase Auth 가입 시 profile 자동 생성 Trigger
- 기존 정책이 있어도 `drop policy if exists` 후 재생성

## 2. Supabase Auth 설정
Dashboard → Authentication → Providers → Email:
- Email provider: ON
- Confirm email: ON 권장

Confirm email을 켜야 실제로 수신 가능한 이메일인지 이메일 인증으로 검증할 수 있습니다.

## 3. GitHub Pages
`index.html`을 저장소 루트에 두고 Pages로 배포하면 됩니다.

### 환경변수 관련 중요사항
GitHub Pages의 정적 HTML은 서버 환경변수를 직접 읽을 수 없습니다.
따라서 아래처럼 사용할 수 있습니다.

- `window.__SUPABASE_URL__`
- `window.__SUPABASE_PUBLISHABLE_KEY__`

현재 HTML에는 사용자가 제공한 Supabase URL과 publishable key가 기본값으로 들어 있습니다.

publishable key는 브라우저에서 사용하는 공개용 키이므로 HTML에 존재해도 됩니다.
절대로 `service_role` 키를 넣지 마세요.

## 4. 회원가입 흐름
1. 이메일/비밀번호/이름/전화번호 입력
2. 비밀번호 조건 검사
   - 10자 이상
   - 대문자 1개 이상
   - 숫자 1개 이상
   - `! @ $ ^ *` 중 1개 이상
3. 비밀번호 재확인
4. 개인정보 수집·이용 동의 필수
5. Supabase Auth 가입
6. 이메일 인증 메일 발송
7. 인증 완료 후 로그인 가능
8. `profiles`에 이름/전화번호 등 저장

## 5. "임의의 이메일" 검증에 대한 주의
브라우저가 이메일 주소가 실제 존재하는지 100% 판별할 수는 없습니다.
형식 검사는 가능하지만 실제 수신 가능 여부는 이메일 인증으로 검증해야 합니다.

또한 Supabase Auth는 보안을 위해 가입 여부를 외부에 과도하게 노출하지 않는 동작을 할 수 있습니다.
실제 중복은 Auth의 고유 이메일 정책이 최종적으로 처리합니다.

## 6. 다음 개발에서 재사용
이 페이지의 구조를 그대로 복사하고:
- `index.html`만 수정
- Supabase 프로젝트 URL/key 유지
- SQL은 회원 테이블 구조가 바뀔 때만 migration 형태로 추가

게시판/자료실/웹진 등 다른 페이지를 붙일 때는 로그인 상태를 확인한 후
`supabase.auth.getUser()`를 이용해 현재 사용자를 식별하면 됩니다.
