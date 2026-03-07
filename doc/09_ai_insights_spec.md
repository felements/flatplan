# 09. AI Insights Feature Specification

## Overview
A new feature to display a "Budget Health & AI Suggestions" card on the Dashboard (the fourth summary card next to "Total Budget", "Total Spent", and "Free Money"). This feature leverages Generative AI to analyze the user's current spending pacing, remaining balances, and category-level data to provide personalized, actionable financial advice.

## UI/UX Changes
1. **Dashboard View**: 
   - Add a fourth card at the top of the dashboard.
   - **Card Content**:
     - **Header**: "AI Insights" or "Budget Health".
     - **Status Indicator**: An icon/color reflecting the assessed state (Green = On Track, Orange = Caution, Red = Off Track).
     - **Summary**: 1-2 sentence high-level take on the budget state.
     - **Action Items**: 1-2 concise bullet points of advice.
     - **Refresh Action**: A small refresh button to manually trigger a re-analysis.
2. **Settings View**:
   - Add a section for "AI Assistant Configuration".
   - Input fields for:
     - **Provider Selection**: (e.g., OpenAI / Gemini / Anthropic)
     - **API Key**: Securely stored locally.
   - Toggle to Enable/Disable AI Insights.

---

## Data Payload & Prompt Engineering

To minimize token usage and latency while maximizing context, the prompt should receive a summarized JSON representation of the current active `Period` and its statistics.

### 1. Data Formatted into the Prompt
The prompt will include a strictly structured JSON payload containing:

* **Time Context**: 
  * Total days in the period vs. Days passed (determines the "pacing percentage").
* **Overall Stats**: 
  * Total Income (Planned vs. Fact).
  * Total Expenses (Planned vs. Fact).
  * Free Money (Remaining unallocated funds).
* **Category High-Level Stats**:
  * For each active category: Name, Group (Mandatory/Optional), Planned amount, Fact amount, Remaining amount, and whether it's over budget.
* **Important Upcoming Expenses**:
  * Unpaid planned expenses with due dates in the near future.

**Example Payload Structure:**
```json
{
  "period": {
    "name": "March 2026",
    "days_passed": 4,
    "days_total": 31,
    "pacing_percentage": 12.9
  },
  "overall_stats": {
    "total_income_planned": 5000,
    "total_income_fact": 5000,
    "total_spent_planned": 4000,
    "total_spent_fact": 800,
    "free_money_remaining": 200
  },
  "categories": [
    {
      "name": "Groceries",
      "type": "Mandatory",
      "planned": 600,
      "fact": 450,
      "remaining": 150,
      "is_overbudget": false
    }
  ]
}
```

### 2. System Instructions
*   **Role**: You are a supportive, concise, and analytical personal finance assistant.
*   **Task**: Analyze the user's current budget state based on the provided JSON data. Compare the time pacing (e.g., 13% of the month passed) against the spending pacing (e.g., 75% of groceries budget spent).
*   **Tone**: Constructive, encouraging, non-judgmental. Keep it brief.
*   **Output Format**: You MUST output ONLY valid JSON conforming to the requested schema.

---

## Expected AI Outcomes & Responses

The AI will output a JSON object containing the `health_status`, `summary_message`, and `actionable_tips`. Here are examples of scenarios the AI could identify:

1. **Pacing Warnings (The "Too Fast" Scenario)**:
   - *Outcome*: "CAUTION"
   - *Summary*: "You are 13% into the month but have already spent 75% of your Groceries budget."
   - *Actionable Tips*: "Pace your grocery shopping or reallocate extra funds from Free Money to cover the remaining days."

2. **Income Shortfall (The "Squeezed Budget" Scenario)**:
   - *Outcome*: "OFF_TRACK"
   - *Summary*: "Your fact income is lower than planned, causing your Free Money to drop to zero."
   - *Actionable Tips*: "Consider pausing optional purchases in the 'Entertainment' category to maintain a healthy balance."

3. **Positive Reinforcement (The "Smooth Sailing" Scenario)**:
   - *Outcome*: "ON_TRACK"
   - *Summary*: "Great job! You are halfway through the month and your spending is perfectly aligned with your planned budget."
   - *Actionable Tips*: "You have $300 remaining in optional spending if you want to treat yourself, or leave it to boost savings."

4. **Upcoming Due Dates Anticipation**:
   - *Outcome*: "CAUTION"
   - *Summary*: "You have three planned mandatory expenses due next week totaling $500."
   - *Actionable Tips*: "Keep your $600 Free Money intact to ensure these bills are comfortably covered."

---

## Architecture & Implementation Steps

1. **Data Model**: 
   - Create `AiInsight` using `freezed` and `json_serializable` to match the expected JSON output from the AI.
2. **Settings**: 
   - Update `UserDefaults` (or equivalent shared preferences) to store the API Key and Provider choice.
3. **Service Layer (`AiInsightService`)**: 
   - Constructs the prompt payload from `Period` and `PeriodStats`.
   - Uses `http` package (or `google_generative_ai` SDK) to request structured JSON output.
4. **State Management (`aiInsightProvider`)**:
   - A Riverpod `FutureProvider` that manages the fetch state.
   - **Caching Strategy**: Because LLM calls are slow and cost money, we should NOT call the API on every widget rebuild. Instead, we generate an insight when requested, or at most once per app session / once per day, storing the last insight locally (e.g., in `~/.flatplan/ai_cache.yaml`).
5. **UI Integration**:
   - Add the `AiSummaryCard` to `DashboardView`. Handle `AsyncLoading`, `AsyncData`, and `AsyncError` gracefully.
