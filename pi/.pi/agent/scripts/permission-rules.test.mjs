import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, copyFileSync, lstatSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, realpathSync, statSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import {
  CONFIG_PATH,
  LOCK_PATH,
  applySpec as applySpecWith,
  generateAws,
  generateCurl,
  generatedManifest,
  main,
  parseConfig,
  planSpec,
  replaceBlock,
  serialize,
  serializeManifest,
  spec,
  writeFileAtomic,
} from "./permission-rules.mjs";

const clone = (o) => structuredClone(o);
const realConfig = () => JSON.parse(readFileSync(CONFIG_PATH, "utf8"));
const realManifest = () => JSON.parse(readFileSync(LOCK_PATH, "utf8"));
const bashKeys = (config) => Object.keys(config.permission.bash);
// The committed manifest is the default, as it is for the real config.
const applySpec = (config, s = spec, manifest = realManifest()) => applySpecWith(config, s, manifest);

// Regenerates the real config from `s` and asserts a second run, driven by the
// manifest the first run produced, changes nothing and the manifest matches
// the generated keys (what `--check` verifies).
function regenerate(s) {
  const first = planSpec(realConfig(), s, realManifest());
  assert.deepEqual(first.manifest, generatedManifest(s));
  const second = planSpec(clone(first.config), s, first.manifest);
  assert.equal(serialize(second.config), serialize(first.config));
  assert.deepEqual(second.manifest, first.manifest);
  return first.config;
}

test("generated blocks reproduce the committed config and manifest", () => {
  const text = readFileSync(CONFIG_PATH, "utf8");
  assert.equal(serialize(applySpec(JSON.parse(text))), text);
  assert.deepEqual(realManifest(), generatedManifest(spec));
});

test("renaming one curl write flag changes every prefix and width copy in the config", () => {
  const s = clone(spec);
  s.curl.groups[0].flags[s.curl.groups[0].flags.indexOf("-d")] = "-Z";
  const before = bashKeys(realConfig());
  const out = regenerate(s);
  const after = bashKeys(out);
  assert.equal(after.length, before.length);

  const isD = (k) => /(^| )-\?*d\*$/.test(k) && !k.includes("--");
  const isZ = (k) => /(^| )-\?*Z\*$/.test(k);
  const oldD = before.filter(isD);
  const newZ = after.filter(isZ);
  // 4 prefixes x (2 plain forms + 8 widths x 2 forms)
  assert.equal(oldD.length, spec.curl.prefixes.length * (2 + spec.curl.bundleWidth * 2));
  assert.equal(before.filter(isZ).length, 0);
  assert.deepEqual(newZ, oldD.map((k) => k.replace(/d\*$/, "Z*")));
  assert.equal(after.filter(isD).length, 0);
  for (const { prefix } of spec.curl.prefixes) {
    for (let w = 0; w <= spec.curl.bundleWidth; w++) {
      const f = `-${"?".repeat(w)}Z*`;
      assert.ok(after.includes(`${prefix} ${f}`), `${prefix} ${f}`);
      assert.ok(after.includes(`${prefix} * ${f}`), `${prefix} * ${f}`);
      assert.equal(out.permission.bash[`${prefix} ${f}`], "ask");
    }
  }
});

test("changing the spec flag changes the rewritten config", () => {
  const s = clone(spec);
  s.curl.groups[1].flags = ["--jsonx"];
  const config = JSON.parse(readFileSync(CONFIG_PATH, "utf8"));
  const keys = Object.keys(applySpec(config, s).permission.bash);
  assert.equal(keys.filter((k) => k.endsWith("--jsonx*")).length, spec.curl.prefixes.length * 2);
  assert.equal(keys.filter((k) => k.endsWith("--json*")).length, 0);
});

test("applying the spec twice gives the same config", () => {
  const once = applySpec(realConfig());
  assert.equal(serialize(applySpec(clone(once))), serialize(once));
});

test("bundleWidth 9 regenerates and passes the check", () => {
  const s = clone(spec);
  s.curl.bundleWidth = 9;
  const keys = bashKeys(regenerate(s));
  assert.ok(keys.includes("\\curl * -?????????K*"));
  const grown = generateCurl(s.curl).length - generateCurl(spec.curl).length;
  assert.ok(grown > 0);
  assert.equal(keys.length, bashKeys(realConfig()).length + grown);
});

