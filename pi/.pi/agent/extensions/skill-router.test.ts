/**
 * skill-router.test.ts — repo-local tests for skill-router extension.
 *
 * Run: npx tsx --test pi/.pi/agent/extensions/skill-router.test.ts
 *
 * Tests exercise the pure functions exported from skill-router.ts against
 * synthetic vectors. Entry shapes match Pi 0.84.2's session-manager.js:
 *
 *   custom_message (appendCustomMessageEntry, ~L866):
 *     { type: "custom_message", customType, content, display, details,
 *       id, parentId, timestamp }
 *
 *   custom (appendCustomEntry, ~L820):
 *     { type: "custom", customType, data, id, parentId, timestamp }
 *
 *   message (appendMessage, ~L766):
 *     { type: "message", id, parentId, timestamp,
 *       message: { role, content: [{ type, ... }] } }
 *
 *   compaction (appendCompaction, ~L803):
 *     { type: "compaction", summary, firstKeptEntryId, tokensBefore,
 *       id, parentId, timestamp }
 *
 * Tool calls inside assistant messages use:
 *     { type: "toolCall", id, name, arguments: { path: "..." } }
 *
 * User message content blocks use:
 *     { type: "text", text: "..." }
 */

import { describe, it } from "node:test";
import * as assert from "node:assert/strict";
import skillRouter, {
  parseFrontmatter,
  buildNameRegex,
  isExplicitTurn,
  scorePrompt,
  selectSkills,
  selectSkillsWithKev,
  skillsInContext,
  formatSkillMessage,
  buildNamesOnlyList,
  replaceSkillsBlock,
  getContextEntries,
  loadCatalog,
  loadConfig,
  expandTilde,
  queryKev,
  queryKevWithState,
  kevThenRules,
  routeDispatchTasks,
  validateDeciderUrl,
  ENFORCER,
  _setConfig,
  _getConfig,
  SCORE_NAMED,
  SCORE_ENFORCER,
  CUSTOM_TYPE,
  DECISION_ENTRY,
  type CatalogEntry,
  type RouterConfig,
} from "./skill-router.ts";

// ── Entry builders (Pi 0.84.2 shapes) ──────────────────────────────

let _nextId = 1;
function nextId(): string { return `test-${_nextId++}`; }

/** Router injection as persisted by appendCustomMessageEntry */
function makeRouterInjection(skillNames: string[], parentId?: string): any {
  const content = skillNames
    .map((n) => `<skill name="${n}" location="/path/to/${n}/SKILL.md">\nSkill body for ${n}\n</skill>`)
    .join("\n\n");
  const id = nextId();
  return {
    type: "custom_message",
    customType: CUSTOM_TYPE,
    content,
    display: false,
    details: undefined,
    id,
    parentId: parentId ?? nextId(),
    timestamp: new Date().toISOString(),
  };
}

/** Decision entry as persisted by pi.appendEntry (appendCustomEntry) */
function makeDecisionEntry(injected: string[], parentId?: string): any {
  const id = nextId();
  return {
    type: "custom",
    customType: DECISION_ENTRY,
    data: { hits: {}, inContext: [], injected, explicit: false },
    id,
    parentId: parentId ?? nextId(),
    timestamp: new Date().toISOString(),
  };
}

/** User message entry as persisted by appendMessage */
function makeUserMessage(text: string, parentId?: string): any {
  const id = nextId();
  return {
    type: "message",
    id,
    parentId: parentId ?? nextId(),
    timestamp: new Date().toISOString(),
    message: {
      role: "user",
      content: [{ type: "text", text }],
    },
  };
}

/** Assistant message with a tool call to read a file */
function makeToolCallMessage(toolName: string, path: string, parentId?: string): any {
  const id = nextId();
  return {
    type: "message",
    id,
    parentId: parentId ?? nextId(),
    timestamp: new Date().toISOString(),
    message: {
      role: "assistant",
      content: [
        {
          type: "toolCall",
          id: `tooluse_${nextId()}`,
          name: toolName,
          arguments: { path },
        },
      ],
    },
  };
}

/** Compaction entry as persisted by appendCompaction */
function makeCompaction(firstKeptEntryId: string, parentId?: string): any {
  const id = nextId();
  return {
    type: "compaction",
    summary: "Session compacted.",
    firstKeptEntryId,
    tokensBefore: 50000,
    id,
    parentId: parentId ?? nextId(),
    timestamp: new Date().toISOString(),
  };
}

// ── Catalog loading ─────────────────────────────────────────────────

describe("loadCatalog", () => {
  it("loads at least 40 skills from skill-profiles/all", () => {
    const catalog = loadCatalog();
    assert.ok(catalog.size >= 40, `Expected ≥40 skills, got ${catalog.size}`);
  });

  it("each entry has name, description, location, body", () => {
    const catalog = loadCatalog();
    for (const [name, entry] of catalog) {
      assert.equal(entry.name, name);
      assert.ok(entry.location.endsWith("SKILL.md"), `${name} location`);
      assert.ok(entry.body.length > 0, `${name} has body`);
    }
  });
});

// ── Frontmatter parsing ─────────────────────────────────────────────

describe("parseFrontmatter", () => {
  it("parses quoted string", () => {
    const text = '---\nname: "git-commit"\ndescription: "Commit authoring"\n---\n# Hi\n';
    assert.equal(parseFrontmatter(text, "name"), "git-commit");
    assert.equal(parseFrontmatter(text, "description"), "Commit authoring");
  });

  it("parses unquoted string", () => {
    const text = "---\nname: git-commit\n---\n# Hi\n";
    assert.equal(parseFrontmatter(text, "name"), "git-commit");
  });

  it("parses block scalar >", () => {
    const text = "---\ndescription: >\n  First line\n  second line\n---\n# Hi\n";
    assert.equal(parseFrontmatter(text, "description"), "First line second line");
  });

  it("parses block scalar |", () => {
    const text = "---\ndescription: |\n  Line one\n  Line two\n---\n# Hi\n";
    assert.equal(parseFrontmatter(text, "description"), "Line one\nLine two");
  });

  it("returns empty for missing key", () => {
    const text = "---\nname: foo\n---\n# Hi\n";
    assert.equal(parseFrontmatter(text, "description"), "");
  });
});

// ── Named-skill regex ───────────────────────────────────────────────

describe("buildNameRegex", () => {
  it("matches exact name", () => {
    const re = buildNameRegex("git-pr");
    assert.ok(re.test("open a git-pr"));
    assert.ok(re.test("use git pr please"));
  });

  it("matches /skill:name form", () => {
    const re = buildNameRegex("git-commit");
    assert.ok(re.test("/skill:git-commit"));
    assert.ok(re.test("use /git-commit"));
  });

  it("does not match as substring of longer name", () => {
    const re = buildNameRegex("nix");
    assert.ok(!re.test("nix-darwin"), "should not match nix-darwin");
    assert.ok(!re.test("nix-packaging"), "should not match nix-packaging");
    assert.ok(re.test("use nix for this"));
  });

  it("handles special regex characters", () => {
    const re = buildNameRegex("test-design");
    assert.ok(re.test("load test-design"));
    assert.ok(re.test("load test design"));
  });
});

// ── Explicit turn detection ─────────────────────────────────────────

describe("isExplicitTurn", () => {
  const names = new Set(["git-commit", "nix", "brainstorm"]);

  it("detects <skill tag", () => {
    assert.ok(isExplicitTurn('<skill name="git-commit">', names));
  });

  it("detects SKILL.md mention", () => {
    assert.ok(isExplicitTurn("read the SKILL.md file", names));
  });

  it("detects /skill: prefix", () => {
    assert.ok(isExplicitTurn("/skill:git-commit", names));
  });

  it("detects first word as catalog name", () => {
    assert.ok(isExplicitTurn("brainstorm about this idea", names));
    assert.ok(isExplicitTurn("/brainstorm about this idea", names));
  });

  it("does not flag normal prompts", () => {
    assert.ok(!isExplicitTurn("help me commit my changes", names));
  });
});

// ── Scoring ─────────────────────────────────────────────────────────

