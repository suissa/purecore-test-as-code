const std = @import("std");

const max_types = 64;
const max_actions = 32;
const max_scenarios = 128;
const max_output = 131072;

pub const TestKind = enum {
    dynamic_contract,
    load,
    stress,
    chaos,
    security,
    benchmark,
};

const SemanticType = struct {
    name: []const u8,
    category: []const u8,
    meaning: []const u8,
};

const Action = struct {
    name: []const u8,
    input_type: []const u8,
    output_type: []const u8,
};

const Scenario = struct {
    kind: TestKind,
    action: []const u8,
    invariants: []const u8,
};

const Declaration = struct {
    type_system: []const u8 = "",
    suite: []const u8 = "",
    agent: []const u8 = "",
    intent: []const u8 = "",
    types: [max_types]SemanticType = undefined,
    type_count: usize = 0,
    actions: [max_actions]Action = undefined,
    action_count: usize = 0,
    scenarios: [max_scenarios]Scenario = undefined,
    scenario_count: usize = 0,
};

const YamlConfig = struct {
    type_system: []const u8 = "",
    suite: []const u8 = "",
    agent: []const u8 = "",
    intent: []const u8 = "",
    valid_fixtures: []const u8 = "",
    input_types: []const u8 = "",
    output_types: []const u8 = "",
    load_repetitions: usize = 8,
    load_max_events: usize = 256,
    stress_workers: usize = 4,
    stress_duration_ms: usize = 1000,
    stress_max_failures: usize = 0,
    chaos_faults: []const u8 = "",
    chaos_recovery: []const u8 = "",
    security_capabilities: []const u8 = "",
    security_denials: []const u8 = "",
    benchmark_warmup: usize = 3,
    benchmark_iterations: usize = 20,
    benchmark_concurrency: usize = 1,
    benchmark_p95_max_ms: usize = 250,
};

pub const Buffer = struct {
    bytes: [max_output]u8 = undefined,
    len: usize = 0,

    fn raw(self: *Buffer, value: []const u8) void {
        if (self.len + value.len > max_output) @compileError("generated JSON exceeds compiler buffer");
        @memcpy(self.bytes[self.len .. self.len + value.len], value);
        self.len += value.len;
    }

    fn jsonString(self: *Buffer, value: []const u8) void {
        self.raw("\"");
        for (value) |character| {
            switch (character) {
                '"' => self.raw("\\\""),
                '\\' => self.raw("\\\\"),
                '\n' => self.raw("\\n"),
                '\r' => self.raw("\\r"),
                '\t' => self.raw("\\t"),
                else => {
                    self.bytes[self.len] = character;
                    self.len += 1;
                },
            }
        }
        self.raw("\"");
    }

    fn key(self: *Buffer, name: []const u8, value: []const u8) void {
        self.jsonString(name);
        self.raw(":");
        self.jsonString(value);
    }

    fn number(self: *Buffer, value: usize) void {
        var temporary: [32]u8 = undefined;
        var cursor = temporary.len;
        var remaining = value;
        if (remaining == 0) {
            self.raw("0");
            return;
        }
        while (remaining > 0) {
            cursor -= 1;
            temporary[cursor] = @intCast('0' + remaining % 10);
            remaining /= 10;
        }
        self.raw(temporary[cursor..]);
    }

    fn boolean(self: *Buffer, value: bool) void {
        self.raw(if (value) "true" else "false");
    }

    fn comma(self: *Buffer, first: *bool) void {
        if (!first.*) self.raw(",");
        first.* = false;
    }

    pub fn slice(self: *const Buffer) []const u8 {
        return self.bytes[0..self.len];
    }
};

fn tokenAt(line: []const u8, wanted: usize) []const u8 {
    var iterator = std.mem.tokenizeAny(u8, line, " \t\r");
    var index: usize = 0;
    while (iterator.next()) |token| {
        if (index == wanted) return token;
        index += 1;
    }
    return "";
}

fn valueToken(line: []const u8, key_name: []const u8) []const u8 {
    var iterator = std.mem.tokenizeAny(u8, line, " \t\r");
    _ = iterator.next();
    _ = iterator.next();
    while (iterator.next()) |token| {
        if (token.len > key_name.len and
            std.mem.startsWith(u8, token, key_name) and
            token[key_name.len] == '=')
            return token[key_name.len + 1 ..];
    }
    return "";
}

