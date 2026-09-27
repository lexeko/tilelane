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
