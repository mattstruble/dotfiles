// beads-compaction-trigger — Pi extension
// Triggers context compaction at bd-close boundaries using economic analysis
// extracted from the Online Context Compact (OCC) extension.
//
// Detects `bd close` in bash tool calls, tracks request counts between
// boundaries, and runs decideCompaction() at turn_end. If compaction is
// warranted: abort → agent_settled → ctx.compact() → sendMessage(triggerTurn).
//
// Config: PI_CACHE_WRITE_READ_RATIO env var (default null = window_protection only)
//   Anthropic: 1.25 (cache_write_price / base_input_price = $3.75/$3.00)

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// ── OCC Economics (MIT licensed) ──────────────────────────────────────────
// Extracted verbatim from online-context-compact/economics.ts
//
// SPDX-FileCopyrightText: Copyright (c) 2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
// SPDX-License-Identifier: MIT

type CompactionEconomics = {
	readonly remainingRequestScale: number;
	readonly remainingRequestStddevK: number;
	readonly windowReserveTokens: number;
	readonly firstCompactionRequestScale: number;
	readonly subsequentCompactionMargin: number;
};

const DEFAULT_COMPACTION_ECONOMICS: CompactionEconomics = Object.freeze({
	remainingRequestScale: 1,
	remainingRequestStddevK: 0,
	windowReserveTokens: 16_384,
	firstCompactionRequestScale: 2,
	subsequentCompactionMargin: 1.5,
});

type CompactionReason =
	| "economic"
	| "window_protection"
	| "deferred_economic"
	| "deferred_subsequent_margin"
	| "deferred_carried_debt"
	| "horizon_unavailable"
	| "cache_ratio_unavailable"
	| "native_not_compactable"
	| "non_positive_saving";

type RequestHorizonEstimate = {
	readonly completedBoundaryRequestCounts: readonly number[];
	readonly requestsPerBoundaryMean: number;
	readonly requestsPerBoundaryLowerBound: number;
	readonly unboundedExpectedRemainingRequests: number;
	readonly averageContextTokenIncrement: number | null;
	readonly windowRequestUpperBound: number | null;
	readonly expectedRemainingRequests: number;
};

type CompactionDecision = {
	readonly writeTokens: number;
	readonly archiveTokens: number;
	readonly memoTokens: number;
	readonly contextTokens: number;
	readonly completedBoundaryRequestCounts: readonly number[] | null;
	readonly requestsPerBoundaryMean: number | null;
	readonly requestsPerBoundaryLowerBound: number | null;
	readonly unboundedExpectedRemainingRequests: number | null;
	readonly averageContextTokenIncrement: number | null;
	readonly windowRequestUpperBound: number | null;
	readonly expectedRemainingRequests: number | null;
	readonly breakevenRequests: number | null;
	readonly combinedBreakevenRequests: number | null;
	readonly effectiveHorizonRequests: number | null;
	readonly cacheWriteReadRatio: number | null;
	readonly incrementalCacheCostRatio: number | null;
	readonly priorCompactionCount: number;
	readonly carriedDebtTokens: number;
	readonly cacheDebtRepaymentTokens: number;
	readonly compact: boolean;
	readonly reason: CompactionReason;
};

const MINIMUM_VARIANCE_SAMPLES = 3;
const SMALL_SAMPLE_SCALE = 0.5;

