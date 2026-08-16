import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: page

    property alias cfg_launchers: launchersField.text
    property alias cfg_groupName: groupNameField.text
    property alias cfg_iconSize: iconSizeField.value

    QQC2.TextField {
        id: groupNameField
        Kirigami.FormData.label: i18n("Group name:")
        placeholderText: i18n("e.g. coding")
    }

    QQC2.TextArea {
        id: launchersField
        Kirigami.FormData.label: i18n("Launchers:")
        Layout.preferredWidth: Kirigami.Units.gridUnit * 24
        Layout.preferredHeight: Kirigami.Units.gridUnit * 8
        wrapMode: TextEdit.WrapAnywhere
        placeholderText: i18n("Comma-separated launcher URLs, e.g.\napplications:code.desktop,applications:org.kde.konsole.desktop")
    }

    QQC2.SpinBox {
        id: iconSizeField
        Kirigami.FormData.label: i18n("Icon size (px, 0 = auto):")
        from: 0
        to: 256
    }
}
