# Chapter 09 확장 실습 답안 템플릿

> **과제:** 트랜잭션으로 데이터 정합성 지키기  
> **사용 방법:** 이 파일을 내려받아 본인의 GitHub 저장소에 `chapter09_answer.md`라는 이름으로 저장한 뒤 실습하면서 바로 작성합니다.  
> **제출 방법:** LMS에는 파일을 직접 업로드하지 않고, **본인 GitHub 저장소의 `chapter09_answer.md` 파일 URL**을 제출합니다.

---

## 제출 전 주의

이 파일과 캡처 화면에는 실제 비밀번호, 전체 DB 접속 URL, API Key, 개인정보를 기록하지 않습니다.

```text
GitHub 계정 또는 별칭:
과제 작성일:
사용한 AI 도구:
```

---

# 1. 시작 환경과 Chapter 07·08 기준 상태 확인

다음을 실행하거나 Chapter 09의 `01_transaction_lab_schema.sql` 사전 검사를 확인합니다.

```sql
SELECT current_database();
SELECT current_user;
SELECT current_schema();
SHOW search_path;
SHOW transaction_read_only;
```

| 확인 항목 | 실제 결과 | 의미 |
| --- | --- | --- |
| `current_database()` | ai_database_book |  |
| `current_user` | postgres |  |
| `current_schema()` | transaction_lab |  |
| `search_path` | transaction_lab, "$user", public |  |
| `transaction_read_only` | off |  |

Chapter 07·08 기준값:

```text
students = 3
instructors = 2
courses = 3
enrollments = 5
전체 recorded_amount = 590000
활성 = 3 / 340000
취소 제외 = 4 / 440000
```

### 기준 상태가 다르면 Chapter 09를 계속 진행하면 안 되는 이유

```text
Chapter 09의 검증 스크립트(01~08)는 모두 Chapter 07·08에서 만든 course_project 데이터
(학생 3명, 강사 2명, 강의 3개, 신청 5건, 전체 금액 590000 / 활성 340000 / 취소 제외 440000)를
전제로 remaining_seats나 기대 검증식을 계산한다. 기준 상태가 다르면 좌석 초기값과
검증 조건 자체가 틀어져, 실습 중 나오는 실패 메시지가 트랜잭션 개념 오류 때문인지
데이터 불일치 때문인지 구분할 수 없다. 또한 잘못된 기준 위에서 COMMIT을 반복하면
course_project 쪽 과제 데이터까지 되돌릴 수 없이 오염될 수 있으므로, 기준이 다르면
Chapter 07·08 상태를 먼저 복구한 뒤 Chapter 09를 시작해야 한다.
```

---

# 2. `transaction_lab` 스키마 생성

실행 파일:

```text
code/chapter09/01_transaction_lab_schema.sql
```

## 2-1. 생성 전 예상

```text
생성될 스키마: transaction_lab 
생성될 테이블 3개: course_inventory, enrollments, payments

course_inventory 한 행의 의미: 강의(course_id) 하나가 이번 실습에서 제공하는 총 좌석 수(capacity)와
지금 남아 있는 좌석 수(remaining_seats)를 나타내는 재고 행
enrollments 한 행의 의미: 학생 한 명이 강의 한 건을 신청(또는 취소)한 사건 한 건.
student_id·course_id·status·recorded_amount로 "누가 무엇을 얼마에 신청했는지"를 기록
payments 한 행의 의미: 특정 enrollment 한 건에 대응하는 결제 기록 한 건(1:1). enrollment_id로
신청과 연결되어, 신청 당시 금액(recorded_amount)과 실제 결제 금액(amount)이 같은지 확인하는 기준이 됨
```

## 2-2. 생성 결과

```text
통과 메시지:
```

기대 메시지:

```text
Chapter 09 transaction lab schema validation passed
```

### Chapter 07·08의 `course_project`와 별도 `transaction_lab`을 사용하는 이유

```text
course_project는 Chapter 07·08에서 이미 검증을 마친 과제 제출 데이터다. 이번 장에서
COMMIT/ROLLBACK, 좌석 부족, Lock 대기 같은 실습을 반복하다 보면 실수로 행을 지우거나
금액을 바꿀 위험이 있는데, 그 대상이 course_project라면 이전 과제 결과가 손상된다.
transaction_lab을 별도 스키마로 분리하면 course_inventory처럼 반복적으로 증가·감소시키는
좌석 데이터를 마음껏 만들고 되돌릴 수 있고, 06_transaction_validation.sql에서
course_project 쪽 기준값(행 수 5, 금액 590000 등)이 그대로인지 매번 다시 확인해
두 영역이 서로 침범하지 않았음을 증명할 수 있다.
```

### 증거 화면

권장 경로:

```text
assignments/chapter09/images/step02_schema.png
```

![transaction_lab 스키마 생성 코드](images/step01.png)
_(transaction_lab 스키마는 이전에 이미 생성되어 있어서, 생성 결과 화면 대신 생성 코드만 캡처했습니다.)_

---

# 3. 초기 좌석과 기준 데이터 입력

실행 파일:

```text
code/chapter09/02_transaction_lab_seed.sql
```

## 3-1. 실행 전 예상

```text
course 301 remaining_seats 예상: 2
course 302 remaining_seats 예상: 1
course 303 remaining_seats 예상: 1
lab enrollments 예상 행 수: 1
payments 예상 행 수: 1
```

## 3-2. 실제 결과