test("an appended aws service regenerates and passes the check", () => {
  const s = clone(spec);
  s.aws.services.push("sts");
  const keys = bashKeys(regenerate(s));
  for (const v of spec.aws.readVerbs) assert.ok(keys.includes(`aws sts ${v}-*`));
  assert.equal(keys.length, bashKeys(realConfig()).length + spec.aws.readVerbs.length);
});

test("a new flag in the last curl group regenerates and passes the check", () => {
  const s = clone(spec);
  s.curl.groups[2].flags.push("-Q");
  const keys = bashKeys(regenerate(s));
  for (const { prefix } of spec.curl.prefixes) {
    for (let w = 0; w <= spec.curl.bundleWidth; w++) {
      assert.ok(keys.includes(`${prefix} ${"-" + "?".repeat(w) + "Q*"}`));
    }
  }
});

test("regeneration keeps every rule outside the blocks in value and position", () => {
  const s = clone(spec);
  s.curl.bundleWidth = 9;
  s.aws.services.push("sts");
  const before = realConfig().permission.bash;
  const gen = new Set(
    [spec, s].flatMap((x) => [...generateCurl(x.curl), ...generateAws(x.aws)]).map(([k]) => k),
  );
  const out = applySpec(realConfig(), s).permission.bash;
  const rest = (o) => Object.entries(o).filter(([k]) => !gen.has(k));
  assert.deepEqual(rest(out), rest(before));
});

test("missing block boundaries throw", () => {
  for (const block of ["curl", "aws"]) {
    for (const role of ["before", "after"]) {
      const config = realConfig();
      delete config.permission.bash[spec[block].neighbors[role]];
      assert.throws(() => applySpec(config), new RegExp(`${block}: ${role} neighbor.*found 0 times`));
    }
  }
});

test("duplicated or misordered block boundaries throw", () => {
  const gen = [["x", "ask"]];
  const nb = { before: "a", after: "b" };
  const e = (...ks) => ks.map((k) => [k, "allow"]);
  assert.deepEqual(replaceBlock(e("a", "old", "b"), gen, nb, "t").map(([k]) => k), ["a", "x", "b"]);
  assert.throws(() => replaceBlock(e("a", "b", "a"), gen, nb, "t"), /before neighbor.*2 times/);
  assert.throws(() => replaceBlock(e("a", "b", "b"), gen, nb, "t"), /after neighbor.*2 times/);
  assert.throws(() => replaceBlock(e("b", "old", "a"), gen, nb, "t"), /out of order/);
  // a generated rule that also exists outside the block is ambiguous
  assert.throws(() => replaceBlock(e("x", "a", "old", "b"), gen, nb, "t"), /duplicate rule "x"/);
});

test("a failed regeneration does not modify the input config", () => {
  const config = realConfig();
  delete config.permission.bash[spec.curl.neighbors.after];
  const snapshot = serialize(config);
  assert.throws(() => applySpec(config));
  assert.equal(serialize(config), snapshot);
});

// --- safety: refuse to delete rules the generator did not write ---------------

const SCRIPT = join(import.meta.dirname, "permission-rules.mjs");
const withBash = (config, entries) => ({ ...config, permission: { ...config.permission, bash: Object.fromEntries(entries) } });

// Returns a config whose bash entries have `key` moved to `where` ("top"/"end").
function moved(key, where) {
  const config = realConfig();
  const entries = Object.entries(config.permission.bash);
  const i = entries.findIndex(([k]) => k === key);
  const [e] = entries.splice(i, 1);
  if (where === "top") entries.unshift(e);
  else entries.push(e);
  return withBash(config, entries);
}

function inserted(afterKey, entry) {
  const config = realConfig();
  const entries = Object.entries(config.permission.bash);
  entries.splice(entries.findIndex(([k]) => k === afterKey) + 1, 0, entry);
  return withBash(config, entries);
}

