# Finance Budget & Decision Support 프로젝트 기획서 — Updated

## 1. 프로젝트 개요

### 프로젝트명
**AI-enabled Finance Budget & Decision Support Platform**

### 목적
Budget, Forecast, Actual 데이터를 통합하여 현재 집행 현황을 분석하고, 월별 추세·과거 집행 패턴·연말 예상·예산 재배분 시나리오를 통해 Finance 및 Business 사용자의 의사결정을 지원하는 분석 플랫폼을 구축한다.

### 핵심 목표
- Budget / Forecast / Actual 데이터를 표준화하여 일관된 분석 구조를 구축
- 현재 집행 상태와 Linear 대비 초과·저집행을 빠르게 파악
- 부서 / G/L 수준에서 주요 차이 원인을 분석
- 월별 추세와 Historical Pattern을 이용해 연말 예상치를 계산
- Simple / Seasonal / ML 방식의 예측 성능을 Backtest로 비교
- 부서 특성에 따라 Forecast Method를 선택할 수 있는 구조 검토
- Budget 재배분 What-if Scenario를 통해 Resource Allocation 의사결정 지원
- Databricks Genie를 활용한 자연어 기반 분석 제공
- 향후 SharePoint / Azure DB / ERP 연동을 통한 자동 Refresh 구조 확장

---

## 2. 비즈니스 문제

기존 예산 분석에서는 다음 문제가 있다.

- Budget / Forecast / Actual 데이터가 여러 버전과 형태로 존재
- 특정 시점 Actual 집행 상태를 전사 / 부서 / G/L 수준에서 빠르게 비교하기 어려움
- 단순 KPI 보고만으로 어떤 부서와 계정이 문제인지 판단하기 어려움
- 월별 추세와 과거 패턴을 이용한 연말 예측이 체계화되어 있지 않음
- 예산을 다른 부서로 재배분했을 때 효과를 사전에 판단하기 어려움
- 분석 결과를 자연어로 탐색하기 위한 기능 부족

따라서 단순 Reporting이 아니라 다음 흐름을 목표로 한다.

```text
Current Status
→ Trend
→ Forecast
→ Scenario
→ Decision
```

---

## 3. 전체 아키텍처

```text
SharePoint / Excel / Azure DB / ERP
                ↓
        Azure Databricks
                ↓
              Bronze
          Raw Source Data
                ↓
              Silver
      Standardized Fact / Dimension
                ↓
               Gold
 Current / Trend / Historical / Forecast
                ↓
        Semantic / Metric View
                ↓
       Dashboard / Power BI
                ↓
          Databricks Genie
                ↓
       Business Decision Support
```

운영 환경에서는 Source Refresh 이후 Silver → Gold → Semantic → Dashboard가 자동으로 갱신되도록 구성하는 것을 최종 방향으로 한다.

---

## 4. 데이터 구성

### 4.1 Bronze

#### 2026 Budget / Actual Raw
```text
finance.bronze.budget_analysis_2026_raw
```

#### Historical Actual Raw
```text
finance.bronze.historical_actual_2021_2025_raw
```

Historical Raw 주요 컬럼:
```text
회계기간
코스트센터
코스트센터내역
원가요소
원가요소명
예산
실적
잔액
```

### 4.2 Silver

#### 2026 Clean
```text
finance.silver.budget_analysis_2026_clean
```

#### Current Actual Monthly
```text
finance.silver.fact_actual_monthly
```

Grain:
```text
fiscal_year × fiscal_month × cost_center × gl_account
```

#### Plan Version
```text
finance.silver.fact_plan_version
```

Plan Version:
```text
BP26
CF02
CF05
CF09
```

#### Dimensions
```text
finance.silver.dim_department
finance.silver.dim_gl_account
finance.silver.dim_month
```

#### Reporting Period
```text
finance.silver.reporting_period
```

Cutoff Month는 수동 입력하지 않고 Actual이 존재하는 가장 최근 월을 자동 계산한다.