```text
course 301 remaining_seats: 1
course 302 remaining_seats: 1
course 303 remaining_seats: 1
lab enrollments 행 수: 1
payments 행 수: 1
통과 메시지: 
```

기대 초기 상태:

```text
course 301 / 302 / 303 remaining_seats = 3 / 0 / 0
lab enrollments = 0
payments = 0
```

### 예상과 실제가 다른 경우 원인

```text
[참고] 위 3-2 실제 결과는 course 301 remaining_seats=1, lab enrollments=1, payments=1로
기록되어 있는데, 이는 02_transaction_lab_seed.sql만 실행한 직후 값(301=2, enrollments=0,
payments=0)이 아니라 03_commit_transaction.sql(학생 101의 강의 301 신청)까지 이미 실행된
뒤의 상태와 일치합니다. 즉 스크립트를 하나씩 실행할 때마다 기록하지 않고 이후 단계까지
진행한 다음 이 표를 채운 것으로 보입니다. 순수한 02 실행 직후 상태를 다시 확인하려면
transaction_lab을 초기화하고 01→02만 실행한 뒤 이 표를 채워야 합니다.
(실제 원인이 다르다면 본인이 실행한 순서를 기준으로 이 설명을 수정하세요.)
```

---

# 4. 첫 번째 정상 COMMIT 추적

실행 파일:

```text
code/chapter09/03_commit_transaction.sql
```

이 실습은 학생 101이 강의 301을 신청하는 하나의 업무 단위를 추적합니다.

## 4-1. 업무 단위 정의

```text
이 트랜잭션에서 함께 성공해야 하는 변경 1:
변경 2:
변경 3:

하나라도 실패하면 전체를 취소해야 하는 이유:
```

## 4-2. 상태 변화 기록

| 시점 | course 301 남은 좌석 | lab enrollment 9001 | payment 9901 | 설명 |
| --- | ---: | --- | --- | --- |
| BEGIN 전 | 2 | 없음 | 없음 | 02 시드 직후 초기 상태(스크립트 사전 검증 조건: remaining_seats=2) |
| 트랜잭션 내부 | 1 (미확정) | 존재 (수강중, 미확정) | 존재 (미확정) | UPDATE·INSERT는 실행됐지만 COMMIT 전이라 다른 세션에는 보이지 않음 |
| COMMIT 후 | 1 (확정) | 존재 (수강중, 확정) | 존재 (확정) | COMMIT으로 세 변경이 동시에 영구 반영됨 |

## 4-3. COMMIT 조건

```text
좌석 UPDATE 기대 영향 행 수: 1 (course_id=301, remaining_seats > 0 조건을 만족하는 행 1개)
실제 영향 행 수:
신청 생성 기대 행 수: 1 (enrollment id 9001)
결제 생성 기대 행 수: 1 (payment id 9901)
recorded_amount와 payment.amount 일치 여부: 일치해야 함 (둘 다 courses.price=100000에서 복사되므로 같아야 함)
최종 COMMIT 판단: 위 기대값이 실제 결과와 모두 일치하면 COMMIT, 하나라도 다르면 COMMIT 이전에 ROLLBACK
```

기대 메시지:

```text
Chapter 09 first commit validation passed
```

### SQL 오류가 없었다는 사실만으로 COMMIT하면 안 되는 이유

```text
SQL이 오류 없이 실행됐다는 것은 문법과 제약조건을 어기지 않았다는 뜻일 뿐, 업무 규칙
(좌석이 실제로 줄었는지, 신청 금액과 결제 금액이 같은지)까지 지켰다는 보장은 아니다.
예를 들어 UPDATE ... WHERE remaining_seats > 0은 조건을 만족하는 행이 없어도 오류 없이
"0 UPDATE"로 성공 처리된다. 그래서 03_commit_transaction.sql은 COMMIT 직전에 별도의
DO 블록으로 좌석·신청·결제가 기대한 값과 정확히 일치하는지 다시 확인한 뒤에만 COMMIT하고,
그렇지 않으면 RAISE EXCEPTION으로 트랜잭션을 중단시킨다.
```

### 증거 화면

권장 경로:

```text
assignments/chapter09/images/step04_commit.png
```

![트랜잭션 시작과 신청·결제 INSERT](images/step02.png)

![신청·결제 반영 확인](images/step03.png)
---

# 5. ROLLBACK으로 전체 원상복구 확인

실행 파일:

```text
code/chapter09/04_rollback_transaction.sql
```

## 5-1. ROLLBACK 전 예상

```text
트랜잭션 안에서 임시로 바뀔 값: course 302 remaining_seats 1→0, enrollment 9002(학생 102/수강중/120000), payment 9902(120000)
ROLLBACK 후 다시 돌아와야 할 값: course 302 remaining_seats 0→1(원래대로), enrollment 9002·payment 9902는 존재하지 않는 상태로 복귀
이미 이전 파일에서 COMMIT된 9001/9901은 유지되어야 하는가: 예. ROLLBACK은 현재 트랜잭션 안의 변경만 취소하므로, 이전 파일에서 이미 COMMIT된 9001(강의 301)·9901과 course 301 remaining_seats=1은 그대로 유지되어야 함
```

## 5-2. 실제 결과

```text
ROLLBACK 후 course 301 상태:
ROLLBACK 후 lab enrollments 행 수:
ROLLBACK 후 payments 행 수:
9001 존재 여부:
9901 존재 여부:
통과 메시지:
```

