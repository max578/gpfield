# Orchestra membership — gpfield

> **This project (gpfield) is a MEMBER of the Orchestra** (one coordination
> structure; reconciled 2026-06-03). The leader-node is **ORCHESTRA_dev**
> (governance, roster, contracts, TACI, publication); the technical inference hub
> is **flexyBayes** (the dependency-DAG sink). This file is gpfield's back-pointer
> to that charter and a map of my siblings.

- **My role:** the **spatial member** — exact change-of-support Gaussian-process
  regression for field & multi-environment-trial data: point↔block prediction
  with full within-block-covariance propagation, row-column field smoothing, and
  spatio-temporal kriging. I model spatial structure; I do not decide or optimise.
- **Contracts I own / honour:** I **emit `orchestra_manifest`** day-one
  (`as_orchestra_manifest()`, `inferential_target = "predictions"`; sha256 payload
  hash) — a downstream consumer (decideR, conductoR) reads my surface with no
  special casing. I consume no manifest.
- **My edge:** producer — gpfield → the manifest layer → decideR / kernR /
  downstream. Acyclic leaf on the producing side.
- **What binds me (charter invariants):** *single-responsibility* (spatial GP +
  change-of-support only); *typed honest abstention* — `gpfield_abstention`
  (`range_too_short` / `support_gap` / `degenerate_fit` / `empty_query`) returned
  in place of a fabricated surface; *leader-directed adoption*. Known boundary
  (per the 2026-06-23 constellation verify): the kernel is **isotropic** —
  directional gradients need an anisotropic kernel (a flagged R&D item).
- **Governance:** gpfield is a **Max-owned personal package** (MIT-track); the
  AAGI-AUS canon does not apply. Built v0.1.0, local (no remote yet — Max's
  visibility call).

## My siblings (the full roster — so I am informed about the others)

| Member | Role | Class |
|---|---|---|
| flexyBayes | inference hub (owns C1/C4/C5/C7) | open (AAGI-gated) |
| PESTO | calibration + manifest source (C2) | open |
| kernR | validation + TACI/ACI engine | open |
| proxymix | KL-optimal proxy compression; the `proxymix_map` optimisation engine | open |
| gretaR | engine — torch MCMC | open |
| koine | synthesis — fourth opinion | open |
| terroir | data collector (C6) | open (MIT) |
| kalmix | state-space / change-point / ACI | open (MIT) |
| masque | data sovereignty (clones) | open |
| apsimR | external engine — APSIM Next Gen | open (MIT-src) |
| bourse | grounded market-data connector (trading arm) | open |
| survkit | time-to-event toolkit | open |
| janusplot | asymmetric GAM association matrices (diagnostic-viz) | open |
| gpfield | **change-of-support spatial GP (this package); emits `orchestra_manifest`** | open (MIT) |
| decideR | decision layer (loss-optimal closer) | open |
| grainPlan | grain decision-orchestration (on decideR) | open (MIT) |
| optimix | optimisation meta-layer; emits `orchestra_manifest` | open (MIT) |
| flexyBayesOrchestra | composition layer (surrogates, koine backend) | open |

Planned: genoR. **Canonical charter:** `ORCHESTRA_dev/ORCHESTRA.md` (mirrored in
the MaxAIbase brain, open tier). **Contract + dependency DAG:**
`ORCHESTRA_dev/integration/orchestra_manifest.R`.
