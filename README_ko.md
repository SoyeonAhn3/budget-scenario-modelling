🌐 [한국어](./README_ko.md) | [English](./README.md)

# AI-enabled Finance Budget & Decision Support Platform

> Azure Databricks 기반 예산·실적 분석, 연말 예측, 예산 재배분 What-if 모델링

https://github.com/user-attachments/assets/e50a1ab9-b22c-45d6-a9af-8236109ce7f1

## 개요

Budget, Forecast, Actual 데이터가 여러 Plan Version(BP26, CF02, CF05, CF09)에 흩어져 있어, 어떤 부서와 G/L 계정이 리스크인지, 연말에 집행이 어디로 갈지 파악하기 어렵습니다.

이 프로젝트는 데이터를 Azure Databricks의 Bronze → Silver → Gold → Semantic 구조로 통합하고, AI/BI Dashboard와 Genie로 현재 상태와 월별 추세를 탐색하게 하며, 연말 예측 방법을 Backtest로 비교한 뒤, 그 예측을 예산 재배분 What-if 모델로 확장합니다.

> [!NOTE]
> 포트폴리오용 프로젝트입니다. 모든 데이터는 **합성(Synthetic) 데이터**이며, 부서명과 금액은 실제 조직과 관계가 없습니다.

### 핵심 결과

| 영역 | 결과 |
|---|---|
| 연말 예측 | 2025 Backtest(8월 시점, 44개 부서)에서 **Seasonal EAC MAPE 0.32%**. Simple Annualization(1.10%) 대비 오차 약 71% 감소, 44개 중 41개 부서에서 우세 |
| ML 비교 | Linear Regression, Gradient Boosting, Residual 모델 모두 Seasonal EAC보다 오차가 큼 (MAPE 0.78% ~ 2.57%) |
| 재배분 What-if | 두 부서 간 1억 원 재배분으로 Target 부서의 예상 초과는 1.89억 → 0.89억으로 감소, 대신 Source 부서는 0.36억 여유에서 0.64억 초과로 전환 |

## 목차

