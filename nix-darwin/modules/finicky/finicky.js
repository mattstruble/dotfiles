// Finicky v4 routing rules. `settings` is prepended by nix-darwin/modules/finicky.nix.
//
// Web links are rewritten to each app's URL scheme and handed to the app, so they
// skip the browser's "Open in app?" redirect page. Links an app sends to the
// browser itself ("Open in browser", SSO) are left alone to avoid bouncing back.

const hostIs = (url, domain) =>
  url.hostname === domain || url.hostname.endsWith("." + domain);

const openedBy = (options, bundleId) =>
  !!(options && options.opener && options.opener.bundleId === bundleId);

// https://<host>.zoom.us/j/<id>?pwd=<pwd> -> zoommtg://<host>.zoom.us/join?...
const zoomRewrite = (url) => {
  const confno = url.pathname.match(/^\/j\/(\d+)/)[1];
  const pwd = url.searchParams.get("pwd");
  return (
    "zoommtg://" + url.hostname + "/join?action=join&confno=" + confno +
    (pwd ? "&pwd=" + encodeURIComponent(pwd) : "")
  );
};

// Workspace-subdomain links (<workspace>.slack.com/archives/...) carry no team ID,
// so they need an entry in settings.slackTeams; unmapped ones stay in the browser.
const slackDeepLink = (url) => {
  let m = url.pathname.match(/^\/client\/([TE][A-Z0-9]+)\/([CDG][A-Z0-9]+)\/?$/);
  if (url.hostname === "app.slack.com" && m) {
    return "slack://channel?team=" + m[1] + "&id=" + m[2];
  }

  m = url.pathname.match(/^\/archives\/([CDG][A-Z0-9]+)(?:\/p(\d{10})(\d{6}))?\/?$/);
  const team = settings.slackTeams[url.hostname.replace(/\.slack\.com$/, "")];
  if (!m || !team) return null;

  let link = "slack://channel?team=" + team + "&id=" + m[1];
  if (m[2]) link += "&message=" + m[2] + "." + m[3];
  const thread = url.searchParams.get("thread_ts");
  if (thread) link += "&thread_ts=" + thread;
  return link;
};

// Account and marketing pages on notion.so stay in the browser.
const notionNonPage =
  /^\/(login|signup|logout|oauth|install-integration|integrations|native|desktop|api|product|pricing|help)\b/;

const spotifyPath =
  /^\/(?:intl-[a-z-]+\/)?(track|album|artist|playlist|episode|show)\/([A-Za-z0-9]+)/;

// `rewrite` turns a matching https link into the app's scheme; `scheme` routes that
// result to the app. Apps without `rewrite` accept https links directly.
const apps = {
  slack: {
    bundleId: "com.tinyspeck.slackmacgap",
    scheme: "slack",
    match: (url) => hostIs(url, "slack.com") && slackDeepLink(url) !== null,
    rewrite: slackDeepLink,
  },
  zoom: {
    bundleId: "us.zoom.xos",
    scheme: "zoommtg",
    match: (url) => hostIs(url, "zoom.us") && /^\/j\/\d+/.test(url.pathname),
    rewrite: zoomRewrite,
  },
  notion: {
    bundleId: "notion.id",
    scheme: "notion",
    match: (url) =>
      (url.hostname === "www.notion.so" || url.hostname === "notion.so") &&
      url.pathname !== "/" &&
      !notionNonPage.test(url.pathname),
    rewrite: (url) => "notion://www.notion.so" + url.pathname + url.search + url.hash,
  },
  teams: {
    bundleId: "com.microsoft.teams2",
    scheme: "msteams",
    match: (url) =>
      ["teams.microsoft.com", "teams.cloud.microsoft", "teams.live.com"].includes(url.hostname) &&
      /^\/(l|meet)\//.test(url.pathname),
    rewrite: (url) => "msteams://" + url.hostname + url.pathname + url.search + url.hash,
  },
  spotify: {
    bundleId: "com.spotify.client",
    scheme: "spotify",
    match: (url) => url.hostname === "open.spotify.com" && spotifyPath.test(url.pathname),
    rewrite: (url) => {
      const m = url.pathname.match(spotifyPath);
      return "spotify:" + m[1] + ":" + m[2];
    },
  },
  figma: {
    bundleId: "com.figma.Desktop",
    match: (url) =>
      hostIs(url, "figma.com") &&
      /^\/(file|design|board|proto|slides|deck)\//.test(url.pathname),
  },
};

const enabled = settings.apps.map((name) => apps[name]);

const matchFrom = (app) => (url, options) =>
  app.match(url) && !openedBy(options, app.bundleId);

export default {
  defaultBrowser: settings.defaultBrowser,
  rewrite: enabled
    .filter((app) => app.rewrite)
    .map((app) => ({ match: matchFrom(app), url: app.rewrite })),
  handlers: enabled.map((app) => ({
    match: app.rewrite
      ? (url) => url.protocol === app.scheme + ":"
      : matchFrom(app),
    browser: app.bundleId,
  })),
};
