import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root

    readonly property var launcherList: parseLaunchers(Plasmoid.configuration.launchers)
    readonly property bool horizontal: Plasmoid.formFactor !== PlasmaCore.Types.Vertical
    readonly property var myKeys: launcherList.map(appKey)

    function parseLaunchers(s) {
        if (!s) return [];
        return ("" + s).split(",").map(function (x) { return x.trim(); })
                       .filter(function (x) { return x.length > 0; });
    }

    // Reduce any launcher URL to a comparable app key: strip path + scheme, drop
    // ".desktop". applications:org.kde.kate.desktop -> "org.kde.kate".
    function appKey(u) {
        if (!u) return "";
        var s = ("" + u).split("?")[0];
        s = s.split("/").pop();          // strip path
        s = s.split(":").pop();          // strip scheme (applications:, preferred:)
        return s.replace(/\.desktop$/i, "").toLowerCase();
    }

    function isMine(url) { return myKeys.indexOf(appKey(url)) !== -1; }

    // Single task model carrying our launchers. separateLaunchers:false folds a
    // launcher into its window once the app runs, so there is exactly one row per
    // app: a launcher row (not running) or a window row (running). We decide
    // visibility per row from its (reactive) model roles — showing a row only when
    // it's a launcher (not running) or a MINIMIZED window, and only for our apps.
    TaskManager.TasksModel {
        id: tasks
        launcherList: root.launcherList
        separateLaunchers: false
        groupMode: TaskManager.TasksModel.GroupDisabled
    }

    preferredRepresentation: fullRepresentation

    fullRepresentation: GridLayout {
        id: strip
        rowSpacing: Kirigami.Units.smallSpacing
        columnSpacing: Kirigami.Units.smallSpacing
        flow: root.horizontal ? GridLayout.LeftToRight : GridLayout.TopToBottom
        rows: root.horizontal ? 1 : -1
        columns: root.horizontal ? -1 : 1

        Repeater {
            model: tasks
            delegate: Item {
                id: cell
                required property int index
                required property var model

                // show for our apps only, when either not running (launcher row) or
                // running-and-minimized (a minimized window row); hide a visible window.
                readonly property bool shown: root.isMine(model.LauncherUrl)
                    && (model.IsLauncher === true
                        || (model.IsWindow === true && model.IsMinimized === true))
                visible: shown

                readonly property real thickness: root.horizontal ? strip.height : strip.width
                readonly property real box: (Plasmoid.configuration.iconSize > 0)
                    ? Plasmoid.configuration.iconSize : thickness
                Layout.preferredWidth: shown ? box : 0
                Layout.preferredHeight: shown ? box : 0
                Layout.fillHeight: root.horizontal
                Layout.fillWidth: !root.horizontal

                Kirigami.Icon {
                    anchors.fill: parent
                    anchors.margins: Math.round(Kirigami.Units.smallSpacing / 2)
                    source: cell.model.decoration
                    active: mouse.containsMouse
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // Launcher row -> launches; minimized-window row -> restores/raises.
                    onClicked: tasks.requestActivate(tasks.index(cell.index, 0))
                }
            }
        }
    }
}