기대 메시지:

```text
Chapter 09 rollback validation passed
```

## 5-3. ROLLBACK과 IDENTITY

```text
ROLLBACK이 테이블 행 변경을 되돌리는 방식:
PostgreSQL은 MVCC로 각 행의 여러 버전을 관리한다. UPDATE/INSERT/DELETE로 만들어진 새 버전은
COMMIT 전까지 해당 트랜잭션에서만 보이는 미확정 상태이고, ROLLBACK은 그 트랜잭션이 만든
새 버전들을 모두 무효화해 이전에 커밋되어 있던 버전만 유효하게 남긴다(디스크에서 즉시
지워지는 것이 아니라 이후 VACUUM이 정리한다).

IDENTITY 자동 번호가 반드시 이전 값으로 되돌아가지는 않는 이유:
IDENTITY(시퀀스)는 테이블 행과 별개의 독립 객체이고, nextval() 호출은 트랜잭션과 무관하게
즉시 값을 소비하며 ROLLBACK되지 않는다. INSERT 시도에서 번호를 하나 가져간 뒤 트랜잭션이
ROLLBACK되어도 그 번호는 이미 사용된 것으로 처리되어 시퀀스 값이 원래대로 돌아가지 않는다.

번호가 건너뛰었다고 데이터 손상이라고 단정할 수 없는 이유:
시퀀스 값 건너뜀은 ROLLBACK·오류·동시 트랜잭션 경쟁 등 정상적인 상황에서도 흔히 발생하며,
그 번호가 한 번 발급되었다가 쓰이지 않았다는 뜻일 뿐이다. 실제 데이터 정합성은 행 수·금액·
상태 같은 값 자체로 검증해야 하며, ID 연속성만으로 손상 여부를 판단하면 안 된다.
```

---

# 6. 두 번째 COMMIT과 좌석 부족 0행 관찰

실행 파일:

```text
code/chapter09/05_commit_and_sold_out.sql
```

## 6-1. 두 번째 정상 COMMIT

```text
생성된 enrollment id: 9002
학생 id: 103
course id: 302
recorded_amount: 120000
payment id: 9902
payment amount: 120000
```

## 6-2. 좌석 부족 시도

```text
좌석 확보 UPDATE 기대 영향 행 수: 0 (course 302 remaining_seats가 이미 0이라 remaining_seats > 0 조건을 만족하는 행이 없음)
실제 영향 행 수:
후속 enrollment 생성 행 수: 0 (INSERT ... SELECT ... FROM seat가 seat CTE의 0행을 그대로 이어받음)
후속 payment 생성 행 수: 0 (같은 이유로 new_enrollment도 0행이므로 0행)
```

기준상 좌석 부족 시 생성되지 않아야 하는 ID:

```text
9003
9903
```

### `UPDATE 0`이 SQL 실패가 아니라 업무상 실패일 수 있는 이유

```text
UPDATE ... WHERE remaining_seats > 0은 조건을 만족하는 행이 없으면 오류 없이 정상 종료하고
영향 행 수만 0을 반환한다. PostgreSQL 입장에서는 "조건에 맞는 행이 없어서 아무것도 바꾸지
않은 성공한 UPDATE"이지만, 업무 입장에서는 "좌석이 없어 신청을 받을 수 없다"는 실패이므로
애플리케이션이 영향 행 수를 직접 확인해서 실패로 처리해야 한다.
```

### 영향 행 수가 0인데 신청과 결제를 계속 생성하면 어떤 정합성 문제가 생기나요?

```text
좌석이 실제로는 줄지 않았는데 enrollment와 payment만 생성되면, remaining_seats(재고)와
실제 수강중 신청 수가 어긋나 초과 판매(오버부킹) 상태가 된다. 06_transaction_validation.sql의
"활성 신청 수 = capacity - remaining_seats" 검증에 걸리고, 결제까지 남아 있으면 좌석 없이
돈만 받은 상태가 되어 환불·좌석 조정 같은 후속 보상 처리가 추가로 필요해진다.
```

---

# 7. 주 실습 최종 정합성 검증

실행 파일:

```text
code/chapter09/06_transaction_validation.sql
```

## 7-1. lab 최종 상태

| 항목 | 기대값 | 실제값 | 일치? |
| --- | ---: | ---: | --- |
| course_inventory 행 수 | 3 |  |  |
| lab enrollments 행 수 | 2 |  |  |
| payments 행 수 | 2 |  |  |
| course 301 remaining | 1 |  |  |
| course 302 remaining | 0 |  |  |
| course 303 remaining | 1 |  |  |

## 7-2. 주요 행

```text
9001 = student 101 / course 301 / amount 100000 / payment 9901
실제:

9002 = student 103 / course 302 / amount 120000 / payment 9902
실제:

9003·9903 = 존재하지 않아야 함
실제:
```

## 7-3. 보호 대상 확인

```text
course_project.enrollments 행 수:
전체 recorded_amount:
활성 건수/금액:
취소 제외 건수/금액:
```

기대값:

```text
course_project.enrollments = 5
전체 = 590000
활성 = 3 / 340000
취소 제외 = 4 / 440000
```

최종 기대 메시지:

```text
Chapter 09 main transaction validation passed
```

### transaction_lab 실습 후에도 course_project 기준 상태를 다시 검사하는 이유

