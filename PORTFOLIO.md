# Portfolio Notes

This document captures the design rationale, architectural tradeoffs, and lessons learned from building the GTFS-Realtime Feed Health Audit pipeline.

For a structural overview of the repository and pointers to specific files, see [ARCHITECTURE.md](./ARCHITECTURE.md).

---

## Problem framing

The focus on feed health was a deliberate simplification.

Feed health is not the end goal of a real GTFS-Realtime analytics system. It is the smallest non-trivial question that immediately exposes ingestion gaps,
timestamp ambiguity, and state management problems. That made it a useful forcing function for designing and testing the data pipeline itself.

If this were a production project, feed health would be a prerequisite rather than the outcome. Once trust in the feeds exists, downstream work would naturally move toward service reliability, vehicle behavior, or schedule adherence. Those problems are domain-specific and context-dependent, so I intentionally avoided them here.

The goal of this project was not to demonstrate transit analytics expertise, but to design and reason about a reliable, testable, and explainable data engineering system.

---

## Architecture evolution

### Snowflake-first baseline

I started with a Snowflake-only implementation to understand the shape and reliability of the GTFS-Realtime data before introducing additional tooling.

An AWS Lambda function polled GTFS-RT endpoints and wrote append-only JSONL records to S3, which were ingested into Snowflake as raw audit data. From there, I defined a canonical view that normalized timestamps and feed semantics. This view acted as a contract boundary between ingestion and analytics.

Using Snowflake alone, I built minute-level and time-bucketed health facts scheduled with native tasks. While this worked functionally, incremental behavior and failure modes were implicit, embedded directly in SQL and task definitions. Verifying correctness required holding too much context at once.

---

### Introducing dbt

dbt was introduced not to enable new transformations, but to make system behavior explicit and easier to reason about.

Incremental behavior became declarative rather than implicit. Dependencies were expressed as a graph rather than encoded in task schedules. Data quality expectations were written down as tests instead of being assumed.

dbt did not make the pipeline more powerful. It made it more legible. The same logic could have continued to run in Snowflake alone, but dbt provided structure around it: versioned models, explicit contracts, and visible failure modes.

---

### Comparing with Databricks

After the Snowflake + dbt pipeline was stable, I mirrored the same problem in Databricks to compare how the same mental model translated to a lakehouse-style system.

The scope was intentionally constrained. I reused the same source data, canonical concepts, and health logic. What stood out was how much behavior Databricks encoded into defaults: incremental ingestion, state management, and schema handling required less explicit code.

This reduced friction but shifted responsibility. Correctness depended more on understanding platform guarantees than on writing explicit logic. I stopped short of
fully productionizing this version; the goal was to understand abstraction boundaries, not to add another system to maintain.

---

## Key design concepts

### Canonical models as contract boundaries

A canonical representation of the data was introduced early to decouple ingestion from analytics. Its purpose was insulation rather than convenience.

By establishing a stable contract, downstream models could be written against a predictable interface even as upstream behavior changed. This boundary carried cleanly across Snowflake, dbt, and Databricks and mattered more than any individual tool choice.

---

### Incremental processing and explicit state

The core challenge of the pipeline was managing state: what has already been processed, what is new, and what assumptions are being made about completeness and
ordering.

In Snowflake, incremental behavior was implicit. dbt made state explicit through incremental models and declared uniqueness rules. In Databricks, state was
externalized into platform-managed checkpoints. Across all implementations, making state explicit reduced the risk of silent errors.

---

### Health metrics versus health judgments

The project separates raw health signals from health judgments. Metrics such as ingestion lag and source staleness are computed mechanically and retained as evidence. Health status and primary issue classifications are derived from those metrics using explicit thresholds.

This separation makes it easier to change policy, explain failures, or reuse metrics for different operational definitions of “healthy.” The system surfaces evidence rather than opinions.

---

### Defaults versus explicit control

Comparing Snowflake + dbt with Databricks highlighted a tradeoff between explicit control and productive defaults.

Snowflake + dbt favored legibility and inspectability at the cost of verbosity. Databricks favored momentum through defaults, at the cost of hidden complexity. Neither removed complexity; they relocated it.

---

## Lessons learned

### Legibility matters more than raw capability

The difficulty of the project came less from implementing transformations than from reasoning about system behavior over time. Making intent, state, and assumptions explicit reduced cognitive load and increased trust in the system.

---

### State is the core challenge in incremental pipelines

Across all implementations, the most persistent source of complexity was state. Incremental processing always involves memory, whether encoded in SQL, dbt metadata, or streaming checkpoints. Hiding state does not remove complexity; it only changes where mistakes can occur.

---

### Narrow scope enables depth

Focusing on feed health enabled deeper exploration of ingestion, contracts, and incremental state without being distracted by domain-specific analytics. Solving a
small but structurally demanding problem provided more learning than broader but shallower use cases.

---

## Cheat sheet

### 60-second summary

I built a GTFS-Realtime feed health pipeline that ingests high-frequency JSON data, normalizes it behind a canonical contract, and computes operational health metrics. I started with a Snowflake-only implementation, introduced dbt to make incremental behavior and data quality explicit, and mirrored the same logic in Databricks to compare how different platforms handle state and defaults.

### Constants by design

- Append-only raw ingestion  
- Canonical contract boundary before analytics  
- Explicit handling of incremental state  
- Health metrics separated from health classification  
- Deterministic rebuilds preferred over hidden mutation  

### What I intentionally did not do

- No dashboards or BI layer  
- No continuous streaming jobs  
- No business KPIs or rider-facing metrics  
- No attempt to productionize free-tier infrastructure  