describe("scorePrompt", () => {
  const names = [
    "anyscale", "api-design", "brainstorm", "code-reviewer", "docker",
    "git-commit", "git-pr", "nix", "python-design", "software-design",
    "test-design", "test-driven-development",
  ];

  it("named-skill match scores 1.0", () => {
    const scores = scorePrompt("use the git-commit skill", names);
    assert.equal(scores.get("git-commit"), SCORE_NAMED);
  });

  it("enforcer pattern match scores 0.75", () => {
    const scores = scorePrompt("help me commit my changes", names);
    assert.equal(scores.get("git-commit"), SCORE_ENFORCER);
  });

  it("named-skill overrides enforcer (keeps 1.0)", () => {
    const scores = scorePrompt("follow git-commit and commit changes", names);
    assert.equal(scores.get("git-commit"), SCORE_NAMED);
  });

  it("multiple skills can match", () => {
    const scores = scorePrompt("write python test coverage", names);
    assert.ok(scores.has("python-design"), "python-design");
    assert.ok(scores.has("test-design"), "test-design");
  });

  it("returns empty for unrelated prompt", () => {
    const scores = scorePrompt("what is the weather today?", names);
    assert.equal(scores.size, 0);
  });
});

// ── Selection ───────────────────────────────────────────────────────

describe("selectSkills", () => {
  it("returns top 2 by score desc, name desc", () => {
    const scores = new Map([
      ["alpha", 0.75],
      ["beta", 0.75],
      ["gamma", 1.0],
    ]);
    const result = selectSkills(scores, new Set());
    assert.deepEqual(
      result.map((s) => s.name),
      ["gamma", "beta"],
    );
  });

  it("drops skills already in context", () => {
    const scores = new Map([
      ["git-commit", 1.0],
      ["software-design", 0.75],
    ]);
    const result = selectSkills(scores, new Set(["git-commit"]));
    assert.equal(result.length, 1);
    assert.equal(result[0].name, "software-design");
  });

  it("drops skills below threshold", () => {
    const scores = new Map([["alpha", 0.3]]);
    const result = selectSkills(scores, new Set());
    assert.equal(result.length, 0);
  });

  it("caps at 2", () => {
    const scores = new Map([
      ["a", 1.0], ["b", 1.0], ["c", 1.0],
    ]);
    const result = selectSkills(scores, new Set());
    assert.equal(result.length, 2);
  });
});

// ── In-context detection (Pi 0.84.2 entry shapes) ──────────────────

describe("skillsInContext", () => {
  it("detects router custom_message entries via <skill> tags in content", () => {
    const entries = [makeRouterInjection(["git-commit", "nix"])];
    const result = skillsInContext(entries);
    assert.ok(result.has("git-commit"));
    assert.ok(result.has("nix"));
  });

  it("ignores decision entries (type custom, not custom_message)", () => {
    // Decision entries are metadata, not context; must not trigger dedup
    const entries = [makeDecisionEntry(["git-commit", "nix"])];
    const result = skillsInContext(entries);
    assert.ok(!result.has("git-commit"), "decision entry should not count as in-context");
    assert.ok(!result.has("nix"), "decision entry should not count as in-context");
  });

  it("detects SKILL.md read tool calls in assistant messages", () => {
    const entries = [
      makeToolCallMessage("read", "/Users/me/.pi/agent/skill-profiles/all/docker/SKILL.md"),
    ];
    const result = skillsInContext(entries);
    assert.ok(result.has("docker"));
  });

  it("detects /skill expansions in user messages", () => {
    const entries = [
      makeUserMessage('/skill:python-design loaded\n<skill name="python-design" location="...">...</skill>'),
    ];
    const result = skillsInContext(entries);
    assert.ok(result.has("python-design"));
  });

  it("handles empty and null entries", () => {
    const result = skillsInContext([null, undefined, {}]);
    assert.equal(result.size, 0);
  });

  it("ignores entries with wrong type field", () => {
    // Old test shape (type: "custom" + customType: "skill-router") must not match
    const entries = [
      { type: "custom", customType: CUSTOM_TYPE, data: { injected: ["git-commit"] } },
    ];
    const result = skillsInContext(entries);
    assert.ok(!result.has("git-commit"), "type 'custom' with skill-router customType is a decision shape, not injection");
  });
});

// ── Injection format ────────────────────────────────────────────────

describe("formatSkillMessage", () => {
  it("produces Pi /skill format", () => {
    const entry: CatalogEntry = {
      name: "test-skill",
      description: "A test skill",
      location: "/path/to/test-skill/SKILL.md",
      body: "---\nname: test-skill\n---\n# Test\nContent here.",
    };
    const msg = formatSkillMessage(entry);
    assert.ok(msg.startsWith('<skill name="test-skill"'));
    assert.ok(msg.includes("location=\"/path/to/test-skill/SKILL.md\""));
    assert.ok(msg.includes("References are relative to /path/to/test-skill."));
    assert.ok(msg.includes("Content here."));
    assert.ok(msg.endsWith("</skill>"));
  });
});

// ── Names-only list ─────────────────────────────────────────────────

describe("buildNamesOnlyList", () => {
  it("produces a text block with all catalog names", () => {
    const catalog = loadCatalog();
    const block = buildNamesOnlyList(catalog);
    assert.ok(block.includes("Skills under"));
    assert.ok(block.includes("/<name>/SKILL.md:"));
    for (const name of catalog.keys()) {
      assert.ok(block.includes(name), `missing ${name}`);
    }
  });

  it("does not include descriptions", () => {
    const catalog = loadCatalog();
    const block = buildNamesOnlyList(catalog);
    assert.ok(!block.includes("<description>"), "no XML description tags");
  });
});

// ── System prompt transform ─────────────────────────────────────────

describe("replaceSkillsBlock", () => {
  it("replaces verbose <available_skills> block", () => {
    const verbose = [
      "Base prompt here.",
      "\n\nThe following skills provide specialized instructions for specific tasks.",
      "Use the read tool to load a skill's file when the task matches its description.",
      "When a skill file references a relative path, resolve it against the skill directory.",
      "",
      "<available_skills>",
      '  <skill><name>git-commit</name><description>Commits</description><location>/path</location></skill>',
      "</available_skills>",
    ].join("\n");
    const catalog = loadCatalog();
    const namesBlock = buildNamesOnlyList(catalog);
    const result = replaceSkillsBlock(verbose, namesBlock);
    assert.ok(!result.includes("<available_skills>"), "XML removed");
    assert.ok(result.includes("Skills under"), "names-only present");
    assert.ok(result.startsWith("Base prompt here."), "base preserved");
  });

  it("replaces compressed 'Skills under' form", () => {
    const compressed = [
      "Base prompt here.",
      "\n\nThe following skills provide specialized instructions for specific tasks. When a skill name matches the task you are doing, read the SKILL.md.",
      "",
      "Skills under /root/<name>/SKILL.md:",
      "  git-commit, nix, python-design",
    ].join("\n");
    const catalog = loadCatalog();
    const namesBlock = buildNamesOnlyList(catalog);
    const result = replaceSkillsBlock(compressed, namesBlock);
    assert.ok(!result.includes("/root/<name>/SKILL.md"), "old list gone");
    assert.ok(result.includes("Skills under"), "new list present");
    assert.ok(result.startsWith("Base prompt here."), "base preserved");
  });

  it("appends when no skill block found", () => {
    const prompt = "Just a plain prompt.";
    const catalog = loadCatalog();
    const namesBlock = buildNamesOnlyList(catalog);
    const result = replaceSkillsBlock(prompt, namesBlock);
    assert.ok(result.startsWith("Just a plain prompt."));
    assert.ok(result.includes("Skills under"));
  });
});

// ── Enforcer parity ─────────────────────────────────────────────────