test("moving a neighbor rule throws and names offending keys", () => {
  for (const [block, role] of [["curl", "before"], ["curl", "after"], ["aws", "before"], ["aws", "after"]]) {
    const key = spec[block].neighbors[role];
    for (const where of ["top", "end"]) {
      const config = moved(key, where);
      const snapshot = serialize(config);
      assert.throws(
        () => applySpec(config),
        (err) =>
          /out of order|overlap/.test(err.message) ||
          (/refusing to delete \d+ rule/.test(err.message) && /"[^"]+"/.test(err.message)),
        `${block} ${role} -> ${where}`,
      );
      assert.equal(serialize(config), snapshot);
    }
  }
  // aws s3api * moved to the end: the aws denies and env dumps are named
  assert.throws(() => applySpec(moved("aws s3api *", "end")), /"aws \*get-secret-value\*"/);
  assert.throws(() => applySpec(moved("rsync *", "top")), /"git push \*"/);
});

test("a hand-written rule inside either block throws and is named, even one shaped like a generated rule", () => {
  const deny = { action: "deny", reason: "x" };
  const cases = [
    ["curl * -X*", ["curl evil.example*", deny], "curl evil.example"],
    ["curl * -X*", ["curl * -evil*", "deny"], "curl \\* -evil"],
    ["curl * -X*", ["curl * -o*", "ask"], "curl \\* -o"],
    ["curl * -X*", ["curl * | x", deny], "curl \\* \\| x"],
    ["gh repo view *", ["aws s3 ls prod*", deny], "aws s3 ls prod"],
    ["gh repo view *", ["aws iam delete-*", "allow"], "aws iam delete-"],
    ["gh repo view *", ["aws s3 get-*", "allow"], "aws s3 get-"],
  ];
  for (const [after, entry, named] of cases) {
    const config = inserted(after, entry);
    const snapshot = serialize(config);
    assert.throws(() => applySpec(config), new RegExp(`refusing to delete 1 rule.*${named}`), entry[0]);
    assert.equal(serialize(config), snapshot);
  }
});

test("overlapping block spans throw", () => {
  const s = clone(spec);
  s.aws.neighbors = { before: "curl -X*", after: "curl --json*" };
  s.curl.neighbors = { before: "rsync *", after: "wget --post-data*" };
  assert.throws(() => applySpec(realConfig(), s), /overlap/);
  // interleaved spans on a minimal config
  const mini = { permission: { bash: { a: "ask", b: "ask", c: "ask", d: "ask" } } };
  const t = clone(spec);
  t.curl.neighbors = { before: "a", after: "c" };
  t.aws.neighbors = { before: "b", after: "d" };
  assert.throws(() => applySpec(mini, t), /curl and aws blocks overlap/);
});

test("integer-like bash keys throw", () => {
  const config = realConfig();
  config.permission.bash["123"] = "ask";
  assert.throws(() => applySpec(config), /integer-like.*"123"/);
});

test("a malformed config throws a descriptive error", () => {
  assert.throws(() => applySpec({ permission: {} }), /permission\.bash is missing or not an object/);
  assert.throws(() => applySpec({}), /permission\.bash is missing/);
  assert.throws(() => applySpec({ permission: { bash: [] } }), /not an object/);
  assert.throws(() => applySpec({ permission: { bash: "ask" } }), /not an object/);
  assert.throws(() => parseConfig("{nope", "/tmp/config.json"), /\/tmp\/config\.json: invalid JSON/);
});

// Temp dir holding config.json and, unless `lock` is null, its manifest.
function workDir(config = realConfig(), lock = realManifest()) {
  const dir = mkdtempSync(join(tmpdir(), "perm-rules-"));
  writeFileSync(join(dir, "config.json"), serialize(config));
  if (lock) writeFileSync(join(dir, LOCK_NAME), serializeManifest(lock));
  return { dir, path: join(dir, "config.json"), lock: join(dir, LOCK_NAME) };
}
const LOCK_NAME = "permission-rules.lock.json";

function runCli(path, ...args) {
  return spawnSync(process.execPath, [SCRIPT, "--config", path, ...args], { encoding: "utf8" });
}

test("CLI on a moved neighbor exits non-zero, prints one line, and leaves both files byte-identical", () => {
  const { dir, path, lock } = workDir(moved("aws s3api *", "end"));
  const before = [readFileSync(path), readFileSync(lock)];
  for (const args of [[], ["--check"]]) {
    const r = runCli(path, ...args);
    assert.notEqual(r.status, 0);
    assert.match(r.stderr, /refusing to delete/);
    assert.equal(r.stderr.trim().split("\n").length, 1);
    assert.doesNotMatch(r.stderr, /\n\s+at /);
  }
  assert.ok(readFileSync(path).equals(before[0]));
  assert.ok(readFileSync(lock).equals(before[1]));
  assert.deepEqual(readdirSync(dir).sort(), ["config.json", LOCK_NAME]);
});

