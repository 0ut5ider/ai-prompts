# Decision Archaeology Report: AI-Prompts Workflow Critique

**Date:** 2026-02-18
**Participants:** Adrian (user), Claude Opus 4.6 (AI)
**Session type:** Workflow review and gap analysis

---

## 1. Starting State

**Initial question:** "Read the README.md and let me know if you understand the purpose of this repo. After that, critique the usefulness of all the functionality built into this repo's workflow. Let me know what is actually useful and what you think just adds unnecessary token usage."

**Constraints and framing the user brought in:**
- The user framed usefulness explicitly in terms of **token efficiency** — not feature completeness, not developer experience, not correctness. The cost metric was tokens.
- The user already had the README content pasted into the prompt (the Read tool call and its output were included in the initial message), suggesting familiarity with the content and an expectation that the AI would go deeper than surface-level reading.
- No constraints on scope — the user asked for a critique of "all the functionality."

**What the user seemed to want (vs. what they asked):**
- The literal ask was a usefulness audit filtered by token cost. But the follow-up question ("what does the repo miss out on?") suggests the user was actually looking for a **comprehensive workflow review** — strengths, weaknesses, and gaps. The token critique was the entry point, not the full scope. The user wanted an opinionated architectural assessment of their AI-assisted development methodology.

---

## 2. Evolution Map

**Phase 1: Comprehension → Critique (Message 1)**

The AI explored the full repo structure via a subagent, reading every file. The resulting critique was organized along two axes: what earns its token cost vs. what doesn't. This established the conversation's initial frame: efficiency analysis.

Key reframing: The AI didn't just answer "useful vs. wasteful." It introduced a third category — **bugs and inconsistencies** (hardcoded project-specific paths, CLAUDE.md references in OpenCode commands, command name collisions). This shifted the conversation from "is this efficient?" to "is this correct?"

**Phase 2: Critique → Gap Analysis (Message 2)**

The user's second message reframed the conversation entirely: "What does the repo miss out on? What other useful work could be captured... What type of functionality am I not thinking of?"

This was a pivot from **evaluating what exists** to **identifying what's absent**. The user explicitly acknowledged blind spots ("what am I not thinking of?"), which invited the AI to go beyond the user's frame.

**Phase 3: Structured Discovery via Interview (Messages 3-4)**

The AI paused to interview the user before answering, asking about failure modes, post-execution workflow, mid-flight plan failure, team context, recurring pain points, and documentation audience. This was a reframing from "let me list missing features" to "let me diagnose your actual workflow failures first."

**Key revelations from the interview:**
- User hasn't used the workflow enough to identify primary failure modes ("I don't know yet")
- Post-execution review is low-rigor ("I mostly trust it")
- No mechanism for mid-execution plan invalidation ("No mechanism for this")
- Small team (2-4) where others contribute but interact with docs only "occasionally when there's something gone wrong"
- Tech debt accumulates silently — the only pain point the user identified with certainty

**What caused the reframings:**
- The first reframing (efficiency → correctness) was AI-driven, based on discovering project-specific artifacts in global files.
- The second reframing (critique → gap analysis) was user-driven.
- The third reframing (feature list → diagnostic interview) was AI-driven, based on recognizing that "what's missing" depends on "what's actually failing."

**Dead ends explored:**
- None in a traditional sense. The conversation was linear with no backtracking. However, the user's initial framing around token efficiency was partially abandoned — the gap analysis section didn't return to token cost as a filter. The implicit dead end was treating token cost as the primary lens.

---

## 3. Decision Points

### Decision 1: The Augster prompt is ~50% bloat (AI recommendation, accepted implicitly)

**What was decided:** The Augster system prompt contains significant token waste in personality traits, hyperbolic language, and rigid 17-step workflows. An estimated 40-60% could be cut.

**Alternatives considered:**
- The prompt is fine as-is (implicitly rejected)
- The prompt needs minor trimming (not discussed as a middle ground)
- The entire prompt philosophy is wrong (not raised)

**Why this option won:** The AI argued that "16 personality traits are vibes, not instructions" and that "CAPS LOCK emphasis and dramatic language" lack evidence of improving modern frontier model performance. The reasoning was: `"Saying 'be a genius' doesn't make a model smarter."` and `"prompt engineering folklore... arguably useful with GPT-3.5; with Opus-class models, you're spending tokens on theater."`