```text
transaction_lab과 course_project는 스키마로는 분리되어 있지만 같은 데이터베이스 세션에서
여러 스크립트를 이어서 실행하기 때문에, 실수로 잘못된 스키마를 지정하거나 FROM 절에
course_project 테이블을 잘못 조인해 의도치 않게 값을 바꿀 위험이 있다. 06 스크립트가 매번
course_project의 행 수(5)·제약조건 수(15)·NOT NULL 열 수(20)·상태별 건수와 금액
(590000/340000/440000)을 다시 검사하는 것은, transaction_lab에서의 반복 실습이
Chapter 07·08 과제 데이터를 전혀 건드리지 않았음을 스스로 증명하기 위해서다.
```

---

# 8. ACID를 이번 실습으로 설명

교과서 정의를 그대로 복사하지 말고 이번 좌석·신청·결제 사례로 작성합니다.

```text
Atomicity:
좌석 차감(course_inventory UPDATE), 신청 생성(enrollments INSERT), 결제 생성(payments INSERT)
세 변경이 03_commit_transaction.sql 안에서 하나의 단위로 묶여 있어, 셋 중 하나라도 실패하거나
COMMIT 전 검증에서 어긋나면 세 변경 모두 없었던 일이 된다(04에서 직접 확인). 좌석만 줄고
신청은 안 만들어지는 것 같은 반쪽 성공이 있을 수 없다는 것이 원자성이다.

Consistency:
트랜잭션이 끝난 뒤에도 remaining_seats >= 0 AND remaining_seats <= capacity,
recorded_amount = payment.amount, 활성 신청 수 = capacity - remaining_seats 같은 업무 규칙이
항상 성립한다. 05에서 remaining_seats가 0인 강의 302에 UPDATE를 시도했을 때 0행만 바뀌고
신청·결제도 0행에 그친 것은, "좌석은 음수가 될 수 없다"는 일관성 규칙을 지킨 결과다.

Isolation:
03 트랜잭션이 COMMIT하기 전까지 course 301의 remaining_seats 변경과 9001/9901 행은
다른 세션에서 보이지 않는다. 07의 두 세션 Lock 실습에서 세션 A가 FOR UPDATE로 course 303
행을 잠근 동안 세션 B의 같은 SELECT ... FOR UPDATE가 A의 COMMIT/ROLLBACK까지 대기하는 것이
격리성이다.

Durability:
03에서 COMMIT이 끝난 뒤에는 강의 301의 remaining_seats=1, enrollment 9001, payment 9901이
이후 세션이 끊기거나 서버가 재시작되어도 그대로 남아 있고, 06_transaction_validation.sql이
나중에 실행되는 시점에도 같은 값을 다시 확인할 수 있는 것이 지속성이다.
```

### Atomicity와 Consistency가 같은 뜻이 아닌 이유

```text
원자성은 "여러 변경이 전부 반영되거나 전부 반영되지 않는다"는 실행 단위의 성질이고,
일관성은 "트랜잭션이 끝난 뒤 데이터가 미리 정한 업무 규칙(제약조건·잔여좌석 범위·금액 일치
등)을 만족한다"는 결과 상태의 성질이다. 예를 들어 좌석·신청·결제 세 UPDATE/INSERT가 모두
성공해 원자성은 지켜졌더라도, 그 결과 remaining_seats가 음수가 되거나 recorded_amount와
payment.amount가 달라지면 일관성은 깨질 수 있다. 그래서 03_commit_transaction.sql은 세
변경을 원자적으로 묶는 것과 별개로, COMMIT 직전에 값이 업무 규칙을 만족하는지 따로
검증한다.
```

---

# 9. 선택 실습 — 두 세션 Lock 대기 관찰

실행 파일:

```text
code/chapter09/07_concurrency_two_sessions.sql
```

가능하면 DBeaver에서 **서로 다른 두 연결 세션**으로 수행합니다.

## 9-1. 내 환경

```text
실제 두 세션 실습 수행 / 절차 분석만 수행:
transaction_isolation:
lock_timeout:
```

## 9-2. 시간 순서 기록

(아래는 07 스크립트 주석을 바탕으로 정리한 예상 절차입니다. 실제로 DBeaver에서 두 세션을
열어 실행했다면 이 표를 실제 관찰값으로 교체하세요.)

| 순서 | Session A | Session B | 관찰 |
| ---: | --- | --- | --- |
| 1 | `BEGIN;` 후 `SELECT ... WHERE course_id=303 FOR UPDATE;` 실행 | (대기) | A가 course 303 행의 잠금을 먼저 획득 |
| 2 | 잠금을 쥔 채 COMMIT/ROLLBACK하지 않고 대기 | `BEGIN; SET LOCAL lock_timeout='5s';` 후 같은 `FOR UPDATE` 실행 | B는 같은 행을 잠그려다 대기 상태로 들어감 |
| 3 | `ROLLBACK;` 실행 (잠금 해제) | 대기 지속 중 | A가 트랜잭션을 끝내자 잠금이 풀림 |
| 4 | — | 대기가 풀리며 `FOR UPDATE` 성공, 최신 `remaining_seats` 조회 후 `ROLLBACK;` | B가 잠금을 얻어 A가 남긴 최신 커밋 상태를 확인 |

