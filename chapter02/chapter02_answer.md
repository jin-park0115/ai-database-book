# Chapter 02 확장 실습 답안 템플릿

> **과제:** 데이터와 DBMS의 기본 개념  
> **사용 방법:** 이 파일을 내려받아 본인의 GitHub 저장소에 `chapter02_answer.md`라는 이름으로 저장한 뒤 실습하면서 바로 작성합니다.  
> **제출 방법:** LMS에는 파일을 직접 업로드하지 않고, **본인 GitHub 저장소의 `chapter02_answer.md` 파일 URL**을 제출합니다.

---

## 제출 전 개인정보 주의

LMS에서 제출자를 확인할 수 있으므로 이 공개 Markdown 파일에 학번이나 실명을 반드시 적을 필요는 없습니다.

```text
GitHub 계정 또는 별칭:
과제 작성일:
사용한 AI 도구:
```

> 실제 비밀번호, API Key, 전체 DB 접속 URL, 개인정보가 포함된 화면은 올리지 않습니다.

---

# 1. PostgreSQL에서 현재 위치 확인

## 1-1. 실행한 SQL

```sql
SELECT version();
SELECT current_database();
SELECT current_user;
SELECT current_schema();
SHOW search_path;
```

## 1-2. 실행 결과 기록

```text
PostgreSQL 버전: PostgreSQL 18.4 on x86_64-windows, compiled by msvc-19.44.35227, 64-bit
현재 데이터베이스: postgres
현재 사용자: postgres
현재 스키마: public
search_path: "$user", public
```

## 1-3. 구조를 내 말로 설명

```text
PostgreSQL은: 오픈 소스 객체-관계형 데이터베이스 관리 시스템

현재 접속한 데이터베이스는: postgreSQL

스키마는: DB안에서 테이블, 데이터의 구조

DBeaver 또는 psql 같은 도구는: 클라이언트가 DB를 다루기 쉽게 보여주는
```

## 1-4. 계층 구조 완성

```text
사용자
→ ____________________
→ PostgreSQL DBMS
→ ____________________
→ ____________________
→ ____________________
→ 행 / 열
```

## 1-5. 증거 화면

권장 경로:

```text
assignments/chapter02/images/step01_environment.png
```

```markdown
![PostgreSQL 현재 위치 확인](./images/step01_environment.png)
```

`여기에 STEP 1 핵심 증거 화면을 삽입하세요.`
![PostgreSQL 버전확인](./images/step01.png)
---

# 2. 데이터베이스 안의 스키마와 테이블 관찰

## 2-1. 스키마 조회 결과

실행한 SQL:

```sql
SELECT schema_name
FROM information_schema.schemata
ORDER BY schema_name;
```

관찰한 스키마 이름 중 3개 이내를 적습니다.

```text
1. pg_category
2. pg_toast
3. practice
4. public
```

### `public`은 무엇인가요?

```text
나의 설명: postgreSQL에 존재하는 모든 DB 사용자를 포함하는 특수한 기본 그룹
```

### 데이터베이스와 스키마는 같은 것인가요?

```text
나의 설명: 아니요, 다른 개념입니다.
```

## 2-2. 현재 보이는 테이블 조회

```sql
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_type = 'BASE TABLE'
  AND table_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY table_schema, table_name;
```

```text
조회된 사용자 테이블 수 또는 눈에 띈 테이블: auth_user

아직 테이블이 거의 없어도 괜찮은 이유: 만들지 않았기 떄문에
```

## 2-3. 관찰 정리

```text
PostgreSQL 서버 안에는 여러 DataBase가 있을 수 있다.
한 데이터베이스 안에는 여러 schema가 있을 수 있다.
스키마 안에는 테이블과 같은 테이블이 존재한다.
```

---

# 3. TEMP TABLE로 테이블·행·열·키 직접 확인

## 3-1. 임시 테이블 생성 완료 확인

- [ v ] `ch02_students` 생성
- [ v ] `ch02_courses` 생성
- [ v ] `ch02_enrollments` 생성

각 테이블의 **한 행 의미**를 적습니다.

| 테이블 | 한 행의 의미 |
| --- | --- |
| `ch02_students` | 학생 한 명  |
| `ch02_courses` | 강의한개 |
| `ch02_enrollments` | 특정 학생이 특정 강의를 신청한 사건 한 건 |

## 3-2. 열의 의미 확인

### `ch02_students`

