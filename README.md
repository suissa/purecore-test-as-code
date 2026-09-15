# purecore-test-as-code

PureCore semantic test DSL and comptime compiler.

The repository separates three concerns:

1. src/declarations/purecore.pct describes semantic test scenarios.
2. src/config/purecore.yaml supplies values, limits, capabilities and fault plans.
3. src/compiler.zig validates both inputs at comptime and emits deterministic canonical JSON.

The five test types intentionally have different schemas:

- pcore.test.unit.v1: single deterministic behavior, oracle and event bound.
- pcore.test.load.v1: repetitions, event bound and idempotent settlement.
- pcore.test.stress.v1: workers, duration, failure budget and scheduling policy.
- pcore.test.chaos.v1: fault set, recovery strategy and replay requirement.
- pcore.test.security.v1: allowed capabilities, explicit denials, secret handling and terminal authority.

The compiler rejects missing test types, identity mismatches, unknown DSL/YAML keys and invalid numeric limits during compilation. The YAML never supplies executable test code or a pass/fail assertion. It supplies only scenario data; the runtime test executor remains the authority for observed results.

Run locally with Zig 0.16:

~~~bash
zig fmt --check build.zig src
zig build test
zig build run 2> generated-tests.json
~~~

CI validates formatting, executes the comptime compiler tests, validates the generated JSON against the canonical type set and uploads the generated contract as an artifact.