test("CLI hand-written rule inside a span, shaped like a generated one, throws and leaves both files byte-identical", () => {
  const deny = { action: "deny", reason: "x" };
  for (const [after, entry] of [
    ["curl * -X*", ["curl * -o*", "ask"]],
    ["curl * -X*", ["curl * | x", deny]],
    ["gh repo view *", ["aws s3 get-*", "allow"]],
  ]) {
    const { path, lock } = workDir(inserted(after, entry));
    const before = [readFileSync(path), readFileSync(lock)];
    for (const args of [[], ["--check"]]) {
      const r = runCli(path, ...args);
      assert.equal(r.status, 1);
      assert.ok(r.stderr.includes(JSON.stringify(entry[0])), r.stderr);
    }
    assert.ok(readFileSync(path).equals(before[0]));
    assert.ok(readFileSync(lock).equals(before[1]));
  }
});

test("CLI reports invalid JSON by file name and exits non-zero", () => {
  const { path } = workDir();
  writeFileSync(path, "{nope");
  const r = runCli(path);
  assert.notEqual(r.status, 0);
  assert.match(r.stderr, /config\.json: invalid JSON/);
});

test("CLI rewrites a drifted copy atomically, notes the missing key and leaves no temp file", () => {
  const config = realConfig();
  delete config.permission.bash["aws ec2 describe-*"];
  const { dir, path, lock } = workDir(config);
  const r = runCli(path);
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.stdout, /note: aws: 1 generated rule\(s\) were missing.*"aws ec2 describe-\*"/);
  assert.equal(readFileSync(path, "utf8"), readFileSync(CONFIG_PATH, "utf8"));
  assert.equal(readFileSync(lock, "utf8"), readFileSync(LOCK_PATH, "utf8"));
  assert.deepEqual(readdirSync(dir).sort(), ["config.json", LOCK_NAME]);
  assert.equal(runCli(path, "--check").status, 0);
});

// A spec that additionally generates `wcurl * -X*` etc. in the curl span.
const wcurlSpec = () => {
  const s = clone(spec);
  s.curl.prefixes.push({ prefix: "wcurl" });
  return s;
};
const quiet = () => {};

test("a hand-written rule colliding with a newly generated key but with another value refuses and writes nothing", () => {
  const s = wcurlSpec();
  const config = inserted("curl * -X*", ["wcurl * -X*", "deny"]);
  assert.throws(
    () => planSpec(config, s, realManifest()),
    /refusing to overwrite 1 hand-written.*"wcurl \* -X\*" is "deny", generated "ask"/,
  );
  const { dir, path, lock } = workDir(config);
  const before = [readFileSync(path), readFileSync(lock)];
  for (const args of [[], ["--check"]]) {
    assert.throws(() => main(["--config", path, ...args], s, quiet), /"wcurl \* -X\*" is "deny", generated "ask"/);
  }
  assert.ok(readFileSync(path).equals(before[0]));
  assert.ok(readFileSync(lock).equals(before[1]));
  assert.deepEqual(readdirSync(dir).sort(), ["config.json", LOCK_NAME]);
});

test("a hand-written rule colliding with a newly generated key with the generated value heals", () => {
  const s = wcurlSpec();
  const { path, lock } = workDir(inserted("curl * -X*", ["wcurl * -X*", "ask"]));
  assert.equal(main(["--config", path], s, quiet), 0);
  assert.equal(main(["--config", path, "--check"], s, quiet), 0);
  assert.deepEqual(JSON.parse(readFileSync(lock, "utf8")), generatedManifest(s));
  assert.equal(readFileSync(path, "utf8"), serialize(regenerate(s)));
});

test("a key in the manifest is still replaced regardless of its value", () => {
  const config = realConfig();
  config.permission.bash["curl * -X*"] = "allow";
  assert.equal(applySpec(config).permission.bash["curl * -X*"], "ask");
});

