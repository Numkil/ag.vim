-- > package.loaded[ 'agvim' ] = nil
-- > x = require("agvim")
-- > x.get_file("abc|")
-- abc|
-- lua agvim = require("agvim")
-- call v:lua.agvim.as_args()

local function get_fname(entry)
  local idx = string.find(entry, "|")
  if idx == nil then
    return nil
  end
  return string.sub(entry, 1, idx-1)
end

local function extract_files(lines)
  local seen = {}
  local files = {}
  local n = 1
  for _, v in ipairs(lines) do
    local fn = get_fname(v)
    if fn and not seen[fn] then
      seen[fn] = true
      files[n] = fn
      n = n+1
    end
  end
  return files
end

local function as_args()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local files = extract_files(lines)

  for i,v in ipairs(files) do
    files[i] = vim.api.nvim_call_function("fnameescape",{v})
  end
  vim.api.nvim_command("close")
  vim.api.nvim_command("args " .. table.concat(files, " "))
end

return {
  as_args = as_args
}
