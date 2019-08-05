--- Gen RQUUID and remove Response Headers policy

local policy = require('apicast.policy')
local _M = policy.new('Gen UUID', '0.1')

local new = _M.new

local to_header = ''
local headers = {}

local function set_request_header(header_name, value)
    ngx.req.set_header(header_name, value)
end

local function delete_request_header(header_name)
    ngx.req.clear_header(header_name)
end

local function delete_resp_header(header_name)
    ngx.header[header_name] = nil
end

-- Initialize the config so we do not have to check for nulls in the rest of
-- the code.
local function init_config(config)
    local res = config or {}
    res.to_header = res.to_header or ''
    res.headers = res.headers or {}
    return res
end

function _M.new(config)
    local self = new(config)
    self.config = init_config(config)

    local header_setval = config.to_header
    local headers = config.headers
    self.headers = headers

    ngx.log(ngx.DEBUG, 'Input header name for RqUUID = ', header_setval)

    if header_setval == nil then
        self.to_header = 'breadcrumbId'
    else
        self.to_header = header_setval
    end

    ngx.log(ngx.DEBUG, 'set rquuid to header ', ngx_var_new_header)
    ngx.log(ngx.DEBUG, 'list to keep header ', ngx_var_header_to_keep)

    return self
end

function _M:rewrite(context)
    -- This is here to avoid calling ngx.req.get_headers() in every command
    -- applied to the request headers.
    local random = math.random
    local rq_time = ngx.req.start_time()
    local rq_dt = os.date('%Y%m%d%H%M%S', rq_time)
    local template ='xxxxxxxxxxxxyyxxxxxxxxxxxxxxyy'
    local rq_uuid_rand = string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v) end)

    local header_val = self.to_header
    local rq_uuid = rq_dt .. "-" .. rq_uuid_rand
    set_request_header(header_val, rq_uuid)
    delete_request_header('app_key')

    ngx.log(ngx.NOTICE, 'In coming request { ', header_val, ' : ', rq_uuid, ', { Body : ', ngx.var.request_body , ' } }')

end

function _M:header_filter(context)

    local headers = self.headers
    local rs_h, err = ngx.resp.get_headers()
    if err == "truncated" then
        -- one can choose to ignore or reject the current response here
        ngx.log(ngx.DEBUG, 'Cannot read response headers')
    else
        local keep_h = '0'
        local xh = ''
        local cmh = ''
        for k, v in pairs(rs_h) do
            ngx.log(ngx.DEBUG, 'header = ', k)
            xh = string.sub(k, 1, 2)
            cmh = string.sub(k, 1, 5)
            if k == 'app_id' or k == 'app_key' or k == 'user_key' then
                delete_resp_header(k)
                ngx.log(ngx.DEBUG, 'header set to nil = ', k)
            elseif xh == 'x-' or cmh == 'camel' then
                keep_h = '0'
                if k == 'x-transaction-id' or k == 'x-correlation-id' or k == 'x-salt-hex' then
                    keep_h = '1'
                    ngx.log(ngx.DEBUG, 'keep header = ', k)
                elseif headers ~= nil then
                    for htk in headers do
                        ngx.log(ngx.DEBUG, 'input keep header = ', htk)
                        if k == string.lowwer(htk) then
                            keep_h = '1'
                            ngx.log(ngx.DEBUG, 'keep header = ', k)
                            break
                        end
                    end
                end

                if keep_h == '0' then
                    delete_resp_header(k)
                    ngx.log(ngx.DEBUG, 'header set to nil = ', k)
                end
            end
        end
    end
end

function _M:body_filter(context)
    local resp = ''
    local header_val = self.to_header
    local rq_uid = ngx.req.get_headers()[header_val]
    ngx.ctx.buffered = (ngx.ctx.buffered or '') .. string.sub(ngx.arg[1], 1, 1000)
    if ngx.arg[2] then
        resp = ngx.ctx.buffered
    end

    ngx.log(ngx.NOTICE, 'Out going response { ',header_val,' : ', rq_uid, ', { Body : ', resp , ' } }')

end

return _M

