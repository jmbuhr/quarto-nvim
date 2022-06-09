local quarto = R'quarto'
local q = vim.treesitter.query
local api = vim.api


local function lines(str)
  local result = {}
  for line in str:gmatch '[^\n]+' do
    table.insert(result, line)
  end
  return result
end


local function get_language_content(bufnr, language)
  -- get and parse AST
  local language_tree = vim.treesitter.get_parser(bufnr, 'markdown')
  local syntax_tree = language_tree:parse()
  local root = syntax_tree[1]:root()

  -- create capture
  local query = vim.treesitter.parse_query('markdown',
  string.gsub([[
  (fenced_code_block
    (info_string
      (language) @lang
      (#eq? @lang $language)
    )
    (code_fence_content) @code (#offset! @code)
  )
  ]], "%$(%w+)", {language=language})
  )

  -- get text ranges
  local results = {}
  for _, captures, metadata in query:iter_matches(root, bufnr) do
    local text = q.get_node_text(captures[2], bufnr)
    -- line numbers start at 0
    -- {start line, col, end line, col}
    local result = {range = metadata.content[1],
                    text = lines(text)}
    table.insert(results, result)
  end

  return results
end

local function spaces(n)
  local s = {}
  for i=1,n do
    s[i] = ' '
  end
  return s
end

local function create_language_buffer(qmd_bufnr, language)
  local language_lines = get_language_content(qmd_bufnr, language)
  local nmax = api.nvim_buf_line_count(qmd_bufnr)
  local qmd_path = api.nvim_buf_get_name(qmd_bufnr)
  local postfix
  if language == 'python' then
    postfix = '.py'
  elseif language == 'r' then
    postfix = '.R'
  end

  -- create buffer filled with spaces
  local bufname_lang = qmd_path..postfix
  local bufuri_lang = 'file://'..bufname_lang
  local bufnr_lang = vim.uri_to_bufnr(bufuri_lang)
  api.nvim_buf_set_name(bufnr_lang, bufname_lang)

  -- local bufnr_lang = api.nvim_create_buf(false, false)
  -- api.nvim_buf_set_name(bufnr_lang, bufname_lang)
  api.nvim_buf_set_lines(bufnr_lang, 0, nmax, false, spaces(nmax))

  -- write langue lines
  for _,t in ipairs(language_lines) do
    api.nvim_buf_set_lines(bufnr_lang, t.range[1], t.range[3], false, t.text)
  end
  return bufnr_lang
end



-- open ./index.qmd
-- get bufnr of qmd document for testing
-- with :ls
local qmd = 1
local lang = 'python'
local bufnr_py = create_language_buffer(qmd, lang)
P(bufnr_py)
-- show buffer to debug
-- local cmd = 'vsplit | b'..bufnr_py
-- vim.cmd(cmd)



vim.lsp.for_each_buffer_client(bufnr_py, function(client, client_id, bufnr)
  P(client_id)
end)


-- delete debug buffer
-- api.nvim_buf_delete(bufnr_py, {force=true})



