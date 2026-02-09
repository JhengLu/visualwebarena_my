# Complete Code Trace with Line Numbers

This document shows the **exact line-by-line execution flow** for constructing and sending the LLM request.

## Execution Flow

### 1. Start: run.py

```
run.py:539
└─→ test(args, test_file_list)

run.py:323  (test function starts)
└─→ for config_file in config_file_list:

run.py:330-332
└─→ with open(config_file) as f:
    _c = json.load(f)
    intent = _c["intent"]  ✓ EXTRACT INTENT

run.py:377
└─→ agent.reset(config_file)

run.py:379
└─→ obs, info = env.reset(options={"config_file": config_file})

run.py:383
└─→ meta_data = {"action_history": ["None"]}

run.py:384-402
└─→ while True:
        ...
        action = agent.next_action(
            trajectory,
            intent,          ✓ PASS INTENT
            images=images,
            meta_data=meta_data,
        )
```

### 2. Agent Processing: agent/agent.py

```
agent/agent.py:128  (PromptAgent.next_action)
└─→ def next_action(self, trajectory, intent, meta_data, images=None):

agent/agent.py:157-164
└─→ prompt = self.prompt_constructor.construct(
        trajectory, intent, meta_data
    )
    ✓ CONSTRUCT PROMPT

agent/agent.py:165-168
└─→ lm_config = self.lm_config
    while True:
        response = call_llm(lm_config, prompt)  ✓ CALL LLM
```

### 3. Prompt Construction: agent/prompts/prompt_constructor.py

```
prompt_constructor.py:223  (CoTPromptConstructor.construct)
└─→ def construct(self, trajectory, intent, meta_data={}):

prompt_constructor.py:229-232
└─→ intro = self.instruction["intro"]
    examples = self.instruction["examples"]
    template = self.instruction["template"]
    keywords = self.instruction["meta_data"]["keywords"]

prompt_constructor.py:233-246
└─→ state_info = trajectory[-1]
    obs = state_info["observation"][self.obs_modality]
    max_obs_length = self.lm_config.gen_config["max_obs_length"]
    if max_obs_length:
        obs = self.tokenizer.decode(
            self.tokenizer.encode(obs)[:max_obs_length]
        )
    page = state_info["info"]["page"]
    url = page.url
    previous_action_str = meta_data["action_history"][-1]

prompt_constructor.py:244-245
└─→ page = state_info["info"]["page"]
    url = page.url  ✓ GET CURRENT URL FROM BROWSER

prompt_constructor.py:247-252
└─→ current = template.format(
        objective=intent,              ✓ FILL TEMPLATE
        url=self.map_url_to_real(url),  ✓ MAP AND INSERT URL
        observation=obs,
        previous_action=previous_action_str,
    )

prompt_constructor.py:196
└─→ prompt = self.get_lm_api_input(intro, examples, current)
    return prompt
```

### 4. Format as Messages: agent/prompts/prompt_constructor.py

```
prompt_constructor.py:39  (get_lm_api_input)
└─→ def get_lm_api_input(self, intro, examples, current):

prompt_constructor.py:45-64  (OpenAI chat mode)
└─→ if "openai" in self.lm_config.provider:
        if self.lm_config.mode == "chat":
            message = [{"role": "system", "content": intro}]  ✓ SYSTEM MSG

            for (x, y) in examples:  ✓ EXAMPLE MSGS
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

            message.append({"role": "user", "content": current})  ✓ USER MSG
            return message
```

**Result at this point:**
```python
message = [
    {"role": "system", "content": "You are an autonomous intelligent agent..."},
    {"role": "system", "name": "example_user", "content": "OBSERVATION:\n..."},
    {"role": "system", "name": "example_assistant", "content": "Let's think..."},
    {"role": "system", "name": "example_user", "content": "OBSERVATION:\n..."},
    {"role": "system", "name": "example_assistant", "content": "Let's think..."},
    {"role": "system", "name": "example_user", "content": "OBSERVATION:\n..."},
    {"role": "system", "name": "example_assistant", "content": "Let's think..."},
    {"role": "user", "content": "OBSERVATION:\n[1] RootWebArea...\nURL: http://...\nOBJECTIVE: Find me the cheapest blue kayak...\nPREVIOUS ACTION: None"}
]
```

### 5. Call LLM Router: llms/utils.py

```
llms/utils.py:20  (call_llm)
└─→ def call_llm(lm_config, prompt):

llms/utils.py:25-36
└─→ if lm_config.provider == "openai":
        if lm_config.mode == "chat":
            assert isinstance(prompt, list)  ✓ VERIFY LIST
            response = generate_from_openai_chat_completion(
                messages=prompt,  ✓ PASS MESSAGES
                model=lm_config.model,
                temperature=lm_config.gen_config["temperature"],
                top_p=lm_config.gen_config["top_p"],
                context_length=lm_config.gen_config["context_length"],
                max_tokens=lm_config.gen_config["max_tokens"],
                stop_token=None,
            )
```