예:
```text
Jan~Aug Actual 존재
Sep~Dec NULL
→ cutoff_month = 8
```

0은 실제 Actual로 인정하고 NULL만 미존재로 판단한다.

#### Historical Clean
```text
finance.silver.historical_actual_2021_2025_clean
```

#### Unified Actual Fact
```text
finance.silver.fact_actual_monthly_all
```

2021~2025 Historical Actual과 2026 Current Actual을 하나의 표준 구조로 통합한다.

---

## 5. Current Snapshot 분석

### Gold
```text
finance.gold.finance_current_analysis
```

Grain:
```text
fiscal_year × cost_center × gl_account
```

주요 계산:
```text
Actual YTD
Selected Budget
Selected Linear
Variance vs Linear
Linear Utilization
Remaining Budget
```

Linear 계산:
```text
Linear = Annual Plan × cutoff_month / 12
```

주의:
```text
Actual > Linear
```
은 연간 Budget 초과가 아니라 **현재 시점 기준 Linear 집행 속도 초과**를 의미한다.

### Semantic
```text
finance.semantic.finance_current_metrics
```

Plan Version Parameter:
```text
BP26 / CF02 / CF05 / CF09
```

---

## 6. Dashboard 분석 기능

Dashboard:
```text
Finance Budget Dashboard
```

### 주요 KPI
- Actual YTD
- Selected Budget
- Selected Linear
- Variance vs Linear
- Linear Utilization
- Remaining Budget

### 주요 분석
- Department Variance
- Department Utilization
- Actual YTD Top 5 G/L
- G/L Linear Over
- G/L Linear Under
- Budget Tracking by Department
- Actual Exists / No Budget
- Monthly Cumulative Actual vs Linear
- Variance vs Linear Trend

Dashboard의 목적은 단순 KPI 표시가 아니라 다음 질문에 답하는 것이다.

```text
현재 예산 집행 상태는?
어떤 부서가 리스크인가?
어떤 G/L이 차이를 만들고 있는가?
현재 초과가 일시적인가 지속적인가?
```

---

## 7. Monthly Trend 분석

### Gold
```text
finance.gold.finance_monthly_trend
```

Grain:
```text
fiscal_year × fiscal_month × plan_version × cost_center × gl_account
```

주요 계산:
```text
Actual Monthly
Actual Cumulative
Linear Monthly
Linear Cumulative
Variance vs Linear
Linear Utilization
```

### Semantic
```text
finance.semantic.finance_monthly_metrics
```

### 주요 시각화
- Cumulative Actual vs Selected Linear
- Monthly Actual vs Linear
- Variance vs Linear Trend

Snapshot 분석을 월별 Trend 분석으로 확장하였다.

---

## 8. Genie 기반 자연어 분석

Agent:
```text
Finance Budget and Cost Analysis
```

Source:
```text
finance.semantic.finance_current_metrics
finance.semantic.finance_monthly_metrics
```

주요 역할:
- Current Budget / Actual 비교
- Linear Overrun / Under-run 분석
- Department / G/L Ranking
- Actual without Budget 분석
- Monthly Trend 분석
- 최근 연속 Overrun 탐색

예시 질문:
```text
Show the cumulative Actual vs Linear trend for the Marketing department under CF05.
```

핵심 원칙:
- AI가 수치를 임의로 생성하지 않는다.
- 검증된 Semantic Measure를 사용한다.
- 근거 없는 Business Cause를 추론하지 않는다.
- Positive Variance vs Linear를 Annual Budget Overrun으로 잘못 표현하지 않는다.

---

## 9. Historical Pattern 분석

### Historical Gold
```text
finance.gold.finance_historical_patterns
```

Historical Year는 하드코딩하지 않고 현재 Reporting Year보다 이전 연도만 사용한다.

### Actual YTD
```text
1월부터 현재 월까지 누적 Actual
```

### Full-Year Actual
```text
해당 연도 1~12월 전체 Actual
```

### Historical YTD Share
```text
Historical YTD Share
= Actual YTD / Full-Year Actual
```