fn parseScenarioKind(token: []const u8) ?TestKind {
    if (std.mem.eql(u8, token, "load")) return .load;
    if (std.mem.eql(u8, token, "stress")) return .stress;
    if (std.mem.eql(u8, token, "chaos")) return .chaos;
    if (std.mem.eql(u8, token, "security")) return .security;
    return null;
}

fn parseDeclaration(comptime source: []const u8) Declaration {
    var result = Declaration{};
    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;

        const first = tokenAt(line, 0);
        if (std.mem.eql(u8, first, "type_system")) {
            result.type_system = tokenAt(line, 1);
        } else if (std.mem.eql(u8, first, "suite")) {
            result.suite = tokenAt(line, 1);
        } else if (std.mem.eql(u8, first, "agent")) {
            result.agent = tokenAt(line, 1);
        } else if (std.mem.eql(u8, first, "intent")) {
            result.intent = tokenAt(line, 1);
        } else if (std.mem.eql(u8, first, "type")) {
            if (result.type_count >= max_types) @compileError("too many Semantic AtomicBehavior Types");
            result.types[result.type_count] = .{
                .name = tokenAt(line, 1),
                .category = valueToken(line, "category"),
                .meaning = valueToken(line, "meaning"),
            };
            result.type_count += 1;
        } else if (std.mem.eql(u8, first, "action")) {
            if (result.action_count >= max_actions) @compileError("too many semantic action declarations");
            result.actions[result.action_count] = .{
                .name = tokenAt(line, 1),
                .input_type = valueToken(line, "input"),
                .output_type = valueToken(line, "output"),
            };
            result.action_count += 1;
        } else if (parseScenarioKind(first)) |kind| {
            if (result.scenario_count >= max_scenarios) @compileError("too many semantic test declarations");
            result.scenarios[result.scenario_count] = .{
                .kind = kind,
                .action = tokenAt(line, 1),
                .invariants = valueToken(line, "invariants"),
            };
            result.scenario_count += 1;
        } else {
            @compileError("unknown semantic DSL declaration");
        }
    }
    return result;
}

fn parseNumber(value: []const u8, key_name: []const u8) usize {
    return std.fmt.parseInt(usize, value, 10) catch @compileError(key_name ++ " must be an unsigned integer");
}

fn parseYaml(comptime source: []const u8) YamlConfig {
    var result = YamlConfig{};
    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;
        const separator = std.mem.indexOfScalar(u8, line, ':') orelse @compileError("YAML line must contain ':'");
        const key_name = std.mem.trim(u8, line[0..separator], " \t");
        const value = std.mem.trim(u8, line[separator + 1 ..], " \t\"");

        if (std.mem.eql(u8, key_name, "type_system")) result.type_system = value
        else if (std.mem.eql(u8, key_name, "suite")) result.suite = value
        else if (std.mem.eql(u8, key_name, "agent")) result.agent = value
        else if (std.mem.eql(u8, key_name, "intent")) result.intent = value
        else if (std.mem.eql(u8, key_name, "valid_fixtures")) result.valid_fixtures = value
        else if (std.mem.eql(u8, key_name, "input_types")) result.input_types = value
        else if (std.mem.eql(u8, key_name, "output_types")) result.output_types = value
        else if (std.mem.eql(u8, key_name, "load_repetitions")) result.load_repetitions = parseNumber(value, key_name)
        else if (std.mem.eql(u8, key_name, "load_max_events")) result.load_max_events = parseNumber(value, key_name)
        else if (std.mem.eql(u8, key_name, "stress_workers")) result.stress_workers = parseNumber(value, key_name)
        else if (std.mem.eql(u8, key_name, "stress_duration_ms")) result.stress_duration_ms = parseNumber(value, key_name)
        else if (std.mem.eql(u8, key_name, "stress_max_failures")) result.stress_max_failures = parseNumber(value, key_name)
        else if (std.mem.eql(u8, key_name, "chaos_faults")) result.chaos_faults = value
        else if (std.mem.eql(u8, key_name, "chaos_recovery")) result.chaos_recovery = value
        else if (std.mem.eql(u8, key_name, "security_capabilities")) result.security_capabilities = value
        else if (std.mem.eql(u8, key_name, "security_denials")) result.security_denials = value
        else if (std.mem.eql(u8, key_name, "benchmark_warmup")) result.benchmark_warmup = parseNumber(value, key_name)
        else if (std.mem.eql(u8, key_name, "benchmark_iterations")) result.benchmark_iterations = parseNumber(value, key_name)
        else if (std.mem.eql(u8, key_name, "benchmark_concurrency")) result.benchmark_concurrency = parseNumber(value, key_name)
        else if (std.mem.eql(u8, key_name, "benchmark_p95_max_ms")) result.benchmark_p95_max_ms = parseNumber(value, key_name)
        else @compileError("unknown YAML configuration key");
    }
    return result;
}

