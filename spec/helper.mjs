

import { JSDOM } from "jsdom";
import { DA_HTML } from "../src/index.mjs";
import { describe, it, assert } from "da_spec";

const HTML5 = `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title></title>
  </head>
  <body></body>
</html>`;

export function new_dom() {
  return new JSDOM(HTML5);
} // function

export function new_window() {
  const dom = new JSDOM(HTML5);
  return dom.window;
} // function

export function to_html(x) {
  const dom = new JSDOM(HTML5);
  let e = dom.window.document.createElement("div");
  e.appendChild(x.fragment);
  return e.innerHTML;
} // function

export function to_page(x) {
  const dom = new JSDOM(HTML5);
  dom.window.document.appendChild(x.fragment);
  return e.serialize();
} // function

export { DA_HTML, describe, it, assert };
