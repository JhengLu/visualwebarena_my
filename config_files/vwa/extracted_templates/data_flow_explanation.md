# Data Flow: Config File → LLM Serving Engine

## Overview
This document explains what JSON data is sent to the LLM serving engine when `run.py` processes a test configuration file.

## Example Config File
Using `/mnt/2_1/visualwebarena_my/config_files/vwa/test_classifieds/0.json` as an example:

```json
{
  "sites": ["classifieds"],
  "task_id": 0,
  "require_login": true,
  "storage_state": "./.auth/classifieds_state.json",
  "start_url": "http://158.130.4.229:9980",
  "geolocation": null,
  "intent_template": "Find me the {{attribute}} {{item}} on this site.",
  "intent": "Find me the cheapest blue kayak on this site.",
  "image": null,
  "instantiation_dict": {
    "attribute": "cheapest",
    "item": "blue kayak"
  },
  "require_reset": false,
  "eval": {
    "eval_types": ["url_match"],
    "reference_answers": null,
    "reference_url": "http://158.130.4.229:9980/index.php?page=item&id=4799",
    "program_html": [],
    "url_note": "EXACT"
  },
  "reasoning_difficulty": "medium",
  "visual_difficulty": "easy",
  "overall_difficulty": "medium",
  "comments": "",
  "intent_template_id": 0
}
```

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. CONFIG FILE (0.json)                                         │
│    - Full task specification                                    │
│    - Contains metadata, templates, evaluation criteria          │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. run.py EXTRACTS (lines 330-372)                              │
│    ✓ intent: "Find me the cheapest blue kayak on this site."   │
│    ✓ task_id: 0                                                 │
│    ✓ image: null                                                │
│    ✓ storage_state: "./.auth/classifieds_state.json"           │
│                                                                  │
│    ✗ intent_template (NOT used)                                 │
│    ✗ instantiation_dict (NOT used)                              │
│    ✗ eval config (NOT used)                                     │
│    ✗ difficulty ratings (NOT used)                              │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. agent.next_action() RECEIVES (lines 393-398)                 │
│    - trajectory: [StateInfo objects with observations]          │
│    - intent: "Find me the cheapest blue kayak on this site."   │
│    - images: [] (or List[PIL.Image] if provided)               │
│    - meta_data: {"action_history": ["None", ...]}              │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. PromptConstructor.construct() BUILDS (lines 157-164)         │
│    Fills template with:                                         │
│    - objective: "Find me the cheapest blue kayak on this site." │
│    - url: "http://158.130.4.229:9980" (from browser)           │
│    - observation: <accessibility tree from browser>             │
│    - previous_action: "None" (from action_history)              │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. get_lm_api_input() FORMATS (lines 39-64)                     │
│    Creates OpenAI chat messages format                          │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ 6. FINAL JSON SENT TO LLM API                                   │
│                                                                  │
│    [                                                             │
│      {                                                           │
│        "role": "system",                                         │
│        "content": "<system instructions>"                        │
│      },                                                          │
│      {                                                           │
│        "role": "system",                                         │
│        "name": "example_user",                                   │
│        "content": "OBJECTIVE: ...\nURL: ...\nOBSERVATION: ..."  │
│      },                                                          │
│      {                                                           │
│        "role": "system",                                         │
│        "name": "example_assistant",                              │
│        "content": "Let me think... <reasoning> <action>..."     │
│      },                                                          │
│      ... (more examples) ...                                     │
│      {                                                           │
│        "role": "user",                                           │
│        "content": "OBJECTIVE: Find me the cheapest blue kayak   │
│                    on this site.                                 │
│                    URL: http://158.130.4.229:9980               │
│                    OBSERVATION: <current accessibility tree>    │
│                    PREVIOUS ACTION: None"                        │
│      }                                                           │
│    ]                                                             │
└─────────────────────────────────────────────────────────────────┘
```

## Key Points

### ✅ What IS Sent to LLM:
1. **intent** - The fully instantiated task description
   - Example: "Find me the cheapest blue kayak on this site."
2. **Current browser state**:
   - URL of current page
   - Accessibility tree / HTML / Screenshot (depending on observation_type)
3. **Action history** - List of previous actions taken
4. **System instructions** - From the instruction file (e.g., `state_action_agent.json`)
5. **Few-shot examples** - Demonstration examples from instruction file
6. **Input images** - If task includes reference images (optional)

### ❌ What is NOT Sent to LLM:
1. **intent_template** - The template with placeholders
   - Example: `"Find me the {{attribute}} {{item}} on this site."`
2. **instantiation_dict** - The values used to fill the template
   - Example: `{"attribute": "cheapest", "item": "blue kayak"}`
3. **eval** configuration - Evaluation criteria and reference answers
4. **Metadata** - difficulty ratings, comments, task_id
5. **Environment config** - sites, require_login, storage_state, etc.

## Why This Matters

The LLM only sees:
- **What the user wants** (intent)
- **What it can currently see** (browser observation)
- **What it has done** (action history)

The LLM does NOT see:
- How the task was generated (template + instantiation)
- How it will be evaluated
- Any hints about difficulty or expected solution

This ensures the LLM solves the task based purely on the objective and observations, without any privileged information about the evaluation setup.

## Code References

- Config loading: [run.py:330-372](../../run.py#L330-L372)
- Agent invocation: [run.py:393-398](../../run.py#L393-L398)
- Prompt construction: [agent/agent.py:157-164](../../../agent/agent.py#L157-L164)
- API formatting: [agent/prompts/prompt_constructor.py:39-64](../../../agent/prompts/prompt_constructor.py#L39-L64)