fn hasScenario(declaration: Declaration, kind: TestKind) bool {
    for (declaration.scenarios[0..declaration.scenario_count]) |scenario| {
        if (scenario.kind == kind) return true;
    }
    return false;
}

fn findAction(declaration: Declaration, name: []const u8) ?Action {
    for (declaration.actions[0..declaration.action_count]) |action| {
        if (std.mem.eql(u8, action.name, name)) return action;
    }
    return null;
}

fn findType(declaration: Declaration, name: []const u8) ?SemanticType {
    for (declaration.types[0..declaration.type_count]) |semantic_type| {
        if (std.mem.eql(u8, semantic_type.name, name)) return semantic_type;
    }
    return null;
}

fn csvCount(value: []const u8) usize {
    var count: usize = 0;
    var iterator = std.mem.tokenizeAny(u8, value, ",");
    while (iterator.next()) |_| count += 1;
    return count;
}

fn validateTypeUniverse(declaration: Declaration, value: []const u8) void {
    var iterator = std.mem.tokenizeAny(u8, value, ",");
    while (iterator.next()) |entry| {
        const name = std.mem.trim(u8, entry, " \t");
        if (findType(declaration, name) == null)
            @compileError("YAML type universe may contain only declared Semantic AtomicBehavior Types");
    }
}

fn invalidPairCount(action: Action, config: YamlConfig) usize {
    var count: usize = 0;
    var inputs = std.mem.tokenizeAny(u8, config.input_types, ",");
    while (inputs.next()) |input_type| {
        var outputs = std.mem.tokenizeAny(u8, config.output_types, ",");
        while (outputs.next()) |output_type| {
            const normalized_input = std.mem.trim(u8, input_type, " \t");
            const normalized_output = std.mem.trim(u8, output_type, " \t");
            if (!std.mem.eql(u8, normalized_input, action.input_type) or
                !std.mem.eql(u8, normalized_output, action.output_type))
                count += 1;
        }
    }
    return count;
}

fn validate(declaration: Declaration, config: YamlConfig) void {
    if (!std.mem.eql(u8, declaration.type_system, "semantic-atomicbehavior") or
        !std.mem.eql(u8, config.type_system, "semantic-atomicbehavior"))
        @compileError("type_system must be semantic-atomicbehavior");
    if (declaration.suite.len == 0 or declaration.agent.len == 0 or declaration.intent.len == 0)
        @compileError("DSL must declare suite, agent and intent");
    if (config.suite.len == 0 or config.agent.len == 0 or config.intent.len == 0)
        @compileError("YAML must declare suite, agent and intent");
    if (!std.mem.eql(u8, declaration.suite, config.suite) or
        !std.mem.eql(u8, declaration.agent, config.agent) or
        !std.mem.eql(u8, declaration.intent, config.intent))
        @compileError("DSL identity and YAML identity must match");
    if (declaration.type_count == 0) @compileError("DSL must declare Semantic AtomicBehavior Types");
    if (declaration.action_count == 0) @compileError("DSL must declare at least one action");
    for (declaration.types[0..declaration.type_count]) |semantic_type| {
        if (semantic_type.name.len == 0 or semantic_type.category.len == 0 or semantic_type.meaning.len == 0)
            @compileError("every Semantic AtomicBehavior Type needs name, category and meaning");
    }
    for ([_]TestKind{ .load, .stress, .chaos, .security }) |kind| {
        if (!hasScenario(declaration, kind)) @compileError("DSL must declare load, stress, chaos and security scenarios");
    }
    if (csvCount(config.valid_fixtures) < 5) @compileError("YAML must provide at least five semantic valid_fixtures");
    if (csvCount(config.input_types) == 0 or csvCount(config.output_types) == 0)
        @compileError("YAML must provide input_types and output_types");
    validateTypeUniverse(declaration, config.input_types);
    validateTypeUniverse(declaration, config.output_types);
    if (config.load_repetitions == 0 or config.stress_workers == 0 or
        config.stress_duration_ms == 0 or config.benchmark_iterations == 0 or
        config.benchmark_concurrency == 0)
        @compileError("load, stress and benchmark limits must be non-zero");

    for (declaration.actions[0..declaration.action_count]) |action| {
        if (action.name.len == 0 or action.input_type.len == 0 or action.output_type.len == 0)
            @compileError("action must declare name, semantic input type and semantic output type");
        if (findType(declaration, action.input_type) == null or findType(declaration, action.output_type) == null)
            @compileError("action signatures must use declared Semantic AtomicBehavior Types");
        if (invalidPairCount(action, config) == 0)
            @compileError("semantic type matrix must contain at least one invalid input/output pair");
    }
    for (declaration.scenarios[0..declaration.scenario_count]) |scenario| {
        if (findAction(declaration, scenario.action) == null)
            @compileError("scenario references an undeclared action");
    }
}