- [개요](#개요)
- [동작 흐름](#동작-흐름)
- [AI 구성 요소](#ai-구성-요소)
- [기술 스택](#기술-스택)
- [프로젝트 구조](#프로젝트-구조)
- [문서](#문서)
- [현재 상태](#현재-상태)
- [한계점](#한계점)

## 동작 흐름

![아키텍처 다이어그램](screenshot/Architecture_Diagram.png)

### 1. 데이터 기반

- Silver에서 원천 파일을 월별 Actual Fact(`fiscal_year × fiscal_month × cost_center × gl_account`), Plan Version Fact(BP26 / CF02 / CF05 / CF09), Dimension, 2021 ~ 2026 통합 Actual Fact로 표준화합니다.
- **Cutoff Month 자동 계산**: Actual이 존재하는 가장 최근 월을 Cutoff로 사용합니다. 0은 실제 Actual로 인정하고 NULL만 미존재로 판단합니다.
- **연도 하드코딩 없음**: Historical Pattern은 현재 Reporting Year 이전 연도만 사용합니다.
- 검증: 과거 각 연도 1 ~ 12월 존재, Fact Grain 중복 0건, 12월 YTD Share = 1.0을 확인했습니다.

### 2. 현재 집행 현황과 월별 추세

```text
Selected Linear     = Annual Plan × Cutoff Month ÷ 12
Variance vs Linear  = Actual YTD − Selected Linear
Linear Utilization  = Actual YTD ÷ Selected Linear
Remaining Budget    = Selected Budget − Actual YTD
```

> [!IMPORTANT]
> **Linear 초과 ≠ 연간 예산 초과.** `Actual > Linear`는 Cutoff 시점에 균등 배분보다 집행 속도가 빠르다는 뜻이지, 연간 Budget을 넘었다는 뜻이 아닙니다. Dashboard와 Genie 모두 이 구분을 지킵니다.

Dashboard는 부서별 Variance와 Utilization, Actual YTD Top 5 G/L, Linear 초과·미달 G/L, Budget 없는 Actual, Plan Version별 Budget Tracking, 월별 누적 Actual vs Linear를 다룹니다.

![Finance Budget Dashboard](screenshot/Finance_Budget_Dashboard_Screenshot.png)

### 3. 연말 예측과 Backtest

```text
Simple Annualization = Actual YTD ÷ Cutoff Month × 12
Seasonal EAC         = Actual YTD ÷ Historical Average YTD Share
Historical YTD Share = (YTD at cutoff month ÷ Full-Year Actual) in past years
```

2025년을 아직 끝나지 않은 해로 가정했습니다. 2021 ~ 2024년이 Historical Pattern, 2025년 1 ~ 8월이 입력, 2025년 Full-Year Actual이 정답입니다. 각 테스트 연도에는 그 이전 연도의 데이터만 사용합니다.

**2025년, 8월 시점, 44개 부서**

| 방법 | Input / Target | MAPE |
|---|---|---|
| Simple Annualization | YTD 기반 단순 연환산 | 1.10% |
| **Seasonal EAC** | YTD ÷ 과거 평균 YTD Share | **0.32%** |
| Linear Regression | YTD, 최근 3개월 평균, Cutoff 월 Actual | 0.79% |
| Linear Regression + Seasonality | 위 Feature + Seasonal EAC Feature | 1.10% |
| Seasonal EAC + Residual ML | Seasonal EAC 오차율 보정 | 0.91% |
| Gradient Boosting | Target = Full-Year 금액 | 2.57% |
| Gradient Boosting | Target = Remaining Rate | 0.78% |

<sub>Linear Regression은 2021 ~ 2024로 학습했습니다. 나머지 ML 모델은 과거 이력 Feature가 필요해 2022 ~ 2024로 학습했고, 같은 기간으로 학습한 기본 Linear Regression의 MAPE는 0.76%입니다.</sub>

**ML 실험**: 같은 Backtest에서 Linear Regression과 Gradient Boosting 모델을 별도 실험으로 비교했습니다. Seasonal EAC를 넘은 모델이 없어 Scenario 모델은 Seasonal EAC를 사용하며, ML 모델은 프로젝트의 다른 곳에 쓰이지 않습니다.

- Full-Year 금액을 예측한 Gradient Boosting은 Feature Importance의 99%가 `ytd_actual`에 집중됐습니다. 집행 패턴이 아니라 부서 규모를 학습한 것입니다.
- Target을 Remaining Rate `(Full-Year − YTD) ÷ YTD`로 바꾸자 오차가 2.57% → 0.78%로 줄었고, 가장 중요한 Feature는 최근 3개월 Momentum(0.83)이었습니다.
- Linear Regression에 Seasonality Feature를 추가하거나(0.76% → 1.10%), Seasonal EAC의 잔차를 모델링하면(0.32% → 0.91%) 모두 오히려 악화됐습니다.

**예측 시점별**: 모든 시점과 테스트 연도에서 Seasonal EAC가 Simple Annualization보다 정확했습니다.

| Cutoff | 2024 Simple | 2024 Seasonal | 2025 Simple | 2025 Seasonal |
|---|---|---|---|---|
| 3월 | 3.19% | 1.58% | 3.38% | 1.05% |
| 5월 | 1.48% | 0.67% | 1.24% | 0.20% |
| 8월 | 1.38% | 0.67% | 1.10% | 0.32% |

**집행 패턴별**: 모든 부서에서 이기는 단일 방법은 없었습니다.

| 부서 | 패턴 | Simple APE | Seasonal APE |
|---|---|---|---|
| 마케팅팀 3 | 강한 계절성 | 13.87% | **1.46%** |
| 정보기술팀 2 | Trend / Level Shift | **0.51%** | 2.26% |
| 연구개발팀 3 | Project Milestone | 6.78% | 7.58% |

모든 부서에서 이기는 방법이 없기 때문에, 향후 부서별 Method Selector를 위한 원칙을 정했습니다. 부서명 기준 하드코딩 금지, 예측 시점 이전 데이터만 사용, 최종 Test Year는 선택 규칙 생성에 사용하지 않음.

### 4. 예산 재배분 What-if

```text
Forecast Gap = Seasonal EAC − Current Budget (CF05)
Status       = PROJECTED_OVERRUN if Forecast Gap > 0, otherwise WITHIN_BUDGET
```

Scenario 입력: 전사 총액은 유지한 채 재무회계팀 4(Source)에서 마케팅팀 3(Target)으로 100,000,000원 이동

| | 마케팅팀 3 (Target) | 재무회계팀 4 (Source) |
|---|---|---|
| Current Budget | 789,112,330 | 820,630,150 |
| Scenario Budget | 889,112,330 | 720,630,150 |
| Seasonal EAC | 978,057,834 | 784,216,654 |
| Forecast Gap (이동 전) | +188,945,504 | −36,413,496 |
| Forecast Gap (이동 후) | +88,945,504 | +63,586,504 |
| Status | OVERRUN → OVERRUN | WITHIN → **OVERRUN** |

검증: 이동 전후 전사 Budget은 36,725,755,630으로 동일(차이 0)하고, 최소 Scenario Budget은 292,340,152(음수 Budget 없음)입니다.

재배분은 Target의 리스크를 줄였지만 Source에 새 리스크를 만들었습니다. 모델은 이 Trade-off를 보여주므로, 사용자는 "얼마를 옮길 수 있는가"와 "새로운 초과가 생기는가"를 함께 판단할 수 있습니다.

![Scenario Modeling](screenshot/Finance_Budget_Scenario_Modeling_Screenshot.png)

## AI 구성 요소

이 프로젝트의 AI 구성 요소는 두 Metric View 위에 만든 Genie Space **Finance Budget and Cost Analysis** 하나입니다.

### AI가 처리하는 부분

| 입력 | 출력 |
|---|---|
| 자연어 질문 | 두 Metric View에 대한 SQL, 결과 표 또는 차트, 짧은 설명 |

질문 범위: Current Budget / Actual 비교, Linear Overrun / Under-run, 부서·G/L Ranking, Budget 없는 Actual, 월별 Trend, 최근 연속 Overrun 탐색

### 규칙 기반 처리

- 모든 수치는 Metric View Measure(Actual YTD, Linear, Variance, Utilization, Remaining Budget)가 계산합니다. Measure는 한 번만 정의되어 Dashboard와 공유됩니다. Genie는 쿼리를 작성할 뿐 수치를 직접 계산하지 않습니다.

### 모델 선택 방식

- Genie는 Databricks가 관리하는 LLM으로 동작해 따로 고를 모델이 없습니다. 대신 데이터 Source(두 Metric View), Space 지침, 예시 SQL 쿼리로 답변을 통제합니다.

### AI 실패 처리 방식

- Space 지침으로 데이터에 없는 Business Cause를 추론하지 않고, Positive Variance vs Linear를 연간 Budget 초과로 표현하지 않도록 했습니다.
- 모든 답변에서 생성된 SQL을 보여주므로 쿼리를 직접 확인할 수 있습니다.
- 자주 쓰는 질문은 Space에 예시 SQL 쿼리로 등록해 참고하도록 했습니다.

### AI 결과의 성격

- Genie는 탐색 도구입니다. 설명은 참고용이며 예산 의사결정은 Finance 사용자가 합니다.

```text
Show the cumulative Actual vs Linear trend for the Marketing department under CF05.
```

![Genie Agent](screenshot/Genie_Agent_Screenshot.png)

## 기술 스택

| Technology | Role | Why |
|---|---|---|
| Azure Databricks (Serverless) | 데이터·BI·AI 작업 환경 | 클러스터 관리 없이 Pipeline, Dashboard, Genie, Notebook을 한 Workspace에서 운영 |
| Unity Catalog | 테이블 Namespace와 거버넌스 | `finance.bronze / silver / gold / semantic` Schema로 Layer 구분 |
| Spark SQL | Gold 테이블, Backtest | Window 함수로 YTD와 Full-Year를 검토하기 쉬운 SQL로 계산 |
| PySpark | Notebook 데이터 준비 | 모델링 전에 Gold 데이터를 부서 단위로 집계 |
| Databricks Metric Views | Semantic Layer | Measure를 한 번 정의하고 Dashboard와 Genie가 `MEASURE()`로 재사용 |
| Databricks AI/BI Dashboard | 현재 상태·추세 시각화 | Metric View를 직접 읽어 별도 BI 도구로 내보낼 필요 없음 |
| Databricks Genie | 자연어 분석 | Metric View 기반으로 답하고 실행한 SQL을 보여줌 |
| pandas, NumPy | Backtest 계산 | 부서 단위 데이터가 작음 (연도당 44행) |
| scikit-learn | ML 예측 실험 | 규칙 기반 방법과 비교할 표준 Linear Regression, Gradient Boosting Baseline |

## 프로젝트 구조

```text
.
├── README.md                                    # English README
├── README_ko.md                                 # Korean README
├── notebook/
│   ├── Finance_ML_YearEnd_Forecast.ipynb        # Forecast backtest, ML experiments, pattern profiling
│   └── Finance_Budget_Scenario_Modeling.ipynb   # Budget reallocation what-if model
├── sql/
│   ├── historical_patterns.sql                  # Builds the historical pattern Gold table
│   └── backtest.sql                             # Simple vs. Seasonal EAC backtest by department
├── sample_data/
│   ├── budget_analysis_2026.csv                 # 2026 budget, plan versions, monthly actual (813 rows)
│   └── historical_actual_2021_2025_raw.csv      # 2021–2025 monthly actual (48,780 rows)
├── screenshot/                                  # Architecture diagram; dashboard, Genie, and scenario screenshots
└── plan/
    └── finance_budget_decision_support_project_plan_updated.md   # Detailed project plan (Korean)
```

## 문서

| 문서 | 설명 |
|---|---|
| [프로젝트 기획서](plan/finance_budget_decision_support_project_plan_updated.md) | 데이터 모델, 지표 정의, 전체 Backtest와 ML 실험, 패턴 진단, Scenario 결과를 담은 상세 기획서 |

## 현재 상태

| Phase | Status | Deliverable |
|---|---|---|
| Phase 1 — 데이터 기반 | ✅ Done | Bronze / Silver / Gold 테이블, 2021 ~ 2026 통합 Actual Fact, Cutoff Month 자동 계산 |
| Phase 2 — 현재 집행 현황 | ✅ Done | Current Snapshot Gold, Metric View, Plan Version 필터가 있는 AI/BI Dashboard |
| Phase 3 — 월별 추세 | ✅ Done | Monthly Trend Gold와 Metric View, 누적 Actual vs Linear 차트 |
| Phase 4 — Genie | ✅ Done | 두 Metric View 기반 Genie Space, 지침과 예시 쿼리 |
| Phase 5 — 예측과 Backtest | ✅ Done | Historical Pattern Gold, 3개 시점 × 2개 연도 Simple vs Seasonal EAC Backtest |
| Phase 6 — ML 실험 | ✅ Done | Linear Regression, Residual, Gradient Boosting 모델을 Seasonal EAC와 비교 |
| Phase 7 — 재배분 What-if | ✅ Done | 전사 총액을 유지하는 Scenario 모델과 검증 로직 |
| Forecast Method Selector | 📋 Design only | 선택 원칙만 정의, 자동 선택은 미구현 |
| 자동 Refresh | 📋 Not implemented | SharePoint / Azure DB / ERP 원천부터 Dashboard까지 자동 갱신 |

## 한계점

- **패턴이 매우 안정적인 합성 데이터.** 44개 부서의 8월 YTD Share 연도 간 표준편차 중앙값은 0.06%p, 연간 Trend R² 중앙값은 0.98입니다. 실제 데이터에서는 Seasonal EAC의 우위가 더 작을 수 있습니다.
- **작은 ML 표본.** 132 ~ 176개 부서-연도 행으로 학습하고 44개로 테스트해, 비교의 통계적 검정력이 제한적입니다.
- **Forecast와 Scenario는 Notebook에만 있음.** 결과가 Gold 테이블에 저장되지 않고 Dashboard나 Genie에서 조회되지 않습니다.
- **점추정만 제공.** 예측 구간이 없습니다.
- **Scenario는 한 번에 하나.** Source, Target, 금액을 Notebook 입력값으로 지정합니다.
- **Repository에는 코드 일부만 포함.** Silver 변환, Current/Trend Gold 테이블, Metric View 정의, Dashboard와 Genie 설정은 스크린샷으로만 보여줍니다.
- **예약 실행 없음.** Pipeline은 수동으로 실행했습니다.

---
<p align="center">Made with AI-assisted development</p>
