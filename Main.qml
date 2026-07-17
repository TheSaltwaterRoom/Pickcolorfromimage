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

    // C++ 注册的图片读取对象，用于读取 BMP 的原始像素颜色。
    ColorSampler {
        id: colorSampler
    }

    FileDialog {
        id: imageFileDialog

        title: qsTr("选择 BMP 图片")
        fileMode: FileDialog.OpenFile
        nameFilters: [qsTr("BMP 图片 (*.bmp)")]

        onAccepted: {
            colorHexField.clear()

            /*
             * ColorSampler 用于读取像素；
             * Image 用于在界面中显示图片。
             */
            if (colorSampler.loadImage(selectedFile)) {
                osdBmpPreview.source = selectedFile
            } else {
                osdBmpPreview.source = ""
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

            // 图片超出预览区域后，隐藏超出的部分。
            clip: true

            color: window.palette.base
            border.color: window.palette.mid

            /*
             * 恢复原始缩放倍数，并让图片在 viewport 中居中。
             *
             * 居中公式：
             *
             * x = (容器宽度 - 图片宽度) / 2
             * y = (容器高度 - 图片高度) / 2
             */
            function resetView() {
                if (osdBmpPreview.status !== Image.Ready)
                    return

                osdBmpPreview.scale = 1.0
                osdBmpPreview.x =
                        (viewport.width - osdBmpPreview.width) / 2
                osdBmpPreview.y =
                        (viewport.height - osdBmpPreview.height) / 2
            }

            Image {
                id: osdBmpPreview

                asynchronous: true

                // 使用最近邻采样，放大 BMP 时保留清晰像素。
                smooth: false

                // 1.0 为原始大小。
                scale: 1.0

                /*
                 * 从图片左上角缩放。
                 *
                 * 因此图片内部某一点显示到 viewport 的公式为：
                 *
                 * viewportX = image.x + imagePointX × scale
                 * viewportY = image.y + imagePointY × scale
                 */
                transformOrigin: Item.TopLeft

                onStatusChanged: {
                    if (status === Image.Ready)
                        viewport.resetView()
                }
            }

            MouseArea {
                id: imageMouseArea

                anchors.fill: parent
                acceptedButtons: Qt.LeftButton

                /*
                 * 拖动时自动修改图片的 x、y，
                 * 允许水平和垂直方向同时移动。
                 */
                drag.target: osdBmpPreview
                drag.axis: Drag.XAndYAxis

                cursorShape: osdBmpPreview.status === Image.Ready
                             ? (pressed
                                ? Qt.SizeAllCursor
                                : Qt.CrossCursor)
                             : Qt.ArrowCursor

                /*
                 * 以鼠标位置为中心缩放图片。
                 *
                 * 缩放步骤：
                 *
                 * 1. 找到鼠标当前指向的原图坐标。
                 * 2. 根据滚轮计算新的缩放倍数。
                 * 3. 修改图片 scale。
                 * 4. 修改图片 x、y，让鼠标下的图片内容保持不动。
                 */
                onWheel: function(wheel) {
                    if (osdBmpPreview.status !== Image.Ready
                            || wheel.angleDelta.y === 0) {
                        return
                    }

                    /*
                     * 将鼠标在 imageMouseArea 中的坐标，
                     * 转换成 osdBmpPreview 图片内部坐标。
                     *
                     * 在当前场景中可以近似理解为：
                     *
                     * imagePoint.x =
                     *     (wheel.x - osdBmpPreview.x)
                     *     / osdBmpPreview.scale
                     *
                     * imagePoint.y =
                     *     (wheel.y - osdBmpPreview.y)
                     *     / osdBmpPreview.scale
                     */
                    const imagePoint = osdBmpPreview.mapFromItem(
                        imageMouseArea,
                        wheel.x,
                        wheel.y
                    )

                    /*
                     * 普通滚轮一格通常为 120。
                     *
                     * 向上滚一格：
                     * factor = 1.1^(120 / 120) = 1.1
                     *
                     * 向下滚一格：
                     * factor = 1.1^(-120 / 120)
                     *        = 1 / 1.1
                     */
                    const factor = Math.pow(
                        1.1,
                        wheel.angleDelta.y / 120
                    )

                    /*
                     * 新缩放倍数：
                     *
                     * 当前缩放倍数 × 本次缩放系数
                     *
                     * 最终限制在 0.1～32.0 之间。
                     */
                    const newScale = Math.max(
                        0.1,
                        Math.min(
                            32.0,
                            osdBmpPreview.scale * factor
                        )
                    )

                    osdBmpPreview.scale = newScale

                    /*
                     * 图片点显示到 viewport 的公式：
                     *
                     * wheel.x =
                     *     image.x + imagePoint.x × newScale
                     *
                     * wheel.y =
                     *     image.y + imagePoint.y × newScale
                     *
                     * 移项后：
                     *
                     * image.x =
                     *     wheel.x - imagePoint.x × newScale
                     *
                     * image.y =
                     *     wheel.y - imagePoint.y × newScale
                     *
                     * 这样缩放后，鼠标原来指向的图片点不会移动。
                     */
                    osdBmpPreview.x =
                            wheel.x - imagePoint.x * newScale

                    osdBmpPreview.y =
                            wheel.y - imagePoint.y * newScale

                    wheel.accepted = true
                }

                // 点击图片，读取鼠标所指像素的颜色。
                onClicked: function(mouse) {
                    if (osdBmpPreview.status !== Image.Ready)
                        return

                    /*
                     * 将鼠标坐标转换为原图坐标。
                     *
                     * 无论图片如何拖动或缩放，
                     * point 都表示图片内部的位置。
                     */
                    const point = osdBmpPreview.mapFromItem(
                        imageMouseArea,
                        mouse.x,
                        mouse.y
                    )

                    // 像素坐标必须为整数。
                    const pixelX = Math.floor(point.x)
                    const pixelY = Math.floor(point.y)

                    // 点击位置不在图片范围内。
                    if (pixelX < 0
                            || pixelY < 0
                            || pixelX >= colorSampler.imageWidth
                            || pixelY >= colorSampler.imageHeight) {
                        return
                    }

                    const color = colorSampler.colorAt(pixelX, pixelY)

                    if (!color.valid)
                        return

                    colorHexField.text = color.hex
                }
            }

            Label {
                anchors.centerIn: parent
                visible: osdBmpPreview.status === Image.Null
                text: qsTr("请选择一张 BMP 图片")
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            Label {
                text: qsTr("HEX:")
            }

            Rectangle {
                Layout.preferredWidth: 120
                Layout.preferredHeight: 30

                radius: 2
                color: window.palette.base

                border.color: window.palette.mid
                border.width: 1

                TextInput {
                    id: colorHexField

                    anchors.fill: parent
                    anchors.margins: 4

                    readOnly: true
                    selectByMouse: true
                    clip: true

                    horizontalAlignment: TextInput.AlignHCenter
                    verticalAlignment: TextInput.AlignVCenter

                    color: window.palette.text
                    selectionColor: window.palette.highlight
                    selectedTextColor:
                        window.palette.highlightedText
                }

                // TextInput 为空时显示提示文字。
                Text {
                    anchors.fill: parent

                    visible: colorHexField.text.length === 0
                    text: qsTr("未选择颜色")

                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter

                    color: window.palette.placeholderText
                }
            }

            // 显示当前选中的颜色。
            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30

                radius: 4

                color: colorHexField.text.length > 0
                       ? colorHexField.text
                       : "transparent"

                border.color: "#808080"
                border.width: 1
            }

            Button {
                text: qsTr("选择 BMP 图片")
                onClicked: imageFileDialog.open()
            }
        }
    }
}