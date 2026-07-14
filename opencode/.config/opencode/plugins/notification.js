// notification — kitty tab title indicator
// 󰂞 = permission needed, 󰸞 = idle/done

export const NotificationPlugin = async ({ $ }) => {
  const childSessions = new Set();
  let state = "active";
  const windowId = process.env.KITTY_WINDOW_ID;

  async function setTitle(icon) {
    const raw = JSON.parse(await $`kitty @ ls`.text());
    let title = "OC";
    const wid = parseInt(windowId);
    for (const osWin of raw) {
      for (const tab of osWin.tabs) {
        if (tab.windows.some((w) => w.id === wid)) {
          title = tab.title;
          break;
        }
      }
    }
    await $`kitty @ set-tab-title --match window_id:${windowId} ${icon + " " + title}`;
  }

  async function clearTitle() {
    await $`kitty @ set-tab-title --match window_id:${windowId} ""`;
  }

  return {
    event: async ({ event }) => {
      try {
        if (
          event.type === "session.created" &&
          event.properties?.info?.parentID
        ) {
          childSessions.add(event.properties.sessionID);
          return;
        }

        const sid = event.properties?.sessionID;
        if (sid && childSessions.has(sid)) return;

        if (event.type === "permission.asked") {
          state = "permission";
          await setTitle("󰂞");
        } else if (event.type === "session.idle" && state !== "permission" && state !== "idle") {
          state = "idle";
          await setTitle("󰸞");
        } else if (state !== "active" && event.type !== "session.idle") {
          state = "active";
          await clearTitle();
        }
      } catch {}
    },
  };
};