test("the missing-keys note omits keys the spec no longer generates", () => {
  // A crash after a spec edit that dropped the wcurl keys: config.json is
  // already regenerated, the manifest still lists them.
  const { path, lock } = workDir(realConfig(), generatedManifest(wcurlSpec()));
  const lines = [];
  assert.equal(main(["--config", path], spec, (l) => lines.push(l)), 0);
  assert.deepEqual(lines, ["manifest written"]);
  assert.equal(readFileSync(lock, "utf8"), readFileSync(LOCK_PATH, "utf8"));
  // a key the spec still generates is reported
  const config = realConfig();
  delete config.permission.bash["aws ec2 describe-*"];
  const w = workDir(config, generatedManifest(wcurlSpec()));
  const out = [];
  main(["--config", w.path], spec, (l) => out.push(l));
  assert.equal(out.filter((l) => l.startsWith("note:")).length, 1);
  assert.match(out.join("\n"), /"aws ec2 describe-\*"/);
  assert.doesNotMatch(out.join("\n"), /wcurl/);
});

test("--check fails when the manifest does not match the generated keys", () => {
  const lock = realManifest();
  lock.aws = [...lock.aws, "aws ghost get-*"];
  const { path, lock: lockPath } = workDir(realConfig(), lock);
  const before = readFileSync(lockPath);
  const r = runCli(path, "--check");
  assert.equal(r.status, 1);
  assert.match(r.stderr, /permission-rules\.lock\.json differs/);
  assert.ok(readFileSync(lockPath).equals(before));
  // a regular run repairs it
  assert.equal(runCli(path).status, 0);
  assert.equal(readFileSync(lockPath, "utf8"), readFileSync(LOCK_PATH, "utf8"));
  assert.equal(runCli(path, "--check").status, 0);
});

test("a stale manifest with a spec-matching config is repaired by a write run", () => {
  const s = clone(spec);
  s.curl.prefixes.push({ prefix: "wcurl" });
  // config matches the edited spec; the manifest is the old one (restored, or
  // checked out at another revision)
  const edited = planSpec(realConfig(), s, realManifest());
  const { path, lock } = workDir(edited.config, realManifest());
  const run = (...args) => main(["--config", path, ...args], s, () => {});
  const configBefore = readFileSync(path);
  const origError = console.error;
  console.error = () => {};
  try {
    assert.equal(run("--check"), 1, "stale manifest is reported, not thrown");
  } finally {
    console.error = origError;
  }
  assert.equal(run(), 0);
  assert.ok(readFileSync(path).equals(configBefore));
  assert.deepEqual(JSON.parse(readFileSync(lock, "utf8")), generatedManifest(s));
  assert.equal(run("--check"), 0);

  // the same through the CLI with a manifest missing keys the span holds
  const stale = realManifest();
  stale.curl = stale.curl.filter((k) => k !== "curl -X*");
  const w = workDir(realConfig(), stale);
  const r = runCli(w.path, "--check");
  assert.equal(r.status, 1);
  assert.match(r.stderr, /manifest stale/);
  assert.doesNotMatch(r.stderr, /refusing/);
  assert.equal(runCli(w.path).status, 0);
  assert.equal(readFileSync(w.lock, "utf8"), readFileSync(LOCK_PATH, "utf8"));
  assert.equal(runCli(w.path, "--check").status, 0);
});

test("a hand-written rule that is neither in the manifest nor generated still refuses", () => {
  const stale = realManifest();
  stale.curl = stale.curl.filter((k) => k !== "curl -X*");
  const { path, lock } = workDir(inserted("curl * -X*", ["curl * -o*", "ask"]), stale);
  const before = [readFileSync(path), readFileSync(lock)];
  for (const args of [[], ["--check"]]) {
    const r = runCli(path, ...args);
    assert.equal(r.status, 1);
    assert.match(r.stderr, /refusing to delete 1 rule.*"curl \* -o\*"/);
  }
  assert.ok(readFileSync(path).equals(before[0]));
  assert.ok(readFileSync(lock).equals(before[1]));
});

