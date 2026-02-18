# Decision Archaeology Report — Workflow Critique Conversation

**Date:** 2026-02-18  
**Session model:** claude-sonnet-4-6  

---

## 1. Starting State

**Initial question:**  
The user opened by presenting a pre-read README and immediately asking for a critique of the workflow's usefulness — specifically: what is actually useful vs. what adds unnecessary token usage. The request was phrased as: *"critique the usefulness of all the functionality built into this repo's workflow."*

**Constraints and framing the user brought in:**
- They had already read the README and linked it explicitly, indicating they wanted the critique grounded in the actual content.
- The phrasing "unnecessary token usage" signals the user was already aware the workflow might be bloated.
- The user framed it as a binary ("useful vs. token waste"), which is a reductive lens; they didn't ask for degrees of usefulness.

**What the user seemed to want (vs. what they asked):**
- They asked for a utility critique.
- What they likely wanted: validation that the workflow is sound with targeted suggestions for trimming. The pre-screening interview answers ("Correctness first, Learning, Auditability") suggest they have high investment in the workflow and are seeking refinement, not a teardown.
- They did not ask "what's missing" — that came only after the critique was delivered.

---

## 2. Evolution Map

**Shift 1 — From binary to graded assessment**  
The initial framing was "useful vs. waste" (binary). The AI's response introduced a graded structure: "Actually useful," "Borderline / conditional," and "Mostly token waste." This reframing was implicit — the user accepted it without comment.

**Shift 2 — From workflow critique to requirements gap**  
The second user message asked: *"what does the repo miss out on?"* This is a distinct problem from the first. The conversation moved from critique (what's wrong) to discovery (what's absent). This shift was user-driven.

