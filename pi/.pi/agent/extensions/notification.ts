import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  const setTitle = (title: string) => {
    process.stdout.write(`\x1b]2;${title}\x07`);
  };

  pi.on("agent_start", async () => {
    setTitle("⏳ pi");
  });

  pi.on("agent_settled", async () => {
    setTitle("✓ pi");
  });

  pi.on("session_shutdown", async () => {
    setTitle("pi");
  });
}
