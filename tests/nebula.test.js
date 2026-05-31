"use strict";

const { test } = require("node:test");
const assert = require("node:assert/strict");
const Nebula = require("../src/web/nebula.js");

test("clampBpm keeps in-range values untouched", () => {
  assert.equal(Nebula.clampBpm(60), 60);
  assert.equal(Nebula.clampBpm(30), 30);
  assert.equal(Nebula.clampBpm(220), 220);
});

test("clampBpm clamps below the floor and above the ceiling", () => {
  assert.equal(Nebula.clampBpm(0), 30);
  assert.equal(Nebula.clampBpm(-50), 30);
  assert.equal(Nebula.clampBpm(500), 220);
  assert.equal(Nebula.clampBpm(221), 220);
  assert.equal(Nebula.clampBpm(29), 30);
});

test("bpmToPeriodSeconds is one beat per cycle (60 / bpm), clamped", () => {
  assert.equal(Nebula.bpmToPeriodSeconds(60), 1);
  assert.equal(Nebula.bpmToPeriodSeconds(120), 0.5);
  // out-of-range input is clamped first: 10 -> 30 bpm -> 2s
  assert.equal(Nebula.bpmToPeriodSeconds(10), 2);
  // 240 -> 220 bpm
  assert.ok(Math.abs(Nebula.bpmToPeriodSeconds(240) - 60 / 220) < 1e-9);
});

test("bpmToPeriodCss formats seconds with 3 decimals and an s suffix", () => {
  assert.equal(Nebula.bpmToPeriodCss(60), "1.000s");
  assert.equal(Nebula.bpmToPeriodCss(120), "0.500s");
  assert.equal(Nebula.bpmToPeriodCss(90), "0.667s");
});

test("PULSE_KEYFRAMES spans 0..100 and is sorted", () => {
  const k = Nebula.PULSE_KEYFRAMES;
  assert.equal(k[0], 0);
  assert.equal(k[k.length - 1], 100);
  for (let i = 1; i < k.length; i++) assert.ok(k[i] > k[i - 1], "strictly increasing");
});

test("pulseFactor stays within [0, 1] across the whole cycle", () => {
  for (let p = 0; p <= 100; p++) {
    const f = Nebula.pulseFactor(p);
    assert.ok(f >= 0 && f <= 1, `f out of range at p=${p}: ${f}`);
  }
});

test("pulseFactor peaks at the systolic lub (~14%) above the resting tail", () => {
  const lub = Nebula.pulseFactor(14);
  const rest = Nebula.pulseFactor(90);
  assert.ok(lub > rest, "lub peak should exceed the resting phase");
  assert.ok(lub > 0.9, `lub should be near full intensity, got ${lub}`);
});

test("pulseFactor shows a secondary dub bump (~34%) below the lub", () => {
  const dub = Nebula.pulseFactor(34);
  const lub = Nebula.pulseFactor(14);
  const trough = Nebula.pulseFactor(25); // between the two peaks
  assert.ok(dub < lub, "dub should be softer than lub");
  assert.ok(dub > trough, "dub should rise above the inter-peak trough");
});

test("pulseFilterValues returns formatted CSS strings tied to pulseFactor", () => {
  const v = Nebula.pulseFilterValues(14);
  assert.match(v.brightness, /^\d+\.\d{3}$/);
  assert.match(v.saturate, /^\d+\.\d{3}$/);
  assert.match(v.hue, /^\d+\.\d{2}deg$/);
  assert.match(v.scale, /^\d+\.\d{5}$/);
});

test("pulseFilterValues at rest sits at the minimum filter values", () => {
  // p=75 is deep in the resting phase -> f near 0
  const v = Nebula.pulseFilterValues(75);
  assert.ok(parseFloat(v.brightness) >= 0.6, "brightness floor is 0.6");
  assert.ok(parseFloat(v.scale) >= 1.0, "scale floor is 1.0");
});

test("dubDelaySeconds is 20% of the beat period", () => {
  assert.ok(Math.abs(Nebula.dubDelaySeconds(60) - 0.2) < 1e-9);  // 1s period
  assert.ok(Math.abs(Nebula.dubDelaySeconds(120) - 0.1) < 1e-9); // 0.5s period
  // dub must fall inside the cycle, never after it
  assert.ok(Nebula.dubDelaySeconds(220) < Nebula.bpmToPeriodSeconds(220));
});

test("isValidBpm accepts finite numbers, rejects junk", () => {
  assert.equal(Nebula.isValidBpm(72), true);
  assert.equal(Nebula.isValidBpm(0), true); // finite; clamping handles the range
  assert.equal(Nebula.isValidBpm(NaN), false);
  assert.equal(Nebula.isValidBpm(Infinity), false);
  assert.equal(Nebula.isValidBpm(Number("not-a-number")), false);
});

test("formatMeta joins source and time, with a fallback source", () => {
  assert.equal(Nebula.formatMeta("AirPods Pro", "12:30:45"), "AirPods Pro • 12:30:45");
  assert.equal(Nebula.formatMeta("", "12:30:45"), "unknown • 12:30:45");
  assert.equal(Nebula.formatMeta(undefined, "09:00:00"), "unknown • 09:00:00");
});

test("isValidBpm rejects non-numeric types", () => {
  assert.equal(Nebula.isValidBpm(null), false);
  assert.equal(Nebula.isValidBpm(undefined), false);
  assert.equal(Nebula.isValidBpm("72"), false); // string type is not a finite number directly in Number.isFinite
  assert.equal(Nebula.isValidBpm({}), false);
  assert.equal(Nebula.isValidBpm(true), false);
});

test("pulseFactor handles values outside the standard 0-100 range safely", () => {
  // Negative percent
  const negativeFactor = Nebula.pulseFactor(-50);
  assert.ok(negativeFactor >= 0 && negativeFactor <= 1);
  
  // Percent greater than 100
  const largeFactor = Nebula.pulseFactor(150);
  assert.ok(largeFactor >= 0 && largeFactor <= 1);
});

test("pulseFilterValues returns valid object properties for every keyframe in PULSE_KEYFRAMES", () => {
  Nebula.PULSE_KEYFRAMES.forEach(p => {
    const v = Nebula.pulseFilterValues(p);
    
    // Structure check
    assert.ok(v.hasOwnProperty("brightness"));
    assert.ok(v.hasOwnProperty("saturate"));
    assert.ok(v.hasOwnProperty("hue"));
    assert.ok(v.hasOwnProperty("scale"));
    
    // Formats check
    assert.match(v.brightness, /^\d+\.\d{3}$/);
    assert.match(v.saturate, /^\d+\.\d{3}$/);
    assert.match(v.hue, /^\d+\.\d{2}deg$/);
    assert.match(v.scale, /^\d+\.\d{5}$/);
  });
});

test("clampBpm handles numeric string inputs correctly due to JS coercion", () => {
  assert.equal(Nebula.clampBpm("72"), 72);
  assert.equal(Nebula.clampBpm("10"), 30);
  assert.equal(Nebula.clampBpm("300"), 220);
});

