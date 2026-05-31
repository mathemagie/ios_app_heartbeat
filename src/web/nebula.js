// Pure, DOM-free helpers shared by the web pages and the unit tests.
// UMD-style: exposed as `window.Nebula` in the browser and as a CommonJS
// module under Node so the logic is tested exactly as the pages run it.
(function (global) {
  "use strict";

  // The BPM the visuals and sound actually beat at, clamped to a sane band
  // so a glitchy sample can't freeze the animation or scream the audio.
  function clampBpm(bpm) {
    return Math.max(30, Math.min(220, bpm));
  }

  // One beat per cycle: the animation period in seconds for a given BPM.
  function bpmToPeriodSeconds(bpm) {
    return 60 / clampBpm(bpm);
  }

  // The same period as a CSS animation-duration string.
  function bpmToPeriodCss(bpm) {
    return bpmToPeriodSeconds(bpm).toFixed(3) + "s";
  }

  // The keyframe percents the breathing animation is sampled at.
  var PULSE_KEYFRAMES = [0, 6, 12, 18, 25, 33, 42, 50, 58, 67, 75, 83, 91, 100];

  // Breathing intensity f in [0,1] at a keyframe percent p in [0,100]:
  // a strong systolic "lub", a softer "dub", plus a faint baseline tremor.
  function pulseFactor(p) {
    var lubCenter = 14, lubWidth = 9, dubCenter = 34, dubWidth = 11, dubAmp = 0.6;
    var lub = Math.exp(-Math.pow((p - lubCenter) / lubWidth, 2));
    var dub = dubAmp * Math.exp(-Math.pow((p - dubCenter) / dubWidth, 2));
    var baseline = 0.04 * (Math.sin((p / 100) * 2 * Math.PI * 1.7) + 1) / 2;
    return Math.max(0, Math.min(1, lub + dub + baseline));
  }

  // The CSS custom-property values driving one keyframe of the pulse.
  function pulseFilterValues(p) {
    var intensity = 1.5, maxSat = 1.5, maxHue = 6, maxScale = 1.016;
    var minBright = Math.max(0.6, intensity - 0.4), minSat = 0.9, minScale = 1.0;
    var f = pulseFactor(p);
    return {
      brightness: (minBright + (intensity - minBright) * f).toFixed(3),
      saturate: (minSat + (maxSat - minSat) * f).toFixed(3),
      hue: (maxHue * f).toFixed(2) + "deg",
      scale: (minScale + (maxScale - minScale) * f).toFixed(5),
    };
  }

  // When the soft "dub" thump fires within a beat cycle, in seconds
  // (lub at 0, dub at 20% of the period — tracks the visual keyframes).
  function dubDelaySeconds(bpm) {
    return 0.20 * bpmToPeriodSeconds(bpm);
  }

  // Whether an incoming heart-rate value is renderable on the client.
  function isValidBpm(bpm) {
    return Number.isFinite(bpm);
  }

  // The quiet "source • time" caption shown once a real beat arrives.
  // Takes an already-formatted time string so it stays locale-independent.
  function formatMeta(source, timeString) {
    return (source || "unknown") + " • " + timeString;
  }

  var api = {
    clampBpm: clampBpm,
    bpmToPeriodSeconds: bpmToPeriodSeconds,
    bpmToPeriodCss: bpmToPeriodCss,
    PULSE_KEYFRAMES: PULSE_KEYFRAMES,
    pulseFactor: pulseFactor,
    pulseFilterValues: pulseFilterValues,
    dubDelaySeconds: dubDelaySeconds,
    isValidBpm: isValidBpm,
    formatMeta: formatMeta,
  };

  if (typeof module !== "undefined" && module.exports) module.exports = api;
  if (typeof window !== "undefined") global.Nebula = api;
})(typeof window !== "undefined" ? window : globalThis);
