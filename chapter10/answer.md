# Chapter 10 확장 실습 답안 템플릿

> **과제:** 실행 계획으로 인덱스 효과 검증하기  
> **사용 방법:** 이 파일을 내려받아 본인의 GitHub 저장소에 `chapter10_answer.md`라는 이름으로 저장한 뒤 실습하면서 바로 작성합니다.  
> **제출 방법:** LMS에는 파일을 직접 업로드하지 않고, **본인 GitHub 저장소의 `chapter10_answer.md` 파일 URL**을 제출합니다.

---

## 제출 전 주의

이 파일과 캡처 화면에는 실제 비밀번호, 전체 DB 접속 URL, API Key, 개인정보를 기록하지 않습니다.

```text
GitHub 계정 또는 별칭:
과제 작성일:
사용한 AI 도구:
```

---

# 1. PostgreSQL 버전과 시작 환경 확인

다음을 실행합니다.

```sql
SELECT version();
SELECT current_database();
SELECT current_user;
SELECT current_schema();
SHOW search_path;
```

| 확인 항목 | 실제 결과 | 의미 |
| --- | --- | --- |
| PostgreSQL 버전 | PostgreSQL 18.4 on x86_64-windows, compiled by msvc-19.44.35227, 64-bit | 버전을 확인한다. |
| `current_database()` | ai_database_book |  |
| `current_user` | postgres |  |
| `current_schema()` | public |  |
| `search_path` | public, "$user" |  |

### PostgreSQL 버전을 기록해야 하는 이유

```text

```

> 이 장의 자동 검증 기준은 PostgreSQL 16입니다. PostgreSQL 18 이상에서는 B-tree Skip Scan 등으로 동일 SQL의 실행 계획이 달라질 수 있습니다.

---

# 2. Chapter 07·08 기준 상태 확인

Chapter 10은 기존 `course_project`를 변경하지 않습니다.

확인 기준:

```text
students = 3
instructors = 2
courses = 3
enrollments = 5

전체 recorded_amount = 590000
활성 = 3건 / 340000
취소 제외 = 4건 / 440000
```

```text
1001 = 완료 / 100000
1004 = 취소 / 150000
1005 = 신청 / 120000
```

### 실제 확인 결과

```text
students:
instructors:
courses:
enrollments:
전체 recorded_amount:
활성 신청 건수/금액:
취소 제외 건수/금액:
```

### 성능 실험을 기존 `course_project`에 대량 데이터를 넣지 않고 별도 스키마에서 하는 이유

```text

```

---

# 3. `performance_lab` 생성과 대량 데이터 확인

다음 파일을 순서대로 실행합니다.

```text
code/chapter10/01_performance_lab_schema.sql
code/chapter10/02_performance_lab_seed.sql
```

## 3-1. 생성 후 행 수

| 테이블 | 기대 행 수 | 실제 행 수 | 일치? |
| --- | ---: | ---: | --- |
| `performance_lab.students` | 10003 |  |  |
| `performance_lab.instructors` | 2 |  |  |
| `performance_lab.courses` | 2003 |  |  |
| `performance_lab.enrollments` | 100005 |  |  |

## 3-2. 데이터 분포 확인

| 조건 | 기대 행 수 | 실제 행 수 | 대략적 비율 |
| --- | ---: | ---: | ---: |
| `performance5000@example.com` | 1 |  |  |
| `student_id = 5000` | 10 |  | 약 0.010% |
| `course_id = 1500` | 50 |  | 약 0.050% |
| `course_id = 1500 AND status='수강중'` | 15 |  | 약 0.015% |
| 전체 `status='수강중'` | 30001 |  | 약 30.0% |

### 선택도가 낮은 조건과 많은 행을 반환하는 조건은 인덱스 판단에서 어떻게 다르게 볼 수 있나요?

```text

```

### 증거 화면

권장 경로:

```text
assignments/chapter10/images/step03_data_scale.png
```

`여기에 데이터 규모 확인 화면을 삽입하세요.`
AI야 여기 넣어줘 step03_data_scale.png를 
---

# 4. 인덱스 생성 전 기준 계획 기록

다음 파일을 실행합니다.

```text
code/chapter10/03_baseline_explain.sql
```

> **중요:** `04_create_candidate_indexes.sql`을 먼저 실행하지 않습니다. 기준 계획을 잃으면 같은 조건의 전후 비교가 어려워집니다.