**Who drove it:** AI recommendation. The user did not push back or confirm — the conversation moved to the next topic.

**Confidence level:** Stated with moderate certainty. The AI hedged slightly with "arguably useful with GPT-3.5" (acknowledging historical value) and "My estimate" (framing the 40-60% as estimation, not measurement). However, the claim "There's no evidence that CAPS LOCK emphasis and dramatic language improve instruction-following in modern frontier models" was stated as fact without citation.

**Status:** Implicit acceptance. The user never explicitly agreed or disagreed.

### Decision 2: code-simplifier-pure-c.md should be deleted (AI recommendation, not addressed)

**What was decided:** The first C simplifier is redundant because the second is a strict superset.

**Alternatives considered:**
- Keep both for different use cases (implicitly rejected by the AI — "The first file adds nothing that the second doesn't cover better")
- Merge them (not discussed)

**Who drove it:** AI assertion. The user did not respond to this specific recommendation.

**Confidence level:** Stated with high certainty: "Delete the first one."

**Status:** Unaddressed. Neither accepted nor rejected.

### Decision 3: The two-phase workflow (plan/execute separation) is the core value (mutual convergence)

**What was decided:** The separation of planning from execution with a hard context boundary is the most valuable architectural decision in the repo.

**Alternatives considered:** None — this was presented as established fact by the AI and was already the user's premise (per the README).

**Who drove it:** The user designed it; the AI validated it. This is the one point where the AI's critique was purely affirming.

**Confidence level:** High certainty from both sides. No hedging.

### Decision 4: The biggest missing piece is a feedback loop (AI recommendation, implicitly accepted)

**What was decided:** The workflow's lack of a retrospective/learning mechanism is its most important gap. The AI ranked it highest priority in the summary table.

**Alternatives considered:**
- Circuit breaker / phase gates (ranked second)
- Structured human review (ranked third)
- Tech debt register (ranked fourth)

**Why this option won:** The AI argued the workflow is "open-loop" and that without feeding failure patterns back into planning, `"the entire documentation infrastructure is just expensive journaling."` This was framed as an architectural criticism, not a feature request.

**Who drove it:** AI recommendation. The user's interview answers (tech debt accumulates silently, docs only read during incidents) provided the evidence base, but the user didn't name "feedback loop" as a need — the AI synthesized it from the symptoms.

**Confidence level:** High certainty. The AI ended with a direct challenge: `"if /write-plan never consults what went wrong last time — the entire documentation infrastructure is just expensive journaling."` No hedging.

**Status:** Implicitly accepted. The user moved to requesting this summary rather than pushing back on the gap analysis.

### Decision 5: "I mostly trust it" is a problem (AI assertion, not contested)

**What was decided:** The user's low-rigor post-execution review process is identified as a risk. The AI called it `"a time bomb."` 

**Alternatives considered:**
- Trusting AI output after automated verification is reasonable (implicitly rejected by the AI)
- The verification subagent is sufficient review (implicitly rejected — AI argued "AI reviewing AI is a weak signal")

**Who drove it:** AI assertion, based on the user's own answer.

**Confidence level:** High certainty, strong language: `"That's a problem."` No hedging.

**Status:** Not contested but also not explicitly acknowledged by the user. The user did not defend their current process or commit to changing it.

---

## 4. Rejected Paths

### Path: The Augster prompt's emphatic style might actually work

**Was the reasoning explicit?** Partially. The AI acknowledged the style is "a deliberate prompt engineering technique" and "arguably useful with GPT-3.5" but dismissed it for modern models. The dismissal was based on a general claim about frontier model behavior, not empirical testing against this specific workflow.

**Type of rejection:** "Hard no" in tone, but epistemically weaker than presented. The actual evidence base is "there's no evidence" — which is an absence-of-evidence argument, not evidence-of-absence.

**In retrospect:** This rejection may be premature. The user is running MiniMax M2.5 and GLM 4.7 (per opencode.json), not Opus-class models, for execution. The emphatic style might matter more for these models than the AI acknowledged. The critique was calibrated for frontier models but the execution context uses mid-tier models. This was never surfaced.

### Path: The 17-step AxiomaticWorkflow might be valuable for weaker models