| 열 | 값의 의미 | 내부 식별자 / 업무 식별자 / 일반 속성 |
| --- | --- | --- |
| `id` | 학생을 DB내부에서 고유하게 식별 | 내부 식별자 |
| `student_number` | 학생의 학번으로 식별하는 값 | 업무 식별자 |
| `name` | 학생의 이름 | 일반 속성 |
| `major` | 학생의 전공 | 일반 속성 |

### `ch02_enrollments`

| 열 | 값의 의미 | PK / FK / 일반 속성 |
| --- | --- | --- |
| `id` | 수강 정보를 DB 내부에서 고유하게 식별하는 값 | PK |
| `student_id` | 수강하는 학생을 가리키는 학생 ID | FK |
| `course_id` | 수강하는 과목을 가리키는 과목 ID | FK |
| `status` | 해당 과목의 수강 상태 | 일반 속성 |

## 3-3. 입력된 행 수

```text
students 행 수: 4
courses 행 수: 3
enrollments 행 수: 4
```

## 3-4. 내부 식별자와 업무 식별자

```text
students.id가 필요한 이유: 학생 한 명을 고유하게 식별하기 위해서

student_number가 필요한 이유: 학생을 실제 학번으로 식별하기 위해서

둘을 항상 같은 값으로 사용하지 않아도 되는 이유: DB에서 목적이 다르기 때문에
```

## 3-5. 숫자처럼 보이는 학번을 문자열로 저장한 이유

```text
나의 설명: 학번에 - 하이픈이 들어갈 수 있기 떄문에
```

---

# 4. 테이블과 조회 결과는 다르다

## 4-1. 원본 테이블 행 수

```text
ch02_students 전체 행 수: 3
```

## 4-2. 일부 열만 조회

실행 SQL:

```sql
SELECT name, major
FROM ch02_students
ORDER BY id;
```

```text
원본 테이블의 열 수와 조회 결과의 열 수가 다른 이유: select로 조회를 2개 컬럼만 조회했으므로
```

## 4-3. 조건을 적용한 조회

실행 SQL:

```sql
SELECT id, student_number, name, major
FROM ch02_students
WHERE major = '컴퓨터공학'
ORDER BY id;
```

```text
원본 테이블 행 수: 4
조회 결과 행 수: 4
원본 테이블의 데이터가 삭제된 것인가?: 아니요
그렇게 판단한 이유: 조회만 그렇게 해서
```

## 4-4. 정렬 결과 비교

```sql
SELECT id, name
FROM ch02_students
ORDER BY name ASC;

SELECT id, name
FROM ch02_students
ORDER BY name DESC;
```

```text
ASC 결과의 첫 학생: 김민지
DESC 결과의 첫 학생: 이준호

이 실험을 통해 ORDER BY에 대해 알게 된 점: asc는 오름차순 desc는 내림차순
```

## 4-5. 증거 화면

권장 경로:

```text
assignments/chapter02/images/step04_result_set.png
```

`여기에 STEP 4 핵심 증거 화면을 삽입하세요.`
![PostgreSQL 버전확인](./images/step02.png)
---

# 5. PK와 FK를 실제로 관찰

## 5-1. 정상 데이터의 관계 읽기

다음 SQL 결과를 보고 작성합니다.

```sql
SELECT
    e.id AS enrollment_id,
    s.name AS student_name,
    c.title AS course_title,
    e.status
FROM ch02_enrollments AS e
JOIN ch02_students AS s
    ON s.id = e.student_id
JOIN ch02_courses AS c
    ON c.id = e.course_id
ORDER BY e.id;
```

```text
한 행이 의미하는 것: 학생이 강의를 신청/수강 중/ 완료

같은 student_id가 여러 enrollment 행에서 반복될 수 있는 이유: 학생은 강의를 여러개 들을 수 있다

같은 course_id가 여러 enrollment 행에서 반복될 수 있는 이유: 강의는 여러 학생들이랑 관계가 가능
```

## 5-2. 기본키 중복 오류 관찰

중복 PK 입력을 시도한 결과: SQL Error [23505]: 오류: 중복된 키 값이 "ch02_students_pkey" 고유 제약 조건을 위반함
  세부 정보: (id)=(1) 키가 이미 있습니다.

```text
실행 성공 / 실패: 실패
오류 메시지에서 확인한 핵심 단어: 중복된 키 값이 고유 제약 조건을 위반함 id = 1 키가 이미 있음
왜 실패했다고 생각하는가: id는 primarykey로 오직 하나여야 하는데 1로 추가하려 했기 떄문에
```

