/**
 * Normalizes a scientific name to a valid Firestore document ID.
 * Replaces whitespace with underscore; removes periods, apostrophes,
 * and other characters that could cause issues.
 * @param {string} scientificName
 * @returns {string}
 */
function speciesCacheKey(scientificName) {
  return scientificName
    .replace(/\s/g, '_')
    .replace(/[^a-zA-Z0-9_-]/g, '');
}

module.exports = { speciesCacheKey };