describe("ENFORCER patterns", () => {
  it("has exactly 10 patterns matching run_models.py ENFORCER", () => {
    assert.equal(ENFORCER.length, 10);
  });

  it("maps to the same skill names", () => {
    const expected = [
      "git-commit", "git-pr", "software-design", "test-design",
      "docker", "helm", "nix", "python-design", "api-design", "code-reviewer",
    ];
    assert.deepEqual(ENFORCER.map((e) => e.skill), expected);
  });

  it("enforcer pattern for a skill absent from a synthetic catalog produces no hit", () => {
    // Use a synthetic catalog that deliberately omits "helm" to test that
    // enforcer patterns only fire for skills present in the catalog.
    const syntheticNames = ["git-commit", "git-pr", "nix", "docker"];
    const scores = scorePrompt("Build a helm chart for the microservice", syntheticNames);
    assert.ok(!scores.has("helm"), "helm absent from catalog → no hit");
    assert.ok(ENFORCER.some((e) => e.skill === "helm"), "helm enforcer pattern should exist");
  });
});

// ── Synthetic test vectors ──────────────────────────────────────────

interface TestVector {
  prompt: string;
  expectedHits: Record<string, number>;
  explicit?: boolean;
}

const SYNTHETIC_VECTORS: TestVector[] = [
  // Named-skill matches (score 1.0)
  {
    prompt: "Load the git-commit skill and follow it",
    expectedHits: { "git-commit": 1.0 },
  },
  {
    prompt: "Can you use the nix skill to fix my config?",
    expectedHits: { nix: 1.0 },
  },
  {
    prompt: "Follow the api-design skill for this endpoint",
    expectedHits: { "api-design": 1.0, "software-design": 0.75 },
  },
  {
    prompt: "Use the code-reviewer and software-design skills",
    expectedHits: { "code-reviewer": 1.0, "software-design": 1.0 },
  },
  {
    prompt: "Apply git pr conventions here",
    expectedHits: { "git-pr": 1.0 },
  },
  // Enforcer-only matches (score 0.75)
  {
    prompt: "Help me commit my changes and push",
    expectedHits: { "git-commit": 0.75 },
  },
  {
    prompt: "Write a test for the parser module",
    expectedHits: { "test-design": 0.75 },
  },
  {
    prompt: "Refactor this module into smaller functions",
    expectedHits: { "software-design": 0.75 },
  },
  {
    prompt: "Create a Dockerfile for this service",
    expectedHits: { docker: 0.75 },
  },
  {
    prompt: "Fix the nix-darwin configuration",
    expectedHits: { nix: 0.75 },
  },
  {
    prompt: "Review the diff in this PR",
    expectedHits: { "code-reviewer": 0.75 },
  },
  {
    prompt: "Add a pytest fixture for database setup",
    expectedHits: { "python-design": 0.75, "test-design": 0.75 },
  },
  {
    prompt: "Design a REST API for user management",
    expectedHits: { "api-design": 0.75, "software-design": 0.75 },
  },
  {
    prompt: "Create a pull request for the feature branch",
    expectedHits: { "git-pr": 0.75 },
  },
  {
    prompt: "Build a helm chart for the microservice",
    expectedHits: { helm: 1.0 },  // helm is now in catalog; named + enforcer match
  },
  // Named overrides enforcer
  {
    prompt: "Use python-design to write python code",
    expectedHits: { "python-design": 1.0, "software-design": 0.75 },
  },
  // No matches
  {
    prompt: "What is the weather today?",
    expectedHits: {},
  },
  {
    prompt: "Tell me a joke",
    expectedHits: {},
  },
  // Explicit turns — routing is skipped
  {
    prompt: '/skill:git-commit please follow it',
    explicit: true,
    expectedHits: {},
  },
  {
    prompt: '<skill name="nix">content</skill>',
    explicit: true,
    expectedHits: {},
  },
  {
    prompt: "Read the SKILL.md for docker",
    explicit: true,
    expectedHits: {},
  },
  {
    prompt: "brainstorm about API patterns",
    explicit: true,
    expectedHits: {},
  },
  // Named-skill with hyphen-space equivalence
  {
    prompt: "use test design for this",
    expectedHits: { "test-design": 1.0, "software-design": 0.75 },
  },
];

describe("synthetic vectors", () => {
  // Fixed catalog name list so this test does not depend on the live catalog
  const names = [
    "anyscale", "api-design", "brainstorm", "code-reviewer", "docker",
    "git-commit", "git-pr", "helm", "nix", "python-design",
    "software-design", "test-design", "test-driven-development",
  ];
  const nameSet = new Set(names);

  for (const vec of SYNTHETIC_VECTORS) {
    it(`"${vec.prompt.slice(0, 60)}..."`, () => {
      const explicit = isExplicitTurn(vec.prompt.slice(0, 2000), nameSet);

      if (vec.explicit) {
        assert.ok(explicit, "should be detected as explicit");
        return;
      }

      assert.ok(!explicit, "should not be explicit");

      const scores = scorePrompt(vec.prompt, names);
      // Only check catalog skills in expected hits
      for (const [name, expectedScore] of Object.entries(vec.expectedHits)) {
        if (!nameSet.has(name)) continue;
        assert.equal(
          scores.get(name),
          expectedScore,
          `${name} should score ${expectedScore}, got ${scores.get(name) ?? 0}`,
        );
      }
      // Check no unexpected hits
      for (const [name, score] of scores) {
        if (!(name in vec.expectedHits)) {
          assert.fail(`unexpected hit: ${name} = ${score}`);
        }
      }
    });
  }
});

// ── Dedup across turns (Pi entry shapes) ────────────────────────────

describe("dedup across turns", () => {
  it("skill injected on turn 1 is not re-injected on turn 2", () => {
    const catalog = loadCatalog();
    const names = [...catalog.keys()];

    // Turn 1: git-commit scores and gets injected
    const scores1 = scorePrompt("commit my changes", names);
    const inContext1 = new Set<string>();
    const inject1 = selectSkills(scores1, inContext1);
    assert.ok(inject1.some((s) => s.name === "git-commit"), "turn 1 injects git-commit");

    // Turn 2: same prompt, but session now contains the router injection entry
    const entries = [makeRouterInjection(["git-commit"])];
    const inContext2 = skillsInContext(entries);
    assert.ok(inContext2.has("git-commit"), "injection detected in context");
    const scores2 = scorePrompt("commit my changes", names);
    const inject2 = selectSkills(scores2, inContext2);
    assert.ok(!inject2.some((s) => s.name === "git-commit"), "turn 2 does not re-inject");
  });

  it("re-injects after compaction removes the injection entry", () => {
    // Simulate: injection at id "inj-1", then compaction with firstKeptEntryId
    // after the injection. buildContextEntries would exclude the injection.
    // We simulate the post-compaction context by only including entries after the cut.
    const postCompactionUser = makeUserMessage("commit my changes");
    // After compaction, only the compaction summary and post-compaction entries remain.
    // The injection entry is gone from context.
    const entries = [postCompactionUser];
    const inContext = skillsInContext(entries);
    assert.ok(!inContext.has("git-commit"), "git-commit not in context after compaction");

    // So it should be re-injected
    const catalog = loadCatalog();
    const names = [...catalog.keys()];
    const scores = scorePrompt("commit my changes", names);
    const inject = selectSkills(scores, inContext);
    assert.ok(inject.some((s) => s.name === "git-commit"), "re-injects after compaction");
  });

  it("deduplicates against a SKILL.md read by the model", () => {
    const entries = [
      makeToolCallMessage("read", "/Users/me/.pi/agent/skill-profiles/all/git-commit/SKILL.md"),
    ];
    const inContext = skillsInContext(entries);
    assert.ok(inContext.has("git-commit"), "SKILL.md read detected");

    const catalog = loadCatalog();
    const names = [...catalog.keys()];
    const scores = scorePrompt("commit my changes", names);
    const inject = selectSkills(scores, inContext);
    assert.ok(!inject.some((s) => s.name === "git-commit"), "no re-inject after SKILL.md read");
  });

  it("deduplicates against explicit /skill turns", () => {
    const entries = [
      makeUserMessage('/skill:docker loaded\n<skill name="docker" location="...">body</skill>'),
    ];
    const inContext = skillsInContext(entries);
    assert.ok(inContext.has("docker"), "/skill:docker detected in user message");
  });
});

// ── Commit gate (Pi entry shapes) ───────────────────────────────────