## 5-3. 존재하지 않는 학생을 참조하는 FK 오류 관찰

존재하지 않는 `student_id`를 사용한 수강신청 입력 결과: SQL Error [23503]: 오류: "ch02_enrollments" 테이블에서 자료 추가, 갱신 작업이 "ch02_enrollments_student_id_fkey" 참조키(foreign key) 제약 조건을 위배했습니다
  세부 정보: (student_id)=(999) 키가 "ch02_students" 테이블에 없습니다.

Error position:

```text
실행 성공 / 실패: 실패
오류 메시지에서 확인한 핵심 단어: 참조키 제약 조건을 위배했다.
왜 실패했다고 생각하는가: student_id의 키가 없기 때문에
```

## 5-4. PK와 FK의 차이 정리

```text
PK는 테이블 내의 각 레코드를 고유하게 식별 하기 위한 키이다.

FK는 다른 테이블과의 연관 관계를 맺고 참조 무결성 하기 위한 키이다.

FK 값이 여러 행에서 반복될 수 있는 이유는 자식 테이블의 여러 레코드가 부모 테이블의 동일한 레코드를 참조하는 일대다 관계를 표현하기 때문이다.
```

## 5-5. 증거 화면

권장 경로:

```text
assignments/chapter02/images/step05_pk_fk.png
```

> 오류 메시지는 전체 화면이 아니라 테이블명·constraint·참조 오류가 보이는 정도만 캡처합니다.

`여기에 STEP 5 핵심 증거 화면을 삽입하세요.`
![PostgreSQL 실행 환경 확인](./images/step03.png)
---

# 6. 관계와 카디널리티를 자연어로 설명

현재 임시 데이터 기준으로 작성합니다.

```text
학생 한 명은 여러 수강신청을 가질 수 있는가?: 학생 한명을 여러 수강 신청을 가질 수 있다.

강의 한 개는 여러 수강신청을 가질 수 있는가?: 강의 한 개는 여러 수강신청을 가질 수 있다.

수강신청 한 건은 학생 몇 명을 참조하는가?: 3명

수강신청 한 건은 강의 몇 개를 참조하는가?: 5개
```

아래 구조를 완성합니다.

```text
students 1 ── ______ N enrollments N ______ ── 1 courses
```

### 학생과 강의가 N:M 관계라고 볼 수 있는 이유

```text
나의 설명: 학생은 여러 강의를 들을 수 있고, 강의도 여러 학생을 가질 수 있다.
```

> 아직 0개 허용 여부, 필수 관계, 삭제 정책까지 확정하지 않습니다. 그런 규칙은 Chapter 05~06에서 다룹니다.

---

# 7. AI가 만든 테이블 구조 직접 검토

## 7-1. AI에게 묻기 전에 내가 먼저 찾은 문제

다음 구조를 보고 최소 4개를 적습니다.

```sql
CREATE TABLE student_courses (
    student_name VARCHAR(50),
    student_email VARCHAR(100),
    course_title VARCHAR(100),
    instructor_name VARCHAR(50)
);
```

```text
문제 1. 이 테이블의 한 행은 무엇을 의미하나
문제 2. 각 행을 안정적으로 구분하는 PK가 있는가
문제 3. 학생.강의.강사를 이름 문자열로만 연결해도 되는가
문제 4. 서로 다른 종류의 현재 정보와 사건 정보가 섞여 있지 않은가
```

## 7-2. AI 검토 요청 프롬프트

사용한 핵심 프롬프트를 기록합니다.

```text
정규화와 ERD를 정식으로 배우기 전입니다. 테이블 구조를 검토해주세요.
```

## 7-3. AI 제안과 나의 판단

| AI의 지적 또는 제안 | 동의 / 수정 / 보류 | 나의 근거 |
| --- | --- | --- |
| 한 행의 의미가 명확하지 않다 | 동의 | 테이블 생성 쿼리문에 수강 중이라는 의미가 없다 |
| PK 후보가 필요한가 | 동의 | 같은 행이 들어오게 되면 서로 같은 기록인지 다른 기록인지 구분하기 어렵다 |
| 중복 저장 위험이 있는가? | 동의 | 학생이 3개의 강의를 듣는다면 학생의 이름과 이메일이 계속 반복된다. |


## 7-4. 본문과 대조한 항목

AI 설명 중 최소 하나를 `chapter02.md`와 비교합니다.

