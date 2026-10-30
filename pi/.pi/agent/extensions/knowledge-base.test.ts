/**
 * Run: npx tsx --test pi/.pi/agent/extensions/knowledge-base.test.ts
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { buildInjection, parseIndex, recoverInjectedKeys } from "./knowledge-base.ts";

const INDEX = `## Topics
- [[topics/kubernetes-networking|K8s Networking]] — cilium ingress service mesh
- [[topics/postgres-tuning|Postgres Tuning]] — vacuum autovacuum indexes
`;
const entries = parseIndex(INDEX);
const P1 = "how do I debug cilium ingress networking problems";

test("message shape and no systemPrompt", () => {
  const r = buildInjection(P1, entries, new Set())!;
  assert.equal(r.message.customType, "knowledge-base");
  assert.equal(r.message.display, false);
  assert.match(r.message.content, /topics\/kubernetes-networking/);
  assert.deepEqual(r.message.details.keys, ["topics/kubernetes-networking"]);
  assert.ok(!("systemPrompt" in r));
});

test("once-per-session dedup", () => {
  const inj = new Set<string>();
  assert.ok(buildInjection(P1, entries, inj));
  assert.equal(buildInjection(P1, entries, inj), undefined);
  const r = buildInjection("tune postgres vacuum autovacuum indexes", entries, inj)!;
  assert.deepEqual(r.message.details.keys, ["topics/postgres-tuning"]);
});

test("no match returns undefined", () => {
  assert.equal(buildInjection("hello there friend", entries, new Set()), undefined);
});

const kb = (id: string, keys: string[]) => ({ type: "custom_message", id, customType: "knowledge-base", details: { keys } });
const msg = (id: string) => ({ type: "message", id });

test("recovery from entries", () => {
  const keys = recoverInjectedKeys([
    msg("1"), kb("2", ["a", "b"]), msg("3"),
    { type: "custom_message", id: "4", customType: "other", details: { keys: ["z"] } },
  ]);
  assert.deepEqual([...keys].sort(), ["a", "b"]);
});

test("compaction drops keys before firstKeptEntryId", () => {
  const keys = recoverInjectedKeys([
    kb("1", ["old"]), msg("2"), kb("3", ["kept"]), msg("4"),
    { type: "compaction", id: "5", firstKeptEntryId: "3" },
    kb("6", ["new"]),
  ]);
  assert.deepEqual([...keys].sort(), ["kept", "new"]);
});

test("compacted key can be re-injected", () => {
  const inj = recoverInjectedKeys([
    kb("1", ["topics/kubernetes-networking"]), msg("2"),
    { type: "compaction", id: "3", firstKeptEntryId: "2" },
  ]);
  assert.ok(buildInjection(P1, entries, inj));
});
