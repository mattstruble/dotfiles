import { it } from "node:test";
import * as assert from "node:assert/strict";
import { routeTasks } from "./model-routing.ts";

it("routes by profile, falls back to default, keeps explicit models", () => {
  const map = { default: "p/opus:high", builder: "p/sonnet" };
  const tasks = [
    { profile: "builder" },
    {},
    { profile: "builder", model: "p/haiku" },
    { profile: "unmapped" },
  ];
  routeTasks(tasks, map);
  assert.deepEqual(tasks.map((t: any) => t.model), ["p/sonnet", "p/opus:high", "p/haiku", "p/opus:high"]);
});