test("unknown flags and bad flag values exit non-zero without writing", () => {
  const drifted = realConfig();
  delete drifted.permission.bash["aws ec2 describe-*"];
  const w = workDir(drifted);
  const before = [readFileSync(w.path), readFileSync(w.lock)];
  for (const args of [
    ["--config", w.path, "--chek"],
    ["--config", w.path, "extra"],
    ["--config", "--check"],
    ["--config"],
    ["--config", w.path, "--manifest"],
    ["--config", w.path, "--manifest", "--check"],
  ]) {
    const r = spawnSync(process.execPath, [SCRIPT, ...args], { encoding: "utf8" });
    assert.notEqual(r.status, 0, args.join(" "));
    assert.equal(r.stderr.trim().split("\n").length, 1, r.stderr);
    assert.match(r.stderr, /unknown argument|requires a path/);
    assert.ok(readFileSync(w.path).equals(before[0]));
    assert.ok(readFileSync(w.lock).equals(before[1]));
  }
  assert.deepEqual(readdirSync(w.dir).sort(), ["config.json", LOCK_NAME]);
});

test("the CLI entry guard runs through a file symlink and a directory symlink", () => {
  const dir = mkdtempSync(join(tmpdir(), "perm-rules-"));
  const real = join(dir, "real");
  mkdirSync(real);
  copyFileSync(SCRIPT, join(real, "permission-rules.mjs"));
  const cfg = join(dir, "config.json");
  writeFileSync(cfg, "{nope");
  symlinkSync(join(real, "permission-rules.mjs"), join(dir, "file-link.mjs"));
  symlinkSync(real, join(dir, "dir-link"));
  for (const script of [join(real, "permission-rules.mjs"), join(dir, "file-link.mjs"), join(dir, "dir-link", "permission-rules.mjs")]) {
    for (const args of [[], ["--check"]]) {
      const r = spawnSync(process.execPath, [script, "--config", cfg, ...args], { encoding: "utf8" });
      assert.notEqual(r.status, 0, script);
      assert.match(r.stderr, /config\.json: invalid JSON/, script);
    }
  }
});

test("the CLI entry guard fails closed through a symlink under --preserve-symlinks-main and NODE_PRESERVE_SYMLINKS_MAIN", () => {
  const dir = mkdtempSync(join(tmpdir(), "perm-rules-"));
  const real = join(dir, "real");
  mkdirSync(real);
  copyFileSync(SCRIPT, join(real, "permission-rules.mjs"));
  const cfg = join(dir, "config.json");
  writeFileSync(cfg, "{nope");
  const link = join(dir, "file-link.mjs");
  symlinkSync(join(real, "permission-rules.mjs"), link);
  const runs = [
    { flags: ["--preserve-symlinks-main"], env: process.env },
    { flags: [], env: { ...process.env, NODE_PRESERVE_SYMLINKS_MAIN: "1" } },
  ];
  for (const { flags, env } of runs) {
    for (const args of [[], ["--check"]]) {
      const r = spawnSync(process.execPath, [...flags, link, "--config", cfg, ...args], { encoding: "utf8", env });
      assert.notEqual(r.status, 0, `${flags} ${args}`);
      assert.match(r.stderr, /config\.json: invalid JSON/);
    }
  }
});

test("writeFileAtomic writes through a dangling symlink to its target, keeps the link and leaves no temp file", () => {
  const dir = mkdtempSync(join(tmpdir(), "perm-rules-"));
  const link = join(dir, "link.json");
  symlinkSync("real.json", link);
  writeFileAtomic(link, "new\n");
  assert.ok(lstatIsLink(link));
  assert.equal(readFileSync(join(dir, "real.json"), "utf8"), "new\n");
  assert.deepEqual(readdirSync(dir).sort(), ["link.json", "real.json"]);
});

test("writeFileAtomic resolves a dangling link under a symlinked parent against the real parent", () => {
  const dir = realpathSync(mkdtempSync(join(tmpdir(), "perm-rules-")));
  mkdirSync(join(dir, "a", "b"), { recursive: true });
  symlinkSync(join(dir, "a", "b"), join(dir, "via"));
  const link = join(dir, "via", "link.json");
  symlinkSync("../target.json", link);
  writeFileAtomic(link, "new\n");
  assert.equal(readFileSync(join(dir, "a", "target.json"), "utf8"), "new\n");
  assert.equal(lstatSync(join(dir, "target.json"), { throwIfNoEntry: false }), undefined);
});

test("a missing manifest is bootstrapped when config.json matches the spec", () => {
  const { dir, path, lock } = workDir(realConfig(), null);
  const before = readFileSync(path);
  assert.equal(runCli(path, "--check").status, 1);
  assert.deepEqual(readdirSync(dir), ["config.json"]);
  const r = runCli(path);
  assert.equal(r.status, 0, r.stderr);
  assert.equal(readFileSync(lock, "utf8"), readFileSync(LOCK_PATH, "utf8"));
  assert.ok(readFileSync(path).equals(before));
  assert.equal(runCli(path, "--check").status, 0);
});

