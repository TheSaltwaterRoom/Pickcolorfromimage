import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs
import Pickcolorfromimage


ApplicationWindow {
    id: window
    width: 640
    height: 480
    minimumWidth: 200
    minimumHeight: 250
    visible: true
    title: qsTr("BMP 图片预览")

    ColorSampler {
        id: colorSampler
    }

    FileDialog {
        id: imageFileDialog
        title: qsTr("选择 BMP 图片")
        fileMode: FileDialog.OpenFile
        nameFilters: [qsTr("BMP 图片 (*.bmp)")]
        onAccepted: {
            if (colorSampler.loadImage(selectedFile)) {
                previewImage.source = selectedFile
            } else {
                previewImage.source = ""
                console.warn("无法读取 BMP 图片：", selectedFile)
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Rectangle {
            id: viewport
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            color: window.palette.base
            border.color: window.palette.mid

            function resetView() {
                if (previewImage.status !== Image.Ready)
                    return

                previewImage.scale = 1.0
                previewImage.x = (width - previewImage.width) / 2
                previewImage.y = (height - previewImage.height) / 2
            }

            Image {
                id: previewImage
                asynchronous: true
                smooth: false
                scale: 1.0
                transformOrigin: Item.TopLeft

                onStatusChanged: {
                    if (status === Image.Ready)
                        viewport.resetView()
                }
            }

            MouseArea {
                id: imageMouseArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                drag.target: previewImage
                drag.axis: Drag.XAndYAxis
                cursorShape: previewImage.status === Image.Ready
                             ? (pressed ? Qt.SizeAllCursor : Qt.CrossCursor)
                             : Qt.ArrowCursor

                onWheel: function(wheel) {
                    if (previewImage.status !== Image.Ready
                            || wheel.angleDelta.y === 0) {
                        return
                    }

                    const imagePoint = previewImage.mapFromItem(
                        imageMouseArea, wheel.x, wheel.y)
                    const factor = Math.pow(1.1, wheel.angleDelta.y / 120)
                    const newScale = Math.max(
                        0.1, Math.min(32.0, previewImage.scale * factor))

                    previewImage.scale = newScale
                    previewImage.x = wheel.x - imagePoint.x * newScale
                    previewImage.y = wheel.y - imagePoint.y * newScale
                    wheel.accepted = true
                }

                onClicked: function(mouse) {
                    if (previewImage.status !== Image.Ready)
                        return

                    const point = previewImage.mapFromItem(
                        imageMouseArea, mouse.x, mouse.y)
                    const pixelX = Math.floor(point.x)
                    const pixelY = Math.floor(point.y)

                    if (pixelX < 0 || pixelY < 0
                            || pixelX >= colorSampler.imageWidth
                            || pixelY >= colorSampler.imageHeight) {
                        return
                    }

                    const color = colorSampler.colorAt(pixelX, pixelY)
                    if (!color.valid)
                        return

                    console.log(
                        "Pixel:", pixelX, pixelY,
                        "RGB:", color.r, color.g, color.b,
                        "HEX:", color.hex)
                }
            }

            Label {
                anchors.centerIn: parent
                visible: previewImage.status === Image.Null
                text: qsTr("请选择一张 BMP 图片")
            }
        }

        Button {
            text: qsTr("选择 BMP 图片")
            Layout.alignment: Qt.AlignHCenter
            onClicked: imageFileDialog.open()
        }
    }
}