### 6. OpenAI API Call: llms/providers/openai_utils.py

```
openai_utils.py:15-16  (module level - client setup)
└─→ client = OpenAI(
        api_key=os.environ["OPENAI_API_KEY"],
        base_url=os.environ.get("OPENAI_BASE_URL")
    )

openai_utils.py:243-265  (with @retry_with_exponential_backoff decorator)
└─→ def generate_from_openai_chat_completion(
        messages: list[dict[str, str]],
        model: str,
        temperature: float,
        max_tokens: int,
        top_p: float,
        context_length: int,
        stop_token: str | None = None,
    ) -> str:

openai_utils.py:257-263
└─→ response = client.chat.completions.create(  ✓ ACTUAL API CALL
        model=model,
        messages=messages,  ✓ THE REQUEST JSON
        temperature=temperature,
        max_tokens=max_tokens,
        top_p=top_p,
    )

openai_utils.py:264
└─→ answer: str = response.choices[0].message.content
    return answer
```

## What `client.chat.completions.create()` Sends

The OpenAI Python SDK converts the function call into this HTTP request:

**HTTP POST to:** `https://api.openai.com/v1/chat/completions`

**Headers:**
```
Authorization: Bearer <OPENAI_API_KEY>
Content-Type: application/json
```

**Body (JSON):**
```json
{
  "model": "gpt-3.5-turbo-0613",
  "messages": [
    {"role": "system", "content": "You are an autonomous intelligent agent..."},
    {"role": "system", "name": "example_user", "content": "OBSERVATION:\n[1744] link 'HP CB782A#ABA 640 Inkjet Fax Machine (Renewed)'..."},
    {"role": "system", "name": "example_assistant", "content": "Let's think step-by-step..."},
    {"role": "system", "name": "example_user", "content": "OBSERVATION:\n[204] heading '/f/food'..."},
    {"role": "system", "name": "example_assistant", "content": "Let's think step-by-step..."},
    {"role": "system", "name": "example_user", "content": "OBSERVATION:\n[42] link 'My account'..."},
    {"role": "system", "name": "example_assistant", "content": "Let's think step-by-step..."},
    {"role": "user", "content": "OBSERVATION:\n[1] RootWebArea 'Classifieds'...\nURL: http://158.130.4.229:9980\nOBJECTIVE: Find me the cheapest blue kayak on this site.\nPREVIOUS ACTION: None"}
  ],
  "temperature": 1.0,
  "top_p": 0.9,
  "max_tokens": 384
}
```

## Return Path

```
OpenAI API
└─→ returns JSON response

openai_utils.py:264
└─→ answer = response.choices[0].message.content
    return answer

llms/utils.py:28-36
└─→ return response

agent/agent.py:168
└─→ response = call_llm(...)

agent/agent.py:172
└─→ response = f"{force_prefix}{response}"

agent/agent.py:176-190
└─→ parsed_response = self.prompt_constructor.extract_action(response)
    action = create_id_based_action(parsed_response)
    return action

run.py:393-398
└─→ action = agent.next_action(...)
    # Continue execution loop
```

## Key Observation

**At no point in this entire flow is:**
- `intent_template` accessed
- `instantiation_dict` accessed
- `eval` configuration accessed
- Any metadata beyond `intent`, `task_id`, `image`, and `storage_state` used

The only thing from the config file that reaches the LLM is the **already-instantiated `intent` string**.

## Files Involved (in order of execution)

1. [run.py](../../../run.py) - Main execution loop
2. [agent/agent.py](../../../agent/agent.py) - Agent logic
3. [agent/prompts/prompt_constructor.py](../../../agent/prompts/prompt_constructor.py) - Prompt formatting
4. [llms/utils.py](../../../llms/utils.py) - LLM call routing
5. [llms/providers/openai_utils.py](../../../llms/providers/openai_utils.py) - OpenAI API wrapper
6. [agent/prompts/jsons/p_cot_id_actree_3s.json](../../../agent/prompts/jsons/p_cot_id_actree_3s.json) - Instruction template

## Quick Reference Table

| Step | File | Function | Lines | Action |
|------|------|----------|-------|--------|
| 1 | run.py | test | 330-332 | Extract intent from config |
| 2 | run.py | test | 393-398 | Call agent.next_action() |
| 3 | agent/agent.py | PromptAgent.next_action | 157-164 | Construct prompt |
| 4 | prompt_constructor.py | CoTPromptConstructor.construct | 247-252 | Fill template |
| 5 | prompt_constructor.py | get_lm_api_input | 45-64 | Format as messages |
| 6 | llms/utils.py | call_llm | 25-36 | Route to OpenAI |
| 7 | openai_utils.py | generate_from_openai_chat_completion | 257-263 | Make API call |