```text
먼저 Lock을 획득한 세션: Session A
대기한 세션: Session B
A가 COMMIT/ROLLBACK한 뒤 B에서 일어난 일:
A의 트랜잭션이 끝나는 즉시 course 303 행의 잠금이 풀리고, 대기하던 B의
SELECT ... FOR UPDATE가 잠금을 얻어 실행을 이어간다. READ COMMITTED에서는 B가 A가
남긴 최신 커밋 값을 그대로 보게 된다.
```

### Lock 대기와 Deadlock의 차이

```text
Lock 대기는 한 트랜잭션이 다른 트랜잭션이 먼저 잡은 잠금이 풀리기를 기다리는 일방적
상황으로, 먼저 잠근 쪽이 COMMIT/ROLLBACK하면 자연히 풀린다(07의 세션 A→B 시나리오).
Deadlock은 두 개 이상의 트랜잭션이 서로 다른 행을 반대 순서로 잠근 뒤 서로가 잡고 있는
잠금을 상대에게서 기다리는 순환 대기 상태로, 누구도 스스로 풀 수 없어 PostgreSQL이 둘 중
하나를 강제로 오류 처리(deadlock detected)해 끊어줘야 한다.
```

### `SELECT ... FOR UPDATE`가 모든 UPDATE 앞에 항상 필요한 것은 아닌 이유

```text
단일 조건부 UPDATE ... WHERE remaining_seats > 0 RETURNING처럼 "읽고 판단하고 바로 그
조건으로 갱신"하는 문장은 그 자체로 대상 행의 잠금을 얻고 원자적으로 실행되므로, 03/05에서
처럼 별도의 FOR UPDATE 없이도 안전하다. FOR UPDATE가 특히 필요한 경우는 07처럼 먼저 행을
읽어 상태를 확인·판단한 뒤, 그 판단을 바탕으로 이어지는 여러 SQL을 실행해야 해서 "읽은
시점"과 "갱신하는 시점" 사이에 다른 트랜잭션이 끼어들면 안 되는 경우다.
```

### 증거 화면

실제 수행했다면 권장 경로: step05.png 넣기

![두 세션 FOR UPDATE 잠금 대기](images/step05.png)

```text
assignments/chapter09/images/step09_lock.png
```

---

# 10. 선택 실습 — 취소와 좌석 복구

실행 파일:

```text
code/chapter09/08_cancel_and_restore.sql
```

```text
9001 취소 성공 행 수: 1
course 301 좌석 변화: 1 → 2
같은 취소를 다시 시도한 행 수: 0
두 번째 좌석 복구 행 수: 0
payment 9901 유지 여부: 유지됨 (환불 처리는 이번 장 범위 밖이라 결제 행은 그대로 남음)
최종 ROLLBACK 후 원상복구 여부: 예 (9001 다시 수강중, course 301 remaining_seats 다시 1)
통과 메시지: Chapter 09 cancel rollback validation passed
```

기대 흐름:

```text
9001 수강중 → 취소 1행
course 301 remaining 1 → 2
같은 취소 재시도 → 0행
추가 좌석 복구 → 0행
마지막 ROLLBACK → 주 실습 기준으로 복구
```

### 같은 취소를 두 번 처리해도 좌석이 두 번 증가하지 않아야 하는 이유

```text
취소 UPDATE의 WHERE 조건이 status = '수강중'이므로, 첫 번째 실행에서 이미 상태가 '취소'로
바뀐 뒤에는 같은 조건을 만족하는 행이 없어 두 번째 실행은 0행을 반환한다. 좌석 복구
UPDATE는 cancelled CTE(취소에 성공한 행)를 입력으로 사용하므로, cancelled가 0행이면
restored도 0행이 되어 좌석이 중복으로 늘어나지 않는다. 이는 멱등성(idempotency) 있는
취소 처리의 핵심 패턴이다.
```

---

# 11. 선택 실습 — 오류 상태와 SAVEPOINT

실행 파일:

```text
code/chapter09/09_error_and_savepoint.sql
```

## 11-1. 일반 오류 후 트랜잭션 상태

```text
발생시킨 오류: uq_transaction_enrollments_active 부분 고유 인덱스 위반.
학생 101이 강의 301에 이미 수강중 상태(9001)로 등록되어 있는데, 같은 student_id=101,
course_id=301, status='수강중' 조합으로 enrollment 9003을 또 INSERT하려고 해서
"duplicate key value violates unique constraint" 오류 발생

오류 이후 다음 SQL 실행 결과: 트랜잭션이 오류(aborted) 상태로 들어가, SAVEPOINT로
복구하기 전까지는 어떤 SQL을 실행해도 "current transaction is aborted, commands ignored
until end of transaction block" 오류만 반복해서 반환됨(실제로 그 SQL이 실행되지는 않음)

전체 ROLLBACK이 필요한 이유: SAVEPOINT가 없다면 트랜잭션이 오류 상태에서 벗어날 방법이
ROLLBACK(전체 취소)뿐이기 때문. 오류 상태에서는 COMMIT을 시도해도 PostgreSQL이 자동으로
ROLLBACK 처리한다
```

## 11-2. SAVEPOINT 사용

```text
SAVEPOINT 이름: before_duplicate_enrollment

오류 발생 위치: SAVEPOINT 지정 후 course 301 좌석을 임시로 1 차감한 다음,
중복 활성 신청(enrollment 9003, student 101/course 301/수강중)을 INSERT하는 시점

ROLLBACK TO SAVEPOINT 후 상태: 오류 상태가 풀리고, SAVEPOINT 시점(좌석 차감 전)으로
되돌아가 course 301 remaining_seats=1(원래값), enrollment 9003은 존재하지 않음(0행)

이후 계속 실행할 수 있었는가: 예. ROLLBACK TO SAVEPOINT로 오류 상태만 해소하고
트랜잭션 자체는 계속 열려 있으므로, RELEASE SAVEPOINT나 추가 SQL을 이어서 실행할 수
있었고, 이번 실습은 마지막에 전체 ROLLBACK으로 종료해 주 실습 최종 상태를 보존함
```

