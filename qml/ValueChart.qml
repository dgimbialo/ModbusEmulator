import QtQuick

// Real-time line chart drawn on a Canvas with auto-scaling,
// grid lines and a gradient fill under the curve.
Item {
    id: root

    property var values: []
    property int maxPoints: 150
    property color lineColor: Theme.accent

    function push(value) {
        var v = values.slice()
        v.push(value)
        if (v.length > maxPoints)
            v = v.slice(v.length - maxPoints)
        values = v
        canvas.requestPaint()
    }

    function clear() {
        values = []
        canvas.requestPaint()
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d")
            var w = width
            var h = height
            ctx.reset()

            var padL = 52
            var padR = 12
            var padT = 12
            var padB = 22
            var plotW = w - padL - padR
            var plotH = h - padT - padB

            // Value range with padding
            var vals = root.values
            var minV = 0
            var maxV = 100
            if (vals.length > 0) {
                minV = Math.min.apply(null, vals)
                maxV = Math.max.apply(null, vals)
                if (minV === maxV) { minV -= 1; maxV += 1 }
                var pad = (maxV - minV) * 0.1
                minV -= pad
                maxV += pad
            }

            // Grid + axis labels
            ctx.strokeStyle = Theme.border
            ctx.fillStyle = Theme.textSecondary
            ctx.lineWidth = 1
            ctx.font = "10px " + Theme.monoFont
            ctx.textAlign = "right"
            var gridLines = 4
            for (var g = 0; g <= gridLines; ++g) {
                var y = padT + plotH * g / gridLines
                ctx.beginPath()
                ctx.moveTo(padL, y)
                ctx.lineTo(w - padR, y)
                ctx.stroke()
                var labelVal = maxV - (maxV - minV) * g / gridLines
                ctx.fillText(Math.round(labelVal).toString(), padL - 6, y + 3)
            }

            if (vals.length < 2)
                return

            var stepX = plotW / (root.maxPoints - 1)
            function px(i) { return padL + i * stepX }
            function py(v) { return padT + plotH * (1 - (v - minV) / (maxV - minV)) }

            // Gradient fill under the curve
            var gradient = ctx.createLinearGradient(0, padT, 0, padT + plotH)
            gradient.addColorStop(0, Qt.rgba(root.lineColor.r, root.lineColor.g, root.lineColor.b, 0.30))
            gradient.addColorStop(1, Qt.rgba(root.lineColor.r, root.lineColor.g, root.lineColor.b, 0.02))
            ctx.beginPath()
            ctx.moveTo(px(0), py(vals[0]))
            for (var i = 1; i < vals.length; ++i)
                ctx.lineTo(px(i), py(vals[i]))
            ctx.lineTo(px(vals.length - 1), padT + plotH)
            ctx.lineTo(px(0), padT + plotH)
            ctx.closePath()
            ctx.fillStyle = gradient
            ctx.fill()

            // Curve
            ctx.beginPath()
            ctx.moveTo(px(0), py(vals[0]))
            for (var j = 1; j < vals.length; ++j)
                ctx.lineTo(px(j), py(vals[j]))
            ctx.strokeStyle = root.lineColor
            ctx.lineWidth = 2
            ctx.stroke()

            // Last point marker + value
            var lastX = px(vals.length - 1)
            var lastY = py(vals[vals.length - 1])
            ctx.beginPath()
            ctx.arc(lastX, lastY, 3.5, 0, Math.PI * 2)
            ctx.fillStyle = root.lineColor
            ctx.fill()
        }
    }

    // Empty state hint
    Text {
        anchors.centerIn: parent
        visible: root.values.length < 2
        text: qsTr("Waiting for samples...")
        color: Theme.textDisabled
        font.pixelSize: Theme.fontSizeNormal
    }
}
