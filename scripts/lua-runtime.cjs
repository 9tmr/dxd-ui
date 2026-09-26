'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');

function fromLua(state, index, seen = new Set(), field = '') {
  const absolute = lua.lua_absindex(state, index);
  switch (lua.lua_type(state, absolute)) {
    case lua.LUA_TNIL: return null;
    case lua.LUA_TBOOLEAN: return lua.lua_toboolean(state, absolute);
    case lua.LUA_TNUMBER: return lua.lua_tonumber(state, absolute);
    case lua.LUA_TSTRING:
      return field === 'Data'
        ? Buffer.from(lua.lua_tolstring(state, absolute)).toString('base64')
        : to_jsstring(lua.lua_tolstring(state, absolute));
    case lua.LUA_TTABLE: {
      const pointer = lua.lua_topointer(state, absolute);
      if (seen.has(pointer)) return '[circular]';
      seen.add(pointer);
      const entries = [];
      lua.lua_pushnil(state);
      while (lua.lua_next(state, absolute)) {
        const key = fromLua(state, -2, seen);
        const value = fromLua(state, -1, seen, String(key));
        entries.push([key === 'Data' ? 'dataBase64' : key, value]);
        lua.lua_pop(state, 1);
      }
      seen.delete(pointer);
      const isArray = entries.length > 0 && entries.every(([key]) => Number.isInteger(key) && key > 0)
        && Math.max(...entries.map(([key]) => key)) === entries.length;
      if (isArray) {
        const array = new Array(entries.length);
        for (const [key, value] of entries) array[key - 1] = value;
        return array;
      }
      return Object.fromEntries(entries);
    }
    default: return `[${to_jsstring(lua.lua_typename(state, lua.lua_type(state, absolute)))}]`;
  }
}

function toLua(state, value) {
  if (value == null) lua.lua_pushnil(state);
  else if (typeof value === 'boolean') lua.lua_pushboolean(state, value);
  else if (typeof value === 'number') lua.lua_pushnumber(state, value);
  else if (Buffer.isBuffer(value) || value instanceof Uint8Array) lua.lua_pushlstring(state, value, value.length);
  else if (typeof value === 'string') lua.lua_pushstring(state, to_luastring(value));
  else if (typeof value === 'object') {
    lua.lua_newtable(state);
    for (const [key, item] of Object.entries(value)) {
      toLua(state, Array.isArray(value) ? Number(key) + 1 : key);
      toLua(state, item);
      lua.lua_settable(state, -3);
    }
  } else throw new TypeError(`Unsupported bridge value: ${typeof value}`);
}

function createRuntime(options = {}) {
  const root = options.root || path.resolve(__dirname, '..');
  const state = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(state);
  const files = new Map(Object.entries(options.files || {}));
  const native = (name, callback) => {
    lua.lua_pushjsfunction(state, (current) => {
      try { return callback(current); }
      catch (error) { lua.lua_pushstring(current, to_luastring(error.message)); return lua.lua_error(current); }
    });
    lua.lua_setglobal(state, to_luastring(name));
  };
  native('base64decode', (current) => {
    const encoded = to_jsstring(lauxlib.luaL_checkstring(current, 1));
    toLua(current, Buffer.from(encoded, 'base64'));
    return 1;
  });
  native('base64encode', (current) => {
    toLua(current, Buffer.from(lauxlib.luaL_checkstring(current, 1)).toString('base64'));
    return 1;
  });
  native('__json_encode', (current) => { toLua(current, JSON.stringify(fromLua(current, 1))); return 1; });
  native('__json_decode', (current) => { toLua(current, JSON.parse(to_jsstring(lauxlib.luaL_checkstring(current, 1)))); return 1; });
  native('isfile', (current) => { toLua(current, files.has(to_jsstring(lauxlib.luaL_checkstring(current, 1)))); return 1; });
  native('readfile', (current) => {
    const filename = to_jsstring(lauxlib.luaL_checkstring(current, 1));
    if (!files.has(filename)) throw new Error(`File not found: ${filename}`);
    toLua(current, files.get(filename)); return 1;
  });
  native('writefile', (current) => {
    files.set(to_jsstring(lauxlib.luaL_checkstring(current, 1)), to_jsstring(lauxlib.luaL_checkstring(current, 2)));
    return 0;
  });
  native('delfile', (current) => { files.delete(to_jsstring(lauxlib.luaL_checkstring(current, 1))); return 0; });
  native('isfolder', (current) => { lua.lua_pushboolean(current, true); return 1; });
  native('makefolder', () => 0);

  function run(source, label = 'test') {
    const base = lua.lua_gettop(state);
    let status = lauxlib.luaL_loadbuffer(state, to_luastring(source), null, to_luastring(`@${label}`));
    if (status === lua.LUA_OK) status = lua.lua_pcall(state, 0, lua.LUA_MULTRET, 0);
    if (status !== lua.LUA_OK) {
      const message = to_jsstring(lua.lua_tolstring(state, -1));
      lua.lua_settop(state, base);
      throw new Error(message);
    }
    const result = lua.lua_gettop(state) > base ? fromLua(state, base + 1) : undefined;
    lua.lua_settop(state, base);
    return result;
  }
  const load = (filename = options.library || path.join(root, 'dxd.lua')) => run(fs.readFileSync(filename, 'utf8'), filename);
  run(fs.readFileSync(path.join(root, 'tests/mock-runtime.lua'), 'utf8'), 'mock-runtime.lua');
  return { state, files, run, load, snapshot: () => run('return __capture()', 'capture'), stats: () => run('return __stats()', 'stats'), close: () => lua.lua_close(state) };
}

module.exports = { createRuntime, fromLua, toLua };
