var Module = {};
var Browser = {};
var lines = [];
var req_handle = 0;
var timeout_callbacks = {};
var line_buffer = "";

var graphic_display = {
  width: 320, 
  height: 200, 
  data: new Uint8Array(320 * 200 * 4)
}

var performance = {
  now() {return Date.now()}
}

function set_timeout_callback(id) {
  timeout_callbacks[id]();
  delete timeout_callbacks[id];
}

function set_interval_callback(id) {
  timeout_callbacks[id]();
}

function safe_script(js) {
  return `try {${js}} catch (e) {app.alert(e.stack || e)}`;
}

function set_timeout(callback, timeout) {
  let id = Math.random()+"";
  timeout_callbacks[id] = callback;
  app.setTimeOut(safe_script(`set_timeout_callback(${id})`), timeout);
}

function set_interval(callback, interval) {
  let id = Math.random()+"";
  timeout_callbacks[id] = callback;
  app.setInterval(safe_script(`set_interval_callback(${id})`), interval);
}

function print_msg(msg) {
  lines.push(""+msg);
  if (lines.length > 25) 
    lines.shift();
  
  for (var i = 0; i < lines.length; i++) {
    var row = lines[i];
    globalThis.getField("console_"+(25-i-1)).value = row;
  }
}

Module.print = function(msg) {
  let max_len = 40;
  let num_lines = Math.ceil(msg.length / max_len);
  
  for (let i = 0, o = 0; i < num_lines; ++i, o += max_len) {
    print_msg(msg.substr(o, max_len));
  }
}
Module.printErr = function(msg) {
  print_msg(msg);
}

function start() {
  update_framebuffer(320, 200, new Uint8Array(320*200*4), 0, 200);
  let cfg_file = typeof embedded_files["vm_32.cfg"] === "undefined" ? "vm_64.cfg" : "vm_32.cfg";
  var args = [`file:///${cfg_file}`, 128, "", null, 0, 0, 1, ""];
  Module.ccall("vm_start", null, ["string", "number", "string", "string", "number", "number", "number", "string"], args);
}

function round_float(num, s) {
  let multiplier = Math.pow(10, s);
  return Math.round(num * multiplier) / multiplier;
}

var total_instrs = 0;
var last_updated = null;

function machine_tick(m_ptr) {
  total_instrs += _virt_machine_run(m_ptr);
  let now = Date.now();
  let time_interval = now - last_updated;
  if (time_interval > 1000) {
    let k_ips = Math.round(total_instrs / ((time_interval) / 1000) / 1000);
    globalThis.getField("speed_indicator").value = `Speed: ${k_ips} kIPS`;
    total_instrs = 0;
    last_updated = now;
  }
}

function start_machine_interval(m_ptr) {
  print_msg("starting the machine. please be patient...")
  last_updated = Date.now();
  set_interval(() => {machine_tick(m_ptr)}, 1)
}

function update_framebuffer(width, height, data, start_y, updated_height) {
  for (let y=start_y; y < start_y + updated_height; y++) {
    let row = Array(width);
    let old_row = row.join("");
    for (let x=0; x < width; x++) {
      let index = (y * width + x) * 4;
      let r = data[index];
      let g = data[index+1];
      let b = data[index+2];
      let avg = (r + g + b) / 3;
      //let avg = (x/width) * 255; // (uncomment for a gradient test)

      //note - these ascii characters were all picked because they have the same width in the sans-serif font that chrome decided to use for text fields
      if (avg > 200)
        row[x] = "_";
      else if (avg > 150)
        row[x] = "::";
      else if (avg > 100)
        row[x] = "?";
      else if (avg > 50)
        row[x] = "//";
      else if (avg > 25)
        row[x] = "b";
      else
        row[x] = "#";
    }
    let row_str = row.join("");
    if (row_str !== old_row)
      globalThis.getField("field_"+(height-y-1)).value = row_str;
  }
}

