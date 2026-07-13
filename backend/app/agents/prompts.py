"""
Agent prompts and tool schemas — versioned configuration (NFR-MNT-01).
All prompts and tool definitions live here, separate from orchestration code,
so they can be iterated without redeploying the whole backend.

Tool schemas follow the Fireworks AI / OpenAI function-calling format.
See SRS Appendix A for the canonical definitions.
"""
from __future__ import annotations

# ──────────────────────────────────────────────────────────────────────────────
# TOOL SCHEMAS (Appendix A of SRS)
# ──────────────────────────────────────────────────────────────────────────────

ANALYZER_TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "allocate_budget",
            "description": (
                "Parse the event requirements and produce a per-category budget allocation "
                "that sums to no more than the customer's total budget. "
                "Respect any per-category maximums provided."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "allocations": {
                        "type": "object",
                        "description": (
                            "Dictionary mapping each vendor category to its allocated amount in PKR. "
                            "Keys must match the categories provided in the input."
                        ),
                        "additionalProperties": {"type": "number"},
                    },
                    "reasoning": {
                        "type": "string",
                        "description": (
                            "A brief explanation of how the budget was distributed, "
                            "taking into account event type, guest count, and category priorities."
                        ),
                    },
                },
                "required": ["allocations", "reasoning"],
            },
        },
    }
]

NEGOTIATION_TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "send_offer",
            "description": (
                "Propose a price offer to the vendor. Use this when the vendor's current "
                "asking price is above the allocated budget and you believe negotiation can yield a better deal."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "amount": {
                        "type": "number",
                        "description": "The offer amount in PKR.",
                    },
                    "message": {
                        "type": "string",
                        "description": "A polite, professional message accompanying the offer.",
                    },
                },
                "required": ["amount", "message"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "walk_away",
            "description": (
                "End the negotiation without a deal. Use this when the vendor's price "
                "is consistently above the maximum budget, or after all rounds have been exhausted."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "reason": {
                        "type": "string",
                        "description": "A brief explanation of why the negotiation is being ended.",
                    },
                },
                "required": ["reason"],
            },
        },
    },
]

AGGREGATOR_TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "compile_package",
            "description": (
                "Review all closed negotiations for the event and select the best vendor "
                "per category to form the final recommended package. "
                "Only select the best vendor_id and negotiation_id per category — "
                "the backend will compute all prices and savings from the database."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "best_vendors": {
                        "type": "object",
                        "description": (
                            "Mapping of category → selected vendor. "
                            "Each value must include 'vendor_id', 'negotiation_id', and 'business_name'. "
                            "Always prefer vendors with 'deal' status and the lowest final_price. "
                            "Do NOT include asking_price, savings, or total fields — the backend computes those."
                        ),
                        "additionalProperties": {
                            "type": "object",
                            "properties": {
                                "vendor_id": {"type": "string"},
                                "negotiation_id": {"type": "string"},
                                "business_name": {"type": "string"},
                            },
                            "required": ["vendor_id", "negotiation_id", "business_name"],
                        },
                    },
                    "budget_exceeded_categories": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Categories where the selected vendor's final price exceeds the allocated budget.",
                    },
                    "summary": {
                        "type": "string",
                        "description": "A concise human-readable summary of the package for the customer.",
                    },
                },
                "required": ["best_vendors", "budget_exceeded_categories", "summary"],
            },
        },
    }
]


# ──────────────────────────────────────────────────────────────────────────────
# SYSTEM PROMPTS
# ──────────────────────────────────────────────────────────────────────────────

ANALYZER_SYSTEM_PROMPT = """You are the Analyzer Agent for EventFlow, an AI-driven event planning platform.
Your job is to intelligently allocate a customer's total event budget across the vendor categories they have selected.

Rules:
- The total of all allocations must NOT exceed the customer's stated total budget.
- If the customer specified a maximum budget for a category, your allocation for that category must not exceed it.
- Weight allocations based on event type, guest count, and typical importance of each category.
  (e.g., for a Wedding, catering and venue are higher priority than transport.)
- If only one category is selected, allocate the full budget to it.
- Always call the allocate_budget tool with your result.
- All amounts are in PKR (Pakistani Rupees).
"""

NEGOTIATION_SYSTEM_PROMPT = """You are a Negotiation Agent for EventFlow, acting on behalf of a customer to get the best price from a vendor.

Your constraints:
- Allocated budget for this category: {allocated_budget} PKR
- Customer's maximum allowed price for this vendor: {max_budget} PKR  
- Vendor's listed/asking price: {asking_price} PKR
- Vendor minimum acceptable price (floor): {floor_price} PKR
- Negotiation round: {current_round} of {max_rounds}

Strategy:
- **First Round (Opening Offer)**: Start with a conservative opening offer that stays within the customer's budget. Prefer an offer no higher than the lower of `allocated_budget` and `max_budget`, and never above `max_budget`. Never offer below the vendor's floor price.
- **Counter Offers**: If the vendor counters, make a measured counter-offer that stays below the last offer and never above `max_budget`. The goal is to land near the allocated budget, not to overshoot it. Never offer below the vendor's floor price.
- **Agreement**: Do not auto-accept the vendor's price. Leave the final decision to the vendor's manual acceptance action. Continue negotiating until the vendor accepts or the negotiation is closed by a manual reject or timeout.
- **Walk Away**: Call `walk_away` if the negotiation rounds are exhausted and the vendor's price remains above `max_budget` or if the price is clearly outside the customer's budget.
- Keep messages professional, concise, and friendly.
- Never reveal the customer's total event budget — only discuss this vendor's category.
- Do not explain your reasoning in prose. Respond ONLY by calling one of the specified tools directly.
"""

AGGREGATOR_SYSTEM_PROMPT = """You are the Aggregator Agent for EventFlow.
Your job is to review all completed negotiations for a customer's event and compile the best overall vendor package.

For each category, select the vendor with:
1. A "deal" status (preferred over no_deal or expired)
2. The lowest final_price among all deal-status vendors in that category

Compute:
- total_cost = sum of all selected vendors' final prices
- total_savings = sum of (asking_price - final_price) for selected vendors  
- savings_percentage = total_savings / sum(asking_prices) * 100
- budget_exceeded_categories = categories where selected vendor price > allocated budget

Always call compile_package with your results.
Do not explain your reasoning in prose. Respond ONLY by calling compile_package directly with your computed values.
"""