describe("commit gate", () => {
  it("injected git-commit satisfies the gate", () => {
    const entries = [makeRouterInjection(["git-commit"])];
    const inContext = skillsInContext(entries);
    assert.ok(inContext.has("git-commit"), "git-commit should be in context");
  });

  it("SKILL.md read satisfies the gate", () => {
    const entries = [
      makeToolCallMessage("read", "/Users/me/.pi/agent/skill-profiles/all/git-commit/SKILL.md"),
    ];
    const inContext = skillsInContext(entries);
    assert.ok(inContext.has("git-commit"));
  });

  it("empty session blocks commit", () => {
    const entries: any[] = [];
    const inContext = skillsInContext(entries);
    assert.ok(!inContext.has("git-commit"), "empty session has no git-commit");
  });

  it("unrelated skills do not satisfy gate", () => {
    const entries = [makeRouterInjection(["nix", "docker"])];
    const inContext = skillsInContext(entries);
    assert.ok(!inContext.has("git-commit"), "unrelated skills don't satisfy gate");
  });
});

// ── Commit gate integration (mock Pi API) ───────────────────────────

describe("commit gate integration", () => {
  it("allows commit when git-commit is in context entries", async () => {
    const handlers: Record<string, Function> = {};
    const mockPi = {
      on(event: string, handler: Function) { handlers[event] = handler; },
      appendEntry() {},
    };
    skillRouter(mockPi as any);

    const toolHandler = handlers["tool_call"];
    assert.ok(toolHandler, "tool_call handler registered");

    const event = { toolName: "bash", input: { command: "git commit -m 'test'" } };
    const ctx = {
      sessionManager: {
        buildContextEntries() {
          return [makeRouterInjection(["git-commit"])];
        },
      },
    };
    const result = await toolHandler(event, ctx);
    assert.equal(result, undefined, "commit should be allowed");
  });

  it("blocks commit when git-commit is absent from context", async () => {
    const handlers: Record<string, Function> = {};
    const mockPi = {
      on(event: string, handler: Function) { handlers[event] = handler; },
      appendEntry() {},
    };
    skillRouter(mockPi as any);

    const toolHandler = handlers["tool_call"];
    const event = { toolName: "bash", input: { command: "git commit -m 'test'" } };
    const ctx = {
      sessionManager: {
        buildContextEntries() {
          return [makeRouterInjection(["nix"])];
        },
      },
    };
    const result = await toolHandler(event, ctx);
    assert.ok(result?.block, "commit should be blocked");
    assert.ok(result.reason.includes("Load skill:git-commit"), `reason: ${result.reason}`);
  });

  it("blocks commit when session manager throws", async () => {
    const handlers: Record<string, Function> = {};
    const mockPi = {
      on(event: string, handler: Function) { handlers[event] = handler; },
      appendEntry() {},
    };
    skillRouter(mockPi as any);

    const toolHandler = handlers["tool_call"];
    const event = { toolName: "bash", input: { command: "git commit -m 'test'" } };
    const ctx = {
      sessionManager: {
        buildContextEntries() { throw new Error("session unavailable"); },
      },
    };
    const result = await toolHandler(event, ctx);
    assert.ok(result?.block, "commit should be blocked");
    assert.ok(result.reason.includes("Cannot verify"), `reason: ${result.reason}`);
  });

  it("blocks commit when session manager is absent", async () => {
    const handlers: Record<string, Function> = {};
    const mockPi = {
      on(event: string, handler: Function) { handlers[event] = handler; },
      appendEntry() {},
    };
    skillRouter(mockPi as any);

    const toolHandler = handlers["tool_call"];
    const event = { toolName: "bash", input: { command: "git commit -m 'test'" } };
    const ctx = {};
    const result = await toolHandler(event, ctx);
    assert.ok(result?.block, "commit should be blocked");
    assert.ok(result.reason.includes("Load skill:git-commit"), `reason: ${result.reason}`);
  });
});

// ── getContextEntries ───────────────────────────────────────────────

describe("getContextEntries", () => {
  it("prefers buildContextEntries over getBranch", () => {
    const ctx = {
      sessionManager: {
        buildContextEntries() { return [{ marker: "compaction-aware" }]; },
        getBranch() { return [{ marker: "full-branch" }]; },
      },
    };
    const entries = getContextEntries(ctx);
    assert.equal((entries[0] as any).marker, "compaction-aware");
  });

  it("falls back to getBranch", () => {
    const ctx = {
      sessionManager: {
        getBranch() { return [{ marker: "full-branch" }]; },
      },
    };
    const entries = getContextEntries(ctx);
    assert.equal((entries[0] as any).marker, "full-branch");
  });

  it("returns empty when no session manager", () => {
    const entries = getContextEntries({});
    assert.equal(entries.length, 0);
  });
});

// ── Kev filter tests (ephemeral HTTP server) ────────────────────────

import { createServer, type Server, type IncomingMessage, type ServerResponse } from "node:http";


function startKevServer(
  handler: (req: IncomingMessage, res: ServerResponse, body: string) => void,
): Promise<{ server: Server; port: number }> {
  return new Promise((resolve) => {
    const server = createServer((req, res) => {
      let body = "";
      req.on("data", (chunk: Buffer) => { body += chunk.toString(); });
      req.on("end", () => handler(req, res, body));
    });
    server.listen(0, "127.0.0.1", () => {
      const addr = server.address() as any;
      resolve({ server, port: addr.port });
    });
  });
}

function makeCfg(port: number, overrides?: Partial<RouterConfig["decider"]> & { maxSkillsPerTurn?: number; mode?: RouterConfig["mode"] }): RouterConfig {
  return {
    mode: overrides?.mode ?? "inject",
    decider: {
      url: `http://127.0.0.1:${port}`,
      model: "test-model",
      timeoutMs: overrides?.timeoutMs ?? 2000,
      threshold: overrides?.threshold ?? 0.30,
      apiKeyEnv: overrides?.apiKeyEnv ?? null,
    },
    catalog: "~/.pi/agent/skill-profiles/all",
    maxSkillsPerTurn: overrides?.maxSkillsPerTurn ?? 2,
  };
}

describe("queryKev", () => {
  it("returns probs from a successful response", async () => {
    const { server, port } = await startKevServer((_req, res, body) => {
      const parsed = JSON.parse(body);
      const answers: Record<string, any> = {};
      for (const name of Object.keys(parsed.questions)) {
        answers[name] = { type: "noul", noul: 0.85 };
      }
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ answers }));
    });
    try {
      const hits = new Map([["git-commit", 0.75], ["nix", 1.0]]);
      const catalog = loadCatalog();
      const cfg = makeCfg(port);
      const result = await queryKev(hits, catalog, "commit my nix changes", cfg);
      assert.ok(result.ok);
      assert.equal(result.probs["git-commit"], 0.85);
      assert.equal(result.probs["nix"], 0.85);
    } finally { server.close(); }
  });

  it("throws on HTTP 500", async () => {
    const { server, port } = await startKevServer((_req, res) => {
      res.writeHead(500);
      res.end("error");
    });
    try {
      const hits = new Map([["git-commit", 0.75]]);
      const catalog = loadCatalog();
      const cfg = makeCfg(port);
      await assert.rejects(() => queryKev(hits, catalog, "commit", cfg), /HTTP 500/);
    } finally { server.close(); }
  });

  it("throws on malformed body (missing answers)", async () => {
    const { server, port } = await startKevServer((_req, res) => {
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ wrong: true }));
    });
    try {
      const hits = new Map([["git-commit", 0.75]]);
      const catalog = loadCatalog();
      const cfg = makeCfg(port);
      await assert.rejects(() => queryKev(hits, catalog, "commit", cfg), /malformed/);
    } finally { server.close(); }
  });

  it("throws on missing noul for a hit", async () => {
    const { server, port } = await startKevServer((_req, res) => {
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ answers: { "git-commit": { type: "noul" } } }));
    });
    try {
      const hits = new Map([["git-commit", 0.75]]);
      const catalog = loadCatalog();
      const cfg = makeCfg(port);
      await assert.rejects(() => queryKev(hits, catalog, "commit", cfg), /invalid noul/);
    } finally { server.close(); }
  });

  it("sends bearer header when apiKeyEnv is set", async () => {
    let authHeader: string | undefined;
    const { server, port } = await startKevServer((req, res, body) => {
      authHeader = req.headers["authorization"] as string;
      const parsed = JSON.parse(body);
      const answers: Record<string, any> = {};
      for (const name of Object.keys(parsed.questions)) {
        answers[name] = { type: "noul", noul: 0.5 };
      }
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ answers }));
    });
    const envKey = "__SKILL_ROUTER_TEST_KEY";
    process.env[envKey] = "test-secret-123";
    try {
      const hits = new Map([["git-commit", 0.75]]);
      const catalog = loadCatalog();
      const cfg = makeCfg(port, { apiKeyEnv: envKey });
      await queryKev(hits, catalog, "commit", cfg);
      assert.equal(authHeader, "Bearer test-secret-123");
    } finally {
      delete process.env[envKey];
      server.close();
    }
  });

  it("times out on slow server", async () => {
    const { server, port } = await startKevServer((_req, _res) => {
      // Never respond — the timeout should fire first
    });
    try {
      const hits = new Map([["git-commit", 0.75]]);
      const catalog = loadCatalog();
      const cfg = makeCfg(port, { timeoutMs: 100 });
      await assert.rejects(() => queryKev(hits, catalog, "commit", cfg));
    } finally { server.close(); }
  });

  it("returns empty probs when no hits", async () => {
    const hits = new Map<string, number>();
    const catalog = loadCatalog();
    const cfg = makeCfg(9999); // bogus port; should not be called
    const result = await queryKev(hits, catalog, "hello", cfg);
    assert.ok(result.ok);
    assert.deepEqual(result.probs, {});
  });
});

