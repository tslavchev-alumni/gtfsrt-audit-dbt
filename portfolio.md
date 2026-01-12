# GTFS-Realtime Feed Health Audit — Portfolio Notes

This document provides additional context, design rationale, and lessons learned for the GTFS-Realtime Feed Health Audit project. For a concise overview of the project and repository scope, see the [README](./README.md).

The README in this repository describes the dbt project and final architecture. This document focuses on *why* the system was built the way it was, how it evolved, and what I learned while implementing it across different data platforms.

## Problem framing

The focus on feed health was a deliberate simplification, not the end goal.

I chose feed health because it was the most trivial non-useless thing I could do with GTFS-Realtime data. It is easy to define, easy to validate, and immediately exposes ingestion gaps, timestamp ambiguity, and state management problems. That made it a good forcing function for building and testing the data pipeline itself.

If this were a production project, feed health would be table stakes rather than the primary outcome. Once trust in the feed exists, the more interesting work would move toward downstream analytics: service reliability, vehicle behavior, schedule adherence, or rider-facing metrics. Those problems are domain-specific and context-dependent, so I intentionally avoided them here.

The goal of this project was not to demonstrate transit analytics expertise, but to design and reason about a reliable, testable, and explainable data engineering system. Feed health was simply the smallest question that required solving all of the underlying engineering problems.

## Architecture Evolution

### Snoflake Baseline

I started with a Snowflake-only implementation to establish a baseline and understand the shape and reliability of the GTFS-Realtime data before introducing additional tooling.

At this stage, AWS Lambda polled the GTFS-RT endpoints and wrote append-only JSONL records to S3, which were ingested into Snowflake as raw audit data. From there, I defined a canonical view to normalize timestamps, entity identifiers, and feed semantics. This view acted as a contract boundary between ingestion and analytics and allowed downstream logic to be written against a stable interface.

Using only Snowflake, I built fact-level and time-bucketed tables and scheduled them with native tasks. Functionally, this worked: the data refreshed, health metrics could be computed, and historical behavior was visible. However, the transformation logic was implicit. Incremental behavior, assumptions about grain, and failure modes were embedded directly in SQL and task definitions, making it harder to reason about changes or verify correctness without running the system.

This phase was useful because it demonstrated that the problem was solvable with the warehouse alone. It also clarified where the friction points were: not in Snowflake’s capabilities, but in managing transformation logic, incremental state, and data quality guarantees as the pipeline became more complex.

### dbt Cloud - managing logic

The introduction of dbt was not about enabling transformations that Snowflake could not perform. It was about making the behavior of the system explicit, testable, and easier to reason about as it grew.

Before dbt, incremental logic, assumptions about grain, and expectations about data quality were encoded directly in SQL and Snowflake task definitions. While this worked operationally, in a production environment it would require holding too much context in my head at once.

dbt changed this by separating *what* the models were supposed to do from *how* the warehouse executed them. Incremental behavior became declarative rather than implicit. Dependencies were expressed as a graph instead of being scattered across task schedules. Data quality expectations were written down as tests instead of being assumed or checked informally.

dbt did not make the pipeline more powerful; it made it more legible and in the long run - more manageable. The same transformations could have continued to run in Snowflake alone, but dbt provided structure around them: versioned models, explicit contracts, and failure modes that were visible and intentional rather than accidental.

### 3.3 Databricks mirror: same problem, different defaults

After the Snowflake + dbt pipeline was complete and stable, I mirrored the same problem in Databricks. This was not intended as a migration or a replacement, but as a way to compare how the same mental model translated to a lakehouse-style system with different defaults.

The scope was intentionally constrained. I reused the same source data, the same canonical concepts, and the same health logic. The goal was not to redesign the pipeline, but to see how much of the existing structure would carry over when the execution environment changed.

What stood out immediately was how much behavior Databricks encoded into defaults. Incremental ingestion from object storage, schema handling, and state management were largely handled by the platform through Auto Loader and checkpoints. As a result, the amount of code required to achieve the same outcome was noticeably smaller than in the Snowflake-only or Snowflake + dbt versions.

This ease was initially suspicious. It was not that the problem had become simpler, but that many decisions had been pushed into the platform itself. State lived in checkpoints rather than in queries. Incrementality was implicit rather than explicitly defined. This reduced friction, but also shifted responsibility: correctness now depended on understanding what guarantees the platform provided and what assumptions it was making on my behalf.

