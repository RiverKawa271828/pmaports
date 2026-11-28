// RingLight.qml — settings-style mode list: tap the row to preview (10s),
// the Switch arms the boot animation (exactly one stays on; "Lights off"
// un-arms everything). All state lives in ringctl.bootMode (C++ property,
// NOTIFY-driven) — never call ringctl methods at QML-load time.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
	id: root
	width: 360
	height: 640
	visible: true
	title: qsTr("Meizu20-Tools")
	Component.onCompleted: ringctl.refresh()

	ListModel {
		id: modes
		ListElement { key: "chase";  name: qsTr("Chase");  desc: qsTr("Symmetric pair, clockwise") }
		ListElement { key: "flow";   name: qsTr("Flow");   desc: qsTr("Comet with a dark gap") }
		ListElement { key: "breath"; name: qsTr("Breath"); desc: qsTr("Stepped sine, dark hold") }
		ListElement { key: "alternate"; name: qsTr("Alternate"); desc: qsTr("1/3/5 ↔ 2/4/6 blink") }
		ListElement { key: "breath2"; name: qsTr("Breath2"); desc: qsTr("1/3/5 vs 2/4/6 anti-phase breath") }
		ListElement { key: "random"; name: qsTr("Random"); desc: qsTr("Router-style random blinks") }
	}

	ColumnLayout {
		anchors.fill: parent
		anchors.margins: 20
		spacing: 12

		Label {
			Layout.fillWidth: true
			horizontalAlignment: Text.AlignHCenter
			font.pixelSize: 26
			font.bold: true
			text: qsTr("Meizu20-Tools")
		}
		Label {
			Layout.fillWidth: true
			horizontalAlignment: Text.AlignHCenter
			font.pixelSize: 14
			text: ringctl.bootMode === "off"
				? qsTr("Boot animation: off")
				: qsTr("Boot animation: %1").arg(ringctl.bootMode)
		}
		Label {
			Layout.fillWidth: true
			horizontalAlignment: Text.AlignHCenter
			wrapMode: Text.Wrap
			opacity: 0.7
			text: qsTr("Tap a mode to preview it for 10 seconds. The switch arms it for boot — arming and Lights off both ask for your password.")
		}

		Repeater {
			model: modes
			delegate: RowLayout {
				Layout.fillWidth: true
				spacing: 8

				Item {
					Layout.fillWidth: true
					Layout.preferredHeight: 72
					MouseArea {
						anchors.fill: parent
						onClicked: ringctl.preview(key)
					}
					ColumnLayout {
						anchors.fill: parent
						anchors.leftMargin: 12
						anchors.verticalCenter: parent.verticalCenter
						Label { text: name; font.pixelSize: 18; font.bold: true }
						Label { text: desc; opacity: 0.6; font.pixelSize: 13 }
					}
				}
				Switch {
					Layout.alignment: Qt.AlignVCenter
					checked: ringctl.bootMode === key
					onToggled: {
						if (checked) {
							ringctl.select(key)
						} else {
							/* unchecking must not stick: exactly one stays on
							 * (or none, after Lights off). re-arm the binding
							 * (imperative writes break it) */
							checked = Qt.binding(function() { return ringctl.bootMode === key })
						}
					}
				}
			}
		}

		Item { Layout.fillHeight: true }

		Button {
			Layout.fillWidth: true
			Layout.preferredHeight: 60
			text: qsTr("Lights off")
			onClicked: ringctl.lightsOff()
		}
	}
}