// ── selectSkillsWithKev ─────────────────────────────────────────────

describe("selectSkillsWithKev", () => {
  it("keeps high-p and drops low-p hits", () => {
    const hitNames = new Set(["git-commit", "nix"]);
    const kevProbs = { "git-commit": 0.9, "nix": 0.1 };
    const result = selectSkillsWithKev(hitNames, kevProbs, new Set(), 0.3, 2);
    assert.equal(result.length, 1);
    assert.equal(result[0].name, "git-commit");
  });

  it("orders by score (1+p) desc then name desc", () => {
    const hitNames = new Set(["alpha", "beta", "gamma"]);
    const kevProbs = { alpha: 0.5, beta: 0.8, gamma: 0.8 };
    const result = selectSkillsWithKev(hitNames, kevProbs, new Set(), 0.3, 3);
    assert.deepEqual(result.map(s => s.name), ["gamma", "beta", "alpha"]);
  });

  it("caps at maxSkillsPerTurn", () => {
    const hitNames = new Set(["a", "b", "c"]);
    const kevProbs = { a: 0.9, b: 0.8, c: 0.7 };
    const result = selectSkillsWithKev(hitNames, kevProbs, new Set(), 0.3, 2);
    assert.equal(result.length, 2);
  });

  it("deduplicates against inContext", () => {
    const hitNames = new Set(["git-commit"]);
    const kevProbs = { "git-commit": 0.9 };
    const result = selectSkillsWithKev(hitNames, kevProbs, new Set(["git-commit"]), 0.3, 2);
    assert.equal(result.length, 0);
  });
});


// ── Integration: modes (inject / shadow / off) with Kev server ──────

describe("integration: inject mode with Kev", () => {
  it("inject mode keeps high-p, drops low-p, injects remaining", async () => {
    const { server, port } = await startKevServer((_req, res, body) => {
      const parsed = JSON.parse(body);
      const answers: Record<string, any> = {};
      for (const name of Object.keys(parsed.questions)) {
        answers[name] = { type: "noul", noul: name === "git-commit" ? 0.9 : 0.1 };
      }
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ answers }));
    });

    const handlers: Record<string, Function> = {};
    const appendedEntries: any[] = [];
    const mockPi = {
      on(event: string, handler: Function) { handlers[event] = handler; },
      appendEntry(type: string, data: any) { appendedEntries.push({ type, data }); },
    };
    skillRouter(mockPi as any);

    const saved = _getConfig();
    _setConfig(makeCfg(port));

    try {
      const event = { prompt: "commit my changes and refactor the module", systemPrompt: "Base prompt" };
      const ctx = { sessionManager: { buildContextEntries() { return []; } } };
      const result = await handlers["before_agent_start"](event, ctx);
      const decision = appendedEntries.find(e => e.type === DECISION_ENTRY);
      assert.ok(decision, "decision entry recorded");
      assert.equal(decision.data.kev, "ok");
      assert.ok(decision.data.injected.includes("git-commit"));
      assert.ok(!decision.data.injected.includes("software-design"));
    } finally {
      _setConfig(saved);
      server.close();
    }
  });
});

describe("integration: shadow mode", () => {
  it("logs decision with wouldInject but returns nothing", async () => {
    const { server, port } = await startKevServer((_req, res, body) => {
      const parsed = JSON.parse(body);
      const answers: Record<string, any> = {};
      for (const name of Object.keys(parsed.questions)) {
        answers[name] = { type: "noul", noul: 0.9 };
      }
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ answers }));
    });

    const handlers: Record<string, Function> = {};
    const appendedEntries: any[] = [];
    const mockPi = {
      on(event: string, handler: Function) { handlers[event] = handler; },
      appendEntry(type: string, data: any) { appendedEntries.push({ type, data }); },
    };
    skillRouter(mockPi as any);

    const saved = _getConfig();
    _setConfig(makeCfg(port, { mode: "shadow" }));

    try {
      const event = { prompt: "commit my changes", systemPrompt: "Base" };
      const ctx = { sessionManager: { buildContextEntries() { return []; } } };
      const result = await handlers["before_agent_start"](event, ctx);
      assert.equal(result, undefined, "shadow mode returns nothing");
      const decision = appendedEntries.find(e => e.type === DECISION_ENTRY);
      assert.ok(decision, "decision logged");
      assert.equal(decision.data.mode, "shadow");
      assert.ok(decision.data.wouldInject.length > 0, "wouldInject populated");
      assert.equal(decision.data.kev, "ok");
    } finally {
      _setConfig(saved);
      server.close();
    }
  });
});

describe("integration: off mode", () => {
  it("returns nothing from before_agent_start", async () => {
    const handlers: Record<string, Function> = {};
    const mockPi = {
      on(event: string, handler: Function) { handlers[event] = handler; },
      appendEntry() {},
    };
    skillRouter(mockPi as any);

    const saved = _getConfig();
    _setConfig({ ...saved, mode: "off" });
    try {
      const event = { prompt: "commit my changes", systemPrompt: "Base" };
      const ctx = { sessionManager: { buildContextEntries() { return []; } } };
      const result = await handlers["before_agent_start"](event, ctx);
      assert.equal(result, undefined, "off mode returns nothing");
    } finally {
      _setConfig(saved);
    }
  });
});

