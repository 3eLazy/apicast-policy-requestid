
local _M = require('apicast.policy').new('Gen UUID', '0.1')
local new = _M.new

local ngx_var_new_header = ''

function _M.new(config)
  local self = new(config)
  local header_setval = config.gen_request_header
  ngx.log(0, 'get vakue fron header', header_setval)

  if header_setval == nil then
    self.ngx_var_new_header = 'breadcrumbId'
  else
    self.ngx_var_new_header = header_setval
  end
  
  ngx.log(0, 'get vakue fron header', ngx_var_new_header)
  
  return self
end

function _M:rewrite()
  local config = configuration or {}
  local set_header = config.set_header or {}
  local random = math.random
  local template ='xxxxxxxxxxxxyyxxxxxxxxxxxxxxyy'
  local rq_uuid = string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v) end)

  local header_val = self.ngx_var_new_header
  
  ngx.req.set_header(header_val, rq_uuid)
  ngx.log(0, 'In coming request { ', header_val, ' : ', rq_uuid, ', { Body : ', ngx.var.request_body , ' } }')
  
end

function _M:body_filter()
    local resp = ""
    local header_val = self.ngx_var_new_header
    local rq_uid = ngx.req.get_headers()[header_val]
    ngx.ctx.buffered = (ngx.ctx.buffered or "") .. string.sub(ngx.arg[1], 1, 1000)
    if ngx.arg[2] then
      resp = ngx.ctx.buffered
    end

    ngx.log(0, 'Out going response { ',header_val,' : ', rq_uid, ', { Body : ', resp , ' } }')
  
end



return _M
