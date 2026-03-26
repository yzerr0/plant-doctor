const { speciesCacheKey } = require('../lib/utils');

describe('speciesCacheKey', () => {
  test('replaces spaces with underscores', () => {
    expect(speciesCacheKey('Monstera deliciosa')).toBe('Monstera_deliciosa');
  });

  test('removes non-alphanumeric characters except underscore and hyphen', () => {
    expect(speciesCacheKey("Rosa canina L.")).toBe('Rosa_canina_L');
  });

  test('handles single-word genus', () => {
    expect(speciesCacheKey('Ficus')).toBe('Ficus');
  });

  test('handles multiple spaces', () => {
    expect(speciesCacheKey('Ficus  benjamina')).toBe('Ficus__benjamina');
  });
});