describe("integration: Kev failure fallback", () => {
  it("timeout falls back to rules-only", async () => {
    const { server, port } = await startKevServer((_req, res) => {
      // Never respond in time
      setTimeout(() => { res.writeHead(200); res.end("{}"); }, 5000);
    });

    const handlers: Record<string, Function> = {};
    const appendedEntries: any[] = [];
    const mockPi = {
      on(event: string, handler: Function) { handlers[event] = handler; },
      appendEntry(type: string, data: any) { appendedEntries.push({ type, data }); },
    };
    skillRouter(mockPi as any);

    const saved = _getConfig();
    _setConfig(makeCfg(port, { timeoutMs: 100 }));

    try {
      const event = { prompt: "commit my changes", systemPrompt: "Base" };
      const ctx = { sessionManager: { buildContextEntries() { return []; } } };
      const result = await handlers["before_agent_start"](event, ctx);
      const decision = appendedEntries.find(e => e.type === DECISION_ENTRY);
      assert.ok(decision, "decision recorded");
      assert.equal(decision.data.kev, "failed");
      // Should still inject via rules-only
      assert.ok(decision.data.injected.includes("git-commit"), "rules-only fallback injects git-commit");
    } finally {
      _setConfig(saved);
      server.close();
    }
  });

  it("HTTP 500 falls back to rules-only", async () => {
    const { server, port } = await startKevServer((_req, res) => {
      res.writeHead(500);
      res.end("error");
    });

    const handlers: Record<string, Function> = {};
    const appendedEntries: any[] = [];
    const mockPi = {
      on(event: string, handler: Function) { handlers[event] = handler; },
      appendEntry(type: string, data: any) { appendedEntries.push({ type, data }); },
    };
    skillRouter(mockPi as any);

    const saved = _getConfig();
    _setConfig(makeCfg(port));

    try {
      const event = { prompt: "commit my changes", systemPrompt: "Base" };
      const ctx = { sessionManager: { buildContextEntries() { return []; } } };
      await handlers["before_agent_start"](event, ctx);
      const decision = appendedEntries.find(e => e.type === DECISION_ENTRY);
      assert.equal(decision.data.kev, "failed");
      assert.ok(decision.data.injected.includes("git-commit"));
    } finally {
      _setConfig(saved);
      server.close();
    }
  });

  it("malformed body falls back to rules-only", async () => {
    const { server, port } = await startKevServer((_req, res) => {
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ nope: true }));
    });

    const handlers: Record<string, Function> = {};
    const appendedEntries: any[] = [];
    const mockPi = {
      on(event: string, handler: Function) { handlers[event] = handler; },
      appendEntry(type: string, data: any) { appendedEntries.push({ type, data }); },
    };
    skillRouter(mockPi as any);

    const saved = _getConfig();
    _setConfig(makeCfg(port));

    try {
      const event = { prompt: "commit my changes", systemPrompt: "Base" };
      const ctx = { sessionManager: { buildContextEntries() { return []; } } };
      await handlers["before_agent_start"](event, ctx);
      const decision = appendedEntries.find(e => e.type === DECISION_ENTRY);
      assert.equal(decision.data.kev, "failed");
    } finally {
      _setConfig(saved);
      server.close();
    }
  });
});

describe("integration: no Kev request when no rule hits", () => {
  it("does not call Kev when prompt has no matches", async () => {
    let requestCount = 0;
    const { server, port } = await startKevServer((_req, res) => {
      requestCount++;
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ answers: {} }));
    });

    const handlers: Record<string, Function> = {};
    const mockPi = {
      on(event: string, handler: Function) { handlers[event] = handler; },
      appendEntry() {},
    };
    skillRouter(mockPi as any);

    const saved = _getConfig();
    _setConfig(makeCfg(port));

    try {
      const event = { prompt: "what is the weather today?", systemPrompt: "Base" };
      const ctx = { sessionManager: { buildContextEntries() { return []; } } };
      await handlers["before_agent_start"](event, ctx);
      assert.equal(requestCount, 0, "no request to Kev when no rule hits");
    } finally {
      _setConfig(saved);
      server.close();
    }
  });
});

// ── URL validation ──────────────────────────────────────────────────

describe("validateDeciderUrl", () => {
  it("allows http to loopback", () => {
    const r = validateDeciderUrl("http://127.0.0.1:8008");
    assert.ok(r.ok);
    assert.ok(!r.disable);
    assert.equal(r.warn, undefined);
  });

  it("allows http to localhost", () => {
    const r = validateDeciderUrl("http://localhost:8008");
    assert.ok(r.ok);
    assert.ok(!r.disable);
  });

  it("allows http to ::1", () => {
    const r = validateDeciderUrl("http://[::1]:8008");
    assert.ok(r.ok);
    assert.ok(!r.disable);
  });

  it("rejects http to non-loopback", () => {
    const r = validateDeciderUrl("http://example.com:8008/v1");
    assert.ok(!r.ok);
    assert.ok(r.disable);
    assert.ok(r.warn?.includes("non-loopback"));
  });

  it("allows https to non-loopback with warning", () => {
    const r = validateDeciderUrl("https://kev.example.com/v1");
    assert.ok(r.ok);
    assert.ok(!r.disable);
    assert.ok(r.warn?.includes("leave the machine"));
  });

  it("allows https to loopback without warning", () => {
    const r = validateDeciderUrl("https://127.0.0.1:8443");
    assert.ok(r.ok);
    assert.ok(!r.disable);
    assert.equal(r.warn, undefined);
  });

  it("rejects non-http schemes", () => {
    const r = validateDeciderUrl("ftp://127.0.0.1:8008");
    assert.ok(!r.ok);
    assert.ok(r.disable);
    assert.ok(r.warn?.includes("not allowed"));
  });

  it("rejects invalid URLs", () => {
    const r = validateDeciderUrl("not-a-url");
    assert.ok(!r.ok);
    assert.ok(r.disable);
    assert.ok(r.warn?.includes("invalid URL"));
  });
});

// ── NaN noul guard ──────────────────────────────────────────────────

describe("queryKev NaN noul guard", () => {
  it("rejects NaN noul and falls back to rules-only", async () => {
    const { server, port } = await startKevServer((_req, res, body) => {
      const parsed = JSON.parse(body);
      const answers: Record<string, any> = {};
      for (const name of Object.keys(parsed.questions)) {
        answers[name] = { type: "noul", noul: NaN };
      }
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ answers }));
    });
    try {
      const hits = new Map([["git-commit", 0.75]]);
      const catalog = loadCatalog();
      const cfg = makeCfg(port);
      await assert.rejects(() => queryKev(hits, catalog, "commit", cfg), /invalid noul/);
    } finally { server.close(); }
  });

  it("rejects noul > 1", async () => {
    const { server, port } = await startKevServer((_req, res, body) => {
      const parsed = JSON.parse(body);
      const answers: Record<string, any> = {};
      for (const name of Object.keys(parsed.questions)) {
        answers[name] = { type: "noul", noul: 1.5 };
      }
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ answers }));
    });
    try {
      const hits = new Map([["git-commit", 0.75]]);
      const catalog = loadCatalog();
      const cfg = makeCfg(port);
      await assert.rejects(() => queryKev(hits, catalog, "commit", cfg), /invalid noul/);
    } finally { server.close(); }
  });

  it("rejects noul < 0", async () => {
    const { server, port } = await startKevServer((_req, res, body) => {
      const parsed = JSON.parse(body);
      const answers: Record<string, any> = {};
      for (const name of Object.keys(parsed.questions)) {
        answers[name] = { type: "noul", noul: -0.5 };
      }
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ answers }));
    });
    try {
      const hits = new Map([["git-commit", 0.75]]);
      const catalog = loadCatalog();
      const cfg = makeCfg(port);
      await assert.rejects(() => queryKev(hits, catalog, "commit", cfg), /invalid noul/);
    } finally { server.close(); }
  });

  it("rejects non-JSON 200 body", async () => {
    const { server, port } = await startKevServer((_req, res) => {
      res.writeHead(200, { "Content-Type": "text/plain" });
      res.end("this is not json");
    });
    try {
      const hits = new Map([["git-commit", 0.75]]);
      const catalog = loadCatalog();
      const cfg = makeCfg(port);
      await assert.rejects(() => queryKev(hits, catalog, "commit", cfg), /non-JSON/);
    } finally { server.close(); }
  });
});

// ── selectSkillsWithKev takes Set ───────────────────────────────────

describe("selectSkillsWithKev (Set interface)", () => {
  it("accepts a Set of hit names", () => {
    const hitNames = new Set(["git-commit", "nix"]);
    const kevProbs = { "git-commit": 0.9, "nix": 0.1 };
    const result = selectSkillsWithKev(hitNames, kevProbs, new Set(), 0.3, 2);
    assert.equal(result.length, 1);
    assert.equal(result[0].name, "git-commit");
  });
});

// ── Config parsing ──────────────────────────────────────────────────

describe("config parsing", () => {
  it("loadConfig returns a valid config object", () => {
    const cfg = loadConfig();
    assert.ok(["inject", "shadow", "off"].includes(cfg.mode));
    assert.ok(typeof cfg.decider.url === "string");
    assert.ok(typeof cfg.decider.model === "string");
    assert.ok(typeof cfg.decider.timeoutMs === "number");
    assert.ok(typeof cfg.decider.threshold === "number");
    assert.ok(typeof cfg.maxSkillsPerTurn === "number");
    assert.ok(typeof cfg.catalog === "string");
  });

  it("expandTilde replaces leading ~", () => {
    const home = process.env.HOME ?? "";
    assert.equal(expandTilde("~/foo/bar"), `${home}/foo/bar`);
    assert.equal(expandTilde("/absolute/path"), "/absolute/path");
    assert.equal(expandTilde("relative/path"), "relative/path");
  });
});

