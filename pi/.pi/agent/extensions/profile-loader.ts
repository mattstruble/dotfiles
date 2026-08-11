import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Reads PI_SKILL_PATHS (colon-separated) and contributes them as skill search paths.
// Set via direnv: export PI_SKILL_PATHS="/path/to/skills:/another/path"
export default function (pi: ExtensionAPI) {
  pi.on("resources_discover", async () => {
    const paths = process.env.PI_SKILL_PATHS?.split(":");
    if (!paths || paths.length === 0) return;

    const filtered = paths.filter((p) => p.length > 0);
    if (filtered.length === 0) return;

    return { skillPaths: filtered };
  });
}