test("a missing manifest throws when config.json does not match the spec", () => {
  const drifted = realConfig();
  delete drifted.permission.bash["aws ec2 describe-*"];
  const hand = inserted("curl * -X*", ["curl * -o*", "ask"]);
  for (const [config, message] of [
    [drifted, /manifest is missing and config\.json does not match the spec/],
    [hand, /refusing to delete 1 rule.*"curl \* -o\*"/],
  ]) {
    const { dir, path } = workDir(config, null);
    const before = readFileSync(path);
    for (const args of [[], ["--check"]]) {
      const r = runCli(path, ...args);
      assert.equal(r.status, 1);
      assert.match(r.stderr, message);
    }
    assert.ok(readFileSync(path).equals(before));
    assert.deepEqual(readdirSync(dir), ["config.json"]);
  }
});

// Each edit is a supported spec change; it writes config.json and the
// manifest once and every later run (and --check) must succeed.
const SPEC_EDITS = {
  "a new leading aws allow": (s) => s.aws.leadingAllows.push("aws configure list*"),
  "a new aws read verb": (s) => s.aws.readVerbs.push("batch-get"),
  "a new curl prefix": (s) => s.curl.prefixes.push({ prefix: "wcurl" }),
  "curl action deny": (s) => { s.curl.action = "deny"; },
  "a new pipeDenyRule key": (s) => { s.curl.pipeDenyRule.note = "extra"; },
};

for (const [name, edit] of Object.entries(SPEC_EDITS)) {
  test(`spec edit (${name}) regenerates twice and passes --check`, () => {
    const s = clone(spec);
    edit(s);
    const { path, lock } = workDir();
    const run = (...args) => main(["--config", path, ...args], s, () => {});
    assert.equal(run("--check"), 1, "edit is not yet written");
    assert.equal(run(), 0);
    const written = [readFileSync(path), readFileSync(lock)];
    assert.notEqual(written[0].toString(), readFileSync(CONFIG_PATH, "utf8"));
    assert.equal(run("--check"), 0);
    assert.equal(run(), 0);
    assert.ok(readFileSync(path).equals(written[0]));
    assert.ok(readFileSync(lock).equals(written[1]));
    assert.equal(run("--check"), 0);
    assert.deepEqual(JSON.parse(written[1]), generatedManifest(s));
  });
}

test("a hand-written rule makes an edited-spec run throw and leaves both files byte-identical", () => {
  const s = clone(spec);
  s.curl.prefixes.push({ prefix: "wcurl" });
  const { path, lock } = workDir(inserted("curl * -X*", ["curl * -o*", "ask"]));
  const before = [readFileSync(path), readFileSync(lock)];
  assert.throws(() => main(["--config", path], s, () => {}), /"curl \* -o\*"/);
  assert.ok(readFileSync(path).equals(before[0]));
  assert.ok(readFileSync(lock).equals(before[1]));
});

test("writeFileAtomic replaces the file via rename", () => {
  const dir = mkdtempSync(join(tmpdir(), "perm-rules-"));
  const path = join(dir, "config.json");
  copyFileSync(CONFIG_PATH, path);
  writeFileAtomic(path, "new\n");
  assert.equal(readFileSync(path, "utf8"), "new\n");
  assert.deepEqual(readdirSync(dir), ["config.json"]);
});

test("writeFileAtomic preserves the file mode and writes through a symlink to its target", () => {
  const dir = mkdtempSync(join(tmpdir(), "perm-rules-"));
  const target = join(dir, "real.json");
  const link = join(dir, "link.json");
  writeFileSync(target, "old\n");
  chmodSync(target, 0o640);
  symlinkSync(target, link);
  writeFileAtomic(link, "new\n");
  assert.equal(realpathSync(link), realpathSync(target));
  assert.equal(readFileSync(target, "utf8"), "new\n");
  assert.equal(statSync(target).mode & 0o7777, 0o640);
  assert.ok(lstatIsLink(link));
  assert.deepEqual(readdirSync(dir).sort(), ["link.json", "real.json"]);
});
const lstatIsLink = (p) => lstatSync(p).isSymbolicLink();
