--- Gen RQUUID and remove Response Headers policy
local policy = require('apicast.policy')
local _M = policy.new('Gen UUID', '0.1')

local new = _M.new

local t_header = ''
local k_headers = ''
local t_rquuid = ''

function _M.new(config)
    local self = new(config)

    local header_setval = config.to_header
    local headers_keep = config.keep_headers

    if header_setval == nil then
        self.t_header = 'breadcrumbId'
    else
        self.t_header = header_setval
    end

    if headers_keep == nil then
        self.k_headers = 'novalue'
    else
        self.k_headers = headers_keep
    end

    ngx.log(ngx.DEBUG, 'set rquuid to header ', t_header)
    ngx.log(ngx.DEBUG, 'list to keep headers ', k_headers)

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

    local header_val = self.t_header
    local rq_uuid = rq_dt .. "-" .. rq_uuid_rand
    self.t_rquuid = rq_uuid
    ngx.log(ngx.DEBUG, 'generated rquuid = ', t_rquuid)
    ngx.req.set_header(header_val, rq_uuid)
    local rq_app_id = ngx.req.get_headers()['app_id']
    local rq_app_key = ngx.req.get_headers()['app_key']
    local rq_user_key = ngx.req.get_headers()['user_key']
    if rq_app_id ~= nil and rq_app_key ~= nil then
        local access_key = 'app_id: '..rq_app_id..', app_key: '..rq_app_key
        ngx.log(ngx.DEBUG, 'Access Key is { '..access_key..' }')
        ngx.req.clear_header('app_key')
    else
        ngx.log(ngx.DEBUG, 'Access Key is missing')
    end
    if rq_user_key ~= nil then
        local access_key = 'user_key: '..rq_user_key
        ngx.log(ngx.DEBUG, 'Access Key is { '..access_key..' }')
        ngx.req.clear_header('user_key')
    end

    ngx.log(ngx.WARN, 'In coming request { ', header_val, ' : ', rq_uuid, ', { Body : ', ngx.var.request_body , ' } }')
    ngx.header['server'] = 'Unknown'
    ngx.header['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'
end

function _M:header_filter()
    local header_to_keep = self.k_headers
    ngx.log(ngx.DEBUG, 'header to keep = ', header_to_keep)
    local rs_h, err = ngx.resp.get_headers()

    if err == "truncated" then
        -- one can choose to ignore or reject the current response here
        ngx.log(ngx.DEBUG, 'Cannot read response header')
    else
        local keep_h = '0'
        local xh = ''
        local cmh = ''
        for k, v in pairs(rs_h) do
            ngx.log(ngx.DEBUG, 'header = ', k)
            xh = string.sub(k, 1, 2)
            cmh = string.sub(k, 1, 5)
            -- app_id, app_key and user_key cannot remove from response header, it can remove on request only
            if xh == 'x-' or cmh == 'camel' or k == 'forwarded' then
                keep_h = '0'
                if k == 'x-transaction-id' or k == 'x-correlation-id' or k == 'x-salt-hex' then
                    keep_h = '1'
                    ngx.log(ngx.DEBUG, 'keep header = ', k)
                elseif header_to_keep ~= nil or header_to_keep ~= 'novalue' then
                    for htk in string.gmatch(header_to_keep, "([^"..",".."]+)") do
                        ngx.log(ngx.DEBUG, 'input keep header = ', htk)
                        if k == string.lower(htk) then
                            keep_h = '1'
                            ngx.log(ngx.DEBUG, 'keep header = ', k)
                            break
                        end
                    end
                end

                if keep_h == '0' then
                    ngx.header[k] = nil
                    ngx.log(ngx.DEBUG, 'header set to nil = ', k)
                end
            end
        end
        ngx.header['server'] = 'Unknown'
        ngx.header['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'
    end
end

function _M:body_filter()
    local resp = ""
    local header_val = self.t_header
    local rq_uuid = self.t_rquuid
    ngx.ctx.buffered = (ngx.ctx.buffered or "") .. string.sub(ngx.arg[1], 1, 1000)
    if ngx.arg[2] then
        resp = ngx.ctx.buffered
    end

    ngx.log(ngx.WARN, 'Out going response { ',header_val,' : ', rq_uuid, ', { Body : ', resp , ' } }')
    ngx.header['server'] = 'Unknown'
    ngx.header['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'
end

return _M