I intentionally stopped short of fully productionizing the Databricks version. Streaming jobs were run in bounded, `availableNow` mode rather than left running continuously, and downstream models were rebuilt deterministically rather than incrementally. The goal was to understand the abstraction boundary, not to add operational complexity or create another system to maintain.

This comparison reinforced an important distinction. The Snowflake + dbt version favored explicitness and control, at the cost of verbosity. The Databricks version favored momentum and defaults, at the cost of hidden complexity. Both approaches were capable of supporting the same health model, but they encouraged different ways of thinking about state, responsibility, and failure.

## Key Design Concepts

This section summarizes the core design concepts that shaped the project. These are not abstract best practices, but ideas that became concrete through implementation and comparison across systems.

### Canonical models as contract boundaries

One of the earliest design decisions was to introduce a canonical representation of the data before building analytics on top of it. In practice, this meant defining a Snowflake view (and later equivalent logic elsewhere) that normalized timestamps, identifiers, and semantics into a stable shape.

The purpose of the canonical layer was not performance or convenience, but insulation. By establishing a clear contract between ingestion and analytics, downstream models could be written against a predictable interface even as upstream behavior changed. This reduced coupling and made it possible to evolve ingestion logic without rewriting analytical models.

In retrospect, this boundary mattered more than any individual tool choice. The same canonical concepts carried cleanly from Snowflake-only SQL to dbt models and to Databricks, which made the system easier to reason about and compare across platforms.

---

### Incremental processing and explicit state

Although the pipeline processes near-real-time data, the more fundamental challenge was managing state: knowing what had already been processed, what was new, and what assumptions were being made about ordering and completeness.

In the Snowflake-only phase, incremental behavior existed but was implicit, encoded in query logic and task schedules. Introducing dbt made this state explicit through incremental models and well-defined uniqueness and update rules. In Databricks, the same problem was solved differently, with state externalized into checkpoints managed by the platform.

Seeing these approaches side by side clarified an important point: incremental processing is not about speed, but about correctness over time. Whether state lives in SQL predicates, dbt metadata, or streaming checkpoints, it must be understood and protected. Hiding state does not remove it; it only changes where mistakes can occur.

---

### Health metrics versus health judgments

The project deliberately separates raw health signals from health judgments. Metrics such as entity counts, ingestion lag, and source staleness are computed mechanically and retained as evidence. Health status and primary issue classifications are then derived from those metrics using explicit thresholds.

This separation was intentional. Metrics describe what happened; classifications encode policy. By keeping them distinct, it becomes easier to change thresholds, explain failures, or reuse the same metrics for different operational definitions of “healthy.”

This distinction also reinforced the idea that analytics pipelines should surface evidence, not opinions. The system provides enough information to support decisions, but it does not pretend that a single classification captures all operational context.

---

### Defaults versus explicit control

Comparing Snowflake + dbt with Databricks highlighted a recurring tradeoff between explicit control and productive defaults.

The Snowflake + dbt implementation required more code and more deliberate configuration, but it made behavior visible and inspectable. Incremental rules, dependencies, and tests were written down and versioned. Databricks, by contrast, made many of the same behaviors effortless by encoding them into the platform itself.

Neither approach is inherently superior. Defaults accelerate progress, but they also concentrate responsibility in understanding platform guarantees. Explicit control increases verbosity, but it reduces ambiguity. This project reinforced that tool choice is less important than being clear about where decisions live and who is responsible for them when things go wrong.

## Lessons Learned

This project reinforced several lessons about data engineering that go beyond specific tools or technologies. Most of them only became clear through iteration, comparison, and moments of discomfort rather than from initial design.

### Legibility matters more than raw capability

One recurring theme was that the difficulty of the project did not come from implementing transformations, but from being able to reason about what the system was doing over time. Snowflake alone was capable of performing all required computations, but as logic accumulated, intent and assumptions became increasingly implicit.

Introducing dbt did not add new capabilities; it made behavior legible. Incremental rules, dependencies, and data quality expectations were written down instead of inferred. This made the system easier to change, easier to explain, and easier to trust. The lesson was not that more tooling is better, but that explicit structure reduces cognitive load as systems grow.

---

### Ease comes from defaults, not from magic

The Databricks implementation initially felt suspiciously easy. Much of the machinery required elsewhere—incremental ingestion, state tracking, schema handling—was handled by platform defaults. That ease did not mean the problem had disappeared. It meant that decisions were being made on my behalf.

