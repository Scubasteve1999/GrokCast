import assert from "node:assert/strict";
import { test } from "node:test";

import { bearerToken, secureCompare } from "../src/auth.ts";
import { conditionText } from "../src/openmeteo.ts";

test("secureCompare matches only identical strings", () => {
  assert.equal(secureCompare("s3cret", "s3cret"), true);
  assert.equal(secureCompare("s3cret", "s3cres"), false);
  assert.equal(secureCompare("s3cret", "s3cret "), false);
  assert.equal(secureCompare("", ""), true);
});

test("bearerToken parses the header case-insensitively and tolerates spacing", () => {
  assert.equal(bearerToken("Bearer abc123"), "abc123");
  assert.equal(bearerToken("bearer   abc123  "), "abc123");
  assert.equal(bearerToken("Basic abc123"), null);
  assert.equal(bearerToken(null), null);
  assert.equal(bearerToken("Bearer"), null);
});

test("conditionText mirrors WeatherCondition.displayText across the WMO ranges", () => {
  assert.equal(conditionText(0), "Clear");
  assert.equal(conditionText(2), "Mainly Clear");
  assert.equal(conditionText(3), "Overcast");
  assert.equal(conditionText(48), "Fog");
  assert.equal(conditionText(53), "Drizzle");
  assert.equal(conditionText(63), "Rain");
  assert.equal(conditionText(67), "Sleet");
  assert.equal(conditionText(73), "Snow");
  assert.equal(conditionText(77), "Snow Grains");
  assert.equal(conditionText(81), "Rain Showers");
  assert.equal(conditionText(86), "Snow Showers");
  assert.equal(conditionText(96), "Thunderstorm");
  assert.equal(conditionText(42), "Variable");
});
