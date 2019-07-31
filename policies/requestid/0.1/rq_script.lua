
local _M = require('apicast.policy').new('Gen UUID', '0.1')
local new = _M.new

local ngx_var_new_header = ''

function string.starts(String,Start,Range)
    return string.sub(String,Range,string.len(Start))==Start
end

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
--  local set_header = config.set_header or {}
  local random = math.random
  local rq_time = ngx.req.start_time()
  local rq_dt = os.date('%Y%m%d%H%M%S', rq_time)
  local template ='xxxxxxxxxxxxyyxxxxxxxxxxxxxxyy'
  local rq_uuid_rand = string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v) end)

  local header_val = self.ngx_var_new_header

  local rq_uuid = rq_dt .. "-" .. rq_uuid_rand
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

    local rs_h = ngx.resp.get_headers()
    for k, v in pairs(rs_h) do
        local str = k:gsub("%f[%a]%u+%f[%A]", string.lower)
        if string.starts(str, "x-", 2) or string.starts(str, "Camel", 5) then
            ngx.header[k] = nil
        end
        if str == "app_id" or str == "app_key" or str == "user_key" then
            ngx.header[k] = nil
        end
    end

    ngx.log(0, 'Out going response { ',header_val,' : ', rq_uid, ', { Body : ', resp , ' } }')
  
end



return _M