fn appendCsvArray(output: *Buffer, value: []const u8) void {
    output.raw("[");
    var first = true;
    var iterator = std.mem.tokenizeAny(u8, value, ",");
    while (iterator.next()) |entry| {
        output.comma(&first);
        output.jsonString(std.mem.trim(u8, entry, " \t"));
    }
    output.raw("]");
}

fn appendValidCases(output: *Buffer, action: Action, config: YamlConfig) void {
    output.raw("[");
    var first = true;
    var index: usize = 0;
    var iterator = std.mem.tokenizeAny(u8, config.valid_fixtures, ",");
    while (iterator.next()) |raw_fixture| {
        output.comma(&first);
        output.raw("{");
        output.key("case", "valid");
        output.raw(",");
        output.jsonString("ordinal");
        output.raw(":");
        output.number(index + 1);
        output.raw(",");
        output.key("input_type", action.input_type);
        output.raw(",");
        output.key("input_fixture", std.mem.trim(u8, raw_fixture, " \t"));
        output.raw(",");
        output.key("expected_output_type", action.output_type);
        output.raw(",");
        output.key("expected", "accept");
        output.raw("}");
        index += 1;
    }
    output.raw("]");
}

fn appendInvalidCases(output: *Buffer, action: Action, config: YamlConfig) void {
    output.raw("[");
    var first = true;
    var inputs = std.mem.tokenizeAny(u8, config.input_types, ",");
    while (inputs.next()) |input_type| {
        var outputs = std.mem.tokenizeAny(u8, config.output_types, ",");
        while (outputs.next()) |output_type| {
            const normalized_input = std.mem.trim(u8, input_type, " \t");
            const normalized_output = std.mem.trim(u8, output_type, " \t");
            if (std.mem.eql(u8, normalized_input, action.input_type) and
                std.mem.eql(u8, normalized_output, action.output_type))
                continue;
            output.comma(&first);
            output.raw("{");
            output.key("input_type", normalized_input);
            output.raw(",");
            output.key("output_type", normalized_output);
            output.raw(",");
            output.key("expected", "reject");
            output.raw("}");
        }
    }
    output.raw("]");
}

fn appendDynamicContract(output: *Buffer, action: Action, config: YamlConfig) void {
    output.raw("{");
    output.key("schema", "test.dynamic.v1");
    output.raw(",");
    output.key("kind", "dynamic-contract");
    output.raw(",");
    output.key("type_system", "semantic-atomicbehavior");
    output.raw(",");
    output.key("action", action.name);
    output.raw(",");
    output.key("input_type", action.input_type);
    output.raw(",");
    output.key("output_type", action.output_type);
    output.raw(",");
    output.key("oracle", "runtime-owned");
    output.raw(",");
    output.jsonString("valid_cases");
    output.raw(":");
    appendValidCases(output, action, config);
    output.raw(",");
    output.jsonString("invalid_cases");
    output.raw(":");
    appendInvalidCases(output, action, config);
    output.raw(",");
    output.jsonString("invalid_case_count");
    output.raw(":");
    output.number(invalidPairCount(action, config));
    output.raw("}");
}

fn appendBenchmark(output: *Buffer, action: Action, config: YamlConfig) void {
    output.raw("{");
    output.key("schema", "test.benchmark.v1");
    output.raw(",");
    output.key("kind", "benchmark");
    output.raw(",");
    output.key("type_system", "semantic-atomicbehavior");
    output.raw(",");
    output.key("action", action.name);
    output.raw(",");
    output.key("input_type", action.input_type);
    output.raw(",");
    output.key("output_type", action.output_type);
    output.raw(",");
    output.jsonString("warmup");
    output.raw(":");
    output.number(config.benchmark_warmup);
    output.raw(",");
    output.jsonString("iterations");
    output.raw(":");
    output.number(config.benchmark_iterations);
    output.raw(",");
    output.jsonString("concurrency");
    output.raw(":");
    output.number(config.benchmark_concurrency);
    output.raw(",");
    output.jsonString("p95_max_ms");
    output.raw(":");
    output.number(config.benchmark_p95_max_ms);
    output.raw(",");
    output.key("oracle", "runtime-owned");
    output.raw("}");
}