function estimateRemainingRequests(input: {
	readonly completedBoundaryRequestCounts: readonly number[];
	readonly remainingBoundaries: number;
	readonly scale: number;
	readonly standardDeviationK: number;
	readonly contextTokens: number;
	readonly contextWindowTokens: number | null;
	readonly averageContextTokenIncrement: number | null;
}): RequestHorizonEstimate {
	const mean =
		input.completedBoundaryRequestCounts.reduce((total, count) => total + count, 0) /
		Math.max(1, input.completedBoundaryRequestCounts.length);
	let lowerBound = mean;
	if (input.standardDeviationK !== 0) {
		if (input.completedBoundaryRequestCounts.length < MINIMUM_VARIANCE_SAMPLES) {
			lowerBound *= SMALL_SAMPLE_SCALE;
		} else {
			const variance = input.completedBoundaryRequestCounts.reduce(
				(total, count) => total + (count - mean) ** 2,
				0,
			);
			const deviation = Math.sqrt(variance / (input.completedBoundaryRequestCounts.length - 1));
			lowerBound = Math.max(0, mean - input.standardDeviationK * deviation);
		}
	}

	const unboundedExpectedRemainingRequests =
		1 + Math.floor(lowerBound * Math.max(0, input.remainingBoundaries) * input.scale);
	const windowRequestUpperBound =
		input.contextWindowTokens === null ||
		input.averageContextTokenIncrement === null ||
		input.averageContextTokenIncrement <= 0
			? null
			: Math.max(
					0,
					Math.floor((input.contextWindowTokens - input.contextTokens) / input.averageContextTokenIncrement),
				);

	return {
		completedBoundaryRequestCounts: [...input.completedBoundaryRequestCounts],
		requestsPerBoundaryMean: mean,
		requestsPerBoundaryLowerBound: lowerBound,
		unboundedExpectedRemainingRequests,
		averageContextTokenIncrement: input.averageContextTokenIncrement,
		windowRequestUpperBound,
		expectedRemainingRequests:
			windowRequestUpperBound === null
				? unboundedExpectedRemainingRequests
				: Math.min(unboundedExpectedRemainingRequests, windowRequestUpperBound),
	};
}

function decideCompaction(input: {
	readonly writeTokens: number;
	readonly archiveTokens: number;
	readonly memoTokens: number;
	readonly contextTokens: number;
	readonly completedBoundaryRequestCounts: readonly number[] | null;
	readonly remainingBoundaries: number;
	readonly averageContextTokenIncrement: number | null;
	readonly contextWindowTokens: number | null;
	readonly priorCompactionCount: number;
	readonly carriedDebtTokens: number;
	readonly cacheDebtRepaymentTokens: number;
	readonly cacheWriteReadRatio: number | null;
	readonly economics: CompactionEconomics;
}): CompactionDecision {
	const horizon =
		input.completedBoundaryRequestCounts === null
			? null
			: estimateRemainingRequests({
					completedBoundaryRequestCounts: input.completedBoundaryRequestCounts,
					remainingBoundaries: input.remainingBoundaries,
					scale: input.economics.remainingRequestScale,
					standardDeviationK: input.economics.remainingRequestStddevK,
					contextTokens: input.contextTokens,
					contextWindowTokens: input.contextWindowTokens,
					averageContextTokenIncrement: input.averageContextTokenIncrement,
				});
	const savingTokens = input.archiveTokens - input.memoTokens;
	const incrementalCacheCostRatio =
		input.cacheWriteReadRatio === null ? null : Math.max(0, input.cacheWriteReadRatio - 1);
	const breakevenRequests =
		savingTokens > 0 && incrementalCacheCostRatio !== null
			? (input.writeTokens * incrementalCacheCostRatio) / savingTokens
			: null;
	const combinedBreakevenRequests =
		savingTokens > 0 && incrementalCacheCostRatio !== null
			? (input.carriedDebtTokens + input.writeTokens * incrementalCacheCostRatio) / savingTokens
			: null;
	const firstCompaction = input.priorCompactionCount === 0;
	const effectiveHorizonRequests =
		horizon === null
			? null
			: firstCompaction
				? Math.min(
						horizon.expectedRemainingRequests * input.economics.firstCompactionRequestScale,
						horizon.windowRequestUpperBound ?? Number.POSITIVE_INFINITY,
					)
				: horizon.expectedRemainingRequests;
	const windowProtection =
		input.contextWindowTokens !== null &&
		input.contextTokens >= input.contextWindowTokens - input.economics.windowReserveTokens;
	const baseEconomic =
		horizon !== null &&
		horizon.expectedRemainingRequests > 0 &&
		breakevenRequests !== null &&
		breakevenRequests <= horizon.expectedRemainingRequests;
	const firstEconomic =
		firstCompaction &&
		effectiveHorizonRequests !== null &&
		effectiveHorizonRequests > 0 &&
		breakevenRequests !== null &&
		breakevenRequests <= effectiveHorizonRequests;
	const subsequentMarginOpen =
		!firstCompaction &&
		horizon !== null &&
		breakevenRequests !== null &&
		breakevenRequests * input.economics.subsequentCompactionMargin <= horizon.expectedRemainingRequests;
	const carriedDebtGateOpen =
		!firstCompaction &&
		horizon !== null &&
		combinedBreakevenRequests !== null &&
		combinedBreakevenRequests <= horizon.expectedRemainingRequests;
	const economic = firstCompaction ? firstEconomic : baseEconomic && subsequentMarginOpen && carriedDebtGateOpen;
	const compressible = savingTokens > 0;
	const compact = compressible && (windowProtection || economic);

	return {
		writeTokens: input.writeTokens,
		archiveTokens: input.archiveTokens,
		memoTokens: input.memoTokens,
		contextTokens: input.contextTokens,
		...(horizon ?? {
			completedBoundaryRequestCounts: null,
			requestsPerBoundaryMean: null,
			requestsPerBoundaryLowerBound: null,
			unboundedExpectedRemainingRequests: null,
			averageContextTokenIncrement: input.averageContextTokenIncrement,
			windowRequestUpperBound: null,
			expectedRemainingRequests: null,
		}),
		breakevenRequests,
		combinedBreakevenRequests,
		effectiveHorizonRequests,
		cacheWriteReadRatio: input.cacheWriteReadRatio,
		incrementalCacheCostRatio,
		priorCompactionCount: input.priorCompactionCount,
		carriedDebtTokens: input.carriedDebtTokens,
		cacheDebtRepaymentTokens: input.cacheDebtRepaymentTokens,
		compact,
		reason: !compressible
			? "non_positive_saving"
			: windowProtection
				? "window_protection"
				: economic
					? "economic"
					: horizon === null
						? "horizon_unavailable"
						: breakevenRequests === null
							? "cache_ratio_unavailable"
							: !firstCompaction && baseEconomic && !subsequentMarginOpen
								? "deferred_subsequent_margin"
								: !firstCompaction && baseEconomic && !carriedDebtGateOpen
									? "deferred_carried_debt"
									: "deferred_economic",
	};
}