예:
```text
8월 YTD = 80M
Full-Year Actual = 120M

Historical YTD Share = 66.7%
```

검증:
- 2021~2025 각 연도 1~12월 데이터 존재
- Unified Actual Fact Grain 중복 0
- 2026은 Historical Pattern에서 제외
- 12월:
  - actual_ytd = full_year_actual
  - historical_ytd_share = 1.0

---

## 10. Forecast Baseline

### Simple Annualization
현재까지의 평균 월 집행 속도가 연말까지 동일하다고 가정한다.

```text
Simple Annualization
= YTD / cutoff_month × 12
```

### Seasonal EAC

EAC:
```text
Estimate at Completion
= 예상 연말 Actual
```

Seasonal EAC:
```text
Seasonal EAC
= Current YTD / Historical Average YTD Share
```

즉 과거 동일 월까지 연간 지출의 몇 %를 사용했는지 반영하여 연말 Actual을 추정한다.

---

## 11. 2025 Backtest

2025를 아직 끝나지 않은 해라고 가정하고 Backtest를 수행하였다.

```text
2021~2024
→ Historical Pattern

2025 Jan~Aug
→ 예측 시점 데이터

2025 Full-Year Actual
→ 정답
```

### 평가 지표

#### APE
```text
Absolute Percentage Error
= |Prediction - Actual| / |Actual|
```

#### MAPE
```text
Mean Absolute Percentage Error
= 여러 APE의 평균
```

#### MAE
```text
Mean Absolute Error
= 평균 금액 오차
```

#### RMSE
큰 예측 오류에 더 큰 영향을 주는 평가 지표.

### 2025 전체 부서 결과

```text
Department Count       : 44
Simple MAPE            : 1.0992%
Seasonal MAPE          : 0.3213%
Seasonal Better        : 41
Simple Better          : 3
Seasonal Error Improvement : 약 70.8%
```

현재 Dataset에서는 Seasonal EAC가 가장 강력한 Baseline이었다.

---

## 12. Scenario 부서 검증

10개 Scenario 부서를 별도로 확인하였다.

- 마케팅팀 3: 강한 계절성
- 시설관리팀 3: 계절성
- 재무회계팀 4: 반복적인 분기 / 연말 패턴
- 생산관리팀 2: Level Shift + Timing
- 정보기술팀 2: Trend / Level Shift
- 구매팀 3: Inflation / Pre-buy
- 연구개발팀 3: Project Milestone
- 해외영업팀 2: Travel / Service Spike
- 물류팀 2: Freight / Fuel Shock
- 고객지원팀 3: Stable + Incident

주요 결과:

```text
마케팅팀 3
Simple APE   : 13.87%
Seasonal APE : 1.46%

정보기술팀 2
Simple APE   : 0.51%
Seasonal APE : 2.26%

연구개발팀 3
Simple APE   : 6.78%
Seasonal APE : 7.58%
```

결론:
- 안정적인 Seasonality가 있는 부서는 Seasonal EAC가 강함
- Trend / Level Shift 부서는 Seasonal 방식이 항상 최적은 아님
- Project / Milestone형은 어떤 방식도 높은 오차를 보일 수 있음

---

## 13. ML Forecast 실험

Notebook:
```text
Finance_ML_YearEnd_Forecast
```

### 기본 Feature
- YTD Actual
- Recent 3-Month Average
- Cutoff Month Actual
- Momentum
- Historical YTD Share

### Target
```text
Full-Year Actual
```

### Linear Regression

Train:
```text
2021~2024
```

Test:
```text
2025
```

결과:
```text
MAE  : 약 6.3M
RMSE : 약 15.3M
MAPE : 약 0.79%
```

### Linear + Historical Seasonality
Historical Seasonality Feature를 추가했지만 성능이 악화되었다.

```text
Base Linear Regression MAPE            : 0.7568%
Linear + Historical Seasonality MAPE   : 1.1030%
```

### Residual Model
Seasonal EAC의 오차만 ML이 보정하도록 구성하였다.

