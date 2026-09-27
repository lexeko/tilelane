.pragma library

var nativeWindow = {
  address: "0xaaa", title: "Editor — notes", waylandAppId: "org.example.Editor.desktop",
  className: "editor", initialClass: "editor", pid: 101,
  workspaceId: 2, workspaceName: "2", monitorId: 0, monitorName: "DP-1",
  active: true, urgent: false, minimized: false, fullscreen: false,
  maximized: true, floating: false, mapped: true, hidden: false,
  xwayland: false, hasWaylandHandle: true, generation: 1
}

var xwaylandWindow = {
  address: "0xbbb", title: "Legacy dialog", waylandAppId: "",
  className: "Legacy.App", initialClass: "legacy-app", pid: 202,
  workspaceId: 3, workspaceName: "3", monitorId: 1, monitorName: "HDMI-A-1",
  active: false, urgent: true, minimized: false, fullscreen: true,
  maximized: false, floating: true, mapped: true, hidden: false,
  xwayland: true, hasWaylandHandle: false, generation: 2
}

function clone(value) {
  return JSON.parse(JSON.stringify(value))
}
