# 10. AI Prompt Example: February 26 Period

This document demonstrates a realistic prompt payload generated from the sample data (`examples/2026-02-february_26.yaml`) and an example of the expected AI response based on the specification in `09_ai_insights_spec.md`.

## 1. System Prompt

**Role**: You are a supportive, concise, and analytical personal finance assistant for the FlatPlan app.
**Task**: Analyze the user's current budget state based on the provided JSON data. Compare the time pacing against the spending pacing. Identify areas where the user is over budget, recommend reallocations if Free Money is running low, and highlight any upcoming mandatory expenses.
**Tone**: Constructive, encouraging, non-judgmental. Keep it under 3 sentences for the summary and provide 1-2 short bullet points for actionable tips.
**Output Format**: You MUST output ONLY valid JSON conforming to the requested schema. Do not wrap it in markdown block quotes (e.g., no \`\`\`json).

## 2. Input Payload (JSON)

This payload is derived directly from the February 26 data.

```json
{
  "period": {
    "name": "February 26",
    "days_passed": 25,
    "days_total": 30,
    "pacing_percentage": 83.33
  },
  "overall_stats": {
    "total_income_planned": 152500.0,
    "total_income_fact": 171324.0,
    "total_spent_planned": 135610.0,
    "total_spent_fact": 173924.0,
    "free_money_remaining": -2600.0
  },
  "categories": [
    { "name": "🏢Housing & Utilities", "type": "Mandatory", "planned": 33549.0, "fact": 33549.0, "remaining": 0.0, "is_overbudget": false },
    { "name": "🏛️ Government & State", "type": "Mandatory", "planned": 6253.0, "fact": 6198.0, "remaining": 55.0, "is_overbudget": false },
    { "name": "📞 Communications", "type": "Mandatory", "planned": 650.0, "fact": 670.0, "remaining": -20.0, "is_overbudget": true },
    { "name": "💻 Hardware & Software", "type": "Optional", "planned": 500.0, "fact": 2647.0, "remaining": -2147.0, "is_overbudget": true },
    { "name": "☁️ Digital Subscriptions", "type": "Mandatory", "planned": 2000.0, "fact": 1077.0, "remaining": 923.0, "is_overbudget": false },
    { "name": "🎒 School & Childcare", "type": "Mandatory", "planned": 14000.0, "fact": 14000.0, "remaining": 0.0, "is_overbudget": false },
    { "name": "💳 Loans", "type": "Mandatory", "planned": 40158.0, "fact": 40266.0, "remaining": -108.0, "is_overbudget": true },
    { "name": "🛒 Groceries", "type": "Mandatory", "planned": 25000.0, "fact": 21090.0, "remaining": 3910.0, "is_overbudget": false },
    { "name": "👨‍👩‍👧‍👦 Family", "type": "Optional", "planned": 5000.0, "fact": 11800.0, "remaining": -6800.0, "is_overbudget": true },
    { "name": "🚗 Transport & Auto", "type": "Mandatory", "planned": 2000.0, "fact": 4528.0, "remaining": -2528.0, "is_overbudget": true },
    { "name": "🧴 Health & Beauty", "type": "Mandatory", "planned": 2000.0, "fact": 666.0, "remaining": 1334.0, "is_overbudget": false },
    { "name": "👕 Clothing & Shoes", "type": "Optional", "planned": 1000.0, "fact": 5458.0, "remaining": -4458.0, "is_overbudget": true },
    { "name": "🍽️ Dining Out", "type": "Optional", "planned": 2000.0, "fact": 6667.0, "remaining": -4667.0, "is_overbudget": true },
    { "name": "🤝 Charity & Donations", "type": "Optional", "planned": 500.0, "fact": 0.0, "remaining": 500.0, "is_overbudget": false },
    { "name": "🎟️ Entertainment & Leisure", "type": "Optional", "planned": 500.0, "fact": 440.0, "remaining": 60.0, "is_overbudget": false },
    { "name": "📈 Savings & Investments", "type": "Optional", "planned": 0.0, "fact": 0.0, "remaining": 0.0, "is_overbudget": false },
    { "name": "🧺 Home Essentials", "type": "Optional", "planned": 500.0, "fact": 24868.0, "remaining": -24368.0, "is_overbudget": true }
  ]
}
```

## 3. Simulated AI Response

Based on the data, the AI notices that while income is higher than planned, total spending has massively exceeded the budget, leading to negative Free Money (-$2,600). The biggest culprits are "Home Essentials", "Family", and "Clothing & Shoes".

```json
{
  "health_status": "OFF_TRACK",
  "summary_message": "You are 83% through the period, but significant overspending in Optional categories like 'Home Essentials' and 'Family' has pushed your Free Money into the negative (-$2,600). Although your income was higher than planned, it wasn't enough to cover these extra costs.",
  "actionable_tips": [
    "Put an immediate pause on Optional spending, particularly in 'Dining Out' and 'Clothing & Shoes', for the next 5 days.",
    "Review the massive 24k expense in 'Home Essentials' to ensure it was necessary or consider offsetting it with savings."
  ]
}
```