// ── Dispatch routing tests ──────────────────────────────────────────

describe("dispatch routing: Python design task gets python-design", () => {
  it("injects python-design (and software-design) into systemPrompt", async () => {
    const { server, port } = await startKevServer((_req, res, body) => {
      const parsed = JSON.parse(body);
      const answers: Record<string, any> = {};
      for (const name of Object.keys(parsed.questions)) {
        answers[name] = { type: "noul", noul: 0.9 };
      }
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ answers }));
    });

    const saved = _getConfig();
    _setConfig(makeCfg(port));
    const appendedEntries: any[] = [];
    const mockPi = {
      on() {},
      appendEntry(type: string, data: any) { appendedEntries.push({ type, data }); },
    };

    try {
      const catalog = loadCatalog();
      const catalogNames = [...catalog.keys()];
      const catalogNameSet = new Set(catalogNames);
      const tasks = [
        { task: "Implement a Python FastAPI endpoint for user registration with pydantic models" },
      ];

      await routeDispatchTasks(tasks, catalog, catalogNames, catalogNameSet, mockPi as any, {});

      assert.ok(typeof tasks[0].systemPrompt === "string", "systemPrompt should be set");
      assert.ok(tasks[0].systemPrompt.includes('<skill name="python-design"'), "should have python-design");
      // software-design matches via enforcer "implement"
      // With max 2 skills, both should be injected
      const decision = appendedEntries.find(e => e.type === DECISION_ENTRY);
      assert.ok(decision, "decision entry logged");
      assert.ok(decision.data.dispatch, "dispatch marker set");
    } finally {
      _setConfig(saved);
      server.close();
    }
  });
});

describe("dispatch routing: existing systemPrompt preserved", () => {
  it("appends after existing systemPrompt with a blank line", async () => {
    const { server, port } = await startKevServer((_req, res, body) => {
      const parsed = JSON.parse(body);
      const answers: Record<string, any> = {};
      for (const name of Object.keys(parsed.questions)) {
        answers[name] = { type: "noul", noul: 0.9 };
      }
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ answers }));
    });

    const saved = _getConfig();
    _setConfig(makeCfg(port));

    try {
      const catalog = loadCatalog();
      const catalogNames = [...catalog.keys()];
      const catalogNameSet = new Set(catalogNames);
      const tasks = [
        { task: "Write python tests for the parser", systemPrompt: "You are a careful coder." },
      ];

      await routeDispatchTasks(tasks, catalog, catalogNames, catalogNameSet, { on() {}, appendEntry() {} } as any, {});

      assert.ok((tasks[0] as any).systemPrompt.startsWith("You are a careful coder."), "original preserved");
      assert.ok((tasks[0] as any).systemPrompt.includes("\n\n<skill name="), "blank line separator");
    } finally {
      _setConfig(saved);
      server.close();
    }
  });
});

describe("dispatch routing: no-hit task unchanged", () => {
  it("task with no matches stays untouched", async () => {
    const saved = _getConfig();
    _setConfig({ ...saved, mode: "inject" });

    try {
      const catalog = loadCatalog();
      const catalogNames = [...catalog.keys()];
      const catalogNameSet = new Set(catalogNames);
      const tasks = [
        { task: "What is the weather today?" },
      ];

      await routeDispatchTasks(tasks, catalog, catalogNames, catalogNameSet, { on() {}, appendEntry() {} } as any, {});

      assert.equal((tasks[0] as any).systemPrompt, undefined, "no systemPrompt set");
    } finally {
      _setConfig(saved);
    }
  });
});

describe("dispatch routing: multiple tasks routed independently", () => {
  it("each task scored and injected independently", async () => {
    const { server, port } = await startKevServer((_req, res, body) => {
      const parsed = JSON.parse(body);
      const answers: Record<string, any> = {};
      for (const name of Object.keys(parsed.questions)) {
        answers[name] = { type: "noul", noul: 0.9 };
      }
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ answers }));
    });

    const saved = _getConfig();
    _setConfig(makeCfg(port));

    try {
      const catalog = loadCatalog();
      const catalogNames = [...catalog.keys()];
      const catalogNameSet = new Set(catalogNames);
      const tasks = [
        { task: "Implement a Python service" },
        { task: "What is the weather today?" },
        { task: "Write a unit test for the parser module" },
      ];

      await routeDispatchTasks(tasks, catalog, catalogNames, catalogNameSet, { on() {}, appendEntry() {} } as any, {});

      // Task 0: python-design/software-design
      assert.ok((tasks[0] as any).systemPrompt?.includes('<skill name='), "task 0 injected");
      // Task 1: no hits
      assert.equal((tasks[1] as any).systemPrompt, undefined, "task 1 unchanged");
      // Task 2: test-design
      assert.ok((tasks[2] as any).systemPrompt?.includes('<skill name="test-design"'), "task 2 injected test-design");
    } finally {
      _setConfig(saved);
      server.close();
    }
  });
});

describe("dispatch routing: idempotence", () => {
  it("running twice does not double-inject", async () => {
    const { server, port } = await startKevServer((_req, res, body) => {
      const parsed = JSON.parse(body);
      const answers: Record<string, any> = {};
      for (const name of Object.keys(parsed.questions)) {
        answers[name] = { type: "noul", noul: 0.9 };
      }
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ answers }));
    });

    const saved = _getConfig();
    _setConfig(makeCfg(port));

    try {
      const catalog = loadCatalog();
      const catalogNames = [...catalog.keys()];
      const catalogNameSet = new Set(catalogNames);
      const tasks = [
        { task: "Write python code with pytest" },
      ];

      const mockPi = { on() {}, appendEntry() {} } as any;
      await routeDispatchTasks(tasks, catalog, catalogNames, catalogNameSet, mockPi, {});
      const afterFirst = (tasks[0] as any).systemPrompt;
      assert.ok(afterFirst, "first pass injected");

      // Second pass: skills already in systemPrompt should be skipped
      await routeDispatchTasks(tasks, catalog, catalogNames, catalogNameSet, mockPi, {});
      const afterSecond = (tasks[0] as any).systemPrompt;
      assert.equal(afterFirst, afterSecond, "second pass is no-op (idempotent)");
    } finally {
      _setConfig(saved);
      server.close();
    }
  });
});

describe("dispatch routing: shadow mode logs without mutating", () => {
  it("logs wouldInject but does not set systemPrompt", async () => {
    const { server, port } = await startKevServer((_req, res, body) => {
      const parsed = JSON.parse(body);
      const answers: Record<string, any> = {};
      for (const name of Object.keys(parsed.questions)) {
        answers[name] = { type: "noul", noul: 0.9 };
      }
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ answers }));
    });

    const saved = _getConfig();
    _setConfig(makeCfg(port, { mode: "shadow" }));
    const appendedEntries: any[] = [];
    const mockPi = {
      on() {},
      appendEntry(type: string, data: any) { appendedEntries.push({ type, data }); },
    };

    try {
      const catalog = loadCatalog();
      const catalogNames = [...catalog.keys()];
      const catalogNameSet = new Set(catalogNames);
      const tasks = [
        { task: "Implement a Python FastAPI service" },
      ];

      await routeDispatchTasks(tasks, catalog, catalogNames, catalogNameSet, mockPi as any, {});

      assert.equal((tasks[0] as any).systemPrompt, undefined, "shadow mode does not mutate");
      const decision = appendedEntries.find(e => e.type === DECISION_ENTRY);
      assert.ok(decision, "decision logged");
      assert.ok(decision.data.dispatch, "dispatch marker");
      assert.equal(decision.data.mode, "shadow");
      assert.ok(decision.data.wouldInject.length > 0, "wouldInject populated");
    } finally {
      _setConfig(saved);
      server.close();
    }
  });
});

