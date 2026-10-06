import { Type } from "@earendil-works/pi-ai";
import { defineTool, type ExtensionAPI } from "@earendil-works/pi-coding-agent";

// tool-shelf — Pi extension
// Tool schema budget: these tools had zero direct calls across 868 sessions.
// They stay active and reachable via codemode (tools.<name>, describeTool)
// but are dropped from the model's request schema.

const SHELF = [
  "source_check",
  "bg_wait",
  "workflow_control",
  "subagent_supervisor",
  "list_mcp_resources",
  "list_mcp_resource_templates",
  "read_mcp_resource",
];

export default function (pi: ExtensionAPI) {
  pi.registerTool(
    defineTool({
      name: "tool_shelf",
      label: "Tool shelf",
      description: "Inert marker that hides rarely used tool schemas.",
      parameters: Type.Object({}),
      prepareLoadout(loadout: { declared: Array<{ name: string }> }) {
        const present = loadout.declared.map((t) => t.name);
        return {
          hiddenDeclarations: ["tool_shelf", ...SHELF.filter((n) => present.includes(n))],
        };
      },
      async execute() {
        return { content: [{ type: "text" as const, text: "" }], details: {} };
      },
    } as any),
  );

  pi.on("before_agent_start", async (event) => {
    const registered = new Set(pi.getAllTools().map((t: { name: string }) => t.name));
    const names = SHELF.filter((n) => registered.has(n));
    if (names.length === 0) return;
    return {
      systemPrompt:
        event.systemPrompt +
        "\n\nCall only via codemode (describeTool(name) for the schema): " +
        names.join(", "),
    };
  });
}
