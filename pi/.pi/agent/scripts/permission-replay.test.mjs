import { test, before } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const SCRIPT = join(dirname(fileURLToPath(import.meta.url)), "permission-replay.mjs");
const dir = mkdtempSync(join(tmpdir(), "permreplay-test-"));
const p = (name) => join(dir, name);
const json = (name, value) => writeFileSync(p(name), JSON.stringify(value));

before(() => {
  json("old.json", { permission: { "*": "allow", bash: { "*": "ask" } } });
  json("new.json", { permission: { "*": "allow", bash: { "*": "allow", "git push *": "ask" } } });

  const waiting = (extra) => ({ event: "permission_request.waiting", ...extra });
  const lines = [
    waiting({ toolName: "bash", command: "git status" }),
    waiting({ toolName: "bash", command: "git push origin main" }),
    waiting({ toolName: "bash", command: "ls" }),
    // matched unit is "echo"; the full command in the message is what gets replayed
    waiting({ toolName: "bash", command: "echo", message: "Current agent requested bash command 'echo' (matched '*') (full command: 'git push origin x'). Allow this command?" }),
    waiting({ toolName: "edit" }),
    waiting({ toolName: "mcp" }),
    { event: "permission_request.approved", toolName: "bash", command: "git push" },
  ];
  writeFileSync(p("log.jsonl"), `${lines.map((l) => JSON.stringify(l)).join("\n")}\n`);

  json("deny.json", { permission: { "*": "allow", bash: { "*": "allow", "terraform destroy *": "deny" } } });
  writeFileSync(p("deny-log.jsonl"), `${[
    waiting({ toolName: "bash", command: "git status" }),
    waiting({ toolName: "bash", command: "terraform destroy prod" }),
  ].map((l) => JSON.stringify(l)).join("\n")}\n`);

  writeFileSync(p("broken.json"), "{bad");
  json("typo.json", { permission: { bash: { "*": "dney" } } });

  json("pass.json", [
    { tool: "bash", input: { command: "git status" }, expect: "allow", note: "allowed" },
    { tool: "bash", input: { command: "git push origin main" }, expect: ["ask", "deny"], note: "any-of" },
  ]);
  json("deny-fixtures.json", [
    { tool: "bash", input: { command: "terraform destroy prod" }, expect: "deny", note: "denied" },
  ]);
  json("fail.json", [
    { tool: "bash", input: { command: "git status" }, expect: "deny", note: "deliberately wrong" },
  ]);
});

const run = (fixtures) =>
  spawnSync(process.execPath, [SCRIPT, p("old.json"), p("new.json"), "--log", p("log.jsonl"), "--fixtures", p(fixtures), "--cwd", dir], { encoding: "utf8" });

test("reports counts, percentage, calibration and skipped classes", () => {
  const r = run("pass.json");
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.match(r.stdout, /replayable entries \(denominator\): 5/);
  assert.match(r.stdout, /old ask count: 4/);
  assert.match(r.stdout, /new ask count: 2/);
  assert.match(r.stdout, /new\/old ask: 50\.0%/);
  assert.match(r.stdout, /calibration rate .*: 80\.0% \(4\/5\)/);
  assert.match(r.stdout, /entries that deny under the new config: 0/);
  assert.match(r.stdout, /1 {2}mcp: no recorded input to replay/);
  assert.match(r.stdout, /\[bash\] git push origin x/);
  assert.match(r.stdout, /fixtures: 2 passed, 0 failed/);
});

test("lists entries that deny under the new config with the deny rule", () => {
  const r = spawnSync(process.execPath, [SCRIPT, p("old.json"), p("deny.json"), "--log", p("deny-log.jsonl"), "--fixtures", p("deny-fixtures.json"), "--cwd", dir], { encoding: "utf8" });
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.match(r.stdout, /entries that deny under the new config: 1/);
  assert.match(r.stdout, /\[bash\] terraform destroy prod {2}\(old: ask; .*terraform destroy \*.*\)/);
});

test("fixtures can set their own cwd", () => {
  json("cwd.json", [{ tool: "bash", input: { command: "git status" }, cwd: tmpdir(), expect: "allow", note: "other cwd" }]);
  const r = run("cwd.json");
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.match(r.stdout, /fixtures: 1 passed, 0 failed/);
});

test("exits non-zero when a fixture fails", () => {
  const r = run("fail.json");
  assert.equal(r.status, 1, r.stdout + r.stderr);
  assert.match(r.stdout, /FAIL \[bash\].*expected "deny", got allow/);
});

for (const [name, file] of [["unparseable", "broken.json"], ["invalid value", "typo.json"]]) {
  for (const slot of ["old", "new"]) {
    test(`rejects an ${name} ${slot} config instead of replaying package defaults`, () => {
      const args = slot === "old" ? [p(file), p("new.json")] : [p("old.json"), p(file)];
      const r = spawnSync(process.execPath, [SCRIPT, ...args, "--log", p("log.jsonl"), "--fixtures", p("pass.json"), "--cwd", dir], { encoding: "utf8" });
      assert.equal(r.status, 2, r.stdout + r.stderr);
      assert.match(r.stderr, /invalid permission config/);
      assert.match(r.stderr, new RegExp(file.replace(".", "\\.")));
      assert.doesNotMatch(r.stdout, /replayable entries/);
    });
  }
}
