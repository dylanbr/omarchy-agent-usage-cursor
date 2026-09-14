import QtQuick
import Quickshell
import Quickshell.Io

// Feeds the built-in omarchy.agents panel with a Cursor usage record.
// The panel draws whatever lands in the usage state directory; this service
// only runs the bundled collector on a cadence and publishes its output
// there, mirroring what omarchy-agent-usage-update does for packaged
// collectors in OMARCHY_PATH/bin.
Item {
  id: root

  // Injected by omarchy-shell (the service loader).
  property var shell: null

  // Limits are cheap; event history is the expensive crawl.
  readonly property int limitsIntervalMs: 300000
  readonly property int eventsIntervalMs: 1800000

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string usageDir: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/omarchy/agents/usage"
  readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "").replace(/\/$/, "")
  readonly property string recordPath: usageDir + "/cursor.json"
  readonly property string collector: pluginDir + "/collectors/omarchy-agent-usage-cursor"

  function refreshLimits() {
    root.runCollector(["--limits-only"])
  }

  function refreshFull() {
    // --force: immediate full update (limits + usage events).
    root.runCollector(["--force"])
  }

  function runCollector(args) {
    if (cursorCollector.running)
      return
    var command = ["python3", root.collector]
    for (var i = 0; i < args.length; i++)
      command.push(args[i])
    cursorCollector.command = command
    cursorCollector.running = true
  }

  Component.onCompleted: mkdirProcess.running = true

  Process {
    id: mkdirProcess
    command: ["mkdir", "-p", root.usageDir]
    onExited: function(exitCode) {
      if (exitCode !== 0)
        console.warn("agent-usage-cursor: could not create " + root.usageDir);
      // First paint should include day/model stats, not limits alone.
      root.refreshFull();
    }
  }

  Timer {
    interval: root.limitsIntervalMs
    running: true
    repeat: true
    triggeredOnStart: false
    onTriggered: root.refreshLimits()
  }

  Timer {
    interval: root.eventsIntervalMs
    running: true
    repeat: true
    triggeredOnStart: false
    onTriggered: root.refreshFull()
  }

  Process {
    id: cursorCollector
    property string agent: "cursor"
    command: ["python3", root.collector, "--force"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.publish(cursorCollector.agent, text, cursorWriter)
    }
    onExited: function(exitCode) {
      if (exitCode !== 0)
        console.warn("agent-usage-cursor: cursor collector exited " + exitCode);
    }
  }

  // FileView's setText is asynchronous relative to chmod; delay briefly so the
  // atomic replace lands before we tighten mode to 0600 like stock collectors.
  Timer {
    id: chmodTimer
    interval: 100
    repeat: false
    onTriggered: {
      if (!chmodProcess.running)
        chmodProcess.running = true;
    }
  }

  Process {
    id: chmodProcess
    command: ["chmod", "600", root.recordPath]
    onExited: function(exitCode) {
      if (exitCode !== 0)
        console.warn("agent-usage-cursor: could not chmod cursor.json");
    }
  }

  function publish(agent, output, writer) {
    var record = null;
    try {
      record = JSON.parse(output);
    } catch (e) {
      record = null;
    }
    if (record && typeof record === "object" && record.id === agent) {
      writer.setText(output.trim() + "\n");
      chmodTimer.restart();
    } else {
      console.warn("agent-usage-cursor: invalid record from " + agent + " collector");
    }
  }

  FileView {
    id: cursorWriter
    path: root.recordPath
    watchChanges: false
    atomicWrites: true
    printErrors: true
  }
}