var key_to_input_map = {
  "Esc": 0x01, "1": 0x02, "2": 0x03, "3": 0x04, "4": 0x05, "5": 0x06, "6": 0x07, 
  "7": 0x08, "8": 0x09, "9": 0x0a, "0": 0x0b, "-": 0x0c, "=": 0x0d, "Backspace": 0x0e, 
  "Tab": 0x0f, "q": 0x10, "w": 0x11, "e": 0x12, "r": 0x13, "t": 0x14, "y": 0x15, 
  "u": 0x16, "i": 0x17, "o": 0x18, "p": 0x19, "[": 0x1a, "]": 0x1b, "Enter": 0x1c, 
  "Ctrl": 0x1d, "a": 0x1e, "s": 0x1f, "d": 0x20, "f": 0x21, "g": 0x22, "h": 0x23, 
  "j": 0x24, "k": 0x25, "l": 0x26, ";": 0x27, "'": 0x28, "`": 0x29, "Shift": 0x2a, 
  "\\": 0x2b, "z": 0x2c, "x": 0x2d, "c": 0x2e, "v": 0x2f, "b": 0x30, "n": 0x31, 
  "m": 0x32, ",": 0x33, ".": 0x34, "/": 0x35, "RShift": 0x36, "Alt": 0x38, "Space": 0x39, 
  "CapsLock": 0x3a, "F1": 0x3b, "F2": 0x3c, "F3": 0x3d, "F4": 0x3e, "F5": 0x3f, 
  "F6": 0x40, "F7": 0x41, "F8": 0x42, "F9": 0x43, "F10": 0x44, "F11": 0x57, "F12": 0x58, 
  "RCtrl": 97, "RAlt": 100, "Home": 102, "ArrowUp": 103, "PgUp": 104, "ArrowLeft": 105, 
  "ArrowRight": 106, "End": 107, "ArrowDown": 108, "PgDn": 109, "Insert": 110, 
  "Delete": 111, "ContextMenu": 127
};

//a map of characters that are emitted when pressing shift, to their original keys
var keys_shifted_map = {
  "~": "`", "!": "1", "@": "2", "#": "4", "%": "5", "^": "6", 
  "&": "7", "*": "8", "(": "9", ")": "0", "_": "-", "+": "=", 
  "{": "[", "}": "]", "|": "\\", ":": ";", "'": "\"", "<": ",", 
  ">": ".", "?": "/"
};

var key_status_map = {};

function setup_keys() {
  for (let key_code of Object.values(key_to_input_map)) {
    key_status_map[key_code] = false;
  }
}

function key_down(key_code) {
  if (key_status_map[key_code])
    return;
  key_status_map[key_code] = true;
  _display_key_event(true, key_code);
}

function key_up(key_code) {
  if (!key_status_map[key_code])
    return;
  key_status_map[key_code] = false;
  _display_key_event(false, key_code);
}

function press_input(key_code) {
  key_down(key_code);
  key_up(key_code);
}

function button_down(key_str) {
  if (typeof key_to_input_map[key_str] === "undefined") 
    app.alert("bad key: " + key_str);
  print_msg("down: " + key_str);
  key_down(key_to_input_map[key_str]);
}

function button_up(key_str) {
  print_msg("up: " + key_str);
  key_up(key_to_input_map[key_str]);
}

var pressed_list = [];
function button_toggle(key_str) {
  if (typeof key_to_input_map[key_str] === "undefined") 
    app.alert("bad key: " + key_str);
  if (key_status_map[key_to_input_map[key_str]]) {
    pressed_list.splice(pressed_list.indexOf(key_str), 1);
    button_up(key_str);
  }
  else {
    pressed_list.push(key_str);
    button_down(key_str);
  }
  globalThis.getField("key_status").value = "Pressed: " + pressed_list.join(", ");
}

function key_pressed(key_str) {
  let key_lower = key_str.toLowerCase();
  let shift_pressed = false;
  if (key_str === " ") {
    key_str = "Space";
  }
  //handle strings that are different than the actual key because they were pressed with shift
  else if (keys_shifted_map[key_str] || key_lower != key_str) {
    key_str = keys_shifted_map[key_str] || key_lower;
    shift_pressed = true;
    key_down(key_to_input_map["Shift"]);
  }

  if (shift_pressed) key_down(key_to_input_map["Shift"]);
  print_msg("pressed: " + key_str);
  press_input(key_to_input_map[key_str]);
  if (shift_pressed) key_up(key_to_input_map["Shift"]);
}

set_interval(() => {
  globalThis.getField("key_input").value = "Type here for keyboard inputs.";
}, 1000)

set_timeout(start, 100);