```text
Seasonal EAC MAPE             : 0.3213%
Seasonal EAC + Residual ML    : 0.9073%
```

Residual ML 역시 Seasonal EAC보다 낮은 성능을 보였다.

### Gradient Boosting — Full-Year Amount

```text
Simple Annualization MAPE : 1.0992%
Seasonal EAC MAPE         : 0.3213%
Gradient Boosting MAPE    : 2.5725%
```

Feature Importance:
```text
ytd_actual                    : 0.9897
cutoff_month_momentum         : 0.0051
historical_avg_ytd_share      : 0.0043
recent_3m_momentum            : 0.0009
```

모델이 사실상 YTD 금액 규모에 대부분 의존하였다.

### Gradient Boosting — Remaining Rate

문제 정의를 다음과 같이 변경하였다.

```text
Remaining Rate
= (Full-Year Actual - YTD Actual) / YTD Actual
```

최종 예측:
```text
Expected Full-Year
= YTD × (1 + Predicted Remaining Rate)
```

결과:
```text
Seasonal EAC MAPE                     : 0.3213%
Gradient Boosting Remaining Rate MAPE : 0.7842%
```

Feature Importance:
```text
recent_3m_momentum            : 0.8302
historical_remaining_rate     : 0.1557
cutoff_month_momentum         : 0.0141
```

### ML 실험 결론

```text
복잡한 ML이 항상 더 정확한 것은 아니다.
현재 Dataset에서는 Seasonal EAC가 가장 우수하다.
```

따라서 프로젝트는 "ML 적용" 자체가 아니라 **Backtesting을 통해 적합한 Forecast Method를 선택하는 의사결정 과정**을 강조한다.

---

## 14. Multi-Point Backtest 및 Dataset 현실성 진단

3월 / 5월 / 8월 시점에 대해 2024 / 2025 Backtest를 수행하였다.

### 2024
```text
3월 Simple MAPE   : 3.19%
3월 Seasonal MAPE : 1.58%

5월 Simple MAPE   : 1.48%
5월 Seasonal MAPE : 0.67%

8월 Simple MAPE   : 1.38%
8월 Seasonal MAPE : 0.67%
```

### 2025
```text
3월 Simple MAPE   : 3.38%
3월 Seasonal MAPE : 1.05%

5월 Simple MAPE   : 1.24%
5월 Seasonal MAPE : 0.20%

8월 Simple MAPE   : 1.10%
8월 Seasonal MAPE : 0.32%
```

Seasonal EAC는 대부분의 Forecast 시점에서 Simple보다 우수하였다.

---

## 15. 44개 부서 Pattern Profile

2021~2024 데이터로 44개 부서의 패턴 특성을 계산하였다.

### 계산 지표
- Seasonality Stability
- Linear Share Gap
- Trend Slope
- Trend R²
- Monthly Volatility

### 분포 결과

#### Seasonality Std
```text
Min    : 0.0203%p
P25    : 0.0477%p
Median : 0.0618%p
P75    : 0.0819%p
Max    : 7.3193%p
```

#### Linear Share Gap
```text
Median : 0.4116%p
P75    : 0.6385%p
Max    : 10.0720%p
```

#### Annual Trend Slope
```text
Median : 약 5.12% / year
```

#### Trend R²
```text
Median : 0.9837
```

#### Monthly Volatility
```text
Median : 2.09%
P75    : 2.72%
Max    : 51.82%
```

### 해석

현재 Synthetic Dataset의 대부분 부서는:
- 매년 거의 동일한 월별 집행 패턴
- 약 5% 수준의 매우 안정적인 연간 Trend
- 낮은 Monthly Volatility

를 갖고 있다.

따라서 현재 Dataset만 보고 Forecast Method Selector Threshold를 고정하면 현재 데이터에 과도하게 최적화될 가능성이 있다.

향후 방향:
```text
Baseline Dataset
+
Stress Test Dataset
+
Rolling Backtest
```

을 함께 사용하여 Model Selection Rule을 검증한다.

---

