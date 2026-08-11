import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Pattern-to-skill mapping — add entries here to enforce new skills
const skillPatterns: Array<{ pattern: RegExp; skill: string; directive: string }> = [
  {
    pattern: /\b(commit|amend|git add|stage|unstage|git push)\b/i,
    skill: "git-commit",
    directive: "Load and follow skill:git-commit BEFORE any git commit operations.",
  },
  {
    pattern: /\b(pull request|create.*pr|open.*pr|gh pr)\b/i,
    skill: "git-pr",
    directive: "Load and follow skill:git-pr for this PR workflow.",
  },
  {
    pattern: /\b(implement|refactor|design|architect|write.*code|add.*feature|build.*feature)\b/i,
    skill: "software-design",
    directive: "Load and follow skill:software-design for this task.",
  },
  {
    pattern: /\b(write.*test|add.*test|test.*coverage|unit test|integration test|tdd)\b/i,
    skill: "test-design",
    directive: "Load and follow skill:test-design for this task.",
  },
  {
    pattern: /\b(dockerfile|docker.compose|docker compose|container|build.*image|containerize)\b/i,
    skill: "docker",
    directive: "Load and follow skill:docker for this task.",
  },
  {
    pattern: /\b(helm|helm chart|values\.yaml|helmfile|helm template)\b/i,
    skill: "helm",
    directive: "Load and follow skill:helm for this task.",
  },
  {
    pattern: /\b(nix|flake\.nix|derivation|nixos|nix-darwin|darwin-rebuild|home-manager|nixpkgs)\b/i,
    skill: "nix",
    directive: "Load and follow skill:nix for this task.",
  },
  {
    pattern: /\b(python|\.py|pydantic|fastapi|django|flask|pytest|pyproject)\b/i,
    skill: "python-design",
    directive: "Load and follow skill:python-design for this task.",
  },
  {
    pattern: /\b(api design|rest api|grpc|openapi|swagger|resource model|endpoint design|api spec)\b/i,
    skill: "api-design",
    directive: "Load and follow skill:api-design for this task.",
  },
  {
    pattern: /\b(code review|review.*pr|review.*diff|review.*changes|lgtm)\b/i,
    skill: "code-reviewer",
    directive: "Load and follow skill:code-reviewer for this review.",
  },
];

export default function (pi: ExtensionAPI) {
  // Inject skill directives into system prompt when prompt matches patterns
  pi.on("before_agent_start", async (event) => {
    const matches = skillPatterns.filter((sp) => sp.pattern.test(event.prompt));
    if (matches.length === 0) return;

    const directives = matches.map((m) => m.directive).join("\n");
    return {
      systemPrompt: event.systemPrompt + "\n\n## Required Skills\n" + directives,
    };
  });

  // Block git commit if skill:git-commit hasn't been loaded
  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName !== "bash") return;
    const cmd = (event.input as { command?: string }).command ?? "";
    if (!/git\s+commit/.test(cmd)) return;

    const sysPrompt = await ctx.getSystemPrompt();
    if (!sysPrompt.includes("skill:git-commit")) {
      return {
        block: true,
        reason: "Load skill:git-commit before committing. Use /skill:git-commit or read the SKILL.md file.",
      };
    }
  });
}
