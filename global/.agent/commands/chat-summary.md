---
description: Prompt for summarization by documenting the reasoning, tradeoffs, alternatives, and gaps from a conversation 
---
Analyze this conversation and produce a decision archaeology report for reviewing past reasoning.

## 1. Starting State
- What was the initial question or problem?
- What constraints, assumptions, or framing did the user bring in?
- What did the user seem to *want* (which may differ from what they asked)?

## 2. Evolution Map
- How did understanding of the problem shift during the conversation?
- What reframings occurred? What caused them?
- What dead ends were explored before being abandoned?

## 3. Decision Points
For each significant choice made (explicit OR implicit):
- What was decided
- What alternatives were actively considered
- Why this option won—quote the reasoning if articulated, infer if not
- Who drove it: user assertion, AI recommendation, or mutual convergence
- Confidence level at the time: was this stated with certainty or hedged? Quote hedging language verbatim (e.g., "I think," "probably," "not sure but," "might work") rather than paraphrasing it away.

## 4. Rejected Paths (primary focus)
- What options were considered but not chosen?
- For each rejection:
  - Was the reasoning explicit or inferred?
  - Was it a "hard no," "not now," or "dismissed without real evaluation"?
  - In retrospect, was the rejection well-reasoned or premature?
- What alternatives were never raised but plausibly should have been?

## 5. Reasoning Gaps
- Where did the conversation advance without explicit justification?
- Flag moments where a decision was made but the "why" was never articulated
- Note where the user or AI accepted a claim without challenge

## 6. Unresolved Tensions
- What tradeoffs were accepted but not resolved?
- What uncertainties remain open?
- What would need to be true for the final conclusion to be wrong?

## 7. Final State
- What was concluded?
- How does it relate to the original question?
- What's the delta between starting assumptions and ending position?

---

**Formatting instructions:**
- Be specific. Quote key exchanges where reasoning was articulated.
- Don't editorialize or add polish—preserve the mess if the reasoning was messy.
- Preserve uncertainty. When hedging language was used ("maybe," "I guess," "could be wrong"), quote it directly. Don't clean up tentativeness into false confidence.
- If a decision was implicit (no one said "I've decided X" but the conversation moved on as if decided), flag it as implicit.

---

## Metadata (optional, for indexing across multiple summaries)
- Core topic/domain:
- Key decision(s) in one line:
- Confidence in final conclusion (low/medium/high):
- Biggest unresolved question:
