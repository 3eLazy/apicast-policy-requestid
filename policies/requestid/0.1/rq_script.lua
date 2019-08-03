
local _M = require('apicast.policy').new('Gen UUID', '0.1')
local new = _M.new

local ngx_var_new_header = ''
local ngx_var_header_to_keep = ''

function _M.new(config)
    local self = new(config)
    local header_setval = config.gen_request_header
    -- ngx.log(0, 'get vakue fron header', header_setval)

    local header_to_keep = config.list_header_to_keep
    self.ngx_var_header_to_keep = header_to_keep

    if header_setval == nil then
        self.ngx_var_new_header = 'breadcrumbId'
    else
        self.ngx_var_new_header = header_setval
    end

    ngx.log(0, 'set rquuid to header', ngx_var_new_header)
    ngx.log(0, 'list to keep header', ngx_var_header_to_keep)

    return self
end

function _M:rewrite()
    local config = configuration or {}
    local set_header = config.set_header or {}
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

    local header_to_keep = self.ngx_var_header_to_keep
    local rs_h = ngx.resp.get_headers()
    ngx.log(0, 'header to keep = ', header_to_keep)
    ngx.log(0, 'response header = ', rs_h)
    for k, v in pairs(rs_h) do
        ngx.log(0, 'header = ', k)
        local str = k:gsub("%f[%a]%u+%f[%A]", string.lower)
        ngx.log(0, 'header lower = ', str)
        if string.sub(str, 1, 2) == "x-" or string.sub(str, 1, 5) == "camel" then
            local keep_h = 0
            if str == "x-transaction-id" or str == "x-correlation-id" or str == "x-salt-hex" then
                keep_h = 1
                ngx.log(0, 'match header = ', k)
            else
                if header_to_keep ~= nil or header_to_keep ~= "" then
                    for htk in string.gmatch(header_to_keep, "([^"..",".."]+)") do
                        ngx.log(0, 'extra keep header = ', htk)
                        local strhtk = htk:gsub("%f[%a]%u+%f[%A]", string.lower)
                        ngx.log(0, 'extra keep header lower = ', strhtk)
                        if str == strhtk then
                            keep_h = 1
                            ngx.log(0, 'match header = ', k)
                            break
                        end
                    end
                end
            end
            if keep_h ~= 1 then
                ngx.header[k] = nil
                gx.log(0, 'header set to nil = ', k)
            end
        end
        if str == "app_id" or str == "app_key" or str == "user_key" then
            ngx.header[k] = nil
            gx.log(0, 'header set to nil = ', k)
        end
    end

    ngx.log(0, 'Out going response { ',header_val,' : ', rq_uid, ', { Body : ', resp , ' } }')

end



return _M