fn appendScenario(output: *Buffer, scenario: Scenario, action: Action, config: YamlConfig) void {
    output.raw("{");
    output.key("schema", switch (scenario.kind) {
        .load => "test.load.v1",
        .stress => "test.stress.v1",
        .chaos => "test.chaos.v1",
        .security => "test.security.v1",
        else => @compileError("scenario kind cannot be emitted as a configured scenario"),
    });
    output.raw(",");
    output.key("kind", switch (scenario.kind) {
        .load => "load",
        .stress => "stress",
        .chaos => "chaos",
        .security => "security",
        else => @compileError("scenario kind cannot be emitted as a configured scenario"),
    });
    output.raw(",");
    output.key("type_system", "semantic-atomicbehavior");
    output.raw(",");
    output.key("action", action.name);
    output.raw(",");
    output.key("input_type", action.input_type);
    output.raw(",");
    output.key("output_type", action.output_type);
    output.raw(",");
    output.jsonString("invariants");
    output.raw(":");
    appendCsvArray(output, scenario.invariants);

    switch (scenario.kind) {
        .load => {
            output.raw(",");
            output.jsonString("repetitions");
            output.raw(":");
            output.number(config.load_repetitions);
            output.raw(",");
            output.jsonString("max_events");
            output.raw(":");
            output.number(config.load_max_events);
            output.raw(",");
            output.key("settlement", "idempotent-replay");
        },
        .stress => {
            output.raw(",");
            output.jsonString("workers");
            output.raw(":");
            output.number(config.stress_workers);
            output.raw(",");
            output.jsonString("duration_ms");
            output.raw(":");
            output.number(config.stress_duration_ms);
            output.raw(",");
            output.jsonString("max_failures");
            output.raw(":");
            output.number(config.stress_max_failures);
            output.raw(",");
            output.key("scheduling", "bounded-fairness");
        },
        .chaos => {
            output.raw(",");
            output.jsonString("faults");
            output.raw(":");
            appendCsvArray(output, config.chaos_faults);
            output.raw(",");
            output.key("recovery", config.chaos_recovery);
            output.raw(",");
            output.jsonString("replay_required");
            output.raw(":");
            output.boolean(true);
        },
        .security => {
            output.raw(",");
            output.jsonString("capabilities");
            output.raw(":");
            appendCsvArray(output, config.security_capabilities);
            output.raw(",");
            output.jsonString("denials");
            output.raw(":");
            appendCsvArray(output, config.security_denials);
            output.raw(",");
            output.key("secret_handling", "never-export");
            output.raw(",");
            output.key("terminal_authority", "runtime-owned");
        },
        else => @compileError("unsupported configured scenario"),
    }
    output.raw("}");
}

pub fn compile(comptime declaration_source: []const u8, comptime yaml_source: []const u8) Buffer {
    @setEvalBranchQuota(250_000);
    const declaration = parseDeclaration(declaration_source);
    const config = parseYaml(yaml_source);
    validate(declaration, config);

    var output = Buffer{};
    output.raw("{");
    output.key("schema", "test.bundle.v1");
    output.raw(",");
    output.key("type_system", "semantic-atomicbehavior");
    output.raw(",");
    output.key("suite", config.suite);
    output.raw(",");
    output.key("agent", config.agent);
    output.raw(",");
    output.key("intent", config.intent);
    output.raw(",");
    output.jsonString("semantic_types");
    output.raw(":[");
    var first_type = true;
    for (declaration.types[0..declaration.type_count]) |semantic_type| {
        output.comma(&first_type);
        output.raw("{");
        output.key("name", semantic_type.name);
        output.raw(",");
        output.key("category", semantic_type.category);
        output.raw(",");
        output.key("meaning", semantic_type.meaning);
        output.raw("}");
    }
    output.raw("],");
    output.jsonString("tests");
    output.raw(":[");
    var first = true;

    for (declaration.actions[0..declaration.action_count]) |action| {
        output.comma(&first);
        appendDynamicContract(&output, action, config);
        output.raw(",");
        appendBenchmark(&output, action, config);
    }
    for (declaration.scenarios[0..declaration.scenario_count]) |scenario| {
        output.comma(&first);
        const action = findAction(declaration, scenario.action) orelse @compileError("scenario references an undeclared action");
        appendScenario(&output, scenario, action, config);
    }

    output.raw("]}");
    return output;
}