**Shift 3 — Root cause identification**  
The AI reframed "misread requirements" (user's stated pain) from a tooling problem to a **specification fidelity problem.** The user did not explicitly accept or reject this reframing; the conversation ended without response.

**Dead ends explored:**
- None explicitly abandoned. The AI raised multiple suggestions in both responses and the user did not push back on any.

---

## 3. Decision Points

### Decision 1 — Scope the critique to full repo, not just README
- **What was decided:** Critique covers commands, agents, prompts, and templates — not just what README describes.
- **Alternatives considered:** README-only scope was offered as an option in the interview.
- **Why this won:** User explicitly selected "Full repo" in the question tool.
- **Who drove it:** User assertion.
- **Confidence:** High (explicit selection).

---

### Decision 2 — Accept the graded (not binary) utility framing
- **What was decided:** The AI restructured the critique into three tiers (actually useful / borderline / token waste) instead of the binary the user asked for.
- **Alternatives considered:** Not stated. The AI unilaterally reframed.
- **Why this won:** Implicit. The user did not object and the conversation advanced as if this framing were accepted.
- **Who drove it:** AI recommendation, user implicitly accepted.
- **Confidence:** The reframing was never explicitly validated. **Flag as implicit decision.**

---

### Decision 3 — Augster system prompt flagged as "mostly token waste"
- **What was decided:** The Augster prompt was labeled "over-specified" and "a huge token tax for marginal behavioral gains."
- **Alternatives considered:** None raised. The AI did not explore whether Augster's verbosity might be justified by its model target (Opus 4.6 at high complexity).
- **Why this won:** The AI observed it mandates tools (view_tasklist, add_tasks) that may not exist in all environments, and that it's repeated per subagent. This is a valid structural observation.
- **Who drove it:** AI recommendation.
- **Confidence:** Hedged. The AI noted: *"If you consistently run complex, high-risk changes, the documentation overhead could pay for itself."* That hedge was not resolved.
- **Gap:** The critique did not check whether the tool mandates in Augster are actually problematic in the user's OpenCode environment. This was assumed, not verified.

---

### Decision 4 — Hard-coded test fixture path flagged as "hallucination magnet"
- **What was decided:** The path `../sample_model/LowPolyLowTexture-02` in execute-plan.md is project-specific and irrelevant to most repos.
- **Alternatives considered:** None raised.
- **Why this won:** The path is verbatim in the file; it clearly references a specific project.
- **Who drove it:** AI observation (accurate).
- **Confidence:** High. This is a concrete factual error in the prompt, not an opinion.

---

### Decision 5 — Requirements Contract identified as primary missing piece
- **What was decided:** The biggest gap in the workflow is the absence of a **Requirements Contract** — an explicit, measurable definition of what's being built and how success is judged.
- **Alternatives considered:** The AI offered multiple alternatives (traceability matrix, risk register, abuse cases, post-deploy checklist) but ranked the RC as most important.
- **Why this won:** The user stated "misread requirements" as their highest-cost pain. The AI connected this to a specification fidelity gap rather than a tooling gap.
- **Who drove it:** AI recommendation grounded in user-provided context.
- **Confidence:** Medium. The AI itself noted the alternative: *"If you already do requirement capture outside the repo (e.g., tickets), duplicating it here might be redundant."* That question was not answered.
- **Gap:** The user was not asked whether they have existing requirement capture. The AI inferred absence.

---

### Decision 6 — "More tokens, less risk" tradeoff accepted
- **What was decided:** All suggestions in the second response were framed as "add overhead to reduce risk," which the user selected explicitly.
- **Alternatives considered:** The question tool offered "fewer tokens, same risk." The user rejected it.
- **Who drove it:** User assertion.
- **Confidence:** High (explicit selection).

---

## 4. Rejected Paths

### Rejected: README-only scope
- **Reasoning:** User explicitly rejected this in the question tool.
- **Hard no / not now / dismissed:** Hard no (explicit).
- **Retrospect:** Correct rejection. README-only scope would miss the most significant issues (Augster bloat, hardcoded paths).

---

### Rejected: "Fewer tokens, same risk" framing for additions
- **Reasoning:** User explicitly rejected this.
- **Hard no:** Yes.
- **Retrospect:** Defensible given their stated priorities (correctness, auditability). But this forecloses potentially valuable efficiency-oriented suggestions.

---

### Never raised — but plausibly should have been:

1. **Pre-commit hooks and CI integration.** The workflow generates a rich artifact trail but has no mechanism for enforcing it at the tooling level. Nothing prevents a dev from skipping /write-plan and going straight to /execute-plan. This gap was not raised.

2. **Prompt versioning.** The prompts (write-plan, execute-plan, augster) have no version markers. If a prompt is changed mid-project, there's no way to correlate plan outputs to the prompt that generated them. This is an auditability gap that was not raised.

3. **Failure modes and recovery.** What happens if a subagent fails mid-phase? The handoff report structure exists, but there's no rollback protocol. This was not raised.

4. **Metrics collection.** The workflow generates lots of artifacts but no feedback loop. There's no mechanism to capture "how often did plans get amended?" or "which phases had the most open issues?" That data would improve future plans. Not raised.

5. **Prompt injection / agent trust boundary.** If agents read external code and that code contains adversarial instructions, the system has no guard. The AGENTS.md loads external context without sanitization. Not raised.

6. **Cross-plan dependency tracking.** If Plan A's decisions constrain Plan B, there's no cross-reference mechanism beyond "search ADRs." Not raised.

---

## 5. Reasoning Gaps

**Gap 1 — Augster critique assumed environmental incompatibility**  
The AI stated that Augster mandates tools (view_tasklist, add_tasks, remember) that "may not exist in your environment." This was inferred from the XML in the prompt, but the user's OpenCode environment was never inspected. The critique was technically accurate but conditionally valid.

**Gap 2 — "projects/AGENTS.md is dangerous in unrelated projects" claim**  
The AI noted: *"actively dangerous in unrelated projects; it seeds irrelevant constraints."* This is true (split version bump logic, LowPolyLowTexture paths), but the AI did not check whether the template has explicit "replace this" markers (it does — `<!-- UPDATE THE STRUCTURE ABOVE -->`). The critique slightly overstated the risk. The marker mitigates but doesn't eliminate it.

**Gap 3 — No evidence requested for claims**  
The probing question at the end of the first response asked: *"What evidence do you have that token-heavy steps actually reduce regressions in your last 5 medium features?"* The user did not answer this. The second response proceeded without that data. The critique and suggestions are therefore grounded in structural analysis, not empirical evidence from this user's actual runs.

**Gap 4 — "Misread requirements" pain accepted at face value**  
The user selected "misread requirements" as their highest-cost pain. The AI treated this as ground truth and built the second response around it. No attempt was made to verify: Was it misread (wrong spec), or mistransmitted (right spec, wrong execution), or misunderstood (spec was ambiguous)? These have different fixes.

**Gap 5 — Devil's Advocate labeled "high value" without challenge**  
The Devil's Advocate agent was praised as "doing real work" and "forces precision." This was not challenged. A more rigorous critique would note that the agent's value depends heavily on: (a) the quality of conversation before /write-plan, and (b) whether the user actually engages the adversarial responses or just confirms their prior view. The format doesn't enforce genuine engagement.

---

## 6. Unresolved Tensions

**Tension 1 — Correctness vs. token cost**  
The user prioritized correctness and explicitly accepted "more tokens, less risk." But the first response flagged many steps as wasteful. These two positions coexist without resolution: the critique said trim, the additions said add. The net token impact of the session's recommendations is unclear.

**Tension 2 — Solo vs. team artifacts**  
The user is working in a small team (2–5). Many artifacts (run index, plan amendments, verification reports) are primarily valuable for team coordination. But the workflow is clearly designed for solo use and AI-to-AI handoffs, not human review. This tension was not addressed.

**Tension 3 — Requirements contract feasibility**  
The primary recommendation (add a Requirements Contract) assumes there's a spec to capture. If the user's team works in an exploratory/prototyping mode where requirements emerge during building, a formal RC adds friction without value. This was partially hedged: *"If you work on highly exploratory tasks, hard requirements can be counterproductive."* But the user's work mode was never established.

**Tension 4 — Augster is the behavioral core but was called waste**  
Augster was labeled token-wasteful, yet it is the behavioral foundation for all execution subagents. Trimming or replacing it changes the character of execution agents fundamentally. The critique did not propose a replacement, only a critique.

**What would need to be true for the conclusions to be wrong:**
- If Augster's verbosity measurably improves subagent correctness in the user's specific environment, the "token waste" label is wrong.
- If the user already captures requirements in tickets/Jira/etc., the Requirements Contract recommendation is redundant.
- If all team members read the artifacts (run index, verification reports), the "borderline" artifacts become high-value.

---

## 7. Final State

**What was concluded:**
- The workflow has strong structural bones but lacks specification fidelity mechanisms.
- Several components (Augster, dual C simplifiers, hardcoded paths) add token cost without proportional value.
- The primary missing piece is a Requirements Contract that captures measurable success criteria.
- Secondary additions: risk register, traceability matrix, abuse case tests, post-deploy checklist, AGENTS.md definition-of-done.

**Relation to original question:**
- The first question (critique) was answered. The second question (what's missing) was answered. The two responses are not fully consistent: one says "trim," the other says "add." No reconciliation was attempted.

**Delta from starting assumptions to ending position:**
- Starting: User assumed the workflow was mostly sound and wanted targeted trimming.
- Ending: The critique revealed a structural gap (no requirements capture) that the user didn't frame as part of the original problem. That's a significant reframe — from "how do I optimize this workflow" to "this workflow is missing a foundational step."
- Whether the user accepted that reframe is unknown; the conversation ended with the AI's recommendation.

---

## Metadata

- **Core topic/domain:** AI-assisted coding workflow design; prompt engineering; specification fidelity
- **Key decision(s) in one line:** Requirements Contract identified as primary missing piece; Augster system prompt flagged as over-specified token tax; dual C simplifiers flagged as redundant
- **Confidence in final conclusion:** Medium — structural analysis is sound; empirical validation against user's actual runs was never done
- **Biggest unresolved question:** Does the user already capture requirements outside this repo, and if so, does adding a Requirements Contract here provide incremental value or just duplicate existing work?