This shifted responsibility from writing logic to understanding guarantees. Correctness depended less on code and more on knowing what the platform promised and where state lived. The lesson was that “easy” tools are not dangerous, but they require a different kind of attention: understanding abstractions rather than implementations.

---

### State is the core challenge in incremental pipelines

Across all implementations, the hardest problems revolved around state. Incremental processing is fundamentally about remembering what has already been seen, what is new, and what assumptions are being made about completeness and ordering.

Whether state was encoded in SQL predicates, dbt metadata, or streaming checkpoints, it existed regardless. Making state explicit reduced the risk of silent errors and made failure modes easier to reason about. Hiding state did not remove complexity; it only changed where mistakes could occur.

---

### Narrow scope enables depth

The focus on feed health was a deliberate simplification. It was chosen because it was the smallest non-trivial question that forced the pipeline to confront ingestion gaps, timestamp ambiguity, and state management. More complex analytics would have added domain-specific logic without changing the underlying engineering challenges.

This reinforced the value of scoping projects around forcing functions rather than feature richness. Solving a simple but structurally demanding problem provided more learning than implementing broader but shallower use cases.

---

### Portability of thinking matters more than portability of code

When mirroring the pipeline in Databricks, I did not port code line by line. Instead, I reused the same mental model: canonical boundaries, incremental state, and explicit health logic. Because those concepts were already clear, re-expressing them in a different system was straightforward.

This highlighted that good architectures migrate by re-expression rather than translation. Clear thinking travels better than optimized code.

---

### Restraint is part of production readiness

Throughout the project, I intentionally stopped short of full automation or continuous operation. Streaming jobs were bounded, environments were not kept running unnecessarily, and non-essential features were excluded.

This was not a limitation of the tools, but a design choice. Production readiness is not about maximizing completeness; it is about minimizing unnecessary complexity while preserving correctness. Knowing when to stop building is as important as knowing how to build.

## Cheat Sheet

This section is a personal reference for interviews and quick recall. It is intentionally concise and assumes familiarity with the project.

### One-sentence project summary
End-to-end pipeline to ingest GTFS-Realtime data, normalize it behind a canonical contract, and compute operational feed health using both a warehouse-first (Snowflake + dbt) and lakehouse-first (Databricks) approach.

---

### 60-second explanation
I built a GTFS-Realtime feed health pipeline that ingests high-frequency JSON data, normalizes it into a canonical model, and computes health metrics like freshness, staleness, and ingestion lag. I started with a Snowflake-only implementation, introduced dbt to make incremental behavior and data quality explicit, and then mirrored the same logic in Databricks to compare how different platforms handle state and defaults. The focus was on correctness, contracts, and explainability rather than dashboards or business KPIs.

---

### Core invariants (what never changed)
- Append-only raw ingestion
- Canonical contract boundary before analytics
- Explicit handling of incremental state
- Health metrics separated from health classification
- Deterministic rebuilds preferred over hidden mutation

---

### Key concepts (one-liners)
- **Canonical model**: Stable contract that decouples ingestion from analytics.
- **Incremental processing**: Managing state over time, not optimizing for speed.
- **Health metrics vs judgments**: Evidence first, policy second.
- **Checkpoints**: Externalized memory of what has already been processed.
- **Bronze / Silver / Gold**: Evidence → agreement → opinion.

---

### Snowflake vs dbt (how to say it)
- Snowflake can do the work.
- dbt makes the behavior explicit, testable, and explainable.
- dbt adds structure, not capability.

---

### Snowflake/dbt vs Databricks (how to say it)
- Snowflake + dbt favors explicit control and legibility.
- Databricks favors momentum through defaults.
- Neither removes complexity; they relocate it.
- The same mental model works in both.

---

### What I intentionally did NOT do
- No dashboards or BI layer
- No continuous streaming jobs
- No business KPIs or rider-facing metrics
- No attempt to productionize free-tier infrastructure

---

### Common interview questions → anchor answers

**Why feed health?**  
Smallest non-trivial question that forces you to solve ingestion, state, and correctness.

**What would break if checkpoints disappeared?**  
Incremental ingestion would forget progress and silently reprocess data.

**Why not just use Databricks / Snowflake?**  
Tools execute logic; architecture determines whether the logic is understandable and safe to change.

**What would you change for production?**  
Tighter alerting, explicit SLAs, and clearer ownership boundaries — not different core logic.

---

### Personal reminder
If I can explain this calmly and precisely, I understand it well enough to work on similar systems.
