# How the LLM Request JSON is Constructed

This document traces the exact code flow showing how the original VisualWebArena code constructs the JSON request sent to the LLM API.

## Complete Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. run.py: test() function (line 323-463)                      │
│    Loads config file and extracts intent                        │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. run.py: agent.next_action() (line 393-398)                  │
│    Calls agent with: trajectory, intent, images, meta_data     │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. agent/agent.py: PromptAgent.next_action() (line 128-198)    │
│    Constructs prompt using prompt_constructor                   │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. agent/prompts/prompt_constructor.py:                        │
│    CoTPromptConstructor.construct() (line 223-260)             │
│    Fills template with: intent, url, observation, prev_action  │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. agent/prompts/prompt_constructor.py:                        │
│    get_lm_api_input() (line 39-113)                            │
│    Creates messages array in OpenAI format                      │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ 6. agent/agent.py: call_llm() (line 168)                       │
│    Sends prompt to LLM                                          │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ 7. llms/utils.py: call_llm() (line 20-78)                      │
│    Routes to provider-specific function                         │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ 8. llms/providers/openai_utils.py:                             │
│    generate_from_openai_chat_completion() (line 244-265)       │
│    Makes actual API call                                        │
└─────────────────────────────────────────────────────────────────┘
```

## Detailed Code Analysis

### Step 1: Load Config File
**File:** `run.py` lines 330-372

```python
with open(config_file) as f:
    _c = json.load(f)
    intent = _c["intent"]  # <-- Only extracts the INTENT
    task_id = _c["task_id"]
    image_paths = _c.get("image", None)
    # ... storage_state handling ...
```

**Key Point:** Only the `intent` field is extracted and used. The `intent_template` and `instantiation_dict` are **ignored**.

### Step 2: Call Agent
**File:** `run.py` lines 393-398

```python
action = agent.next_action(
    trajectory,        # Contains browser state/observation
    intent,           # "Find me the cheapest blue kayak on this site."
    images=images,    # Optional images
    meta_data=meta_data,  # Contains action_history
)
```

### Step 3: Construct Prompt
**File:** `agent/agent.py` lines 157-164

```python
prompt = self.prompt_constructor.construct(
    trajectory, intent, meta_data
)
```

### Step 4: Fill Template
**File:** `agent/prompts/prompt_constructor.py` lines 223-260 (CoTPromptConstructor)

```python
def construct(self, trajectory, intent, meta_data={}):
    intro = self.instruction["intro"]
    examples = self.instruction["examples"]
    template = self.instruction["template"]

    # Extract current state
    state_info: StateInfo = trajectory[-1]
    obs = state_info["observation"][self.obs_modality]
    page = state_info["info"]["page"]
    url = page.url
    previous_action_str = meta_data["action_history"][-1]

    # Fill template
    current = template.format(
        objective=intent,              # <-- Intent goes here
        url=self.map_url_to_real(url),
        observation=obs,               # <-- Accessibility tree
        previous_action=previous_action_str,
    )

    # Create API input
    prompt = self.get_lm_api_input(intro, examples, current)
    return prompt
```

**The template** (from instruction file) looks like:
```
OBSERVATION:
{observation}
URL: {url}
OBJECTIVE: {objective}
PREVIOUS ACTION: {previous_action}
```

### Step 5: Format as Messages Array
**File:** `agent/prompts/prompt_constructor.py` lines 46-64 (for OpenAI chat mode)

```python
def get_lm_api_input(self, intro, examples, current):
    if "openai" in self.lm_config.provider:
        if self.lm_config.mode == "chat":
            message = [{"role": "system", "content": intro}]

            # Add few-shot examples
            for (x, y) in examples:
                message.append({
                    "role": "system",
                    "name": "example_user",
                    "content": x,
                })
                message.append({
                    "role": "system",
                    "name": "example_assistant",
                    "content": y,
                })

            # Add current task
            message.append({"role": "user", "content": current})
            return message
```

**Result:** A list of message dictionaries in OpenAI chat format.

### Step 6-7: Call LLM
**File:** `llms/utils.py` lines 25-36

```python
def call_llm(lm_config, prompt):
    if lm_config.provider == "openai":
        if lm_config.mode == "chat":
            assert isinstance(prompt, list)
            response = generate_from_openai_chat_completion(
                messages=prompt,  # <-- The messages array
                model=lm_config.model,
                temperature=lm_config.gen_config["temperature"],
                top_p=lm_config.gen_config["top_p"],
                context_length=lm_config.gen_config["context_length"],
                max_tokens=lm_config.gen_config["max_tokens"],
                stop_token=None,
            )
```

### Step 8: Make API Call
**File:** `llms/providers/openai_utils.py` lines 244-265

```python
@retry_with_exponential_backoff
def generate_from_openai_chat_completion(
    messages: list[dict[str, str]],
    model: str,
    temperature: float,
    max_tokens: int,
    top_p: float,
    context_length: int,
    stop_token: str | None = None,
) -> str:
    response = client.chat.completions.create(
        model=model,
        messages=messages,  # <-- The final JSON payload
        temperature=temperature,
        max_tokens=max_tokens,
        top_p=top_p,
    )
    answer: str = response.choices[0].message.content
    return answer
```

## The Actual API Call

The `client.chat.completions.create()` call sends this JSON to OpenAI:

```json
{
  "model": "gpt-3.5-turbo-0613",
  "messages": [
    {
      "role": "system",
      "content": "<full system instructions>"
    },
    {
      "role": "system",
      "name": "example_user",
      "content": "<example 1 observation>"
    },
    {
      "role": "system",
      "name": "example_assistant",
      "content": "<example 1 response>"
    },
    ... (more examples) ...
    {
      "role": "user",
      "content": "OBSERVATION:\n<accessibility tree>\nURL: http://...\nOBJECTIVE: Find me the cheapest blue kayak on this site.\nPREVIOUS ACTION: None"
    }
  ],
  "temperature": 1.0,
  "top_p": 0.9,
  "max_tokens": 384
}
```

## Key Files Reference

### 1. Instruction File
**Path:** `agent/prompts/jsons/p_cot_id_actree_3s.json`

Contains:
- `intro`: System instructions
- `examples`: Few-shot examples (list of [user, assistant] pairs)
- `template`: Template string with `{objective}`, `{url}`, `{observation}`, `{previous_action}` placeholders
- `meta_data`: Additional configuration

### 2. Client Setup
**Path:** `llms/providers/openai_utils.py` line 15

```python
client = OpenAI(
    api_key=os.environ["OPENAI_API_KEY"],
    base_url=os.environ.get("OPENAI_BASE_URL")
)
```

The client uses the official OpenAI Python SDK.

## Summary

The request JSON is constructed through this pipeline:

1. **Config file** → Extract `intent` only
2. **Browser state** → Get current observation (accessibility tree)
3. **Template filling** → Combine intent + observation + URL + previous action
4. **Message formatting** → Wrap in OpenAI chat messages format with system instructions and examples
5. **API call** → Send via `openai.chat.completions.create()`

**Critical insight:** The config file's `intent_template` and `instantiation_dict` are **never sent to the LLM**. Only the pre-filled `intent` is used. The LLM has no knowledge of how the task was generated or what the template structure is.
