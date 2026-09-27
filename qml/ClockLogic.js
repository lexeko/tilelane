.pragma library

function formatDateTime(date, format) {
    // ISO weeks belong to the year containing their Thursday. Use UTC for
    // date arithmetic so daylight-saving changes cannot shift the week.
    const thursday = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
    thursday.setUTCDate(thursday.getUTCDate() + 4 - (thursday.getUTCDay() || 7));
    const yearStart = Date.UTC(thursday.getUTCFullYear(), 0, 1);
    const week = Math.ceil(((thursday.getTime() - yearStart) / 86400000 + 1) / 7);
    const literal = (week < 10 ? "0" : "") + week;
    // Match Omarchy's custom ww token before Qt handles the other fields.
    return Qt.formatDateTime(date, String(format).replace(/ww/g, literal));
}
