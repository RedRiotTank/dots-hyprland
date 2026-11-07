import qs.modules.common
import QtQuick

// Simple vertical bar visualizer for cava output.
Canvas {
    id: root
    property list<var> points: []
    property real maxVisualizerValue: 1000
    property color color: Appearance.colors.colPrimary
    property real minimumBarHeight: 2
    property real barGapRatio: 0.35
    property int smoothing: 1

    onPointsChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);

        const values = root.points ?? [];
        const count = values.length;
        if (count < 1 || width <= 0 || height <= 0) return;

        const maxValue = root.maxVisualizerValue || 1;
        const gap = Math.max(1, (width / count) * root.barGapRatio);
        const barWidth = Math.max(1, (width - gap * (count - 1)) / count);
        ctx.fillStyle = root.color;

        for (let index = 0; index < count; ++index) {
            let sum = 0;
            let samples = 0;
            for (let offset = -root.smoothing; offset <= root.smoothing; ++offset) {
                const sampleIndex = Math.max(0, Math.min(count - 1, index + offset));
                sum += values[sampleIndex] ?? 0;
                samples += 1;
            }
            const value = Math.max(0, Math.min(maxValue, sum / samples));
            const barHeight = Math.max(root.minimumBarHeight, (value / maxValue) * height);
            const x = index * (barWidth + gap);
            ctx.fillRect(x, height - barHeight, barWidth, barHeight);
        }
    }
}
