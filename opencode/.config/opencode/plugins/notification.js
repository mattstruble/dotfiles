// notification — OpenCode plugin
// Desktop notification when OpenCode goes idle (macOS only).

export const NotificationPlugin = async ({ $ }) => {
  return {
    event: async ({ event }) => {
      if (event.type === "session.idle") {
        try {
          await $`osascript -e 'display notification "OpenCode is waiting" with title "OpenCode"'`;
        } catch { /* non-macOS or permission denied */ }
      }
    },
  };
};