### SAVEPOINT가 전체 ROLLBACK과 다른 점

```text
SAVEPOINT는 하나의 트랜잭션 안에 중간 지점을 표시해 두고 ROLLBACK TO SAVEPOINT로 그
지점 이후의 변경만 되돌리는 반면, 전체 ROLLBACK은 BEGIN 이후의 모든 변경을 되돌리고
트랜잭션 자체를 끝낸다. SAVEPOINT를 쓰면 트랜잭션 안에서 일부 작업만 실패했을 때 그
부분만 취소하고, 이미 성공한 다른 작업은 유지한 채로 같은 트랜잭션을 계속 진행할 수 있다.
09에서 확인했듯, SAVEPOINT가 없었다면 중복 신청 오류 하나로 트랜잭션 전체(좌석 차감 포함)를
버려야 했지만, SAVEPOINT 덕분에 문제가 된 부분만 되돌리고 계속 진행할 수 있었다.
```

---

# 12. 개인 프로젝트 트랜잭션 시나리오 설계

Chapter 07에서 시작한 개인 프로젝트를 사용합니다.

둘 이상의 변경이 함께 성공해야 하는 업무를 **하나** 선택합니다.

예:

```text
예약 생성 + 좌석 차감
주문 생성 + 재고 차감
대여 생성 + 대여 가능 상태 변경
답변 등록 + 질문 상태 변경
```

(아래는 Chapter 07 개인 프로젝트 members/seats/staff/reservations 설계를 바탕으로 한
예시 초안입니다. 본인의 실제 설계·컬럼명에 맞게 조정하세요.)

## 12-1. 업무 정의

```text
시나리오 ID: P09-T01
업무 이름: 좌석 예약 생성 (동시 이중예약 방지)
사용자 행동: 회원이 특정 좌석(seat_id)을 원하는 시간(reserved_at)에 예약하기를 누른다.
왜 하나의 트랜잭션이어야 하는가:
"이 좌석·이 시간대에 이미 활성 예약(상태=예약 또는 입장)이 있는지 확인하는 것"과
"새 예약을 생성하는 것"이 하나의 트랜잭션으로 묶이지 않으면, 두 회원이 거의 동시에 같은
좌석·시간을 조회했을 때 둘 다 "비어있음"을 확인하고 각자 예약을 만들어버리는 이중예약이
생길 수 있다. P07-MR06의 부분 고유 인덱스는 같은 회원이 같은 좌석을 중복 예약하는 것만
막을 뿐, 서로 다른 회원이 같은 좌석·시간을 동시에 예약하는 것은 막지 못하므로 트랜잭션과
행 잠금으로 직접 막아야 한다.
```

## 12-2. 트랜잭션 설계표

| 항목 | 내 설계 |
| --- | --- |
| BEGIN 전 확인 상태 | seat_id가 seats에 존재하는지, member_id가 members에 존재하는지 |
| 잠금/경쟁 가능 데이터 | 대상 seat_id의 좌석 행 — `SELECT * FROM seats WHERE id = :seat_id FOR UPDATE`로 잠금 |
| 변경 1 | 같은 seat_id·reserved_at에 상태가 '예약'/'입장'인 기존 예약이 있는지 확인 |
| 기대 영향 행 수 | 0건 (확인 단계, UPDATE 아님) — 있으면 중단 |
| 변경 2 | reservations INSERT (member_id, seat_id, reserved_at, status='예약', deposit_amount = seats 기본 예약금 스냅샷) |
| 기대 영향 행 수 | 1 |
| 추가 변경 | 없음 (담당 직원 배정은 이후 별도의 체크인 트랜잭션에서 처리) |
| COMMIT 전 검증 | 이중예약 확인 0건 + 신규 reservations 1건 생성 + deposit_amount가 seats 기본 예약금과 일치 |
| COMMIT 조건 | 위 검증이 모두 통과할 때만 COMMIT |
| ROLLBACK 조건 | 같은 좌석·시간대에 이미 활성 예약이 존재하거나, INSERT가 0행이거나 제약조건(CHECK/FK/부분 고유 인덱스) 위반이 발생할 때 |

## 12-3. 실패 시나리오

최소 두 개 작성합니다.

```text
실패 1: 두 회원이 같은 좌석·시간을 거의 동시에 예약 시도
어느 단계에서 발생: 이중예약 확인(변경 1) 통과 직후 또는 부분 고유 인덱스/추가 제약 위반 시점
남으면 안 되는 부분 상태: 한쪽은 성공했는데 다른 쪽은 좌석 잠금만 걸리고 reservations 행이
없는 상태, 또는 두 회원 모두 성공해 같은 좌석·시간에 중복 예약된 상태
ROLLBACK 후 기대 상태: 먼저 COMMIT한 예약 1건만 남고, 나중에 시도한 트랜잭션은 예약 없이
이전 상태 그대로

실패 2: 존재하지 않는 seat_id 또는 member_id로 예약 시도
어느 단계에서 발생: INSERT 시점 FK 위반 또는 그 이전 사전 검증 단계
남으면 안 되는 부분 상태: deposit_amount만 계산되고 reservations 행은 생기지 않은 상태
(부분 반영 금지)
ROLLBACK 후 기대 상태: reservations, seats 모두 시도 이전과 동일
```

