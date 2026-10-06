import { it } from "node:test";
import * as assert from "node:assert/strict";
import { bdInitBlockReason, bdVerbs, needsApproval, nestedCallReason, READ_ALLOWLIST_FLAT } from "./guardrails.ts";

it("requires approval unless readOnlyHint is true or allowlisted", () => {
  const tool = "mcp__srv__do_thing";
  assert.equal(needsApproval(tool, undefined, []), true);
  assert.equal(needsApproval(tool, {}, []), true);
  assert.equal(needsApproval(tool, { readOnlyHint: true }, []), false);
  assert.equal(needsApproval(tool, { readOnlyHint: true, destructiveHint: true }, []), false);
  assert.equal(needsApproval(tool, { readOnlyHint: false }, []), true);
  assert.equal(needsApproval(tool, undefined, [tool]), false);
});

it("passes allowlisted tools from servers without annotations", () => {
  assert.equal(needsApproval("mcp__nixos__nix", undefined, READ_ALLOWLIST_FLAT), false);
});

it("blocks workflow and subagent only when another tool issued the call", () => {
  assert.match(nestedCallReason("workflow", "call_1") ?? "", /directly/);
  assert.match(nestedCallReason("subagent", "call_1") ?? "", /directly/);
  assert.equal(nestedCallReason("workflow", undefined), undefined);
  assert.equal(nestedCallReason("bash", "call_1"), undefined);
});

it("extracts bd verbs per segment", () => {
  assert.deepEqual(bdVerbs("cd x && bd init -p y"), ["init"]);
  assert.deepEqual(bdVerbs("bd -v --db x list; bd show a | cat"), ["list", "show"]);
  assert.deepEqual(bdVerbs("echo bd init"), []);
});

it("blocks bd init and bd setup", () => {
  for (const c of [
    "bd init",
    "bd init --stealth",
    "cd x && bd init -p y",
    "BEADS_DIR=/x bd init",
    "env -u BEADS_DIR bd init",
    "command bd init",
    "/nix/store/abc/bin/bd init",
    "bd -v init",
    "bd setup claude",
  ]) {
    assert.match(bdInitBlockReason(c) ?? "", /never run bd init or bd setup/, c);
  }
});

it("allows other bd commands", () => {
  for (const c of ["bd list", 'bd q "fix the init docs"', "bd show x", "echo bd init"]) {
    assert.equal(bdInitBlockReason(c), undefined, c);
  }
});
