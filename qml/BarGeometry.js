.pragma library

var baseHeight = 44

function sanePositive(value, fallback) {
  var number = Number(value)
  return isFinite(number) && number > 0 ? number : fallback
}

function barScale(spacingScale, scaleWithFont, fontScale) {
  var spacing = sanePositive(spacingScale, 1)
  var font = sanePositive(fontScale, 1)
  return spacing * (scaleWithFont === false ? 1 : font)
}

function barHeight(scale) {
  return baseHeight * sanePositive(scale, 1)
}

function statusCompact(screenWidth, scale) {
  var width = Number(screenWidth)
  var safeScale = sanePositive(scale, 1)
  if (!isFinite(width) || width <= 0) return false
  return width / safeScale < 900
}

function motionDuration(duration, reducedMotion) {
  var value = Math.max(0, Number(duration) || 0)
  return reducedMotion === true ? 0 : value
}

function taskOverflowing(contentWidth, availableWidth) {
  var content = Math.max(0, Number(contentWidth) || 0)
  var available = Math.max(0, Number(availableWidth) || 0)
  return content > available + 0.5
}

// Lower a shared cap until the tasks fit. Short titles keep their natural
// width; long titles stop shrinking at the readability floor.
function taskWidthCap(preferredWidths, availableWidth, spacing, minimumWidth) {
  var widths = preferredWidths.slice().sort(function(a, b) { return a - b })
  if (!widths.length) return 0
  var remaining = Math.max(0, availableWidth - Math.max(0, widths.length - 1) * spacing)
  for (var i = 0; i < widths.length; i++) {
    var cap = remaining / (widths.length - i)
    if (widths[i] > cap) return Math.max(minimumWidth, cap)
    remaining -= widths[i]
  }
  return widths[widths.length - 1]
}

function taskMaximumScroll(contentWidth, viewportWidth) {
  var content = Math.max(0, Number(contentWidth) || 0)
  var viewport = Math.max(0, Number(viewportWidth) || 0)
  return Math.max(0, content - viewport)
}

function taskScrollOffset(currentOffset, amount, contentWidth, viewportWidth) {
  var current = Number(currentOffset) || 0
  var delta = Number(amount) || 0
  return Math.max(0, Math.min(taskMaximumScroll(contentWidth, viewportWidth), current + delta))
}

// Keep the new task out of the edge fades. At either end the corresponding
// fade disappears; clamping permits the button to sit against that edge.
function taskRevealOffset(currentOffset, taskX, taskWidth, contentWidth, viewportWidth, fadeWidth) {
  var maximum = taskMaximumScroll(contentWidth, viewportWidth)
  var offset = taskScrollOffset(currentOffset, 0, contentWidth, viewportWidth)
  if (viewportWidth <= 0) return offset
  var fade = Math.max(0, fadeWidth)
  if (taskWidth >= viewportWidth) return taskScrollOffset(taskX, 0, contentWidth, viewportWidth)
  if (taskX < offset + (offset > 0.5 ? fade : 0))
    return taskScrollOffset(taskX - fade, 0, contentWidth, viewportWidth)
  if (taskX + taskWidth > offset + viewportWidth - (offset < maximum - 0.5 ? fade : 0))
    return taskScrollOffset(taskX + taskWidth - viewportWidth + fade, 0, contentWidth, viewportWidth)
  return offset
}