```text
AI가 설명한 내용: FK는 형상 고유할 필요가 없어. 오히려 FK는 중복되는 경우가 매우 많아.

본문에서 확인한 내용: FK 값은 1:N 관계에서 반복될 수 있고 자동으로 UNIQUE가 되지 않는다.


일치 / 부분 일치 / 수정 필요: 일치

내가 최종적으로 이해한 내용: FK는 항상 고유할 필요가 없고 자동으로 UNIQUE가 되지 않는다.
```

## 7-5. 증거 화면

권장 경로:

```text
assignments/chapter02/images/step07_ai_review.png
```

`여기에 AI 검토 과정의 핵심 화면을 삽입하세요.`
![AI검토 확인](./images/step03.png)
---

# 8. Chapter 01의 개인 서비스 아이디어를 DB 용어로 다시 표현

Chapter 01에서 정한 개인 서비스 주제를 그대로 사용하거나 새 주제를 정해도 됩니다.

## 8-1. 서비스 기본 정보

```text
서비스 이름: FastOrder
서비스 목적: 카페 주문하기 서비스
```

## 8-2. PostgreSQL 구조 후보

```text
데이터베이스 이름 후보: fastorder, fastorder_db, cafe_order, fastorder_service
스키마 이름 후보: public, fastorder, cafe
```

> 아직 실제 데이터베이스나 스키마를 생성하지 않아도 됩니다.

## 8-3. 테이블 후보와 한 행 의미

최소 3개를 작성합니다.

| 테이블 후보 | 한 행의 의미 | 내부 ID 후보 | 업무 식별자 후보 |
| --- | --- | --- | --- |
| users | 등록된 특정 회원 1명의 정보 | user_id | 회원번호 |
| menus | 카페에서 판매하는 특정 단품 메뉴 1개의 정보 | menu_id | 메뉴 번호 |
| options | 메뉴에 추가할 수 있는 특정 옵션 종류 1개의 정보 | option_id | 옵션 번호 |

## 8-4. FK 후보

```text
1.  orders.user_id → users.user_id
   이유: 한 회원이 여러 주문을 할 수 있고, 각 주문은 특정 회원에게 속하기 때문.

2.  order_items.order_id → orders.order_id
   이유: 하나의 주문에는 여러 주문 상세가 포함되고, 각 주문 상세는 하나의 주문에 속하기 때문.

3. order_items.menu_id → menus.menu_id
   이유: 하나의 메뉴는 여러 주문 상세에서 선택될 수 있고, 각 주문 상세는 하나의 메뉴를 가리키기 때문.
```

## 8-5. 자연어 관계 문장

```text
1. 한 회원은 여러 번 주문할 수 있지만, 한 주문은 한 회원에게 속합니다. (1:N)
2. 한 주문에는 여러 개의 주문 상세가 포함될 수 있지만, 한 주문 상세는 하나의 주문에만 포함됩니다. (1:N)
3. 하나의 메뉴는 여러 주문 상세에서 선택될 수 있지만, 한 주문 상세는 하나의 메뉴를 가리킵니다. (1:N)
4. 하나의 주문 상세에는 여러 옵션을 선택할 수 있고, 하나의 옵션도 여러 주문 상세에서 선택될 수 있습니다. (N:M)
   → 주문 옵션 상세 테이블을 통해 관계를 관리합니다.
```

## 8-6. 아직 확정하지 않을 정책

```text
Q1. 비회원 주문 허용 여부: 회원가입 없이 주문하는 비회원 주문을 허용할 것인가? (허용 시 주문 테이블의 회원 번호가 NULL 가능해짐)
Q2. 메뉴 가격 변동 처리: 추후 메뉴 가격이 인상되면 이전 주문 내역의 결제 금액도 영향을 받는가? (방지하기 위해 주문 상세에 '주문 당시 가격'을 별도 저장할지 여부)
Q3. 옵션의 메뉴별 종속성: '샷 추가' 같은 옵션을 모든 메뉴에 다 적용할 수 있게 할 것인가, 음료/디저트 등 카테고리별로 선택 가능한 옵션을 제한할 것인가?
Q4. 주문 취소 및 환불 정책: 제조가 시작된 단계(제조 중)에서도 고객이 주문을 취소할 수 있게 허용할 것인가?
Q5. 포인트 적립/사용 기준: 결제 금액의 몇 %를 적립할 것이며, 얼마 이상부터 현금처럼 사용할 수 있게 할 것인가?
```

---

# 9. AI를 개인 구조의 검토자로 사용

## 9-1. 사용한 프롬프트

