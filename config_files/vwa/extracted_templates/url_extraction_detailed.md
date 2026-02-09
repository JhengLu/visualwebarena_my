# URL Extraction: Detailed Flow

This document clarifies exactly where the URL in the LLM prompt comes from.

## Common Misconception

❌ **WRONG:** The URL in the prompt comes from `start_url` in the config file
✅ **CORRECT:** The URL comes from the **current browser page** (dynamically obtained)

## Complete URL Flow

### 1. Config File (Initial Setup Only)

**File:** `test_classifieds/0.json`
```json
{
  "start_url": "http://158.130.4.229:9980",
  ...
}
```

**Purpose:** Used ONLY to initialize the browser to the starting page.

### 2. Browser Initialization

**File:** `run.py` line 379

```python
obs, info = env.reset(options={"config_file": config_file})
```

The `env.reset()` does:
1. Reads `start_url` from config
2. Navigates browser to that URL
3. Returns current observation and info

**File:** `browser_env/env.py` (ScriptBrowserEnv.reset)
```python
def reset(self, options=None):
    config_file = options["config_file"]
    # ... loads config ...
    self.page.goto(start_url)  # Navigate to start_url
    # ...
    info = {"page": self.page, ...}  # page object contains current URL
    return obs, info
```

### 3. Building the Trajectory

**File:** `run.py` lines 380-381

```python
state_info: StateInfo = {"observation": obs, "info": info}
trajectory.append(state_info)
```

The `trajectory` is a list of `StateInfo` objects:
```python
trajectory = [
    {
        "observation": {...},
        "info": {
            "page": <Page object>,  # ← Contains current URL!
            ...
        }
    },
    # ... more states as agent takes actions ...
]
```

### 4. After Agent Takes Action

**File:** `run.py` line 421-423

```python
obs, _, terminated, _, info = env.step(action)
state_info = {"observation": obs, "info": info}
trajectory.append(state_info)
```

Each time the agent takes an action (like clicking a link), the browser may navigate to a new page. The `env.step()` returns the **new current page** info.

### 5. URL Extraction in Prompt Constructor

**File:** `agent/prompts/prompt_constructor.py` lines 233-245

```python
def construct(self, trajectory, intent, meta_data={}):
    # ... setup ...

    # Get the LATEST state from trajectory
    state_info: StateInfo = trajectory[-1]  # ← Last element

    # Extract observation
    obs = state_info["observation"][self.obs_modality]

    # Extract the page object
    page = state_info["info"]["page"]

    # Get CURRENT URL from browser page object
    url = page.url  # ← This is the LIVE browser URL!

    # ... rest of code ...
```

### 6. URL Mapping

**File:** `agent/prompts/prompt_constructor.py` lines 123-128, 249

```python
def map_url_to_real(self, url: str) -> str:
    """Map the urls to their real world counterparts"""
    for i, j in URL_MAPPINGS.items():
        if i in url:
            url = url.replace(i, j)
    return url

# Later in construct():
current = template.format(
    objective=intent,
    url=self.map_url_to_real(url),  # ← Maps local URL to public URL
    observation=obs,
    previous_action=previous_action_str,
)
```

**Purpose:** Converts internal URLs (like `http://shopping.com`) to their public counterparts (like `http://onestopshop.com`) for the prompt.

### 7. Final Result in Prompt

The user message in the API request contains:

```
OBSERVATION:
[1] RootWebArea 'Classifieds'...
...

URL: http://158.130.4.229:9980  ← CURRENT browser URL (after mapping)

OBJECTIVE: Find me the cheapest blue kayak on this site.

PREVIOUS ACTION: None
```

## Example Scenario

### Initial State
```
Config start_url: http://158.130.4.229:9980
Browser navigates to: http://158.130.4.229:9980
Prompt URL: http://158.130.4.229:9980
```

### After Agent Clicks "Search"
```
Config start_url: http://158.130.4.229:9980 (unchanged)
Browser now at: http://158.130.4.229:9980/search
Prompt URL: http://158.130.4.229:9980/search ← UPDATED!
```

### After Agent Clicks a Product
```
Config start_url: http://158.130.4.229:9980 (unchanged)
Browser now at: http://158.130.4.229:9980/item?id=4799
Prompt URL: http://158.130.4.229:9980/item?id=4799 ← UPDATED AGAIN!
```

## Summary

| Source | Purpose | Updated? |
|--------|---------|----------|
| `config["start_url"]` | Initialize browser | Never |
| `page.url` (from browser) | Current location | Every action |
| `url` in prompt | Tell LLM current page | Every turn |

## Key Code References

1. **Config is read:** [run.py:330-332](../../../run.py#L330-L332)
2. **Browser initialized:** [run.py:379](../../../run.py#L379)
3. **State captured:** [run.py:380-381](../../../run.py#L380-L381)
4. **State updated after action:** [run.py:421-423](../../../run.py#L421-L423)
5. **URL extracted from browser:** [prompt_constructor.py:244-245](../../../agent/prompts/prompt_constructor.py#L244-L245)
6. **URL mapped:** [prompt_constructor.py:249](../../../agent/prompts/prompt_constructor.py#L249)
7. **URL inserted in template:** [prompt_constructor.py:247-252](../../../agent/prompts/prompt_constructor.py#L247-L252)

## Diagram

```
Config File
  └─→ start_url: "http://..."
        │
        ▼
  Browser (Playwright)
  ┌─────────────────────┐
  │ page.goto(start_url)│ ← Initial navigation
  └─────────────────────┘
        │
        ▼
  Agent Loop
  ┌──────────────────────────┐
  │ 1. Get page.url         │ ← Current URL
  │ 2. Build prompt         │
  │ 3. LLM decides action   │
  │ 4. Execute action       │
  │ 5. page.url changes?    │ ← URL may update
  └─────────┬────────────────┘
           │
           │ Loop repeats
           ▼
  Prompt always contains
  CURRENT page.url, not
  start_url from config
```

The URL in the LLM prompt is **dynamic** and reflects where the browser currently is, not where it started!