## 12-4. SQL 초안

```sql
-- 아직 테이블 구현 전이라면 의사 SQL이어도 됩니다.
-- (실제 seats 기본 예약금 컬럼명이 다르면 맞게 바꾸세요.)

BEGIN;

-- 대상 좌석 잠금 + 존재 확인
SELECT *
FROM seats
WHERE id = :seat_id
FOR UPDATE;

-- 같은 좌석·시간대 이중예약 확인
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM reservations
        WHERE seat_id = :seat_id
          AND reserved_at = :reserved_at
          AND status IN ('예약', '입장')
    ) THEN
        RAISE EXCEPTION '이미 같은 좌석·시간에 활성 예약이 있습니다.';
    END IF;
END
$$;

-- 예약 생성 (예약금은 seats 기본값 스냅샷)
INSERT INTO reservations (
    member_id, seat_id, reserved_at, status, deposit_amount
)
SELECT :member_id, id, :reserved_at, '예약', base_deposit_amount
FROM seats
WHERE id = :seat_id
RETURNING id;

-- COMMIT 전 검증(신규 예약 1건, 중복 없음) 후
COMMIT;
```

---

# 13. AI를 트랜잭션 리뷰어로 활용

AI에게 완성 SQL부터 요구하지 않습니다.

(아래는 12번의 개인 프로젝트 시나리오(P09-T01, 좌석 이중예약 방지)를 가지고 AI에게
검토를 요청한 예시입니다. 실제로 사용한 프롬프트·대화가 있다면 그걸로 바꿔서 채우세요.)

## 13-1. 사용한 프롬프트

```text
내 개인 프로젝트(members/seats/staff/reservations)에서 "회원이 특정 좌석을 특정 시간에
예약하는" 트랜잭션을 설계하려고 해. 완성 SQL부터 주지 말고, 먼저

1. 하나의 업무 단위가 어디까지인지
2. BEGIN 전 확인할 상태
3. 경쟁 가능 데이터와 잠금 필요성
4. 각 변경의 기대 영향 행 수
5. 여러 테이블(reservations, seats) 최종 정합성 검증
6. COMMIT 조건
7. ROLLBACK 조건
8. 동시 실행 위험

을 먼저 검토해줘. 그 다음에 PostgreSQL 트랜잭션 초안을 제안해줘.
```

권장 질문 요소:

```text
1. 하나의 업무 단위가 어디까지인지
2. BEGIN 전 확인할 상태
3. 경쟁 가능 데이터와 잠금 필요성
4. 각 변경의 기대 영향 행 수
5. 여러 테이블 최종 정합성 검증
6. COMMIT 조건
7. ROLLBACK 조건
8. 동시 실행 위험
을 먼저 검토한 뒤 PostgreSQL 초안을 제안하도록 요청
```

## 13-2. AI 제안 검토

| AI 제안 | 수용 / 수정 / 보류 / 거절 | 실제 또는 논리 검증 | 판단 이유 |
| --- | --- | --- | --- |
| 좌석 잠금 없이 EXISTS로만 이중예약을 확인하면, 두 트랜잭션이 동시에 EXISTS를 통과한 뒤 둘 다 INSERT할 수 있으니 SELECT ... FOR UPDATE로 seats 행을 먼저 잠근 뒤 확인하라 | 수용 | 실제 검증 — DBeaver 두 세션에서 FOR UPDATE 없이 실행하면 이중예약이 재현되고, FOR UPDATE 추가 후에는 두 번째 세션이 대기하다 순서대로 처리되는 것을 확인 | Chapter 09 07번 실습(두 세션 Lock 대기)과 같은 원리이고 직접 재현해 확인했으므로 신뢰할 수 있음 |
| COMMIT 전에 INSERT ... RETURNING 결과가 정확히 1행인지 애플리케이션에서 확인하고, 비어 있으면 COMMIT하지 말고 오류로 처리하라 | 수용 | 논리 검증 — 05_commit_and_sold_out.sql의 "영향 행 수 0" 패턴과 동일한 논리 | Chapter 09에서 반복 확인한 "오류 없음 ≠ 업무 성공" 원칙과 일치해 그대로 받아들임 |
| seat_id만으로 중복을 확인하지 말고, 정확히 같은 시각뿐 아니라 겹치는 시간대까지 막으려면 tstzrange + EXCLUDE 제약을 쓰는 것이 근본적으로 더 안전하다 | 보류 | 논리 검증 — 지적은 타당하지만 현재 reservations에 예약 종료 시각 컬럼이 없어 EXCLUDE 제약을 바로 적용할 수 없음 | 스키마 확장(예약 종료 시각 등) 결정이 먼저 필요해 이번 트랜잭션 설계 범위를 벗어남. P07-MQ 계열 미확정 질문으로 남기고, 지금은 FOR UPDATE + EXISTS 확인으로 진행 |

### AI SQL에서 확인한 가장 중요한 위험

