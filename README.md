# Semantic Test as Code

This repository defines a semantic test DSL and a Zig 0.16 comptime compiler for Actions.

The generator is intentionally split into three inputs:

1. \`src/declarations/actions.tdsl\` contains the Action signature (\`input -> output\`) and the scenario-specific invariants.
2. \`src/config/tests.yaml\` contains values, type universes, limits, capabilities and fault plans.
3. \`src/compiler.zig\` reads both at comptime and emits deterministic canonical JSON.

The old product prefix and the explicit \`unit\` test kind are absent from the canonical schemas. A dynamic contract replaces the fixed unit skeleton:

- \`test.dynamic.v1\`: for every declared Action, emits at least five valid values and the complete invalid input/output type matrix.
- \`test.load.v1\`, \`test.stress.v1\`, \`test.chaos.v1\`, \`test.security.v1\`: distinct schemas for configured operational scenarios.
- \`test.benchmark.v1\`: automatically emitted for every Action, providing the standard execution benchmark.

The DLL does not create or falsify the tests. It only receives the generated contract. The runtime executor remains the authority for executing the Action and reporting observed results. YAML supplies data and policy; it cannot provide executable pass/fail functions.

For seven input types and seven output types, the generator emits \`7 × 7 − 1 = 48\` rejection cases per Action, plus five acceptance cases. Adding a new Action requires changing its declaration and configuration, not writing a new test implementation.

Run locally with Zig 0.16:

~~~bash
zig fmt --check build.zig src
zig build test
zig build run 2> generated-tests.json
~~~

CI formats and compiles the generator, validates the generated JSON shape and cardinalities, and uploads the generated contract as an artifact.
