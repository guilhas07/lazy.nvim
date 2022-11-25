-- Simple string cache with fast saving and loading from file
local M = {}

local cache_path = vim.fn.stdpath("state") .. "/lazy/plugins.state"
---@type string
local cache_hash = nil
local dirty = false

---@type table<string,boolean>
local used = {}

---@type table<string,string>
local cache = {}

---@return string?
function M.get(key)
  if cache[key] then
    used[key] = true
    return cache[key]
  end
end

function M.set(key, value)
  cache[key] = value
  used[key] = true
  dirty = true
end

function M.del(key)
  cache[key] = nil
  dirty = true
end

function M.dirty()
  dirty = true
end

function M.use(pattern)
  for key, _ in pairs(cache) do
    if key:find(pattern) then
      used[key] = true
    end
  end
end

function M.hash(file)
  local stat = vim.loop.fs_stat(file)
  return stat and (stat.mtime.sec .. stat.mtime.nsec .. stat.size)
end

function M.setup()
  M.load()
  vim.api.nvim_create_autocmd("User", {
    pattern = "LazyDone",
    once = true,
    callback = function()
      vim.api.nvim_create_autocmd("VimLeavePre", {
        callback = function()
          if dirty then
            local hash = M.hash(cache_path)
            -- abort when the file was changed in the meantime
            if hash == nil or cache_hash == hash then
              M.save()
            end
          end
        end,
      })
    end,
  })
end

function M.save()
  require("lazy.core.state").save()
  require("lazy.core.module").save()

  vim.fn.mkdir(vim.fn.fnamemodify(cache_path, ":p:h"), "p")
  local f = assert(io.open(cache_path, "wb"))
  for key, value in pairs(cache) do
    if used[key] then
      f:write(key, "\0", tostring(#value), "\0", value)
    end
  end
  f:close()
end

function M.load()
  cache = {}
  local f = io.open(cache_path, "rb")
  if f then
    cache_hash = M.hash(cache_path)
    ---@type string
    local data = f:read("*a")
    f:close()

    local from = 1
    local to = data:find("\0", from, true)
    while to do
      local key = data:sub(from, to - 1)
      from = to + 1
      to = data:find("\0", from, true)
      local len = tonumber(data:sub(from, to - 1))
      from = to + 1
      cache[key] = data:sub(from, from + len - 1)
      from = from + len
      to = data:find("\0", from, true)
    end
  end
end

return M