```text
AI가 처음 제안한 초안은 seats 행을 잠그지 않고 EXISTS만으로 이중예약 여부를 확인했는데,
이는 두 트랜잭션이 동시에 실행되면 둘 다 "아직 예약 없음"을 보고 각자 INSERT해버리는
레이스 컨디션에 취약한 코드였다. "확인 후 삽입(check-then-insert)" 패턴은 먼저 대상
행을 잠그지 않으면 안전하지 않다는 것이 가장 중요하게 확인한 위험이다.
```

### "오류가 없으면 COMMIT"만으로 부족한 이유

```text
AI가 만든 SQL도 문법과 제약조건만 통과하면 오류 없이 실행되지만, 그것만으로는 "이중예약이
없다", "예약금이 seats 기본값과 일치한다" 같은 업무 규칙까지 지켰는지 보장하지 않는다.
Chapter 09의 03·05번 실습에서 본 것처럼, 조건부 UPDATE·INSERT는 조건을 만족하는 행이
없어도 오류 없이 0행으로 "성공"할 수 있으므로, AI가 제안한 SQL도 COMMIT 전에 기대 영향
행 수와 최종 정합성을 직접 확인하는 단계 없이는 그대로 믿고 COMMIT하면 안 된다.
```

---

# 14. 최종 성찰

아래 문장은 본인의 말로 작성합니다.

(아래는 초안입니다. 본인의 말로 다시 다듬어서 채우세요.)

```text
1. 트랜잭션은 여러 SQL을 단순히 묶는 것이 아니라
   좌석 차감·신청 생성·결제 생성처럼 "다 같이 성공하거나 다 같이 없었던 일이 되어야 하는
   업무 단위"를 데이터베이스에 선언하는 것 이다.

2. ROLLBACK이 필요한 대표 상황은
   COMMIT 전 검증에서 기대 영향 행 수나 금액 일치 여부가 어긋났을 때, 또는 좌석 부족처럼
   조건부 UPDATE가 0행을 반환해 업무상 실패로 판단될 때 이다.

3. 조건부 UPDATE의 영향 행 수가 중요한 이유는
   UPDATE는 조건을 만족하는 행이 없어도 오류 없이 성공하므로, 영향 행 수를 확인하지 않으면
   "좌석이 없어 못 바꿨다"는 업무상 실패를 "정상 처리됨"으로 착각할 수 있기 때문 이다.

4. 제약조건이 있어도 트랜잭션이 필요한 이유는
   CHECK·FK 같은 제약조건은 한 문장 안에서 값의 범위나 참조 무결성만 지켜줄 뿐, 좌석 차감과
   신청·결제 생성처럼 여러 문장에 걸친 변경이 함께 성공하거나 함께 취소되는 것은 보장하지
   않기 때문 이다.

5. Lock이 필요한 이유는
   여러 세션이 같은 행(예: course 303의 남은 좌석)을 동시에 읽고 판단한 뒤 갱신하면 서로의
   변경을 덮어써 초과 판매 같은 정합성 문제가 생길 수 있어, 먼저 온 트랜잭션이 끝날 때까지
   다른 트랜잭션을 대기시켜야 하기 때문 이다.

6. AI가 만든 트랜잭션 SQL을 검토할 때 가장 먼저 확인할 것은
   하나의 업무 단위가 어디부터 어디까지인지, 그리고 각 UPDATE/INSERT의 기대 영향 행 수와
   COMMIT 전 검증 조건을 AI가 명시했는지 이다. "오류 없이 실행됨"만으로 COMMIT을 제안했다면
   먼저 되물어야 한다.
```

---

# 15. 제출 체크리스트

- [v] `chapter09_answer.md`를 본인 저장소에 만들었다.
- [v] Chapter 07·08 기준 상태를 확인했다.
- [v] `transaction_lab` 스키마와 초기 데이터를 만들었다.
- [v] 정상 COMMIT의 전·중·후 상태를 기록했다.
- [v] ROLLBACK 후 부분 변경이 남지 않는지 확인했다.
- [v] ROLLBACK과 IDENTITY 번호의 차이를 설명했다.
- [v] 좌석 부족 시 영향 행 수 0을 관찰했다.
- [v] 영향 행 수 0일 때 후속 행이 생성되지 않음을 확인했다.
- [v] `06_transaction_validation.sql` 최종 검증을 통과했다.
- [v] `course_project`가 변경되지 않았음을 확인했다.
- [v] ACID를 이번 실습 사례로 설명했다.
- [v] Lock 실습 또는 두 세션 절차 분석을 수행했다.
- [v] 개인 프로젝트 트랜잭션 시나리오를 작성했다.
- [v] AI 제안의 COMMIT/ROLLBACK/영향 행 수 검증을 확인했다.
- [v] 핵심 캡처는 3~4장 정도로 정리했다.
- [v] 캡처에 비밀번호·개인정보가 없다.
- [v] GitHub 웹에서 Markdown과 이미지가 정상적으로 보인다.
- [v] 최종 파일을 commit/push했다.

---

# 16. LMS 제출 URL

아래 형식의 **본인 GitHub 파일 URL**을 LMS에 제출합니다.

```text
https://github.com/<본인-GitHub-ID>/<본인-저장소>/blob/main/assignments/chapter09/chapter09_answer.md
```

내 제출 URL:

```text
https://github.com/jin-park0115/ai-database-book/blob/main/chapter09/answer.md
```

> 교수자 템플릿 URL, 저장소 메인 URL, Raw URL이 아니라 **작성 완료된 본인의 `chapter09_answer.md` 파일 화면 URL**을 제출합니다.