describe("dispatch routing: off mode does nothing", () => {
  it("tool_call handler skips dispatch when mode is off", async () => {
    const handlers: Record<string, Function> = {};
    const mockPi = {
      on(event: string, handler: Function) { handlers[event] = handler; },
      appendEntry() {},
    };
    skillRouter(mockPi as any);

    const saved = _getConfig();
    _setConfig({ ...saved, mode: "off" });

    try {
      const tasks = [{ task: "Write python tests" }];
      const event = { toolName: "dispatch", input: { tasks } };
      const ctx = {};
      await handlers["tool_call"](event, ctx);
      assert.equal((tasks[0] as any).systemPrompt, undefined, "off mode leaves tasks untouched");
    } finally {
      _setConfig(saved);
    }
  });
});

describe("dispatch routing: Kev failure falls back to rules-only", () => {
  it("injects via rules when Kev returns 500", async () => {
    const { server, port } = await startKevServer((_req, res) => {
      res.writeHead(500);
      res.end("error");
    });

    const saved = _getConfig();
    _setConfig(makeCfg(port));
    const appendedEntries: any[] = [];

    try {
      const catalog = loadCatalog();
      const catalogNames = [...catalog.keys()];
      const catalogNameSet = new Set(catalogNames);
      const tasks = [
        { task: "Help me commit my changes" },
      ];

      await routeDispatchTasks(tasks, catalog, catalogNames, catalogNameSet, {
        on() {},
        appendEntry(type: string, data: any) { appendedEntries.push({ type, data }); },
      } as any, {});

      assert.ok((tasks[0] as any).systemPrompt?.includes('<skill name="git-commit"'), "rules-only fallback injects git-commit");
      const decision = appendedEntries.find(e => e.type === DECISION_ENTRY);
      assert.equal(decision.data.kev, "failed");
    } finally {
      _setConfig(saved);
      server.close();
    }
  });
});

describe("dispatch routing: Kev low p drops a skill", () => {
  it("drops skill when Kev returns low probability", async () => {
    const { server, port } = await startKevServer((_req, res, body) => {
      const parsed = JSON.parse(body);
      const answers: Record<string, any> = {};
      for (const name of Object.keys(parsed.questions)) {
        // software-design gets high p, python-design gets low p
        answers[name] = { type: "noul", noul: name === "software-design" ? 0.9 : 0.05 };
      }
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ answers }));
    });

    const saved = _getConfig();
    _setConfig(makeCfg(port));

    try {
      const catalog = loadCatalog();
      const catalogNames = [...catalog.keys()];
      const catalogNameSet = new Set(catalogNames);
      const tasks = [
        { task: "Implement a Python service with FastAPI" },
      ];

      await routeDispatchTasks(tasks, catalog, catalogNames, catalogNameSet, { on() {}, appendEntry() {} } as any, {});

      const sp = (tasks[0] as any).systemPrompt ?? "";
      assert.ok(sp.includes('<skill name="software-design"'), "high-p skill injected");
      assert.ok(!sp.includes('<skill name="python-design"'), "low-p skill dropped");
    } finally {
      _setConfig(saved);
      server.close();
    }
  });
});

describe("dispatch routing: throwing path leaves input untouched", () => {
  it("exception in routeDispatchTasks does not break dispatch", async () => {
    const handlers: Record<string, Function> = {};
    const mockPi = {
      on(event: string, handler: Function) { handlers[event] = handler; },
      appendEntry() {},
    };
    skillRouter(mockPi as any);

    const saved = _getConfig();
    // Set up a config with an invalid/unreachable URL to provoke errors
    _setConfig({
      ...saved,
      mode: "inject",
      decider: { ...saved.decider, url: "http://127.0.0.1:1", timeoutMs: 50 },
    });

    try {
      // tasks with non-string .task should be skipped gracefully
      const tasks = [
        { task: 123 },  // non-string
        { task: "Write python code" },  // valid but Kev will fail -> rules fallback
        { notATask: true },  // no .task
      ];
      const event = { toolName: "dispatch", input: { tasks } };
      const ctx = {};
      // Should not throw
      await handlers["tool_call"](event, ctx);
      // task 0 and 2 are untouched
      assert.equal((tasks[0] as any).systemPrompt, undefined, "non-string task untouched");
      assert.equal((tasks[2] as any).systemPrompt, undefined, "no .task untouched");
      // task 1 gets rules-only fallback
      assert.ok((tasks[1] as any).systemPrompt?.includes('<skill name='), "valid task still gets injected via fallback");
    } finally {
      _setConfig(saved);
    }
  });
});

describe("dispatch routing: commit gate still works alongside dispatch", () => {
  it("blocks git commit even after dispatch routing runs", async () => {
    const handlers: Record<string, Function> = {};
    const mockPi = {
      on(event: string, handler: Function) { handlers[event] = handler; },
      appendEntry() {},
    };
    skillRouter(mockPi as any);

    const saved = _getConfig();
    _setConfig({ ...saved, mode: "inject" });

    try {
      // Commit gate test
      const event = { toolName: "bash", input: { command: "git commit -m 'test'" } };
      const ctx = {
        sessionManager: {
          buildContextEntries() { return []; },
        },
      };
      const result = await handlers["tool_call"](event, ctx);
      assert.ok(result?.block, "commit should be blocked");
      assert.ok(result.reason.includes("Load skill:git-commit"), `reason: ${result.reason}`);
    } finally {
      _setConfig(saved);
    }
  });
});

describe("dispatch routing: Kev state format", () => {
  it("sends correct state string with cwd and task text", async () => {
    let capturedState = "";
    const { server, port } = await startKevServer((_req, res, body) => {
      const parsed = JSON.parse(body);
      capturedState = parsed.state;
      const answers: Record<string, any> = {};
      for (const name of Object.keys(parsed.questions)) {
        answers[name] = { type: "noul", noul: 0.9 };
      }
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ answers }));
    });

    const saved = _getConfig();
    _setConfig(makeCfg(port));

    try {
      const catalog = loadCatalog();
      const catalogNames = [...catalog.keys()];
      const catalogNameSet = new Set(catalogNames);
      const tasks = [
        { task: "Write python code" },
      ];

      await routeDispatchTasks(tasks, catalog, catalogNames, catalogNameSet, { on() {}, appendEntry() {} } as any, { cwd: "/Users/me/myproject" });

      assert.ok(capturedState.includes("Working directory:"), "state has cwd");
      assert.ok(capturedState.includes("User request:"), "state has user request");
      assert.ok(capturedState.includes("Write python code"), "state has task text");
    } finally {
      _setConfig(saved);
      server.close();
    }
  });
});

describe("dispatch routing: concurrent Kev queries bounded by ~1x timeoutMs", () => {
  it("4 tasks with slow server complete in under 2x timeoutMs total", async () => {
    const TIMEOUT_MS = 200;
    const { server, port } = await startKevServer((_req, _res) => {
      // Never respond — each query will hit the timeout
    });

    const saved = _getConfig();
    _setConfig(makeCfg(port, { timeoutMs: TIMEOUT_MS }));

    try {
      const catalog = loadCatalog();
      const catalogNames = [...catalog.keys()];
      const catalogNameSet = new Set(catalogNames);
      const tasks = [
        { task: "Help me commit my changes" },
        { task: "Write python tests for the parser" },
        { task: "Create a Dockerfile for this service" },
        { task: "Refactor this module into smaller functions" },
      ];

      const start = Date.now();
      await routeDispatchTasks(tasks, catalog, catalogNames, catalogNameSet, { on() {}, appendEntry() {} } as any, {});
      const elapsed = Date.now() - start;

      // If sequential, would be ~4 x TIMEOUT_MS = 800ms.
      // Concurrent: should be ~1 x TIMEOUT_MS. Allow 2x for CI jitter.
      assert.ok(
        elapsed < 2 * TIMEOUT_MS,
        `Expected < ${2 * TIMEOUT_MS}ms, got ${elapsed}ms (sequential would be ~${4 * TIMEOUT_MS}ms)`,
      );

      // All tasks should still get rules-only fallback injection
      for (let i = 0; i < tasks.length; i++) {
        assert.ok(
          (tasks[i] as any).systemPrompt?.includes('<skill name='),
          `task ${i} should have rules-only fallback injection`,
        );
      }
    } finally {
      _setConfig(saved);
      server.close();
    }
  });
});
