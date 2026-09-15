# Semantic Test as Code

Semantic test DSL and Zig 0.16 comptime compiler for Actions.

The public contract uses Semantic AtomicBehavior Types. It does not use a product prefix, an explicit \`unit\` kind, primitive type names, or language-specific containers.

Inputs:

- \`src/declarations/semantic-atomicbehavior.tdsl\`: declares the semantic type system, each Action's \`input -> output\` signature, and scenario invariants.
- \`src/config/tests.yaml\`: supplies semantic fixtures, declared type universes, limits, capabilities, and fault plans.
- \`src/compiler.zig\`: reads both at comptime and emits deterministic canonical JSON.

Generated contracts:

- \`test.dynamic.v1\`: five valid semantic fixtures plus the complete invalid input/output Semantic AtomicBehavior Type matrix for every Action.
- \`test.load.v1\`, \`test.stress.v1\`, \`test.chaos.v1\`, \`test.security.v1\`: different schemas for operational scenarios.
- \`test.benchmark.v1\`: emitted automatically for every Action as the standard execution benchmark.

The compiler rejects undeclared or primitive type names. The DLL does not create or falsify tests: it receives the generated contract. The runtime executor invokes the Action and remains the authority for observed results. YAML supplies data and policy; it cannot provide executable pass/fail functions.

The sample declares ten semantic types in both universes, producing \`10 × 10 − 1 = 99\` rejection cases per Action, plus five acceptance cases. Adding an Action requires its semantic signature and configuration, not a new test implementation.

Run locally with Zig 0.16:

~~~bash
zig fmt --check build.zig src
zig build test
zig build run 2> generated-tests.json
~~~

CI compiles the generator, validates semantic type declarations, checks generated JSON cardinalities, and uploads the generated contract.
