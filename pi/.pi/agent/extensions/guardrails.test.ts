import { it } from "node:test";
import * as assert from "node:assert/strict";
import { needsApproval, READ_ALLOWLIST_FLAT } from "./guardrails.ts";

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