// ── End OCC Economics ─────────────────────────────────────────────────────

// ── Constants ─────────────────────────────────────────────────────────────

const STATE_ENTRY_TYPE = "beads-compaction-trigger-state-v1";
const DEFAULT_KEEP_RECENT_TOKENS = 20_000;
const DEFAULT_NATIVE_SUMMARY_TOKEN_ESTIMATE = 1_000;
const BOUNDARY_COMPACTION_INSTRUCTIONS =
	"Preserve completed work, verification results, important decisions, and remaining work.";
const POST_COMPACTION_MESSAGE =
	"Context compaction complete (triggered by task boundary). Continue with remaining work.";

// ── State ─────────────────────────────────────────────────────────────────

interface TriggerState {
	version: 1;
	requestCount: number;
	lastBoundaryRequestCount: number;
	completedBoundaryRequestCounts: number[];
	lastContextTokens: number | null;
	positiveContextDeltaTotal: number;
	positiveContextDeltaCount: number;
	nativeCompactionCount: number;
	cacheDebtTokens: number;
	cacheDebtRepaymentTokens: number;
}

function initialState(): TriggerState {
	return {
		version: 1,
		requestCount: 0,
		lastBoundaryRequestCount: 0,
		completedBoundaryRequestCounts: [],
		lastContextTokens: null,
		positiveContextDeltaTotal: 0,
		positiveContextDeltaCount: 0,
		nativeCompactionCount: 0,
		cacheDebtTokens: 0,
		cacheDebtRepaymentTokens: 0,
	};
}

// ── Helpers ───────────────────────────────────────────────────────────────

function tokenEstimate(text: string): number {
	return Math.ceil(Buffer.byteLength(text) / 4);
}

function validPositiveInteger(value: unknown): value is number {
	return typeof value === "number" && Number.isSafeInteger(value) && value > 0;
}

// ── Extension ─────────────────────────────────────────────────────────────