최소 3개 SQL의 실행 계획을 기록합니다.

## Query A

```text
업무 질문:
WHERE / JOIN / ORDER BY / LIMIT:
예상 반환 행 수:
실제 반환 행 수:
```

```sql
-- 대상 SQL

```

| 관찰 항목 | 기록 |
| --- | --- |
| 주요 Scan/계획 노드 |  |
| estimated rows |  |
| actual rows |  |
| Filter |  |
| Index Cond |  |
| Buffers hit/read |  |
| Planning Time |  |
| Execution Time |  |

## Query B

```text
업무 질문:
WHERE / JOIN / ORDER BY / LIMIT:
예상 반환 행 수:
실제 반환 행 수:
```

| 관찰 항목 | 기록 |
| --- | --- |
| 주요 Scan/계획 노드 |  |
| estimated rows |  |
| actual rows |  |
| Filter |  |
| Index Cond |  |
| Buffers hit/read |  |
| Execution Time |  |

## Query C

```text
업무 질문:
WHERE / JOIN / ORDER BY / LIMIT:
예상 반환 행 수:
실제 반환 행 수:
```

| 관찰 항목 | 기록 |
| --- | --- |
| 주요 Scan/계획 노드 |  |
| estimated rows |  |
| actual rows |  |
| Filter |  |
| Index Cond |  |
| Buffers hit/read |  |
| Execution Time |  |

### `cost`와 실제 실행 시간이 같은 개념이 아닌 이유

```text

```

### `EXPLAIN ANALYZE`는 실제 SQL을 실행한다는 점을 왜 기억해야 하나요?

```text

```

### 증거 화면

권장 경로:

```text
assignments/chapter10/images/step04_before_plan.png
```

`여기에 대표 기준 실행 계획을 삽입하세요.`
AI야 여기도 step04_before_plan 넣어줘
---

# 5. 후보 인덱스를 만들기 전에 이유 작성

본문 실험 후보는 다음 세 개입니다.

```text
idx_performance_courses_title
idx_performance_enrollments_student_id
idx_performance_enrollments_course_status
```

각 인덱스의 이유를 먼저 작성합니다.

| 후보 인덱스 | 대응 조회 패턴 | 예상 이점 | 컬럼 순서 이유 | 예상 비용/단점 |
| --- | --- | --- | --- | --- |
| `idx_performance_courses_title` |  |  |  |  |
| `idx_performance_enrollments_student_id` |  |  |  |  |
| `idx_performance_enrollments_course_status` |  |  |  |  |

### “중요한 컬럼이므로 인덱스를 만든다”는 설명이 부족한 이유

```text

```

### `(course_id, status)`와 `(status, course_id)`가 항상 같은 효과가 아닌 이유

```text

```

---

# 6. 후보 인덱스 생성

다음을 실행합니다.

```text
code/chapter10/04_create_candidate_indexes.sql
```

생성 후 확인:

```text
후보 인덱스 수:
전체 인덱스 수:
```

본문 기준:

```text
자동 인덱스 = 6
후보 인덱스 = 3
전체 인덱스 = 9
```

### PRIMARY KEY나 UNIQUE가 이미 인덱스를 만들 수 있는데 같은 목적의 인덱스를 또 만들면 어떤 문제가 생기나요?

```text

```

---

# 7. 같은 SQL로 인덱스 후 재측정

다음 파일을 실행합니다.

```text
code/chapter10/05_after_index_explain.sql
```

Chapter 4에서 기록한 **동일 SQL**을 비교합니다.

## Query A 전후 비교

| 항목 | Before | After | 해석 |
| --- | --- | --- | --- |
| 주요 계획 노드 |  |  |  |
| actual rows |  |  |  |
| Buffers hit/read |  |  |  |
| Execution Time |  |  |  |
| Index Cond |  |  |  |

```text
결과 행이 동일했는가:
읽은 버퍼가 줄었는가:
계획이 바뀌었는가:
실행 시간 한 번만으로 결론낼 수 있는가:
```

## Query B 전후 비교

| 항목 | Before | After | 해석 |
| --- | --- | --- | --- |
| 주요 계획 노드 |  |  |  |
| actual rows |  |  |  |
| Buffers hit/read |  |  |  |
| Execution Time |  |  |  |
| Index Cond |  |  |  |

## Query C 전후 비교

