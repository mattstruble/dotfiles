import { it } from "node:test";
import * as assert from "node:assert/strict";
import { needsApproval, nestedCallReason, READ_ALLOWLIST_FLAT } from "./guardrails.ts";

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