export default function (pi: ExtensionAPI): void {
	const cacheWriteReadRatio = process.env.PI_CACHE_WRITE_READ_RATIO
		? parseFloat(process.env.PI_CACHE_WRITE_READ_RATIO)
		: null;
	if (cacheWriteReadRatio !== null && (!Number.isFinite(cacheWriteReadRatio) || cacheWriteReadRatio < 0)) {
		throw new Error("PI_CACHE_WRITE_READ_RATIO must be a finite non-negative number");
	}

	let state: TriggerState = initialState();
	let boundaryDetected = false;
	let selected: CompactionDecision | null = null;
	let compactionInFlight = false;
	let activeDebt: { debtTokens: number; repaymentTokens: number } | null = null;

	// Restore state from session entries on start / after tree navigation
	function restoreState(ctx: any): void {
		try {
			const entries = ctx.sessionManager?.getBranch?.() ?? [];
			for (let i = entries.length - 1; i >= 0; i--) {
				const entry = entries[i];
				if (entry?.type === "custom" && entry.customType === STATE_ENTRY_TYPE) {
					const d = entry.data;
					if (d && d.version === 1) {
						state = {
							version: 1,
							requestCount: d.requestCount ?? 0,
							lastBoundaryRequestCount: d.lastBoundaryRequestCount ?? 0,
							completedBoundaryRequestCounts: Array.isArray(d.completedBoundaryRequestCounts)
								? [...d.completedBoundaryRequestCounts]
								: [],
							lastContextTokens: d.lastContextTokens ?? null,
							positiveContextDeltaTotal: d.positiveContextDeltaTotal ?? 0,
							positiveContextDeltaCount: d.positiveContextDeltaCount ?? 0,
							nativeCompactionCount: d.nativeCompactionCount ?? 0,
							cacheDebtTokens: d.cacheDebtTokens ?? 0,
							cacheDebtRepaymentTokens: d.cacheDebtRepaymentTokens ?? 0,
						};
						return;
					}
				}
			}
		} catch {
			// Fall through to initial state
		}
		state = initialState();
	}

	function saveState(): void {
		try {
			pi.appendEntry(STATE_ENTRY_TYPE, { ...state });
		} catch { /* never crash the host */ }
	}

	// ── Event handlers ──────────────────────────────────────────────────

	pi.on("session_start", async (_event, ctx) => {
		restoreState(ctx);
		boundaryDetected = false;
		selected = null;
		compactionInFlight = false;
		activeDebt = null;
	});

	pi.on("before_provider_request", async (_event, ctx) => {
		const usage = (ctx as any).getContextUsage?.();
		const contextTokens = validPositiveInteger(usage?.tokens) ? usage.tokens : 0;
		if (contextTokens <= 0) return;

		const delta = state.lastContextTokens === null ? 0 : contextTokens - state.lastContextTokens;
		const cacheDebtTokens = Math.max(0, state.cacheDebtTokens - state.cacheDebtRepaymentTokens);
		state = {
			...state,
			requestCount: state.requestCount + 1,
			lastContextTokens: contextTokens,
			positiveContextDeltaTotal: state.positiveContextDeltaTotal + Math.max(0, delta),
			positiveContextDeltaCount: state.positiveContextDeltaCount + (delta > 0 ? 1 : 0),
			cacheDebtTokens,
			cacheDebtRepaymentTokens: cacheDebtTokens === 0 ? 0 : state.cacheDebtRepaymentTokens,
		};
		saveState();
	});

	pi.on("tool_call", async (event) => {
		if ((event as any).toolName !== "bash") return;
		const cmd = ((event as any).input as any)?.command ?? "";

		// Detect bd close (with optional flags before subcommand)
		const closeMatch = cmd.match(/bd\s+(?:-\S+\s+)*close\s+(\S+)/);
		if (!closeMatch) return;

		// Record boundary: interval = requests since last boundary
		const interval = Math.max(0, state.requestCount - state.lastBoundaryRequestCount);
		state = {
			...state,
			lastBoundaryRequestCount: state.requestCount,
			completedBoundaryRequestCounts: [...state.completedBoundaryRequestCounts, interval],
		};
		boundaryDetected = true;
		saveState();
	});

	// Cancel pending tree operations while compaction is in flight
	pi.on("session_before_tree" as any, async () => {
		if (compactionInFlight) return { cancel: true };
	});

	pi.on("turn_end", async (_event, ctx) => {
		if (!boundaryDetected || selected) return;
		boundaryDetected = false;

		// Gather context metrics
		const usage = (ctx as any).getContextUsage?.();
		const writeTokens = validPositiveInteger(usage?.tokens) ? usage.tokens : 0;
		if (writeTokens <= 0) return;

		const systemPrompt = (ctx as any).getSystemPrompt?.() ?? "";
		const fixedTokens = tokenEstimate(systemPrompt);
		const archiveTokens = Math.max(0, writeTokens - fixedTokens - DEFAULT_KEEP_RECENT_TOKENS);
		const contextWindowTokens = validPositiveInteger(usage?.contextWindow)
			? usage.contextWindow
			: validPositiveInteger((ctx as any).model?.contextWindow)
				? (ctx as any).model.contextWindow
				: null;
		const averageContextTokenIncrement =
			state.positiveContextDeltaCount === 0
				? null
				: state.positiveContextDeltaTotal / state.positiveContextDeltaCount;

		const decision = decideCompaction({
			writeTokens,
			archiveTokens,
			memoTokens: DEFAULT_NATIVE_SUMMARY_TOKEN_ESTIMATE,
			contextTokens: writeTokens,
			completedBoundaryRequestCounts: state.completedBoundaryRequestCounts,
			remainingBoundaries: 0, // v1: unknown without plan; yields floor of 1 expected request
			averageContextTokenIncrement,
			contextWindowTokens,
			priorCompactionCount: state.nativeCompactionCount,
			carriedDebtTokens: state.cacheDebtTokens,
			cacheDebtRepaymentTokens: state.cacheDebtRepaymentTokens,
			cacheWriteReadRatio,
			economics: DEFAULT_COMPACTION_ECONOMICS,
		});

		if (!decision.compact) return;

		selected = decision;
		(ctx as any).abort?.();
	});

	pi.on("agent_settled", async (_event, ctx) => {
		const pending = selected;
		selected = null;

		if (!pending) return;
		if (!(ctx as any).isIdle?.()) {
			// Agent not idle yet — re-queue for next settled
			selected = pending;
			return;
		}

		activeDebt = {
			debtTokens: pending.writeTokens * (pending.incrementalCacheCostRatio ?? 0),
			repaymentTokens: Math.max(0, pending.archiveTokens - pending.memoTokens),
		};

		try {
			compactionInFlight = true;
			await new Promise<void>((resolve) => {
				let finished = false;
				const finish = () => {
					if (finished) return;
					finished = true;
					resolve();
				};
				(ctx as any).compact({
					customInstructions: BOUNDARY_COMPACTION_INSTRUCTIONS,
					onComplete: () => finish(),
					onError: () => finish(),
				});
			});
			compactionInFlight = false;

			// Trigger a continuation turn so the agent resumes work
			pi.sendMessage(
				{ content: POST_COMPACTION_MESSAGE, display: false },
				{ triggerTurn: true },
			);
		} catch {
			compactionInFlight = false;
			activeDebt = null;
		}
	});

	pi.on("session_compact", async (_event, ctx) => {
		const debt = activeDebt ?? { debtTokens: 0, repaymentTokens: 0 };
		activeDebt = null;

		state = {
			...state,
			lastContextTokens: null,
			positiveContextDeltaTotal: 0,
			positiveContextDeltaCount: 0,
			nativeCompactionCount: state.nativeCompactionCount + 1,
			cacheDebtTokens: Math.max(0, debt.debtTokens),
			cacheDebtRepaymentTokens: Math.max(0, debt.repaymentTokens),
		};
		boundaryDetected = false;
		selected = null;
		saveState();
	});

	pi.on("session_shutdown", async () => {
		boundaryDetected = false;
		selected = null;
		compactionInFlight = false;
		activeDebt = null;
	});
}
