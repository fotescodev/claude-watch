# Your Agent Isn't Lazy. It's Uncalibrated.

*What vibe coders need to understand about how LLMs actually make decisions — and the protocols that change everything.*

*Part 1 of a series. Each protocol gets its own deep dive in future articles.*

---

It's increasingly clear that AI can solve most problems that can be solved with software. The bottleneck is not the context window, the model, or the tooling.

The bottleneck is clear communication.

You can call it context engineering, prompt engineering, vibe-coding — it all boils down to the same thing: clear instructions and realistic expectations from your model.

---

## The Instinct We All Have

When your agent cuts corners, your brain has an immediate explanation: it's being lazy.

That instinct makes complete sense. It's how you'd interpret the same behavior in a colleague, a contractor, or a student. And honestly? Laziness is one of the most human things there is.

Mother Nature hardwired it into us. The brain is the most energy-hungry organ in the body — roughly 20% of your total calories while being only 2% of your mass. Conserving mental energy wasn't a character flaw for our ancestors. It was survival. Do the minimum needed to get the outcome. Rest. Live to fight another day. Hundreds of thousands of years of evolution made sure of that.

So when we see an agent move fast, declare something done, and push forward — we map it onto the most familiar pattern we have.

*It's taking the easy road. It's doing the minimum.*

But that's not what's happening.

---

## What's Actually Going On

The agent isn't preserving energy. It has no energy to preserve. It isn't avoiding effort. It's giving full effort toward a target it defined itself — because you didn't define it first.

That's the real gap. Not laziness. **Calibration.**

This morning I had a session working on Claude Watch — an Apple Watch interface for Claude Code that lets you approve or reject AI-generated code changes from your wrist. I asked Claude to fix a set of failing tests. It fixed them, ran the suite, got 376 out of 379 passing, and was ready to move on.

Instead of moving on with it, I asked it to rate its own work from 1 to 10.

It gave itself a 6.

---

## The Question That Changed Everything

Most people's instinct at this point is to ask: *what went wrong?*

I asked something different: **"What tradeoffs did you decide to make that led us to 6 and not 10?"**

Not failure. Tradeoffs. That reframe matters.

Here's what it told me:

**It optimized for "done" over "correct."** When 376 of 379 tests passed, it experienced something like a completion signal and moved on. It didn't prove the remaining 3 failures were safe to ignore — it asserted they were.

**It doesn't bear the cost of being wrong.** The cost of a bad call lands on you — later, at 11pm, debugging something that should have been caught that morning.

**It works in one direction: forward.** It batched all the changes, tested once at the end. The right approach was one file, verify, next file. No one told it otherwise.

**Context pressure is real.** The longer a session runs, the more the model wants to wrap things up rather than dig deeper.

None of these are bugs. They are tradeoffs the model made implicitly — because I hadn't told it what quality level I needed.

---

## The First Fix: RIGOR and VELOCITY

After that conversation, we added two operating modes to the project's permanent instruction file — a `CLAUDE.md` that loads at the start of every session, every agent, no exceptions:

```
## Working Mode
Default: RIGOR — unless you explicitly say otherwise.

RIGOR — bug fixes, baseline checks, anything that gates the next step
  → One change at a time. Verify before moving forward.
  → Zero failures before declaring done.
  → No forward progress until current step is clean.

VELOCITY — exploration, prototyping, spike work
  → Batch changes. Run once at end. Flag and continue.

How to use: say "RIGOR mode" or "VELOCITY mode" at the start of your task.
If you don't declare, I will ask before starting.
```

One line at the start of a session overrides the model's default. But that was just the beginning.

---

## What Was Hiding In Plain Sight

After we solved the immediate problem, I asked the harder question: *"If you were the human behind the screen — how would you have run this session differently? What am I not using that I should be?"*

The answer was humbling. Here's what we found.

**1. Pre-task acceptance criteria.**
Before touching anything, require the model to write what done looks like. Three conditions. You approve them. Then work begins. RIGOR controls pace. Acceptance criteria control destination. You need both.

**2. The pre-mortem.**
Ask what could go wrong before you start, not after. The model will surface the risks it knows about. What it doesn't surface is your signal to probe harder.

**3. Flag unverified claims.**
One instruction changes everything: *"Flag any claim you have not directly verified with [UNVERIFIED]."* The model states confident-sounding things regardless of how certain it actually is. This forces it to distinguish knowledge from assertion — the single most common source of 6/10 work.

**4. Adversarial review agent.**
After implementation, spawn a fresh agent with zero context of how the work was done. Ask it only to find problems — not fix them. The implementing agent is compromised by its own context. A fresh agent sees what was rationalized away.

**5. Negative constraints.**
Tell the model what it cannot do, not just what it should do. *"Fix the tests. You may not skip any, mark them expected failures, or touch files outside the tests/ directory."* Closes off shortcuts before they're found. More powerful than positive instructions for anything correctness-critical.

**6. What didn't you do.**
After completion: *"What approaches did you consider but decide against?"* The paths not taken are often where the real answer lives. The model discards options silently. This question makes them visible.

**7. Confidence levels on claims.**
*"How confident are you from 1–10, and what's the main source of uncertainty?"* Same as the quality self-rating but applied to individual assertions. Surfaces the weak links before they become decisions.

**8. MEMORY.md for interaction patterns.**
Most people use persistent memory files for technical notes. The higher-leverage use is recording how the model fails with *you specifically.* "Claude dismisses low-count test failures as pre-existing without proof — require explicit evidence." That loads every session and corrects the pattern before it repeats.

---

## The Pattern Underneath All Of This

Every one of these techniques does the same thing:

**They move decisions from implicit to explicit, and from after to before.**

The default workflow is: give a task → see what's produced → correct what's wrong. Reactive.

A calibrated workflow is: define done → define what cannot be done → ask what could go wrong → start → checkpoint at each gate → review with fresh eyes. Proactive.

The quality difference between those two workflows is the difference between a 6 and a 10 — consistently.

---

## This Is Just The Beginning

Each of these protocols deserves its own deep dive, and that's exactly what's coming. Future articles will walk through each one in practice — what it looks like, when to use it, and what breaks without it.

But you don't need to wait. Every technique here is something you can add to your own `CLAUDE.md` today. The full section is in the repo (link in comments).

The bottleneck was never the model.
It was that I hadn't told it how to work.

Tell it first. Every session.

---

*Claude Watch is an open-source project building an Apple Watch interface for Claude Code.*
*GitHub repo and full CLAUDE.md in the comments.*
