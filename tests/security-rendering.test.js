const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const scriptPath = path.join(__dirname, "..", "script.js");
const source = fs.readFileSync(scriptPath, "utf8");

test("rendering never sends imported or user-controlled fields through an HTML parser", () => {
  assert.doesNotMatch(source, /\.innerHTML\s*=/);

  const helperSource = source.match(
    /function appendTextElement\(parent, tagName, text, className\) \{[\s\S]*?^\}/m
  );
  assert.ok(helperSource, "safe text rendering helper should exist");

  let textContent;
  const child = {
    set textContent(value) {
      textContent = value;
    },
  };
  const parent = {
    appendChild(element) {
      assert.equal(element, child);
    },
  };
  const documentStub = {
    createElement(tagName) {
      assert.equal(tagName, "div");
      return child;
    },
  };
  const appendTextElement = new Function(
    "document",
    `${helperSource[0]}; return appendTextElement;`
  )(documentStub);

  const payload = '<img src=x onerror="globalThis.compromised=true">';
  appendTextElement(parent, "div", payload);

  assert.equal(textContent, payload);
  assert.equal(globalThis.compromised, undefined);
});
