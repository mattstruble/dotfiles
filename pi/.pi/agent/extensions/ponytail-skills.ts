import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { join } from "node:path";

// Always register ponytail skills path, independent of profile-loader.
// This ensures ponytail sub-skills (audit, debt, gain, help, review) are
// discoverable regardless of PI_SKILL_PATHS or direnv configuration.

export default function (pi: ExtensionAPI): void {
  pi.on("resources_discover", async () => {
    const ponytailSkills = join(process.env.HOME ?? "", ".local/share/ponytail/skills");
    return { skillPaths: [ponytailSkills] };
  });
}
