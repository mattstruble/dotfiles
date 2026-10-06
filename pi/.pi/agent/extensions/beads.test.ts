import { test } from "node:test";
import assert from "node:assert/strict";
import { derivePrefix, isBdWrite } from "./beads.ts";

test("derivePrefix", () => {
  assert.equal(derivePrefix("/x/ml.lilabench"), "ml-lilabench");
  assert.equal(derivePrefix("/x/Dotfiles"), "dotfiles");
  assert.equal(derivePrefix("/x/my_repo"), "my-repo");
});

test("isBdWrite", () => {
  for (const c of ["bd q x", "bd create x", "bd remember x", "bd import f"]) assert.equal(isBdWrite(c), true, c);
  for (const c of ["bd list", "bd show x", "echo bd create"]) assert.equal(isBdWrite(c), false, c);
});