| 항목 | Before | After | 해석 |
| --- | --- | --- | --- |
| 주요 계획 노드 |  |  |  |
| actual rows |  |  |  |
| Buffers hit/read |  |  |  |
| Execution Time |  |  |  |
| Index Cond |  |  |  |

### `Index Scan`으로 바뀌었다는 사실만으로 성공이라고 할 수 없는 이유

```text

```

### 증거 화면

권장 경로:

```text
assignments/chapter10/images/step07_after_plan.png
```

`여기에 동일 SQL의 사후 실행 계획을 삽입하세요.`

---

# 8. `status` 단독 조회와 Seq Scan 해석

전체 `status = '수강중'`은 약 30%의 행을 반환합니다.

```text
예상 행 수 = 30001
실제 행 수 =
주요 계획 노드 =
```

### 인덱스가 존재해도 PostgreSQL이 Seq Scan을 선택할 수 있는 이유

```text

```

### “Seq Scan = 나쁜 계획”이라고 단정하면 안 되는 이유

```text

```

### PostgreSQL 16과 18 이상에서 복합 B-tree 후행 컬럼 조건의 계획이 다를 수 있는 이유

```text

```

---

# 9. `ORDER BY`와 `LIMIT`에서 인덱스 관찰

`ORDER BY title`과 `ORDER BY title LIMIT 20` 계획을 비교합니다.

```text
ORDER BY title 계획:

ORDER BY title LIMIT 20 계획:
```

### LIMIT이 있을 때 PostgreSQL이 전체 정렬보다 인덱스 순서를 활용하는 것이 유리할 수 있는 이유

```text

```

### 실제 계획에서 Sort 노드 또는 Index Scan을 어떻게 확인했나요?

```text

```

---

# 10. 인덱스 검토

다음을 실행합니다.

```text
code/chapter10/06_index_review.sql
```

## 10-1. 인덱스별 판단

| 인덱스 | 크기/사용 관찰 | 유지 / 보류 / 제거 | 판단 근거 |
| --- | --- | --- | --- |
|  |  |  |  |
|  |  |  |  |
|  |  |  |  |

### `idx_scan = 0`이라는 이유 하나만으로 인덱스를 삭제하면 안 되는 이유

```text

```

### 외래키 자식 컬럼 인덱스가 무결성 자체의 필수 조건은 아니지만 성능상 필요할 수 있는 이유

```text

```

### 인덱스를 많이 만들었을 때 생기는 쓰기·저장 비용

```text

```

---

# 11. 자동 완료 게이트

다음을 실행합니다.

```text
code/chapter10/07_result_validation.sql
```

```text
최종 검증 결과:
```

검증할 핵심 내용:

```text
performance_lab 기준 행 수 유지
조회 결과 행 수 유지
후보 인덱스 3개 존재
course_project 기준 상태 유지
```

### 실행 계획 비교와 별도로 결과 행 동일성을 검증해야 하는 이유

```text

```

---

# 12. 인덱스 만능론 반박

다음 주장 중 **두 개**를 골라 본문과 실제 실행 계획을 근거로 반박합니다.

```text
A. 인덱스는 많을수록 좋다.
B. 인덱스를 만들었는데 Seq Scan이면 실패다.
C. 모든 FK에는 무조건 같은 방식의 인덱스를 만든다.
D. 실행 시간이 한 번이라도 빨라졌으면 효과가 입증됐다.
E. 선택도가 낮으면 무조건 Index Scan이 나온다.
```

## 주장 1

```text
선택한 주장:

나의 반박:

실행 계획에서 확인한 근거:
```

## 주장 2

```text
선택한 주장:

나의 반박:

실행 계획에서 확인한 근거:
```

---

# 13. 개인 프로젝트 조회 패턴과 인덱스 후보

Chapter 07~09에서 발전시킨 개인 프로젝트를 사용합니다.

최소 2개의 **실제 반복 조회 질문**을 먼저 만듭니다.

| ID | 반복 조회 질문 | WHERE | JOIN | ORDER BY/LIMIT | 예상 반환 비율 | 후보 인덱스 |
| --- | --- | --- | --- | --- | --- | --- |
| P10-Q01 |  |  |  |  |  |  |
| P10-Q02 |  |  |  |  |  |  |

## 후보 1

```text
후보 인덱스:
컬럼 순서:
이 조회에 도움이 될 것으로 예상한 이유:
쓰기/저장 비용:
현재 바로 적용 / 후보로 보류:
```

## 후보 2

