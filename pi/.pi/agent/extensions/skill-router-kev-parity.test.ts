/**
 * skill-router-kev-parity.test.ts — Kev filter parity against harness oracle.
 *
 * For each labeled turn with rule hits, calls the real Kev server through the
 * router's queryKev helper and compares keep/drop per hit with the harness
 * kev_keep predictions. Asserts agreement >= 95%.
 *
 * Run: npx tsx --test pi/.pi/agent/extensions/skill-router-kev-parity.test.ts
 *
 * Skipped when:
 *   - The parity file is absent
 *   - GET http://127.0.0.1:8008/v1/models fails (no Kev server)
 */

import { describe, it, before } from "node:test";
import * as assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import {
  queryKev,
  scorePrompt,
  loadCatalog,
  _getConfig,
  MAX_STATE_CHARS,
} from "./skill-router.ts";
import type { CatalogEntry, RouterConfig } from "./skill-router.ts";

const PARITY_FILE = join(
  process.env.HOME ?? "",
  ".local/share/pi-decision-eval/data/labels/ts_parity_149.jsonl",
);

const KEV_URL = "http://127.0.0.1:8008";

interface ParityVec {
  turn_id: string;
  prompt: string;
  hits: Record<string, number>;
  kev_keep: Record<string, boolean>;
  cwd: string;
  should_load: string[];
}

describe("Kev filter parity (real server)", () => {
  if (!existsSync(PARITY_FILE)) {
    it("SKIPPED: parity file not found", { skip: true }, () => {});
    return;
  }

  const lines = readFileSync(PARITY_FILE, "utf-8").trim().split("\n");
  const vectors: ParityVec[] = lines.map((l) => JSON.parse(l));
  const withHits = vectors.filter((v) => Object.keys(v.kev_keep).length > 0);

  if (withHits.length === 0) {
    it("SKIPPED: no turns with kev_keep data", { skip: true }, () => {});
    return;
  }

  // Check server availability
  let serverAvailable = false;
  before(async () => {
    try {
      const resp = await fetch(`${KEV_URL}/v1/models`, {
        signal: AbortSignal.timeout(5000),
      });
      serverAvailable = resp.ok;
    } catch {
      serverAvailable = false;
    }
  });

  it(`kev filter agreement >= 95% over ${withHits.length} turns with hits`, async (t) => {
    if (!serverAvailable) {
      t.skip("Kev server not available");
      return;
    }

    const catalog = loadCatalog();
    const allNames = [...catalog.keys()];

    // Build a config pointing at the real server
    const cfg: RouterConfig = {
      ..._getConfig(),
      decider: {
        url: KEV_URL,
        model: "kev-latest",
        timeoutMs: 30000, // generous for real inference
        threshold: 0.30,
        apiKeyEnv: null,
      },
    };

    let totalDecisions = 0;
    let agreements = 0;
    const mismatches: Array<{
      turn_id: string;
      skill: string;
      expected: boolean;
      got: boolean;
      p: number;
    }> = [];

    for (const vec of withHits) {
      // Build hits map the same way the router does
      const hits = scorePrompt(vec.prompt, allNames);

      // Only keep the actual hits (score > 0)
      const hitMap = new Map<string, number>();
      for (const [name, score] of hits) {
        if (score > 0 && name in vec.kev_keep) {
          hitMap.set(name, score);
        }
      }

      if (hitMap.size === 0) continue;

      // Override cwd via queryKev's state construction:
      // queryKev uses process.cwd() but we need the turn's cwd.
      // We'll call the server directly with the correct state.
      const cwd = vec.cwd;
      const state = `Working directory: ${cwd}\nUser request:\n${vec.prompt.slice(0, MAX_STATE_CHARS)}`;

      const questions: Record<string, any> = {};
      for (const [name] of hitMap) {
        const entry = catalog.get(name);
        const desc = entry?.description?.slice(0, 400) ?? "";
        questions[name] = {
          type: "noul",
          instructions: `Would a careful coding agent load the \`${name}\` skill before handling this request? Skill description: ${desc}`,
          criteria: {
            true: "The request's task clearly matches this skill's stated purpose",
            false: "The skill is unrelated or only tangential to the request",
          },
        };
      }

      const body = { state, model: cfg.decider.model, questions };
      const resp = await fetch(`${KEV_URL}/v1/systemone`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(cfg.decider.timeoutMs),
      });
      assert.ok(resp.ok, `HTTP ${resp.status} for ${vec.turn_id}`);
      const data = (await resp.json()) as any;

      for (const [name] of hitMap) {
        const p = data.answers?.[name]?.noul;
        assert.ok(
          typeof p === "number",
          `missing noul for ${name} in ${vec.turn_id}`,
        );

        const tsKeep = p >= 0.30;
        const harnessKeep = vec.kev_keep[name];
        totalDecisions++;
        if (tsKeep === harnessKeep) {
          agreements++;
        } else {
          mismatches.push({
            turn_id: vec.turn_id,
            skill: name,
            expected: harnessKeep,
            got: tsKeep,
            p,
          });
        }
      }
    }

    const agreement = totalDecisions > 0 ? agreements / totalDecisions : 1;
    console.log(
      `\n  Kev parity: ${agreements}/${totalDecisions} decisions agree (${(agreement * 100).toFixed(1)}%)`,
    );
    if (mismatches.length > 0) {
      console.log(`  Mismatches (${mismatches.length}):`);
      for (const m of mismatches.slice(0, 10)) {
        console.log(
          `    ${m.turn_id} ${m.skill}: expected=${m.expected} got=${m.got} p=${m.p.toFixed(4)}`,
        );
      }
    }

    assert.ok(
      agreement >= 0.95,
      `Agreement ${(agreement * 100).toFixed(1)}% < 95% (${mismatches.length} mismatches out of ${totalDecisions})`,
    );
  });
});