## 16. Forecast Method Selection 방향

모든 부서에 하나의 Forecast 방식을 강제로 적용하지 않고, 부서 특성 및 과거 Backtest 성능에 따라 적합한 방법을 선택하는 구조를 검토한다.

후보:
```text
Simple Annualization
Seasonal EAC
Trend Model
ML Model
Low Confidence / Manual Review
```

원칙:
- 부서명을 기준으로 Hard-coding하지 않음
- 미래 정답을 보고 Method를 선택하지 않음
- 예측 시점 이전 데이터만 사용
- 최종 Test Year는 Selection Rule 생성에 사용하지 않음

---

# 17. Budget Reallocation Scenario Modelling

Notebook:
```text
Finance_Budget_Scenario_Modeling
```

### 목적

전사 Budget 총액을 늘리지 않고 부서 간 Budget을 재배분했을 때 Projected Overrun Risk가 어떻게 달라지는지 분석한다.

### Baseline 계산
- Current Actual YTD
- Current CF05 Budget
- Historical Average YTD Share
- Seasonal EAC
- Forecast Gap

```text
Forecast Gap
= Seasonal EAC - Current Budget
```

### What-if Scenario

예시:
```text
Source Department : 재무회계팀 4
Target Department : 마케팅팀 3
Reallocation      : 100,000,000
```

Budget 이동:
```text
재무회계팀 4 Budget -100M
마케팅팀 3 Budget   +100M
```

전사 총 Budget은 변경하지 않는다.

---

## 18. Scenario Modelling 실제 결과

### 전사 Budget Validation

```text
Baseline Total Budget : 36,725,755,630
Scenario Total Budget : 36,725,755,630
Budget Difference     : 0

Minimum Scenario Budget : 292,340,152

PASS - Total Budget is preserved.
PASS - No negative Scenario Budget.
```

즉 Budget 총액을 증가시키지 않고 Resource Allocation만 변경하는 What-if Model이 정상적으로 작동하였다.

### 마케팅팀 3

```text
Current Budget       : 789,112,330
Scenario Budget      : 889,112,330
Seasonal EAC         : 978,057,834

Before Forecast Gap  : +188,945,504
After Forecast Gap   :  +88,945,504

Before Status        : PROJECTED_OVERRUN
After Status         : PROJECTED_OVERRUN
```

해석:
- Budget 100M 추가로 예상 Overrun이 약 188.9M → 88.9M으로 감소
- Risk는 감소했지만 완전히 제거되지는 않음

### 재무회계팀 4

```text
Current Budget       : 820,630,150
Scenario Budget      : 720,630,150
Seasonal EAC         : 784,216,654

Before Forecast Gap  : -36,413,496
After Forecast Gap   : +63,586,504

Before Status        : WITHIN_BUDGET
After Status         : PROJECTED_OVERRUN
```

해석:
- 100M을 재배분하기 전에는 약 36.4M Budget 여유가 존재
- 100M을 이동한 후 약 63.6M Projected Overrun 발생
- Target Department의 Risk를 줄였지만 Source Department에 새로운 Risk를 생성

### Scenario의 핵심 의사결정 Insight

```text
Budget Reallocation ≠ 항상 개선
```

Scenario Model은 단순히 Budget 이동을 계산하는 것이 아니라 다음 Trade-off를 보여준다.

```text
Target Risk 감소
vs
Source Risk 증가
```

따라서 사용자는 "얼마를 이동할 수 있는가"와 "새로운 Risk가 발생하는가"를 동시에 판단할 수 있다.

이 사례는 Scenario Modelling / Resource Allocation / Decision Support의 실제 활용 예시로 사용한다.

---

## 19. 프로젝트 핵심 의사결정 흐름

```text
Current Budget / Actual
        ↓
Linear Variance
        ↓
Monthly Trend
        ↓
Historical Pattern
        ↓
Year-End Forecast
        ↓
Forecast Method Evaluation
        ↓
Budget Reallocation Scenario
        ↓
Decision Support
```

핵심 원칙:

