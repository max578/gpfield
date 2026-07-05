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
  in place of a fabricated surface; *leader-directed adoption*.
- **Resolved boundaries (v0.3.0):** the two 2026-06-23 constellation-verify
  boundaries are closed. (1) The isotropic-kernel limit is lifted —
  `gpfield_spec(anisotropic = TRUE)` fits per-axis length-scales (ARD), and a
  spatio-temporal fit is anisotropic by default so directional gradients are
  modelled. (2) The cubic-scaling limit is lifted — `solver = "lowrank"` fits a
  DTC sparse GP on inducing points at `O(n * m^2)`, ~30x faster on ~1700 plots
  and reaching fields the exact solver cannot. Manifest emission is re-grounded
  to contract `2.0.0-draft` (version-stable payload hash; verifies across R
  versions). Open contract question for the leader node: nominal vs structural
  class identity (see `ORCHESTRA_dev/integration/gpfield_contract_sync_2026-07-05.md`).
- **Governance:** gpfield is a **Max-owned personal package** (MIT-track); the
  AAGI-AUS canon does not apply. At **v0.3.0** on the private remote
  `max578/gpfield` (Max's visibility call remains: still private).

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