```text
나는 PostgreSQL과 데이터베이스를 처음 배우는 학생입니다.

아직 정규화와 ERD를 정식으로 배우기 전이므로, 어려운 전문 용어를 전제로 설명하지 말고 기초 개념 → 예시 → 개념 간 차이 순서로 설명해 주세요.

다음 질문들을 하나의 학습 자료처럼 설명해 주세요.
```

## 9-2. AI가 질문한 내용 중 유용했던 것

```text
1. FK는 단순히 "다른 테이블의 값을 복사해서 저장하는 것"과 어떻게 다른가?
2. 내부 ID와 업무 식별자가 반드시 같은 값일 필요가 없는 이유
3. Table의 Row vs 조회 결과의 Row
```

## 9-3. AI가 너무 빨리 결정한 내용 또는 내가 보류한 내용

```text
1.
2.
```

## 9-4. 검토 후 수정한 구조

| 수정 전 | 수정 후 | 수정 이유 |
| --- | --- | --- |
|  |  |  |
|  |  |  |
|  |  |  |

---

# 10. 최종 개념 정리

아래 문장을 본인의 말로 완성합니다.

```text
PostgreSQL은 RDBMS중 하나 이다.

DBeaver 또는 psql은 사용자가 DB를 편하게 쓸 수 있는 어플리케이션 이다.

데이터베이스와 스키마의 차이는 DB는 저장하고 관리 스키마는 DB 안에서 테이블 등을 논리적으로 묶어 관리하는 영역 이다.

테이블 한 행은 하나의 데이터 대상을 나타낸다.

조회 결과가 원본 테이블과 다른 이유는 조회 조건 때문이다.

내부 식별자와 업무 식별자의 차이는 DB내부에서 데이터를 구분하기 위한 값이고 업무식별자는 업무 에서 대상을 식별하기 위한 값 이다.

PK는 테이블의 각 row를 고유하게 식별한다.

FK는 다른 테이블의 PK를 참조한다.
```

---

# 11. 이번 Chapter에서 새롭게 알게 된 점

최소 3개를 작성합니다.

```text
1. 내부 식별자와 업무 식별자
```

## 아직 헷갈리는 내용

```text
1.
2.
```

## AI에게 다시 질문하고 싶은 내용

```text

```

---

# 12. 제출 전 자기 점검

- [ v ] PostgreSQL에서 현재 database / schema / search_path를 확인했다.
- [ v ] DBMS, database, schema, table을 구분해서 설명할 수 있다.
- [ v ] TEMP TABLE 3개를 생성하고 직접 데이터를 조회했다.
- [ v ] 각 테이블의 한 행 의미를 작성했다.
- [ v ] 테이블과 조회 결과가 다르다는 것을 실제 SQL로 확인했다.
- [ v ] `ORDER BY`를 사용하지 않으면 업무 순서를 가정하면 안 된다는 점을 이해했다.
- [ v ] 내부 식별자와 업무 식별자의 차이를 설명할 수 있다.
- [ v ] PK 중복 입력 실패를 직접 확인했다.
- [ v ] 존재하지 않는 FK 참조 실패를 직접 확인했다.
- [ v ] FK 값이 반복될 수 있는 이유를 설명할 수 있다.
- [ v ] AI가 만든 테이블을 내가 먼저 검토했다.
- [ v ] AI 설명 중 최소 하나를 본문과 대조했다.
- [ v ] 개인 서비스의 테이블 후보를 3개 이상 작성했다.
- [ v ] 개인 서비스의 FK 후보와 미확정 정책을 기록했다.
- [ v ] 실제 비밀번호·API Key·민감한 접속 정보가 포함되지 않았는지 확인했다.
- [ v ] 이미지 링크가 GitHub에서 정상적으로 보이는지 확인했다.

---

# 13. GitHub 제출 정보

답안 파일 권장 위치:

```text
assignments/chapter02/chapter02_answer.md
```

이미지 권장 위치:

```text
assignments/chapter02/images/
```

LMS 제출 URL 형식:

```text
https://github.com/jin-park0115/ai-database-book/tree/main/chapter02
```

## 최종 확인

- [ v ] 위 URL을 로그아웃 상태 또는 다른 브라우저에서 열어도 확인 가능하다.
- [ v  ] Markdown이 정상 렌더링된다.
- [ v ] 이미지가 깨지지 않는다.
- [ ] LMS에 교수자 템플릿 URL이 아니라 **내 답안 파일 URL**을 제출했다.