**Was the reasoning explicit?** The AI argued it's "overhead for small phases" and forces rigid execution on simple tasks. The alternative — that rigid structure compensates for weaker model judgment — was never considered.

**Type of rejection:** Dismissed without evaluation of the model context.

**In retrospect:** Same issue as above. The workflow runs on MiniMax M2.5 for execution. Rigid scaffolding may be more necessary for mid-tier models that struggle with open-ended autonomy. The AI evaluated the Augster prompt as if Opus would be executing, but Opus is only used for planning (Devil's Advocate).

### Path: REFERENCE.md serves a purpose beyond AI context

**Was the reasoning explicit?** Yes — the AI noted "It's not loaded into AI context, so it's not wasting tokens. But every change... requires a manual update." It was evaluated purely on maintenance cost.

**What was never raised:** REFERENCE.md might serve as a canonical spec that team members consult. Given the user has a small team, a single comprehensive document might be more useful for onboarding others into the workflow than scattered command files. This human-facing value was acknowledged ("human reference material") but not weighted in the final assessment.

**Type of rejection:** "Not a problem" rather than explicit rejection. But by not recommending it, the AI implicitly endorsed the status quo of maintaining a manually-synced duplicate document.

### Alternatives never raised but plausibly should have been:

1. **A `/dry-run` or `/simulate-plan` command** — execute the plan's phase structure without actually writing code, to validate that the plan is coherent and the phases are properly scoped before committing to full execution. Cheap way to catch plan defects before they cost real tokens.

2. **Model-specific execution profiles** — the Augster prompt is one-size-fits-all, but the user runs different models for different phases. The planning model (Opus) can handle loose instructions; the execution models (MiniMax, GLM) might need more structure. The prompt could adapt based on which model is executing.

3. **Incremental plan execution** — the ability to run a single phase, inspect the result, and decide whether to continue. The current workflow is all-or-nothing (execute all phases sequentially). A step-through mode would address the "no circuit breaker" problem without requiring automated phase gates.

4. **A `/review-diff` command** — purpose-built for the post-execution review step. Rather than reading raw git diff, the AI would produce a structured review focused on: deviations from plan, untested code paths, new coupling introduced, and questions for the human reviewer. This was partially described in the gap analysis ("structured human review prompt") but not formalized as a command proposal.

---

## 5. Reasoning Gaps

### Gap 1: Token cost claims were never quantified

The entire first-half framing was about token efficiency, but no actual token counts were provided. "The Augster prompt is your biggest token sink" — how many tokens? "Cut 40-60%" — saving how much per run? "221 lines loaded on every interaction" — that's ~3-4K tokens, which is trivial against a 128K-190K context window. The conversation proceeded as if token cost was a meaningful concern but never established whether the actual magnitudes matter.

### Gap 2: The model execution context was overlooked

The AI critiqued the Augster prompt and the AxiomaticWorkflow as if Opus-class models would be executing them. But `opencode.json` shows execution happens on MiniMax M2.5 and GLM 4.7 — mid-tier models where rigid scaffolding and emphatic instructions might actually be load-bearing. This disconnect was never surfaced despite the AI having read the config file through its subagent.

### Gap 3: "I mostly trust it" was diagnosed but not explored

The AI called this "a time bomb" but didn't ask *why* the user trusts it. Is it because the verification step has been accurate so far? Because the test suites are comprehensive? Because the code is low-stakes? The prescription (structured review checklist) was offered without diagnosing whether the trust is warranted or unwarranted.

### Gap 4: The team dimension was underexplored

The user said 2-4 people, small team. The AI mentioned "if someone else merges something while your 5-phase execution is running" but otherwise didn't probe how the team interacts with this workflow. Do others write plans? Do they use the Devil's Advocate? Does the docs/ folder create friction for non-AI-workflow team members? The interview asked the question but didn't follow through on the implications.

### Gap 5: The gap analysis priorities were asserted, not derived

The final priority table (feedback loop > circuit breaker > human review > tech debt > ...) was presented as a ranking but the criteria for ranking were never stated. Is it ranked by impact? By frequency of occurrence? By effort-to-value ratio? The user hasn't experienced most of these problems yet ("I don't know yet" for primary failure mode), so the ranking is necessarily speculative — but it was presented without that caveat.

---

## 6. Unresolved Tensions

### Tension 1: Token efficiency vs. model capability compensation

The critique argues for cutting the Augster prompt's verbosity. But the user runs mid-tier models for execution that may need that verbosity. These two goals — minimize tokens and maximize instruction-following on weaker models — directly conflict. This tension was never acknowledged.

### Tension 2: Trust vs. verification

The user "mostly trusts" execution output. The AI says this is dangerous and recommends structured human review. But the user designed a workflow specifically to minimize human intervention (autonomous subagents, automated verification). The tension between "automate everything" and "humans must review" was identified but not resolved. What's the right level of trust for AI-generated code with AI-generated verification?

### Tension 3: Documentation as planning input vs. incident response

The user said docs are read "occasionally when something's gone wrong." The AI argued docs should feed forward into planning. But if the team's actual behavior is to consult docs only during incidents, building a system that assumes continuous docs consumption may be building for a workflow nobody follows. The user would need to change team behavior, not just tooling.

### Tension 4: Global workflow vs. project-specific reality

The repo aspires to be a reusable, project-agnostic workflow. But it contains hardcoded project paths, project-specific version bumping rules, and C-specific tooling. The tension between "general-purpose framework" and "my personal setup" is unresolved. Making it truly generic requires stripping the things that make it immediately useful for the user's current projects.

### Tension 5: Workflow maturity vs. workflow completeness

The user said "I don't know yet" about primary failure modes and "too early to say" effectively about docs consumption. The AI nonetheless recommended 8 major additions. There's a tension between building out a comprehensive workflow before you've validated the core loop and keeping the system lean until real failure patterns emerge. The AI's recommendations assumed the workflow is mature enough to benefit from these additions; the user's answers suggest it might not be.

### What would need to be true for the final conclusions to be wrong:
- The Augster prompt's emphatic style actually improves MiniMax M2.5/GLM 4.7 instruction-following measurably — in that case, cutting it degrades execution quality.
- The user's "mostly trust it" approach is empirically validated by consistently good outcomes — in that case, structured review adds friction without value.
- The workflow is too early-stage for feedback loops — adding retrospectives, debt registers, and metrics capture before the core plan/execute cycle is battle-tested may be premature optimization of the meta-process.

---

## 7. Final State

**What was concluded:**
1. The two-phase plan/execute architecture is sound and should be preserved.
2. The Augster prompt is ~40-60% bloat (contested — see Tension 1).
3. The C simplifiers need consolidation (uncontested but unaddressed).
4. Project-specific artifacts in global files are bugs that need fixing (uncontested).
5. The workflow's biggest structural gap is the absence of a feedback loop — no mechanism to learn from past failures and feed that into future planning.
6. Eight specific gaps were identified, prioritized by estimated impact.

**Relation to original question:**
The user asked for a usefulness critique filtered by token cost, then pivoted to gap analysis. The final state addresses both: what to cut (Augster bloat, redundant C simplifiers) and what to add (feedback loops, circuit breakers, debt tracking, review prompts, cross-project knowledge, metrics, impact analysis, rollback protocol). The token-cost frame was largely abandoned in the second half — the gap analysis is about capability, not efficiency.

**Delta between starting assumptions and ending position:**
- **Starting:** "Is this workflow efficient?" (token-cost lens)
- **Ending:** "This workflow is architecturally incomplete — it's open-loop, has no learning mechanism, no circuit breakers, and enables dangerous levels of trust in unreviewed AI output." (structural-integrity lens)

The conversation's most significant shift was from *evaluating the existing system's efficiency* to *questioning whether the system can improve over time*. The user came in asking about costs; they left with a diagnosis that the workflow doesn't learn.

---

## Metadata

- **Core topic/domain:** AI-assisted development workflow design, prompt engineering, developer tooling
- **Key decision(s) in one line:** The workflow needs a feedback loop; the Augster prompt is probably bloated but the evidence is weaker than presented due to model-context mismatch.
- **Confidence in final conclusions:** Medium. The gap analysis is structurally sound but speculative — the user hasn't hit most of these failure modes yet, and the token efficiency critique was made without accounting for which models actually execute the prompts.
- **Biggest unresolved question:** Does the Augster prompt's emphatic, rigid style actually degrade execution quality on frontier models, or is it load-bearing scaffolding for the mid-tier models (MiniMax M2.5, GLM 4.7) that actually run the subagents?
