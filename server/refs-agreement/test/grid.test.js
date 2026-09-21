import assert from "node:assert/strict";
import test from "node:test";
import { domainFor, gridIndex } from "../src/grid.js";

const conus = {
  kind: "lambert",
  radius: 6_371_229,
  nx: 1799,
  ny: 1059,
  lat1: 21.138,
  lon1: 237.28,
  lad: 38.5,
  lov: 262.5,
  dx: 3000,
  dy: 3000,
  latin1: 38.5,
  latin2: 38.5,
  projectionCenter: 0,
};

const hawaii = {
  kind: "mercator",
  radius: 6_371_229,
  nx: 321,
  ny: 225,
  lat1: 18.072699,
  lon1: 198.474999,
  lad: 20,
  dx: 2500,
  dy: 2500,
};

const alaska = {
  kind: "polar",
  radius: 6_371_229,
  nx: 1649,
  ny: 1105,
  lat1: 40.53,
  lon1: 181.429,
  lad: 60,
  lov: 210,
  dx: 2976,
  dy: 2976,
  projectionCenter: 0,
};

const puertoRico = {
  kind: "mercator",
  radius: 6_371_229,
  nx: 544,
  ny: 310,
  lat1: 15,
  lon1: 284.5,
  lad: 20,
  dx: 2500,
  dy: 2500,
};

test("domain covers the country, not one city", () => {
  assert.equal(domainFor(35.15, -90.05), "conus");
  assert.equal(domainFor(61.22, -149.9), "ak");
  assert.equal(domainFor(21.31, -157.86), "hi");
  assert.equal(domainFor(18.47, -66.11), "pr");
  assert.equal(domainFor(51.5, -0.12), null);
});

test("nearest index matches eccodes on each domain", () => {
  assert.equal(gridIndex(conus, 35.1495, -90.049).index, 745911);
  assert.equal(gridIndex(hawaii, 21.3069, -157.8583).index, 46377);
  assert.equal(gridIndex(alaska, 61.2181, -149.9003).index, 975441);
  assert.equal(gridIndex(puertoRico, 18.4655, -66.1057).index, 82537);
});
