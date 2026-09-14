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

  readonly property int refreshIntervalMs: 300000

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string usageDir: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/omarchy/agents/usage"
  readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "").replace(/\/$/, "")

  function refresh() {
    if (!cursorCollector.running)
      cursorCollector.running = true;
  }

  Component.onCompleted: mkdirProcess.running = true

  Process {
    id: mkdirProcess
    command: ["mkdir", "-p", root.usageDir]
    onExited: function(exitCode) {
      if (exitCode !== 0)
        console.warn("agent-usage-cursor: could not create " + root.usageDir);
      root.refresh();
    }
  }

  Timer {
    interval: root.refreshIntervalMs
    running: true
    repeat: true
    triggeredOnStart: false
    onTriggered: root.refresh()
  }

  Process {
    id: cursorCollector
    property string agent: "cursor"
    command: ["python3", root.pluginDir + "/collectors/omarchy-agent-usage-cursor"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.publish(cursorCollector.agent, text, cursorWriter)
    }
    onExited: function(exitCode) {
      if (exitCode !== 0)
        console.warn("agent-usage-cursor: cursor collector exited " + exitCode);
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
    } else {
      console.warn("agent-usage-cursor: invalid record from " + agent + " collector");
    }
  }

  FileView {
    id: cursorWriter
    path: root.usageDir + "/cursor.json"
    watchChanges: false
    atomicWrites: true
    printErrors: true
  }
}
