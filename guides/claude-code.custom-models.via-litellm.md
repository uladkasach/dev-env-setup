# claude-code with custom models via litellm

run non-claude models (qwen 3.5, llama, mistral, etc.) through claude-code using litellm as a proxy.

> **warning**: this is unsupported by anthropic. expect quirks, missing features, and potential breakage with updates.

## overview

```
┌─────────────┐     ┌─────────────┐     ┌──────────────┐
│ claude-code │ --> │   litellm   │ --> │ together.ai  │
│             │     │   (proxy)   │     │ (qwen 3.5)   │
└─────────────┘     └─────────────┘     └──────────────┘
```

litellm translates claude-code's anthropic api calls into together.ai (or other provider) format.

**qwen 3.5** (released feb 16, 2026) is alibaba's latest:
- native multimodal (text + images + video)
- 397B params, only 17B active (sparse MoE = fast + cheap)
- built for agentic workflows
- ~$0.20/1M tokens on together.ai

## prerequisites

- docker
- together.ai account + api key (https://together.ai)
- claude-code installed (`npm install -g @anthropic-ai/claude-code`)

## step 1: pull litellm docker image

```bash
docker pull ghcr.io/berriai/litellm:main-latest
```

## step 2: get together.ai api key

1. sign up at https://together.ai
2. go to settings > api keys
3. create new key, copy it

```bash
export TOGETHER_API_KEY="your-key-here"
```

## step 3: create litellm config

create `~/.config/litellm/config.yaml`:

```yaml
model_list:
  # map claude model names to qwen 3.5 models
  - model_name: "claude-sonnet-4-20250514"
    litellm_params:
      model: "together_ai/Qwen/Qwen3.5-397B-A17B"
      api_key: "os.environ/TOGETHER_API_KEY"

  - model_name: "claude-3-5-sonnet-20241022"
    litellm_params:
      model: "together_ai/Qwen/Qwen3.5-397B-A17B"
      api_key: "os.environ/TOGETHER_API_KEY"

  - model_name: "claude-3-5-haiku-20241022"
    litellm_params:
      model: "together_ai/Qwen/Qwen3.5-35B-A3B"
      api_key: "os.environ/TOGETHER_API_KEY"

  # add more mappings as needed
  - model_name: "claude-3-opus-20240229"
    litellm_params:
      model: "together_ai/Qwen/Qwen3.5-397B-A17B"
      api_key: "os.environ/TOGETHER_API_KEY"

litellm_settings:
  drop_params: true  # ignore unsupported params silently
```

### available qwen 3.5 models on together.ai

released: february 16, 2026

| model | params (active) | cost | use case |
|-------|-----------------|------|----------|
| `Qwen/Qwen3.5-397B-A17B` | 397B (17B) | ~$0.20/1M | flagship, map to sonnet/opus |
| `Qwen/Qwen3.5-122B-A10B` | 122B (10B) | ~$0.15/1M | balanced |
| `Qwen/Qwen3.5-35B-A3B` | 35B (3B) | ~$0.10/1M | fast/cheap, map to haiku |

### older qwen models (still available)

| model | cost | use case |
|-------|------|----------|
| `Qwen/Qwen3-Coder-480B-A35B-Instruct` | $2.00/1M | code-focused (largest open coder) |
| `Qwen/Qwen3-235B-A22B-Instruct-2507-FP8` | $0.20/1M | logical tasks |
| `Qwen/Qwen2.5-72B-Instruct` | $1.20/1M | previous gen |
| `Qwen/Qwen2.5-Coder-32B-Instruct` | $0.80/1M | code-focused (older) |

check current models: https://www.together.ai/qwen

## step 4: start litellm proxy

```bash
docker run -d \
  --name litellm \
  -p 4000:4000 \
  -v ~/.config/litellm/config.yaml:/app/config.yaml \
  -e TOGETHER_API_KEY="$TOGETHER_API_KEY" \
  ghcr.io/berriai/litellm:main-latest \
  --config /app/config.yaml
```

verify it works:

```bash
curl http://localhost:4000/health
# should return: {"status":"healthy"}
```

manage the container:

```bash
docker logs litellm        # view logs
docker stop litellm        # stop
docker start litellm       # restart
docker rm litellm          # remove
```

## step 5: configure claude-code

option a: environment variables (temporary)

```bash
export ANTHROPIC_BASE_URL="http://localhost:4000"
export ANTHROPIC_API_KEY="sk-litellm"  # litellm accepts any key by default

claude
```

option b: shell alias (persistent)

add to `~/.bash_aliases` or `~/.zshrc`:

```bash
alias claude-qwen='ANTHROPIC_BASE_URL="http://localhost:4000" ANTHROPIC_API_KEY="sk-litellm" claude'
```

then use:

```bash
claude-qwen
```

## step 6: testdrive

```bash
# ensure litellm container is up
docker ps | grep litellm

# set env vars
export ANTHROPIC_BASE_URL="http://localhost:4000"
export ANTHROPIC_API_KEY="sk-litellm"

# launch claude-code
claude

# try a simple prompt
> what model are you? respond in one sentence.
```

if working, you should see responses from qwen (though it may still say "claude" due to system prompts).

## troubleshooting

### "connection refused"

litellm container not active. start it:

```bash
docker start litellm

# or if container doesn't exist, re-run step 4
```

### "model not found"

model name mismatch. check litellm logs and ensure model_name matches what claude-code requests.

check logs:

```bash
docker logs litellm --tail 100
```

### "rate limit" or "quota exceeded"

together.ai rate limits. check your usage at https://api.together.xyz/settings/billing

### features not working

expected. these claude-specific features won't work with qwen:

- extended thinking (`/think`)
- computer use tool
- mcp servers (may partially work)
- vision/image analysis (depends on model)

### slow responses

qwen 3.5-397B is large. try smaller model:

```yaml
- model_name: "claude-3-5-sonnet-20241022"
  litellm_params:
    model: "together_ai/Qwen/Qwen3.5-35B-A3B"  # faster, only 3B active params
```

## alternative providers

litellm supports many providers. swap together.ai for:

### openrouter

```yaml
- model_name: "claude-sonnet-4-20250514"
  litellm_params:
    model: "openrouter/qwen/qwen3.5-397b-a17b"
    api_key: "os.environ/OPENROUTER_API_KEY"
```

### fireworks

```yaml
- model_name: "claude-sonnet-4-20250514"
  litellm_params:
    model: "fireworks_ai/accounts/fireworks/models/qwen3p5-397b-a17b"
    api_key: "os.environ/FIREWORKS_API_KEY"
```

### local ollama

```yaml
- model_name: "claude-sonnet-4-20250514"
  litellm_params:
    model: "ollama/qwen3.5:35b"  # smaller variant for local
    api_base: "http://localhost:11434"
```

## quick start launcher

save as `~/bin/claude-qwen`:

```bash
#!/usr/bin/env bash
# claude-code with qwen via litellm (docker)

set -e

LITELLM_PORT=4000
LITELLM_CONFIG="$HOME/.config/litellm/config.yaml"

# check if litellm container is active
if ! curl -s "http://localhost:$LITELLM_PORT/health" > /dev/null 2>&1; then
  echo "starting litellm container..."

  # remove old container if exists
  docker rm -f litellm 2>/dev/null || true

  # start new container
  docker run -d \
    --name litellm \
    -p "$LITELLM_PORT:4000" \
    -v "$LITELLM_CONFIG:/app/config.yaml" \
    -e TOGETHER_API_KEY="$TOGETHER_API_KEY" \
    ghcr.io/berriai/litellm:main-latest \
    --config /app/config.yaml

  sleep 3
fi

# run claude-code pointed at litellm
ANTHROPIC_BASE_URL="http://localhost:$LITELLM_PORT" \
ANTHROPIC_API_KEY="sk-litellm" \
claude "$@"
```

```bash
chmod +x ~/bin/claude-qwen
claude-qwen
```

## cost comparison

| provider | model | ~cost per 1M tokens |
|----------|-------|---------------------|
| anthropic | claude sonnet 4 | $3 in / $15 out |
| together.ai | qwen 3.5-397B | ~$0.20 |
| together.ai | qwen 3.5-35B | ~$0.10 |
| together.ai | qwen3-coder-480B | $2.00 |
| openrouter | qwen 3.5 | varies |
| ollama | qwen 3.5 (local) | free (your hardware) |

## when to use this

**good for**:
- experimenting with different models
- cost-sensitive workflows
- local/offline usage (with ollama)
- comparing model behaviors

**not good for**:
- production workflows (unsupported)
- features requiring claude-specific capabilities
- guaranteed stability

## case studies and real-world experience

### qwen 3.5 highlights (feb 2026)

- **native multimodal**: understands text, images, video in one system
- **sparse MoE**: 397B total params, only 17B active (efficient)
- **agentic-native**: built for agent workflows, compatible with OpenClaw
- **60% cheaper** to run than qwen3, 8x better at large workloads
- **three inference modes**: Auto (adaptive), Deep (reason), Fast (instant)

source: [alibaba qwen3.5 announcement](https://www.cnbc.com/2026/02/17/china-alibaba-qwen-ai-agent-latest-model.html)

### qwen 3.5 vs claude: benchmark head-to-head

| benchmark | qwen 3.5 | claude sonnet 4.5 | winner |
|-----------|----------|-------------------|--------|
| SWE-bench verified | 76.4% | 80.9% | claude |
| SWE-bench (mid-tier) | competitive | 77.2% | claude |
| BrowseComp (agentic browse) | **78.6%** | 2nd place | qwen |
| Code Arena | #17 overall | top tier | tie |
| multi-file edit/debug | good | **best** | claude |

source: [buildmvpfast benchmark](https://www.buildmvpfast.com/blog/alibaba-qwen-3-5-agentic-ai-benchmark-2026)

### real-world case study: sysadmin tasks

[itsfoss tested qwen-code](https://itsfoss.com/qwen-code-sysadmin-tasks/) as claude code alternative:

**what worked well**:
- multi-step tasks (caddy + vhosts, borgbackup)
- shows every command before execution (safe)
- reduces cognitive load without loss of control
- educational for junior admins

**what struggled**:
- preferred tar downloads over apt repos
- sudo/permission complications
- vague prompts → vague plans

**verdict**: "genuinely practical alternative" for interactive setup, not unattended automation

### claude code vs qwen: user sentiment

| aspect | claude code | qwen via litellm |
|--------|-------------|------------------|
| tool use | "just works" | decent, occasional hiccups |
| edit application | clean | sometimes messy |
| complex tool chains | excellent | struggles |
| cost | $3-15/1M tokens | $0.10-0.20/1M tokens |
| feel | 2026 | "back in 2023" |

source: [claude-flow wiki](https://github.com/ruvnet/claude-flow/wiki/Use-Claude-Code-with-Open-Models)

### user experience reports

**what works well with qwen via litellm**:
- basic code generation and editing
- file operations and navigation
- simple refactoring tasks
- cost savings (up to 83x cheaper than claude opus)

**what struggles**:
- complex multi-step tool chains
- claude-code's extended thinking mode
- some mcp server integrations
- edits sometimes don't apply as cleanly

**common feedback**:
> "qwen writes decent code but struggles with complex tool chains"
> "local models feel like you're back in 2023"
> "claude remains the best experience with tool use that just works"

source: [using claude code with open models](https://github.com/ruvnet/claude-flow/wiki/Using-Claude-Code-with-Open-Models)

### qwen 3.5 specifics

qwen 3.5-397B-A17B (february 2026):

- native multimodal (text + images + video)
- 397B params, 17B active (sparse MoE)
- built for agentic workflows
- comparable to claude sonnet 4 on many benchmarks

recommended litellm params for qwen 3.5:

```yaml
litellm_params:
  model: "together_ai/Qwen/Qwen3.5-397B-A17B"
  max_tokens: 65536
  temperature: 0.7
  top_k: 20
  top_p: 0.8
```

for code-heavy work, consider qwen3-coder-480B instead:

```yaml
litellm_params:
  model: "together_ai/Qwen/Qwen3-Coder-480B-A35B-Instruct"
  max_tokens: 65536
```

source: [together.ai qwen models](https://www.together.ai/qwen)

### docker deployment (production-like)

for persistent setup, use docker compose with postgresql:

```yaml
# docker-compose.yml
services:
  litellm:
    image: ghcr.io/berriai/litellm:main-stable
    ports:
      - "4000:4000"
    environment:
      - TOGETHER_API_KEY=${TOGETHER_API_KEY}
      - DATABASE_URL=postgresql://litellm:litellm@db:5432/litellm
    volumes:
      - ./config.yaml:/app/config.yaml
    command: ["--config", "/app/config.yaml"]
    depends_on:
      - db

  db:
    image: postgres:15
    environment:
      POSTGRES_USER: litellm
      POSTGRES_PASSWORD: litellm
      POSTGRES_DB: litellm
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:
```

### tips from practitioners

1. **context window matters**: models need 200k+ tokens for proper claude-code functionality. use `/compact` manually with smaller windows.

2. **provider selection**: openrouter lets you pick specific providers per model for cost/latency tradeoffs.

3. **debug mode**: always run litellm with `--debug` initially to see what claude-code is requesting.

4. **model verification**: use `/model` command in claude-code to verify which model is active.

5. **fallback strategy**: configure litellm with multiple providers for reliability:

```yaml
model_list:
  - model_name: "claude-sonnet-4-20250514"
    litellm_params:
      model: "together_ai/Qwen/Qwen2.5-72B-Instruct"
    model_info:
      mode: "fallback"
  - model_name: "claude-sonnet-4-20250514"
    litellm_params:
      model: "openrouter/qwen/qwen-2.5-72b-instruct"
```

### best harnesses for qwen 3.5

qwen 3.5 is compatible with multiple agentic frameworks:

| harness | type | best for | notes |
|---------|------|----------|-------|
| **claude code + litellm** | proxy | familiar UX, existing workflows | this guide |
| **qwen-code** | native | qwen-optimized, free | [github.com/QwenLM/qwen-code](https://github.com/QwenLM/qwen-code) |
| **OpenClaw** | framework | visual agents, browser automation | [docs.openclaw.ai](https://docs.openclaw.ai/providers/qwen) |
| **Cline** | vscode | IDE integration | works out of box |
| **ollama** | local | offline, privacy | `ollama run qwen3.5` |

#### qwen-code (alibaba's native harness)

alibaba's own terminal agent, optimized for qwen models:

```bash
# install
pip install qwen-code

# run with qwen 3.5
qwen-code --model qwen3.5-397b
```

pros:
- native qwen optimization
- free (just API costs)
- approval-before-execution model
- good for sysadmin/devops tasks

cons:
- less polished than claude code
- smaller ecosystem

#### OpenClaw (agentic framework)

best for visual/browser automation:

```bash
# qwen 3.5 scores 78.6% on BrowseComp (agentic browse)
# 2nd place overall, beats Gemini 3 Pro
```

qwen 3.5's visual capabilities (screenshots, UI detection, multi-step workflows) shine here.

#### recommendation by use case

| goal | harness |
|------|---------|
| familiar claude code UX | litellm proxy (this guide) |
| maximum qwen optimization | qwen-code |
| browser/visual automation | OpenClaw |
| IDE workflow | Cline |
| local/offline | ollama + qwen-code |
| multi-provider fallback | litellm with model list |

### bottom line

| use case | recommendation |
|----------|----------------|
| learning/experimenting | qwen 3.5 via litellm is great |
| cost-sensitive dev work | qwen 3.5 is 15x+ cheaper than claude |
| complex agentic workflows | qwen 3.5 is agentic-native, worth trying |
| production/reliability | stick with claude |
| offline/air-gapped | qwen 3.5 via ollama |
| code-heavy work | qwen3-coder-480B ($2/1M) |
| browser automation | qwen 3.5 + OpenClaw |

## references

### setup guides
- litellm docs: https://docs.litellm.ai/
- litellm + claude code: https://docs.litellm.ai/docs/tutorials/claude_non_anthropic_models
- qwen3-coder setup guide: https://gist.github.com/WolframRavenwolf/0ee85a65b10e1a442e4bf65f848d6b01

### qwen 3.5
- together.ai qwen models: https://www.together.ai/qwen
- together.ai qwen 3.5 api: https://www.together.ai/models/qwen3-5-397b-a17b
- qwen 3.5 github: https://github.com/QwenLM/Qwen3.5
- qwen 3.5 announcement: https://www.cnbc.com/2026/02/17/china-alibaba-qwen-ai-agent-latest-model.html

### harnesses
- qwen-code (native): https://github.com/QwenLM/qwen-code
- OpenClaw + qwen: https://docs.openclaw.ai/providers/qwen
- ollama qwen3.5: https://ollama.com/library/qwen3.5

### benchmarks and case studies
- qwen 3.5 benchmarks: https://www.buildmvpfast.com/blog/alibaba-qwen-3-5-agentic-ai-benchmark-2026
- sysadmin case study: https://itsfoss.com/qwen-code-sysadmin-tasks/
- open models comparison: https://github.com/ruvnet/claude-flow/wiki/Use-Claude-Code-with-Open-Models
- academic benchmark study: https://philarchive.org/archive/JOSOVC

### claude code
- claude-code docs: https://docs.anthropic.com/en/docs/claude-code