```text
후보 인덱스:
컬럼 순서:
이 조회에 도움이 될 것으로 예상한 이유:
쓰기/저장 비용:
현재 바로 적용 / 후보로 보류:
```

### 개인 프로젝트 데이터가 너무 적어 성능 검증이 어렵다면

```text
필요한 데이터 규모:
필요한 데이터 분포:
비교할 SQL:
비교할 지표:
현재 판단 상태: 후보 / 보류
```

> 작은 데이터에서 Index Scan이 나오지 않는다고 억지로 설정을 바꾸어 특정 계획을 강제하지 않습니다.

---

# 14. AI를 실행 계획 리뷰어로 활용

AI에게 인덱스를 바로 추천하게 하지 않고 실제 실행 계획과 조회 문맥을 제공합니다.

## 14-1. AI에게 전달한 정보

```text
업무 질문:
PostgreSQL 버전:
테이블 행 수:
데이터 분포:
기존 인덱스:
SQL:
EXPLAIN (ANALYZE, BUFFERS) 핵심 결과:
```

## 14-2. AI 제안 검토

| AI 제안 | 수용 / 수정 / 보류 / 거절 | 실제 계획/데이터 근거 | 최종 판단 |
| --- | --- | --- | --- |
|  |  |  |  |
|  |  |  |  |
|  |  |  |  |

### AI가 제안한 인덱스 중 만들지 않기로 한 것이 있다면 이유

```text

```

### AI가 PostgreSQL 버전이나 데이터 분포를 무시하고 단정한 내용이 있었나요?

```text

```

### AI가 만든 인덱스 제안을 실제 계획 없이 채택하면 위험한 이유

```text

```

---

# 15. 최종 성찰

아래 문장은 본인의 말로 작성합니다.

```text
1. 인덱스가 필요한지 판단할 때 가장 먼저 확인할 것은
   ____________________________________________________________ 이다.

2. 같은 SQL의 인덱스 전후를 비교할 때 통제해야 할 조건은
   ____________________________________________________________ 이다.

3. Seq Scan이 항상 나쁜 것이 아닌 이유는
   ____________________________________________________________ 이다.

4. 실행 시간 한 번보다 계획과 Buffers를 함께 보는 이유는
   ____________________________________________________________ 이다.

5. 내 개인 프로젝트에서 아직 인덱스를 보류한 후보가 있다면 그 이유는
   ____________________________________________________________ 이다.
```

---

# 16. 제출 체크리스트

- [ ] `chapter10_answer.md`를 본인 저장소에 만들었다.
- [ ] PostgreSQL 버전을 기록했다.
- [ ] Chapter 07·08 기준 상태를 확인했다.
- [ ] `performance_lab`의 10003 / 2 / 2003 / 100005 기준을 확인했다.
- [ ] `03_baseline_explain.sql`을 후보 인덱스 생성 전에 실행했다.
- [ ] 기준 실행 계획을 최소 3개 기록했다.
- [ ] 후보 인덱스 3개의 근거를 먼저 작성했다.
- [ ] 동일 SQL의 인덱스 전후 계획을 비교했다.
- [ ] 실행 시간뿐 아니라 Scan, actual rows, Buffers, Index Cond를 확인했다.
- [ ] `status` 단독 조건의 계획을 해석했다.
- [ ] `ORDER BY`와 `LIMIT` 계획을 확인했다.
- [ ] 인덱스 만능론 주장 2개를 반박했다.
- [ ] `07_result_validation.sql`로 최종 상태를 확인했다.
- [ ] 개인 프로젝트의 반복 조회 2개와 인덱스 후보를 작성했다.
- [ ] AI 제안을 실제 실행 계획과 비교했다.
- [ ] 핵심 캡처 3~4장만 넣었다.
- [ ] 캡처에 비밀번호·개인정보가 없다.
- [ ] GitHub 웹에서 Markdown과 이미지가 정상적으로 보인다.
- [ ] 최종 답안을 commit/push했다.

---

# 17. LMS 제출 URL

아래 형식의 **본인 GitHub 파일 URL**을 LMS에 제출합니다.

```text
https://github.com/<본인-GitHub-ID>/<본인-저장소>/blob/main/assignments/chapter10/chapter10_answer.md
```

내 제출 URL:

```text

```

> 저장소 메인 URL, 교수자 템플릿 URL, Raw URL이 아니라 **작성 완료된 본인 `chapter10_answer.md` 파일 화면 URL**을 제출합니다.