```text
코드와 검증된 데이터가 수치를 만든다.
AI는 수치를 해석하고 사용자의 탐색을 돕는다.
```

---

## 20. 포트폴리오 증명 자료

### GitHub Repository 구성 예시

```text
finance-budget-decision-support/
│
├─ README.md
│
├─ notebooks/
│  ├─ Finance_ML_YearEnd_Forecast.ipynb
│  └─ Finance_Budget_Scenario_Modeling.ipynb
│
├─ sql/
│  ├─ historical_patterns.sql
│  └─ backtest.sql
│
├─ docs/
│  ├─ architecture.png
│  ├─ dashboard_overview.png
│  ├─ genie_analysis.png
│  ├─ scenario_modeling.png
│  └─ project_plan.md
│
└─ sample_data/
   └─ synthetic_sample.csv
```

### 현재 확보한 증거
- Databricks Notebook Export
- Finance Budget Dashboard Screenshot
- Genie Agent Screenshot
- Scenario Modelling Screenshot
- Forecast Backtest 결과
- Historical Pattern SQL
- Backtest SQL
- 프로젝트 기획서

### 포트폴리오 핵심 문구

> Backtesting showed that more complex ML was not automatically superior. For the stable historical spending patterns in this dataset, Seasonal EAC produced the most accurate year-end forecast. The solution therefore focuses on selecting fit-for-purpose forecasting methods and extends the forecast into a budget reallocation what-if model that evaluates decision trade-offs while preserving the total organisational budget.

---

## 21. 주요 성과

### Data Engineering
- Bronze / Silver / Gold 구조 설계
- Current + Historical Actual 통합
- Cutoff Month 자동 계산
- 표준 Fact / Dimension 구축

### Analytics
- Current Snapshot
- Monthly Trend
- Historical Pattern
- Year-End Forecast
- Backtesting
- Outlier / Risk 분석

### Forecast / ML
- Simple / Seasonal / Linear / Gradient Boosting 비교
- ML이 항상 우수하지 않음을 Backtest로 검증
- Dataset 패턴과 모델 적합성 분석
- Forecast Method Selection 방향 수립

### Scenario Modelling
- Budget Reallocation What-if Model 구현
- Total Budget 보존 검증
- Negative Budget 방지 검증
- Source / Target Risk Trade-off 분석

### AI
- Databricks Genie 기반 자연어 분석
- Semantic Measure 기반 응답
- 근거 없는 Cause 추론 방지

---

## 22. 향후 마무리 방향

### 1. GitHub README 정리
```text
Business Problem
Solution
Architecture
Dashboard
Forecast & Backtesting
Scenario Modelling
AI / Genie
Technology Stack
Lessons Learned
```

### 2. Architecture Diagram 제작

```text
Source
→ Bronze
→ Silver
→ Gold
→ Semantic
→ Dashboard / Genie
→ Forecast / Scenario
→ Decision
```

### 3. Demo Evidence 정리
- Dashboard
- Genie
- Forecast Notebook
- Scenario Notebook

### 4. 선택 사항
2~3분 Demo Video 제작

---

## 23. 최종 포트폴리오 메시지

> Budget 및 Actual 데이터를 Databricks 기반 Bronze-Silver-Gold 구조로 통합하고, Dashboard와 Genie를 통해 Current Status, Trend, Risk를 탐색할 수 있도록 구현하였다. Historical Pattern 기반 Forecast와 여러 ML 모델을 Backtest한 결과, 복잡한 ML이 항상 우수하지 않으며 현재 Dataset에서는 Seasonal EAC가 가장 정확함을 확인하였다. 이후 Forecast 결과를 Budget Reallocation What-if Model로 확장하여, 전사 Budget 총액을 유지하면서 부서 간 자원 이동이 Projected Overrun Risk에 미치는 영향을 비교할 수 있도록 구현하였다. 이를 통해 단순 Reporting을 넘어 Planning, Resource Allocation 및 Operational Decision Support까지 연결하는 분석 플랫폼을 구축하였다.
